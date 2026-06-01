param(
	[switch]$RemoveGeneratedFiles
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
& (Join-Path $ProjectRoot 'scripts\uninstall-tool.ps1') -Tool 'antigravity' -RemoveGeneratedFiles:$RemoveGeneratedFiles
