param(
	[Parameter(Mandatory = $true)]
	[string]$Tool,
	[switch]$RemoveGeneratedFiles
)

$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'scripts\uninstall-tool.ps1'
& $script -Tool $Tool -RemoveGeneratedFiles:$RemoveGeneratedFiles
