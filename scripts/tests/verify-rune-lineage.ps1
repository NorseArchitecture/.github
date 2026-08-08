#!/usr/bin/env pwsh
# Fixture-driven proof of the lineage classifier. Builds a throwaway canonical repo
# with two versions of a file, then classifies four destination states.
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/../lib/rune-lineage.ps1"
$Failures = [System.Collections.Generic.List[string]]::new()
$Fixture = Join-Path ([System.IO.Path]::GetTempPath()) "rune-lineage-$(New-Guid)"
try {
	$Config = Join-Path $Fixture 'config-repo'
	New-Item -ItemType Directory -Path (Join-Path $Config 'config') -Force | Out-Null
	git -C $Config init --quiet
	Set-Content (Join-Path $Config 'config/probe.targets') "<Project>v1</Project>" -NoNewline
	git -C $Config add . ; git -C $Config -c user.email=t@t -c user.name=t commit -m v1 --quiet
	Set-Content (Join-Path $Config 'config/probe.targets') "<Project>v2</Project>" -NoNewline
	git -C $Config add . ; git -C $Config -c user.email=t@t -c user.name=t commit -m v2 --quiet

	$Dest = Join-Path $Fixture 'dest'
	New-Item -ItemType Directory -Path $Dest -Force | Out-Null
	Set-Content (Join-Path $Dest 'current.targets')   "<Project>v2</Project>" -NoNewline
	Set-Content (Join-Path $Dest 'stale.targets')     "<Project>v1</Project>" -NoNewline
	Set-Content (Join-Path $Dest 'divergent.targets') "<Project>realm edit</Project>" -NoNewline

	$Cases = @(
		@{ File = 'current.targets';   Expected = 'Current' }
		@{ File = 'stale.targets';     Expected = 'Stale' }
		@{ File = 'divergent.targets'; Expected = 'Divergent' }
	)
	foreach ($Case in $Cases) {
		$Actual = Get-RuneClassification -ConfigRepo $Config -CanonicalRelPath 'config/probe.targets' -DestFile (Join-Path $Dest $Case.File)
		if ($Actual -ne $Case.Expected) { $Failures.Add("$($Case.File): expected $($Case.Expected), got $Actual") }
	}
	# Lineage unavailable: a canonical path with no history at all.
	$Actual = Get-RuneClassification -ConfigRepo $Config -CanonicalRelPath 'config/never-existed.targets' -DestFile (Join-Path $Dest 'current.targets')
	if ($Actual -ne 'LineageUnavailable') { $Failures.Add("no-history path: expected LineageUnavailable, got $Actual") }
	# Shallow repo: classification must refuse, not guess.
	$Shallow = Join-Path $Fixture 'shallow'
	git clone --depth 1 "file://$Config" $Shallow --quiet 2>$null
	$Actual = Get-RuneClassification -ConfigRepo $Shallow -CanonicalRelPath 'config/probe.targets' -DestFile (Join-Path $Dest 'stale.targets')
	if ($Actual -ne 'LineageUnavailable') { $Failures.Add("shallow repo: expected LineageUnavailable, got $Actual") }
} finally {
	Remove-Item $Fixture -Recurse -Force -ErrorAction SilentlyContinue
}
if ($Failures.Count) { $Failures | ForEach-Object { Write-Host "FAIL: $_" -ForegroundColor Red }; exit 1 }
Write-Host 'verify-rune-lineage: all assertions green.' -ForegroundColor Green
