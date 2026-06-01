param(
	[ValidateSet('x64', 'arm64')]
	[string]$Architecture = 'x64',
	[string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$SourcePath = Join-Path $ProjectRoot 'src\OpenWithExplorerCommand.cpp'
if (-not $OutputPath) {
	$OutputPath = Join-Path $ProjectRoot "bin\$Architecture\OpenWithExplorerCommand.dll"
}

$OutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
$OutputDir = Split-Path -Parent $OutputPath
$ObjPath = Join-Path $OutputDir 'OpenWithExplorerCommand.obj'

function Quote-CmdArg([string]$Value) {
	return '"' + ($Value -replace '"', '\"') + '"'
}

function Find-VcAuxiliaryBuildDir {
	$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
	if (Test-Path -LiteralPath $vswhere -PathType Leaf) {
		$installPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
		if ($installPath) {
			$candidate = Join-Path $installPath 'VC\Auxiliary\Build'
			if (Test-Path -LiteralPath $candidate -PathType Container) {
				return $candidate
			}
		}
	}

	$candidates = @(
		"${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build",
		"${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build",
		"${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build",
		"${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build"
	)

	foreach ($candidate in $candidates) {
		if (Test-Path -LiteralPath $candidate -PathType Container) {
			return $candidate
		}
	}

	throw 'Visual Studio C++ build tools were not found.'
}

function Get-VcVarsCommand([string]$TargetArchitecture) {
	$buildDir = Find-VcAuxiliaryBuildDir
	if ($TargetArchitecture -eq 'arm64') {
		$crossVars = Join-Path $buildDir 'vcvarsamd64_arm64.bat'
		if (Test-Path -LiteralPath $crossVars -PathType Leaf) {
			return @{
				BatchFile = $crossVars
				Arguments = @()
			}
		}

		throw 'MSVC ARM64 cross tools were not found. Install the Microsoft.VisualStudio.Component.VC.Tools.ARM64 component.'
	}

	$vcVars64 = Join-Path $buildDir 'vcvars64.bat'
	if (Test-Path -LiteralPath $vcVars64 -PathType Leaf) {
		return @{
			BatchFile = $vcVars64
			Arguments = @()
		}
	}

	$vcVarsAllX64 = Join-Path $buildDir 'vcvarsall.bat'
	if (Test-Path -LiteralPath $vcVarsAllX64 -PathType Leaf) {
		return @{
			BatchFile = $vcVarsAllX64
			Arguments = @('x64')
		}
	}

	throw "Visual Studio environment setup script for $TargetArchitecture was not found."
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$vcvarsCommand = Get-VcVarsCommand $Architecture
$args = @(
	'/nologo',
	'/std:c++17',
	'/EHsc',
	'/O2',
	'/LD',
	'/DUNICODE',
	'/D_UNICODE',
	"/Fo:$ObjPath",
	"/Fe:$OutputPath",
	$SourcePath,
	'/link',
	'/NOLOGO',
	'/DLL',
	'/SUBSYSTEM:WINDOWS',
	'/EXPORT:DllGetClassObject',
	'/EXPORT:DllCanUnloadNow',
	'shell32.lib',
	'ole32.lib',
	'advapi32.lib'
)
$vcvarsPart = (Quote-CmdArg $vcvarsCommand.BatchFile)
if ($vcvarsCommand.Arguments.Count -gt 0) {
	$vcvarsPart += ' ' + (($vcvarsCommand.Arguments | ForEach-Object { Quote-CmdArg $_ }) -join ' ')
}

$command = $vcvarsPart + ' >nul && cl.exe ' + (($args | ForEach-Object { Quote-CmdArg $_ }) -join ' ')
cmd.exe /c $command
if ($LASTEXITCODE -ne 0) {
	throw "cl.exe exited with code $LASTEXITCODE"
}

[PSCustomObject]@{
	Architecture = $Architecture
	OutputPath = $OutputPath
	SourcePath = $SourcePath
}
