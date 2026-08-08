#!/usr/bin/env pwsh
#
# rune-lineage.ps1 — classifies a scattered destination file against the canonical
# file's git lineage. A destination whose content matches ANY historical blob of the
# canonical path is merely Current/Stale; content outside the lineage is a realm
# Divergence (hard fail in scatter, never silently overwritten). A repo that cannot
# answer (shallow clone, no history for the path) is LineageUnavailable — its own
# hard-fail outcome, never conflated with divergence, never silently passed.
# Doctrine: Bifrost/Glitnir/docs/the-runes.md ch. 7.

function Get-RuneClassification {
	param(
		[Parameter(Mandatory)] [string]$ConfigRepo,
		[Parameter(Mandatory)] [string]$CanonicalRelPath,
		[Parameter(Mandatory)] [string]$DestFile
	)
	$IsShallow = git -C $ConfigRepo rev-parse --is-shallow-repository 2>$null
	if ($LASTEXITCODE -ne 0 -or $IsShallow -eq 'true') { return 'LineageUnavailable' }

	$Commits = @(git -C $ConfigRepo log --all --format=%H -- $CanonicalRelPath 2>$null)
	if ($LASTEXITCODE -ne 0 -or $Commits.Count -eq 0) { return 'LineageUnavailable' }

	$Blobs = [System.Collections.Generic.HashSet[string]]::new()
	foreach ($Commit in $Commits) {
		$Blob = git -C $ConfigRepo rev-parse --verify --quiet "${Commit}:${CanonicalRelPath}" 2>$null
		if ($LASTEXITCODE -eq 0 -and $Blob) { [void]$Blobs.Add($Blob.Trim()) }
	}
	if ($Blobs.Count -eq 0) { return 'LineageUnavailable' }

	$DestBlob = (git -C $ConfigRepo hash-object $DestFile).Trim()
	if (-not $Blobs.Contains($DestBlob)) { return 'Divergent' }

	$HeadBlob = git -C $ConfigRepo rev-parse --verify --quiet "HEAD:${CanonicalRelPath}" 2>$null
	return ($HeadBlob -and $DestBlob -eq $HeadBlob.Trim()) ?
		'Current' :
		'Stale'
}
