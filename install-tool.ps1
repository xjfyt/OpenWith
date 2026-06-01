param(
	[Parameter(Mandatory = $true)]
	[string]$Tool,
	[string]$ExePath = '',
	[string]$Title = '',
	[string]$Distro = '',
	[ValidateSet('auto', 'x64', 'arm64')]
	[string]$Architecture = 'auto',
	[switch]$ForceCompile,
	[switch]$UsePrebuilt
)

$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'scripts\install-tool.ps1'
& $script -Tool $Tool -ExePath $ExePath -Title $Title -Distro $Distro -Architecture $Architecture -ForceCompile:$ForceCompile -UsePrebuilt:$UsePrebuilt
