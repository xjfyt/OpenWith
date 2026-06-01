param(
	[Parameter(Mandatory = $true)]
	[string]$Tool,
	[string]$ExePath = '',
	[string]$Title = '',
	[string]$Distro = '',
	[switch]$ForceCompile,
	[switch]$UsePrebuilt
)

$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'scripts\install-tool.ps1'
& $script -Tool $Tool -ExePath $ExePath -Title $Title -Distro $Distro -ForceCompile:$ForceCompile -UsePrebuilt:$UsePrebuilt
