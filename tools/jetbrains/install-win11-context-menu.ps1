param(
	[string]$JetBrainsExe = '',
	[string]$Title = '',
	[ValidateSet('auto', 'x64', 'arm64')]
	[string]$Architecture = 'auto',
	[switch]$ForceCompile,
	[switch]$UsePrebuilt,
	[switch]$SkipCompile
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$args = @('-Tool', 'jetbrains')
if ($JetBrainsExe) { $args += @('-ExePath', $JetBrainsExe) }
if ($Title) { $args += @('-Title', $Title) }
if ($Architecture) { $args += @('-Architecture', $Architecture) }
if ($ForceCompile) { $args += '-ForceCompile' }
if ($UsePrebuilt -or $SkipCompile) { $args += '-UsePrebuilt' }
& (Join-Path $ProjectRoot 'scripts\install-tool.ps1') @args
