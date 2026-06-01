param(
	[switch]$RemoveGeneratedFiles
)

$ErrorActionPreference = 'Stop'

$PackageName = 'OpenWith.GitBashHereContextMenu'
$SettingsKey = 'HKCU:\Software\Classes\GitBashHereContextMenu'
$RuntimeRoot = Join-Path $env:LOCALAPPDATA 'OpenWith\GitBashHereContextMenu'

Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue | ForEach-Object {
	Remove-AppxPackage -Package $_.PackageFullName -ErrorAction Stop
}

if (Test-Path $SettingsKey) {
	Remove-Item -Path $SettingsKey -Recurse -Force
}

if ($RemoveGeneratedFiles -and (Test-Path -LiteralPath $RuntimeRoot)) {
	Remove-Item -LiteralPath $RuntimeRoot -Recurse -Force
}

[PSCustomObject]@{
	PackageName = $PackageName
	RemovedSettingsKey = $SettingsKey
	RemovedGeneratedFiles = [bool]$RemoveGeneratedFiles
}
