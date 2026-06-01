param(
	[string]$WslExe = '',
	[string]$Title = '',
	[string]$Distro = '',
	[ValidateSet('auto', 'x64', 'arm64')]
	[string]$Architecture = 'auto',
	[switch]$ForceCompile,
	[switch]$UsePrebuilt,
	[switch]$SkipCompile
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$args = @('-Tool', 'wsl')
if ($WslExe) { $args += @('-ExePath', $WslExe) }
if ($Title) { $args += @('-Title', $Title) }
if ($Distro) { $args += @('-Distro', $Distro) }
if ($Architecture) { $args += @('-Architecture', $Architecture) }
if ($ForceCompile) { $args += '-ForceCompile' }
if ($UsePrebuilt -or $SkipCompile) { $args += '-UsePrebuilt' }
& (Join-Path $ProjectRoot 'scripts\install-tool.ps1') @args
