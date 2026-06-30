#!/usr/bin/env pwsh
#
# sound-gjallarhorn.ps1
#
# Updates <{Realm}Version> in Yggdrasil/Directory.Packages.props and opens
# an auto-merge PR. Idempotent: force-pushes onto the existing branch so a
# faster re-release updates the open PR rather than opening a duplicate.
# Skips pre-release versions (any tag containing '-').
#
# Requirements:
#   GH_TOKEN env var — PAT with repo scope on NorseArchitecture/Yggdrasil
#   git user.name and user.email configured inside $YggdrasilPath (workflow step sets these)
#
# Usage:
#   pwsh scripts/sound-gjallarhorn.ps1 -Realm Svartalfheim -Tag v0.0.2 -YggdrasilPath ./yggdrasil
#   pwsh scripts/sound-gjallarhorn.ps1 -Realm Svartalfheim -Tag v0.0.2 -YggdrasilPath ./yggdrasil -DryRun

param(
	[Parameter(Mandatory)]
	[string]$Realm,

	[Parameter(Mandatory)]
	[string]$Tag,

	[Parameter(Mandatory)]
	[string]$YggdrasilPath,

	[switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$Org      = 'NorseArchitecture'
$Target   = 'Yggdrasil'
$Version  = $Tag.TrimStart('v')
$Branch   = "update/cpm/$($Realm.ToLower())"
$PropFile = Join-Path $YggdrasilPath 'Directory.Packages.props'

# Belt-and-suspenders: skip pre-release even if the workflow if: condition missed it
if ($Version.Contains('-')) {
	Write-Host "==> Pre-release $Version — skipping sounding Gjallarhorn."
	exit 0
}

if (-not (Test-Path $PropFile)) {
	throw "Directory.Packages.props not found at $PropFile. Create it in Yggdrasil before the first release."
}

$Content = Get-Content $PropFile -Raw
$Pattern = "<$($Realm)Version>[^<]*</$($Realm)Version>"
$Replace  = "<$($Realm)Version>$Version</$($Realm)Version>"

if ($Content -notmatch $Pattern) {
	throw "<$($Realm)Version> property not found in Directory.Packages.props. Add it before the first release."
}

$Updated = $Content -replace $Pattern, $Replace

if ($Content -eq $Updated) {
	Write-Host "==> $Realm already at $Version — nothing to do."
	exit 0
}

if ($DryRun) {
	Write-Host "[DRY RUN] Would update <$($Realm)Version> to $Version on branch $Branch → master in $Target."
	exit 0
}

Push-Location $YggdrasilPath
try {
	$RemoteBranchExists = git ls-remote --heads origin $Branch 2>$null
	if ($RemoteBranchExists) {
		git fetch origin $Branch --quiet
		git checkout -b $Branch "origin/$Branch" --quiet
	} else {
		git checkout -b $Branch --quiet
	}
	if ($LASTEXITCODE -ne 0) { throw "Branch checkout failed (exit $LASTEXITCODE)" }

	Set-Content $PropFile $Updated -NoNewline

	git add Directory.Packages.props
	git diff --cached --quiet
	if ($LASTEXITCODE -eq 0) {
		Write-Host "==> No effective change after edit — nothing to commit."
		exit 0
	}

	git commit -m "update: $Realm → $Version" --quiet
	if ($LASTEXITCODE -ne 0) { throw "git commit failed (exit $LASTEXITCODE)" }

	git push origin $Branch --force-with-lease --quiet
	if ($LASTEXITCODE -ne 0) { throw "git push failed (exit $LASTEXITCODE)" }

	$PrNumber = gh pr list `
		--repo "$Org/$Target" `
		--head $Branch `
		--state open `
		--json number `
		--jq '.[0].number'

	if (-not $PrNumber) {
		Write-Host "==> Opening PR..."
		$PrUrl = gh pr create `
			--repo "$Org/$Target" `
			--base master `
			--head $Branch `
			--title "update: $Realm $Version" `
			--body "Bumps ``<$($Realm)Version>`` to ``$Version`` in ``Directory.Packages.props``. Triggered by [$Org/$Realm@$Tag](https://github.com/$Org/$Realm/releases/tag/$Tag)."
		if ($LASTEXITCODE -ne 0) { throw "gh pr create failed (exit $LASTEXITCODE)" }
		Write-Host "==> PR: $PrUrl"

		gh pr merge $Branch --auto --merge --repo "$Org/$Target"
		if ($LASTEXITCODE -ne 0) { throw "gh pr merge --auto failed (exit $LASTEXITCODE)" }
		Write-Host "==> Auto-merge armed."
	} else {
		Write-Host "==> Updated existing PR #$PrNumber."
	}
} finally {
	Pop-Location
}

Write-Host "==> Done."
