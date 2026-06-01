param(
	[switch]$RemoveGeneratedFiles
)

$ErrorActionPreference = 'Stop'

$PackageName = 'OpenWith.AntigravityContextMenu'
$SettingsKey = 'HKCU:\Software\Classes\AntigravityContextMenu'
$RuntimeRoot = Join-Path $env:LOCALAPPDATA 'OpenWith\AntigravityContextMenu'

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
