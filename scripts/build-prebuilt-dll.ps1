param(
	[string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$SourcePath = Join-Path $ProjectRoot 'src\OpenWithExplorerCommand.cpp'
if (-not $OutputPath) {
	$OutputPath = Join-Path $ProjectRoot 'bin\x64\OpenWithExplorerCommand.dll'
}

$OutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
$OutputDir = Split-Path -Parent $OutputPath
$ObjPath = Join-Path $OutputDir 'OpenWithExplorerCommand.obj'

function Quote-CmdArg([string]$Value) {
	return '"' + ($Value -replace '"', '\"') + '"'
}

function Find-VcVars64 {
	$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
	if (Test-Path -LiteralPath $vswhere -PathType Leaf) {
		$installPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
		if ($installPath) {
			$candidate = Join-Path $installPath 'VC\Auxiliary\Build\vcvars64.bat'
			if (Test-Path -LiteralPath $candidate -PathType Leaf) {
				return $candidate
			}
		}
	}

	$candidates = @(
		"${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat",
		"${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat",
		"${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat",
		"${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
	)

	foreach ($candidate in $candidates) {
		if (Test-Path -LiteralPath $candidate -PathType Leaf) {
			return $candidate
		}
	}

	throw 'Visual Studio C++ build tools were not found.'
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$vcvars = Find-VcVars64
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
$command = (Quote-CmdArg $vcvars) + ' >nul && cl.exe ' + (($args | ForEach-Object { Quote-CmdArg $_ }) -join ' ')
cmd.exe /c $command
if ($LASTEXITCODE -ne 0) {
	throw "cl.exe exited with code $LASTEXITCODE"
}

[PSCustomObject]@{
	OutputPath = $OutputPath
	SourcePath = $SourcePath
}
