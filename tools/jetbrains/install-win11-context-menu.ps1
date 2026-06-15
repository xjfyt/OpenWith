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
$forwardArgs = @('-Tool', 'jetbrains')
if ($JetBrainsExe) { $forwardArgs += @('-ExePath', $JetBrainsExe) }
if ($Title) { $forwardArgs += @('-Title', $Title) }
if ($Architecture) { $forwardArgs += @('-Architecture', $Architecture) }
if ($ForceCompile) { $forwardArgs += '-ForceCompile' }
if ($UsePrebuilt -or $SkipCompile) { $forwardArgs += '-UsePrebuilt' }
& (Join-Path $ProjectRoot 'scripts\install-tool.ps1') @forwardArgs
