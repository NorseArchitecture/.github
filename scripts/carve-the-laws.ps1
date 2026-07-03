#!/usr/bin/env pwsh
#
# carve-the-laws.ps1
#
# Applies the "Law of the Æsir" branch ruleset to every repository in the
# Norse Architecture organization. Idempotent: if a ruleset with the same
# name already exists on a repo, it is updated in place; otherwise created.
#
# Requirements:
#   - gh CLI authenticated with an account that has admin on the repos
#     (gh auth status to verify; needs "repo" scope / admin:org not required)
#
# Usage:
#   ./carve-the-laws.ps1           # apply to all repos listed below
#   ./carve-the-laws.ps1 Asgard    # apply to a single repo
#
param(
	[Parameter(ValueFromRemainingArguments)]
	[string[]]$Repos
)

$ErrorActionPreference = 'Stop'

$Org         = 'NorseArchitecture'
$RulesetName = 'Law of the Æsir'

# Repos that carry the CI gate (gate / build status check required to merge).
$GatedRepos = [System.Collections.Generic.HashSet[string]]@(
	'Asgard', 'Svartalfheim', 'Midgard', 'Yggdrasil', 'Urdarbrunnr',
	'Ratatoskr', 'Heimdall', 'Himinbjorg', 'Mimisbrunnr', 'Mimir'
)

# Repos without a build system — gate / build never fires, so status check
# is omitted. Enforcement will be tightened per-repo as CI policies are defined
# (e.g. required_approving_review_count >= 1 until a real gate exists).
$UngatedRepos = [System.Collections.Generic.HashSet[string]]@(
	'.github', 'Bifrost', 'Naglfar', 'Glitnir'
)

$AllRepos = @($GatedRepos) + @($UngatedRepos) | Sort-Object

if (-not $Repos -or $Repos.Count -eq 0) {
	$Repos = $AllRepos
}

# ---------------------------------------------------------------------------
# Builds the ruleset JSON for a given repo.
#
# Notes on the choices encoded here:
#   - required_approving_review_count: 1 — one approval required. Platform
#     PRs (sync/platform-config, update/cpm/*) are auto-approved by the
#     auto-approve.yml workflow via GITHUB_TOKEN; human PRs require a real
#     review. Ungated repos use this in place of a CI gate.
#   - bypass_actors actor_id 5 = Repository admin role. bypass_mode
#     "always" lets an admin push directly in an emergency; change to
#     "pull_request" to allow bypass only through a PR.
#   - required_status_checks context "gate / build" (integration_id 15368)
#     was confirmed empirically 2026-06-25: GitHub Actions (app 15368) reports
#     the check as "{caller job} / {called job}" — the workflow name and event
#     suffix are UI decorations only. Locking to integration_id 15368 prevents
#     a non-Actions source from satisfying the gate with a spoofed context name.
#   - deletion + non_fast_forward: nobody deletes or force-pushes the
#     default branch. Including you. Especially at 2 AM.
# ---------------------------------------------------------------------------
function New-Ruleset {
	param([bool]$Gated)

	$Rules = @(
		@{ type = 'deletion' }
		@{ type = 'non_fast_forward' }
		@{
			type       = 'pull_request'
			parameters = @{
				required_approving_review_count = 1
				dismiss_stale_reviews_on_push   = $true
				require_code_owner_review        = $false
				require_last_push_approval       = $false
				required_review_thread_resolution = $true
			}
		}
	)

	if ($Gated) {
		$Rules += @{
			type       = 'required_status_checks'
			parameters = @{
				strict_required_status_checks_policy = $true
				required_status_checks               = @(
					@{ context = 'gate / build'; integration_id = 15368 }
				)
			}
		}
	}

	@{
		name        = $RulesetName
		target      = 'branch'
		enforcement = 'active'
		conditions  = @{
			ref_name = @{
				include = @('~DEFAULT_BRANCH')
				exclude = @()
			}
		}
		bypass_actors = @(
			@{
				actor_id   = 5
				actor_type = 'RepositoryRole'
				bypass_mode = 'always'
			}
		)
		rules = $Rules
	} | ConvertTo-Json -Depth 10
}

# ---------------------------------------------------------------------------
# Apply: repo settings, then ruleset.
# ---------------------------------------------------------------------------
$Failures = @()

foreach ($Repo in $Repos) {
	Write-Host "==> $Org/$Repo"

	if (-not $GatedRepos.Contains($Repo) -and -not $UngatedRepos.Contains($Repo)) {
		Write-Warning "    $Repo not in gated or ungated list — skipping"
		continue
	}

	$Ruleset = New-Ruleset -Gated $GatedRepos.Contains($Repo)
	$Gate    = if ($GatedRepos.Contains($Repo)) { 'gated' } else { 'ungated' }

	# Repo settings — idempotent PATCH; safe to run repeatedly.
	Write-Host "    Applying repo settings ($Gate)..."
	gh api --method PATCH "repos/$Org/$Repo" `
		-F delete_branch_on_merge=true `
		-F allow_auto_merge=true | Out-Null
	if ($LASTEXITCODE -eq 0) {
		Write-Host '    Repo settings applied.'
	} else {
		Write-Error -ErrorAction Continue '    FAILED to apply repo settings.'
		$Failures += $Repo
		continue
	}

	# Workflow permissions — allow GITHUB_TOKEN to approve PRs (required by auto-approve.yml).
	gh api --method PUT "repos/$Org/$Repo/actions/permissions/workflow" `
		-F can_approve_pull_request_reviews=true | Out-Null
	if ($LASTEXITCODE -eq 0) {
		Write-Host '    Workflow permissions applied.'
	} else {
		Write-Error -ErrorAction Continue '    FAILED to apply workflow permissions.'
		$Failures += $Repo
		continue
	}

	$ExistingId = gh api "repos/$Org/$Repo/rulesets" `
		--jq ".[] | select(.name == `"$RulesetName`") | .id" 2>$null
	if ($LASTEXITCODE -ne 0) {
		$ExistingId = $null
	}

	if ($ExistingId) {
		Write-Host "    Law already carved (ruleset $ExistingId) — re-inscribing..."
		$Ruleset | gh api --method PUT "repos/$Org/$Repo/rulesets/$ExistingId" --input - | Out-Null
		if ($LASTEXITCODE -eq 0) {
			Write-Host '    Updated.'
		} else {
			Write-Error -ErrorAction Continue '    FAILED to update.'
			$Failures += $Repo
		}
	} else {
		Write-Host '    Carving the law anew...'
		$Ruleset | gh api --method POST "repos/$Org/$Repo/rulesets" --input - | Out-Null
		if ($LASTEXITCODE -eq 0) {
			Write-Host '    Created.'
		} else {
			Write-Error -ErrorAction Continue '    FAILED to create.'
			$Failures += $Repo
		}
	}
}

Write-Host
if ($Failures.Count -gt 0) {
	Write-Error -ErrorAction Continue "The Aesir were defied in: $($Failures -join ' ')"
	exit 1
}

Write-Host 'The laws are carved. Verify with:'
Write-Host "  gh ruleset list -R $Org/Asgard"
