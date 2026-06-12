#!/usr/bin/env pwsh
#
# carve-the-laws.ps1
#
# Applies the "Law of the Aesir" branch ruleset to every repository in the
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

$Org = 'NorseArchitecture'
$RulesetName = 'Law of the Aesir'

# The founding realms. Add new repos here as they are born.
$AllRepos = @('Asgard', 'Svartalfheim', 'Midgard', 'Yggdrasil', 'Urdarbrunnr', 'Bifrost', 'Glitnir', '.github')

if (-not $Repos -or $Repos.Count -eq 0) {
	$Repos = $AllRepos
}

# ---------------------------------------------------------------------------
# The law itself.
#
# Notes on the choices encoded here:
#   - required_approving_review_count: 0 — solo-maintainer mode. The PR
#     workflow (no direct push, CI green, threads resolved) is enforced
#     without self-approval theater. Raise to 1+ when a second contributor
#     arrives.
#   - bypass_actors actor_id 5 = Repository admin role. bypass_mode
#     "always" lets an admin push directly in an emergency; change to
#     "pull_request" to allow bypass only through a PR.
#   - required_status_checks context "build" must exactly match the CI
#     job/check name reported to GitHub. Adjust when workflows settle.
#   - deletion + non_fast_forward: nobody deletes or force-pushes the
#     default branch. Including you. Especially at 2 AM.
# ---------------------------------------------------------------------------
$Ruleset = @{
	name = $RulesetName
	target = 'branch'
	enforcement = 'active'
	conditions = @{
		ref_name = @{
			include = @('~DEFAULT_BRANCH')
			exclude = @()
		}
	}
	bypass_actors = @(
		@{
			actor_id = 5
			actor_type = 'RepositoryRole'
			bypass_mode = 'always'
		}
	)
	rules = @(
		@{ type = 'deletion' }
		@{ type = 'non_fast_forward' }
		@{
			type = 'pull_request'
			parameters = @{
				required_approving_review_count = 0
				dismiss_stale_reviews_on_push = $true
				require_code_owner_review = $false
				require_last_push_approval = $false
				required_review_thread_resolution = $true
			}
		}
		@{
			type = 'required_status_checks'
			parameters = @{
				strict_required_status_checks_policy = $true
				required_status_checks = @(
					@{ context = 'build' }
				)
			}
		}
	)
} | ConvertTo-Json -Depth 10

# ---------------------------------------------------------------------------
# Apply: update if a ruleset of the same name exists, create otherwise.
# ---------------------------------------------------------------------------
$Failures = @()

foreach ($Repo in $Repos) {
	Write-Host "==> $Org/$Repo"

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
