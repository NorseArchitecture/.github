#!/usr/bin/env pwsh
#
# realm-classification.ps1
#
# Shared discovery and classification helpers for scatter-the-runes.ps1 and
# carve-the-laws.ps1. Dot-sourced by both — classification logic lives once
# so the two scripts cannot drift on what "default realm" means.
#
# Get-OrgRepos requires `gh` authenticated with at least `read:org` scope
# (in addition to whatever repo/PR scopes the calling script already needs).

function Get-OrgRepos {
	param(
		[Parameter(Mandatory)]
		[string]$Org,
		[int]$Limit = 200
	)

	$Json = gh repo list $Org --json name,isArchived --limit $Limit
	if ($LASTEXITCODE -ne 0) { throw "gh repo list failed (exit $LASTEXITCODE)" }

	$Repos = $Json | ConvertFrom-Json
	if ($Repos.Count -ge $Limit) {
		throw "gh repo list returned $($Repos.Count) repos at limit $Limit — likely truncated, raise -Limit."
	}

	@($Repos | Where-Object { -not $_.isArchived } | ForEach-Object Name)
}

function Get-RealmGroups {
	param(
		[Parameter(Mandatory)]
		$Manifest,
		[Parameter(Mandatory)]
		[string]$Realm
	)

	$Exception = $Manifest.Exceptions[$Realm]
	if ($Exception -and $Exception.ContainsKey('Groups')) { $Exception.Groups }
	else { $Manifest.DefaultGroups }
}

function Get-RealmGated {
	param(
		[Parameter(Mandatory)]
		$Manifest,
		[Parameter(Mandatory)]
		[string]$Realm
	)

	$Exception = $Manifest.Exceptions[$Realm]
	if ($Exception -and $Exception.ContainsKey('Gated')) { $Exception.Gated }
	else { $true }
}
