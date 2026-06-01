param(
	[string]$TraeExe = '',
	[string]$Title = '',
	[switch]$ForceCompile,
	[switch]$UsePrebuilt,
	[switch]$SkipCompile
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$args = @('-Tool', 'trae')
if ($TraeExe) { $args += @('-ExePath', $TraeExe) }
if ($Title) { $args += @('-Title', $Title) }
if ($ForceCompile) { $args += '-ForceCompile' }
if ($UsePrebuilt -or $SkipCompile) { $args += '-UsePrebuilt' }
& (Join-Path $ProjectRoot 'scripts\install-tool.ps1') @args
