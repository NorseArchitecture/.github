#!/usr/bin/env pwsh
#
# verify-schema-templates.ps1 — proves the canonical schema/ Microsoft.Build.Sql (DacFx)
# templates end to end against the scratch Scratch.Rules/Scratch.Database fixture:
#   1. workspace-mode evaluation (RunSqlCodeAnalysis auto-enable, ProjectReference shape,
#      DatabaseSqlCmdVariable custom-metadata passthrough)
#   2. workspace-mode build (rule promotion: NR0001 silent when absent, a hard error when present)
#   3. package-mode build via a throwaway local feed (package-crossing parity)
#   4. the stale-transitive-rule strip (a packed copy shadowing the live ProjectReference is removed)
#
# The fixture realm root IS the top of its own chain — it is not nested under a real Bifröst,
# so it never resolves NorseRef via Bifröst's root Directory.Build.targets. Scratch.Database.sqlproj
# carries its own small Rules="true" Choose (mirroring Bifröst's, scoped to the one reference kind
# a schema project ever declares) so this fixture can prove both crossings standalone. Full
# rationale for that and other fixture-specific adaptations: task-8-report.md.
$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot
$GinnungagapRoot = Split-Path -Parent $ScriptDir
$ConfigDir = Join-Path $GinnungagapRoot 'config'
$FixtureRoot = Join-Path $ScriptDir 'verify-schema-fixtures/RealmRoot'
$DbDir = Join-Path $FixtureRoot 'schema/Scratch.Database'
$SqlProj = Join-Path $DbDir 'Scratch.Database.sqlproj'
$RulesProj = Join-Path $FixtureRoot 'src/Scratch.Rules/Scratch.Rules.csproj'
$ForbiddenSql = Join-Path $DbDir 'dbo/tables/forbidden.sql'
$ForbiddenSqlSource = Join-Path $DbDir 'dbo/tables/forbidden.sql.disabled'
$NugetConfigPath = Join-Path $FixtureRoot 'nuget.config'

$Failures = [System.Collections.Generic.List[string]]::new()

function Write-Fail {
	param([string]$Message)
	$script:Failures.Add($Message)
	Write-Host "FAIL: $Message" -ForegroundColor Red
}

function Remove-ForbiddenTable {
	if (Test-Path -LiteralPath $ForbiddenSql) { Remove-Item -LiteralPath $ForbiddenSql -Force }
}

function Add-ForbiddenTable {
	Copy-Item -LiteralPath $ForbiddenSqlSource -Destination $ForbiddenSql -Force
}

# ---- Refresh fixture copies from config/ — never hand-maintained ----------
function Sync-FixtureTemplates {
	Copy-Item -LiteralPath (Join-Path $ConfigDir 'Directory.Build.props') -Destination (Join-Path $FixtureRoot 'Directory.Build.props') -Force
	Copy-Item -LiteralPath (Join-Path $ConfigDir 'Directory.Build.targets') -Destination (Join-Path $FixtureRoot 'Directory.Build.targets') -Force
	Copy-Item -LiteralPath (Join-Path $ConfigDir 'schema/Directory.Build.props') -Destination (Join-Path $FixtureRoot 'schema/Directory.Build.props') -Force
	Copy-Item -LiteralPath (Join-Path $ConfigDir 'schema/Directory.Build.targets') -Destination (Join-Path $FixtureRoot 'schema/Directory.Build.targets') -Force
	Copy-Item -LiteralPath (Join-Path $ConfigDir 'nuget.config') -Destination $NugetConfigPath -Force

	# A real consumer platform shipping a rules package mirrors the canonical exemplar's
	# commented promotion token into its OWN copy of schema/Directory.Build.targets (the
	# doctrine comment right above the exemplar says so explicitly). This harness performs
	# that one mechanical edit on every run — the fixture's copy is never hand-maintained even
	# though, after this step, it is not byte-identical to the canonical template.
	$TargetsPath = Join-Path $FixtureRoot 'schema/Directory.Build.targets'
	$Anchor = "`t<!--`n`t`tStale-transitive strip,"
	$Promotion = @'
	<!-- Fixture-only instantiation of the exemplar above — appended by this harness's Sync-
	     FixtureTemplates step every run, never hand-maintained. -->
	<PropertyGroup Condition="'$(UseProjectReferences)' == 'true'">
		<SqlCodeAnalysisRules Condition="!$(SqlCodeAnalysisRules.Contains('+!Scratch.Rules.NR0001'))">$(SqlCodeAnalysisRules);+!Scratch.Rules.NR0001</SqlCodeAnalysisRules>
	</PropertyGroup>

'@
	$Content = Get-Content -Raw -LiteralPath $TargetsPath
	if ($Content -notmatch [regex]::Escape($Anchor)) {
		throw "Sync-FixtureTemplates: anchor comment not found in canonical schema/Directory.Build.targets — has its text changed?"
	}
	$Content = $Content -replace [regex]::Escape($Anchor), "$Promotion$Anchor"
	Set-Content -LiteralPath $TargetsPath -Value $Content -NoNewline
}

function Get-Evaluated {
	param([string]$Project, [string[]]$Items = @(), [string[]]$Properties = @(), [string[]]$Props = @(), [switch]$Rebuild)
	# Dynamic items populated by target execution (e.g. @(Analyzer) from a ProjectReference's
	# OutputItemType) reflect whatever the LAST build under a DIFFERENT property set left
	# behind unless the target chain is forced to re-run — MSBuild's incremental up-to-date
	# check otherwise skips ResolveReferences and the reported item list goes stale. Every
	# earlier assertion group in this harness builds the same sqlproj under different -p:
	# combinations, so -Rebuild is required whenever the caller cares about execution-time item
	# state, not just statically-declared items.
	$MsbuildArgs = @($Project, ($Rebuild ? '-t:Rebuild' : '-t:Build'))
	$Items      | ForEach-Object { $MsbuildArgs += "-getItem:$_" }
	$Properties | ForEach-Object { $MsbuildArgs += "-getProperty:$_" }
	if ($Items.Count -eq 0 -and $Properties.Count -eq 1) { $MsbuildArgs += '-getProperty:MSBuildProjectFile' }
	$Props      | ForEach-Object { $MsbuildArgs += "-p:$_" }
	$Raw = dotnet build @MsbuildArgs 2>&1 | Out-String
	if ($Raw -notmatch '(?s)(\{.*\})') { throw "No JSON in msbuild output for ${Project}: $Raw" }
	$Matches[1] | ConvertFrom-Json
}

function Invoke-Build {
	param([string]$Project, [string[]]$Props = @())
	$BuildArgs = @($Project, '-t:Rebuild')
	$Props | ForEach-Object { $BuildArgs += "-p:$_" }
	$Output = dotnet build @BuildArgs 2>&1 | Out-String
	[pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $Output }
}

Write-Host '== Refreshing fixture copies from config/ ==' -ForegroundColor Cyan
Sync-FixtureTemplates
Remove-ForbiddenTable

# ============================================================================
# Assertion group 1 — workspace-mode evaluation
# ============================================================================
Write-Host '== Assertion group 1: workspace-mode evaluation ==' -ForegroundColor Cyan
$Eval = Get-Evaluated $SqlProj -Items ProjectReference -Properties RunSqlCodeAnalysis -Props 'UseProjectReferences=true'

if ($Eval.Properties.RunSqlCodeAnalysis -ne 'true') {
	Write-Fail "group 1: RunSqlCodeAnalysis expected 'true' under UseProjectReferences=true, got '$($Eval.Properties.RunSqlCodeAnalysis)'"
}

$AllRefs = @($Eval.Items.ProjectReference)
$RulesRefs = @($AllRefs | Where-Object { ($_.Identity -replace '\\', '/') -like '*/src/Scratch.Rules/Scratch.Rules.csproj' })
if ($RulesRefs.Count -eq 0) {
	Write-Fail 'group 1: no ProjectReference to src/Scratch.Rules/Scratch.Rules.csproj found under UseProjectReferences=true'
} else {
	$NonAnalyzerRefs = @($RulesRefs | Where-Object { $_.OutputItemType -ne 'Analyzer' })
	if ($NonAnalyzerRefs.Count -gt 0) {
		Write-Fail "group 1: found $($NonAnalyzerRefs.Count) plain (non-Analyzer) compile ProjectReference(s) to Scratch.Rules — expected none"
	}
	$WithSqlCmdVar = @($RulesRefs | Where-Object { $_.DatabaseSqlCmdVariable -eq 'ref_db' })
	if ($WithSqlCmdVar.Count -eq 0) {
		Write-Fail 'group 1: DatabaseSqlCmdVariable=ref_db metadata missing from the second NorseRef''s resolved emission — custom metadata did not pass through the transform'
	}
}

# ============================================================================
# Assertion group 2 — workspace-mode build: promotion proven
# ============================================================================
Write-Host '== Assertion group 2: workspace-mode build (rule promotion) ==' -ForegroundColor Cyan
Remove-ForbiddenTable
$Green = Invoke-Build $SqlProj -Props 'UseProjectReferences=true'
if ($Green.ExitCode -ne 0) {
	Write-Fail "group 2: workspace-mode build failed with forbidden.sql absent (expected green).`n$($Green.Output)"
}

Add-ForbiddenTable
$Red = Invoke-Build $SqlProj -Props 'UseProjectReferences=true'
if ($Red.ExitCode -eq 0) {
	Write-Fail 'group 2: workspace-mode build succeeded with forbidden.sql present — NR0001 was not promoted to an error'
} elseif ($Red.Output -notmatch 'error NR0001') {
	Write-Fail "group 2: workspace-mode build failed as expected, but no 'error NR0001' in output (rule may not have run at all).`n$($Red.Output)"
}
Remove-ForbiddenTable

# ============================================================================
# Assertion group 3 — package-mode build via a throwaway local feed: parity
# ============================================================================
Write-Host '== Assertion group 3: package-mode build (crossing parity) ==' -ForegroundColor Cyan
$LocalFeed = Join-Path ([System.IO.Path]::GetTempPath()) "norse-schema-fixture-feed-$([System.Guid]::NewGuid())"
New-Item -ItemType Directory -Path $LocalFeed -Force | Out-Null
try {
	$PackOutput = dotnet pack $RulesProj -o $LocalFeed 2>&1 | Out-String
	if ($LASTEXITCODE -ne 0) {
		Write-Fail "group 3: 'dotnet pack' of Scratch.Rules failed.`n$PackOutput"
	} else {
		dotnet nuget add source $LocalFeed --name scratch-local-feed --configfile $NugetConfigPath | Out-Null
		# The refreshed nuget.config maps 'Norse.*' to the github source exclusively; the local
		# feed needs its own mapping entry for exactly the one package it carries, or
		# PackageSourceMapping silently never considers it.
		[xml]$NugetXml = Get-Content -Raw -LiteralPath $NugetConfigPath
		$MappingRoot = $NugetXml.configuration.packageSourceMapping
		$NewMapping = $NugetXml.CreateElement('packageSource')
		$NewMapping.SetAttribute('key', 'scratch-local-feed')
		$PackageEl = $NugetXml.CreateElement('package')
		$PackageEl.SetAttribute('pattern', 'Norse.Scratch.Rules')
		$NewMapping.AppendChild($PackageEl) | Out-Null
		$MappingRoot.PrependChild($NewMapping) | Out-Null
		$NugetXml.Save($NugetConfigPath)

		$RestoreOutput = dotnet restore $SqlProj 2>&1 | Out-String
		if ($LASTEXITCODE -ne 0) {
			Write-Fail "group 3: package-mode restore failed.`n$RestoreOutput"
		} else {
			Remove-ForbiddenTable
			$Green = Invoke-Build $SqlProj
			if ($Green.ExitCode -ne 0) {
				Write-Fail "group 3: package-mode build failed with forbidden.sql absent (expected green).`n$($Green.Output)"
			}

			Add-ForbiddenTable
			$Red = Invoke-Build $SqlProj
			if ($Red.ExitCode -eq 0) {
				Write-Fail 'group 3: package-mode build succeeded with forbidden.sql present — the packed build/*.targets did not promote NR0001 (no crossing parity)'
			} elseif ($Red.Output -notmatch 'error NR0001') {
				Write-Fail "group 3: package-mode build failed as expected, but no 'error NR0001' in output.`n$($Red.Output)"
			}
			Remove-ForbiddenTable
		}
	}

	# ========================================================================
	# Assertion group 4 — stale-transitive-rule strip
	# ========================================================================
	Write-Host '== Assertion group 4: stale-transitive-rule strip ==' -ForegroundColor Cyan
	$StaleEval = Get-Evaluated $SqlProj -Items Analyzer -Props 'UseProjectReferences=true', 'NorseInjectStaleTransitiveRule=true' -Rebuild
	$AnalyzerItems = @($StaleEval.Items.Analyzer | Where-Object { $_.Filename -eq 'Norse.Scratch.Rules' -or ($_.Identity -replace '\\', '/') -like '*Norse.Scratch.Rules.dll' })
	$StaleCopies = @($AnalyzerItems | Where-Object { -not $_.MSBuildSourceProjectFile })
	$LiveCopies = @($AnalyzerItems | Where-Object { $_.MSBuildSourceProjectFile })
	if ($StaleCopies.Count -gt 0) {
		Write-Fail "group 4: $($StaleCopies.Count) stale (packed, no MSBuildSourceProjectFile) Norse.Scratch.Rules @(Analyzer) entries survived — _NorseRemoveStaleTransitiveRules did not strip them"
	}
	if ($LiveCopies.Count -eq 0) {
		Write-Fail 'group 4: no live (ProjectReference-sourced) Norse.Scratch.Rules @(Analyzer) entry survived — the strip over-stripped'
	}
} finally {
	if (Test-Path -LiteralPath $LocalFeed) { Remove-Item -LiteralPath $LocalFeed -Recurse -Force }
	Remove-ForbiddenTable
	# nuget.config is a tracked, harness-refreshed file (Sync-FixtureTemplates), not scratch —
	# leaving the ephemeral local-feed source registered would commit a dangling reference to a
	# temp directory this run just deleted. Best-effort: the source may already be gone if group 3
	# never reached the registration step.
	dotnet nuget remove source scratch-local-feed --configfile $NugetConfigPath 2>&1 | Out-Null
}

if ($Failures.Count) {
	Write-Host ''
	Write-Host "verify-schema-templates: $($Failures.Count) failure(s)." -ForegroundColor Red
	exit 1
}
Write-Host ''
Write-Host 'verify-schema-templates: all four assertion groups green.' -ForegroundColor Green
