param(
	[Parameter(Mandatory = $true)]
	[string]$Tool,
	[switch]$RemoveGeneratedFiles
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ToolsRoot = Join-Path $ProjectRoot 'tools'
$SharedRegistryRoot = 'HKCU:\Software\Classes\OpenWithContextMenus'

function Assert-FileExists([string]$Path, [string]$Label) {
	if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
		throw "$Label not found: $Path"
	}
}

function Remove-RegistryKeyIfPresent([string]$Path) {
	if (Test-Path -LiteralPath $Path) {
		try {
			Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
		} catch {
			Write-Warning "Could not remove registry key ${Path}: $($_.Exception.Message)"
		}
	}
}

$toolDir = Join-Path $ToolsRoot $Tool
$configPath = Join-Path $toolDir 'tool.ps1'
Assert-FileExists $configPath 'Tool config'

$config = & $configPath
$classId = ([guid]$config.ClassId).ToString('D').ToUpperInvariant()
$runtimeRoot = Join-Path $env:LOCALAPPDATA "OpenWith\$($config.RuntimeName)"
$toolKey = Join-Path $SharedRegistryRoot "Tools\$($config.ToolId)"
$classMapKey = Join-Path $SharedRegistryRoot "ClassMap\{$classId}"

Get-AppxPackage -Name $config.PackageName -ErrorAction SilentlyContinue | ForEach-Object {
	Remove-AppxPackage -Package $_.PackageFullName -ErrorAction Stop
}

Remove-RegistryKeyIfPresent $toolKey
Remove-RegistryKeyIfPresent $classMapKey

foreach ($key in @($config.LegacySettingsKeys)) {
	Remove-RegistryKeyIfPresent $key
}

if ($RemoveGeneratedFiles -and (Test-Path -LiteralPath $runtimeRoot)) {
	Remove-Item -LiteralPath $runtimeRoot -Recurse -Force
}

[PSCustomObject]@{
	Tool = $config.ToolId
	PackageName = $config.PackageName
	RemovedSettingsKey = $toolKey
	RemovedClassMapKey = $classMapKey
	RemovedGeneratedFiles = [bool]$RemoveGeneratedFiles
}
