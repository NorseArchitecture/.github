#!/usr/bin/env pwsh
#
# scatter-the-runes.ps1
#
# Fans canonical config files from config/ to every realm in the org as
# auto-merge PRs. Idempotent: re-running pushes a new commit onto any existing
# sync/platform-config branch, updating open PRs without creating duplicates.
#
# Realm discovery is live (gh repo list) and classification is by exception —
# see config/manifest.psd1. Onboarding a new default realm needs no edits here.
#
# Requirements:
#   GH_TOKEN — PAT with repo scope + read:org (set in CI via SCATTER_PAT secret;
#              locally via `gh auth login` or env var)
#   git user.name and user.email configured (the workflow step sets these)
#
# Usage:
#   pwsh scripts/scatter-the-runes.ps1                  # all discovered realms
#   pwsh scripts/scatter-the-runes.ps1 Svartalfheim     # one realm
#   pwsh scripts/scatter-the-runes.ps1 -DryRun          # print plan, no writes

param(
	[Parameter(ValueFromRemainingArguments)]
	[string[]]$Realms,
	[switch]$DryRun,
	[switch]$Audit,
	[string[]]$AcceptDivergence = @()
)

$ErrorActionPreference = 'Stop'

$Org       = 'NorseArchitecture'
$Branch    = 'sync/platform-config'
$ConfigDir = Join-Path $PSScriptRoot '../config'
$Manifest  = Import-PowerShellDataFile (Join-Path $ConfigDir 'manifest.psd1')

. (Join-Path $PSScriptRoot 'lib/realm-classification.ps1')
. "$PSScriptRoot/lib/rune-lineage.ps1"

function Get-RealmFiles {
	param([string]$RealmName)
	$Files = [System.Collections.Generic.SortedSet[string]]::new(
		[System.StringComparer]::OrdinalIgnoreCase)
	foreach ($GroupName in (Get-RealmGroups $Manifest $RealmName)) {
		foreach ($File in $Manifest.Groups[$GroupName]) {
			[void]$Files.Add($File)
		}
	}
	@($Files)
}

$DiscoveredRepos = Get-OrgRepos $Org

if ($Realms) {
	$UnknownRealms = $Realms | Where-Object { $_ -notin $DiscoveredRepos }
	foreach ($Unknown in $UnknownRealms) {
		Write-Warning "==> $Unknown not found in $Org — skipping"
	}
	$ExcludedRealms = $Realms | Where-Object { $_ -in $Manifest.ScatterExcludes }
	foreach ($Excluded in $ExcludedRealms) {
		Write-Warning "==> $Excluded is in ScatterExcludes — skipping"
	}
	$TargetRealms = $Realms | Where-Object { $_ -in $DiscoveredRepos -and $_ -notin $Manifest.ScatterExcludes }
} else {
	$TargetRealms = $DiscoveredRepos | Where-Object { $_ -notin $Manifest.ScatterExcludes } | Sort-Object
}

$Failures = @()

foreach ($Realm in $TargetRealms) {
	$Files          = Get-RealmFiles $Realm
	$Classification = if ($Manifest.Exceptions.ContainsKey($Realm)) { 'exception' } else { 'default' }
	Write-Host "==> $Org/$Realm ($Classification, $($Files.Count) files)"

	if ($DryRun) {
		Write-Host "    [DRY RUN] Would sync: $($Files -join ', ')"
		continue
	}

	$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "scatter-$Realm-$(New-Guid)"

	try {
		Write-Host '    Cloning...'
		gh repo clone "$Org/$Realm" $TempDir -- --depth 1 --quiet
		if ($LASTEXITCODE -ne 0) { throw "gh repo clone failed (exit $LASTEXITCODE)" }

		Push-Location $TempDir

		$RemoteBranchExists = git ls-remote --heads origin $Branch 2>$null
		if ($RemoteBranchExists) {
			git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
			git fetch origin $Branch --quiet
			git checkout -b $Branch "origin/$Branch" --quiet
		} else {
			git checkout -b $Branch --quiet
		}
		if ($LASTEXITCODE -ne 0) { throw "branch checkout failed (exit $LASTEXITCODE)" }

		$Report = foreach ($File in $Files) {
			# {Realm} in a manifest filename is a token — substitute it the same way the copy
			# loop below does before probing/hashing the real on-disk file. Comparing against the
			# raw tokenized path (literal braces) never exists on disk, so Test-Path always failed
			# and every {Realm}-tokenized file (e.g. {Realm}.sln.DotSettings) silently classified
			# as 'Stale' instead of actually being checked for realm divergence.
			$RealmFile = $File -replace '\{Realm\}', $Realm
			$Dest = Join-Path $TempDir $RealmFile
			$Classification = (Test-Path $Dest) ?
				(Get-RuneClassification -ConfigRepo $PSScriptRoot/.. -CanonicalRelPath "config/$File" -DestFile $Dest) :
				'Stale'   # a file the realm never had is just not-yet-scattered
			[pscustomobject]@{ Realm = $Realm; File = $RealmFile; State = $Classification }
		}
		$Report | ForEach-Object { Write-Host "    [$($_.State)] $($_.File)" }
		if ($Audit) { continue }   # audit mode reports and touches nothing

		$Unavailable = @($Report | Where-Object State -eq 'LineageUnavailable')
		if ($Unavailable) { throw "Lineage unavailable for $($Unavailable.Count) file(s) in $Realm — full history of the config repo is required (no shallow checkout). Files: $($Unavailable.File -join ', ')" }

		$Divergent = @($Report | Where-Object { $_.State -eq 'Divergent' -and "$Realm/$($_.File)" -notin $AcceptDivergence })
		if ($Divergent) { throw "Refusing to overwrite realm-divergent file(s) in $Realm — a scattered file is canonical by definition; realm law lives in Directory.Analyzers.props or Directory.Realm.targets. Re-run with -AcceptDivergence for a deliberate reversion. Files: $($Divergent.File -join ', ')" }

		foreach ($File in $Files) {
			# {Realm} in a manifest path is a filename token: the source file carries the
			# literal braces name in config/; the destination substitutes the repo name
			# (first case: {Realm}.sln.DotSettings — R# names its team-shared layer after
			# the solution, and every realm's solution is named for the repo).
			$Source  = Join-Path $ConfigDir $File
			$Dest    = Join-Path $TempDir ($File -replace '\{Realm\}', $Realm)
			$DestDir = Split-Path -Parent $Dest
			if (-not (Test-Path $DestDir)) {
				New-Item -ItemType Directory -Path $DestDir | Out-Null
			}
			Copy-Item -Path $Source -Destination $Dest -Force
		}

		git add --all
		git diff --cached --quiet
		if ($LASTEXITCODE -eq 0) {
			Write-Host '    No changes — skipping.'
			continue
		}

		git commit -m 'sync: platform config from Ginnungagap' --quiet
		if ($LASTEXITCODE -ne 0) { throw "git commit failed (exit $LASTEXITCODE)" }

		git push origin $Branch --force-with-lease --quiet
		if ($LASTEXITCODE -ne 0) { throw "git push failed (exit $LASTEXITCODE)" }

		$PrNumber = gh pr list `
			--repo "$Org/$Realm" `
			--head $Branch `
			--state open `
			--json number `
			--jq '.[0].number'

		if (-not $PrNumber) {
			Write-Host '    Opening PR...'
			$PrUrl = gh pr create `
				--repo "$Org/$Realm" `
				--base master `
				--head $Branch `
				--title 'sync: platform config from Ginnungagap' `
				--body 'Automated sync of canonical platform config files from [Ginnungagap](https://github.com/NorseArchitecture/.github). Managed by ``config/manifest.psd1``.'
			if ($LASTEXITCODE -ne 0) { throw "gh pr create failed (exit $LASTEXITCODE)" }
			Write-Host "    PR: $PrUrl"

			gh pr merge $Branch --auto --merge --repo "$Org/$Realm"
			if ($LASTEXITCODE -ne 0) { throw "gh pr merge --auto failed (exit $LASTEXITCODE)" }
			Write-Host '    Auto-merge armed.'
		} else {
			Write-Host "    Updated existing PR #$PrNumber."
		}

		Write-Host '    Done.'

	} catch {
		Write-Error -ErrorAction Continue "    FAILED: $_"
		$Failures += $Realm
	} finally {
		if ((Get-Location).Path -eq $TempDir) { Pop-Location }
		Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
	}
}

Write-Host
if ($Failures.Count -gt 0) {
	Write-Error -ErrorAction Continue "The runes were not scattered in: $($Failures -join ' ')"
	exit 1
}

Write-Host 'The runes are scattered.'
