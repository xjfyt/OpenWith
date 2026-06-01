param(
	[string]$GitBashExe = '',
	[string]$Title = 'Git Bash Here',
	[switch]$SkipCompile
)

$ErrorActionPreference = 'Stop'

$PackageName = 'OpenWith.GitBashHereContextMenu'
$Publisher = 'CN=OpenWith Git Bash Here Context Menu'
$PackageVersion = '1.0.0.0'
$ClassId = 'EE3EDDBD-613B-4D0C-B65F-50B21BB8F678'
$VerbId = 'GitBashHere'
$SettingsKey = 'HKCU:\Software\Classes\GitBashHereContextMenu'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$WorkDir = Join-Path $ScriptDir 'win11-context-menu'
$RuntimeRoot = Join-Path $env:LOCALAPPDATA 'OpenWith\GitBashHereContextMenu'
$SourcePath = Join-Path $WorkDir 'src\GitBashHereExplorerCommand.cpp'
$ExternalDir = Join-Path $RuntimeRoot 'external'
$ManifestDir = Join-Path $RuntimeRoot 'manifest'
$PackageDir = Join-Path $RuntimeRoot 'package'
$AssetsDir = Join-Path $ExternalDir 'Assets'
$DllPath = Join-Path $ExternalDir 'GitBashHereExplorerCommand.dll'
$ObjPath = Join-Path $ExternalDir 'GitBashHereExplorerCommand.obj'
$ManifestPath = Join-Path $ManifestDir 'AppxManifest.xml'
$AppxPath = Join-Path $PackageDir 'GitBashHereContextMenu.appx'
$CertPath = Join-Path $PackageDir 'OpenWithGitBashHereContextMenu.cer'

function Assert-FileExists([string]$Path, [string]$Label) {
	if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
		throw "$Label not found: $Path"
	}
}

function Resolve-GitBashExe([string]$ExplicitPath) {
	if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
		return $ExplicitPath
	}

	$candidates = @(
		"$env:ProgramFiles\Git\git-bash.exe",
		"${env:ProgramFiles(x86)}\Git\git-bash.exe",
		"$env:LOCALAPPDATA\Programs\Git\git-bash.exe"
	)

	foreach ($candidate in $candidates) {
		if (Test-Path -LiteralPath $candidate -PathType Leaf) {
			return $candidate
		}
	}

	$whereResult = & where.exe git-bash 2>$null | Select-Object -First 1
	if ($whereResult -and (Test-Path -LiteralPath $whereResult -PathType Leaf)) {
		return $whereResult
	}

	throw 'git-bash.exe was not found. Re-run with -GitBashExe "C:\Path\To\git-bash.exe".'
}

function Quote-CmdArg([string]$Value) {
	return '"' + ($Value -replace '"', '\"') + '"'
}

function Find-VcVars64 {
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

function Find-WindowsSdkTool([string]$Name) {
	$root = "${env:ProgramFiles(x86)}\Windows Kits\10\bin"
	$tool = Get-ChildItem -Path $root -Recurse -Filter $Name -ErrorAction SilentlyContinue |
		Where-Object { $_.FullName -match '\\x64\\' } |
		Sort-Object FullName -Descending |
		Select-Object -First 1

	if (-not $tool) {
		throw "$Name was not found in the Windows SDK."
	}

	return $tool.FullName
}

function Invoke-Native([string]$FilePath, [string[]]$Arguments) {
	& $FilePath @Arguments
	if ($LASTEXITCODE -ne 0) {
		throw "$FilePath exited with code $LASTEXITCODE"
	}
}

function New-Logo([string]$Path, [int]$Size) {
	Add-Type -AssemblyName System.Drawing
	$bitmap = New-Object System.Drawing.Bitmap $Size, $Size
	$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
	$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
	$graphics.Clear([System.Drawing.Color]::FromArgb(24, 26, 31))
	$brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(116, 176, 255))
	$font = New-Object System.Drawing.Font 'Segoe UI', ([Math]::Max(12, [int]($Size * 0.52))), ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
	$format = New-Object System.Drawing.StringFormat
	$format.Alignment = [System.Drawing.StringAlignment]::Center
	$format.LineAlignment = [System.Drawing.StringAlignment]::Center
	$graphics.DrawString('G', $font, $brush, (New-Object System.Drawing.RectangleF 0, 0, $Size, $Size), $format)
	$bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
	$graphics.Dispose()
	$bitmap.Dispose()
	$brush.Dispose()
	$font.Dispose()
	$format.Dispose()
}

function Compile-Dll {
	Assert-FileExists $SourcePath 'Explorer command source'
	New-Item -ItemType Directory -Force -Path $ExternalDir | Out-Null

	if ($SkipCompile -and (Test-Path -LiteralPath $DllPath -PathType Leaf)) {
		return
	}

	$source = Get-Item -LiteralPath $SourcePath
	$dll = if (Test-Path -LiteralPath $DllPath -PathType Leaf) { Get-Item -LiteralPath $DllPath } else { $null }
	if ($dll -and $dll.LastWriteTimeUtc -ge $source.LastWriteTimeUtc) {
		return
	}

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
		"/Fe:$DllPath",
		$SourcePath,
		'/link',
		'/NOLOGO',
		'/DLL',
		'/SUBSYSTEM:WINDOWS',
		'/EXPORT:DllGetClassObject',
		'/EXPORT:DllCanUnloadNow',
		'shlwapi.lib',
		'shell32.lib',
		'ole32.lib',
		'advapi32.lib'
	)
	$command = (Quote-CmdArg $vcvars) + ' >nul && cl.exe ' + (($args | ForEach-Object { Quote-CmdArg $_ }) -join ' ')
	cmd.exe /c $command
	if ($LASTEXITCODE -ne 0) {
		throw "cl.exe exited with code $LASTEXITCODE"
	}
}

function Write-Manifest {
	New-Item -ItemType Directory -Force -Path $ManifestDir, $AssetsDir | Out-Null
	New-Logo (Join-Path $AssetsDir 'Logo44.png') 44
	New-Logo (Join-Path $AssetsDir 'Logo150.png') 150

	@"
<?xml version="1.0" encoding="utf-8"?>
<Package
  xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
  xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
  xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities"
  xmlns:desktop4="http://schemas.microsoft.com/appx/manifest/desktop/windows10/4"
  xmlns:desktop5="http://schemas.microsoft.com/appx/manifest/desktop/windows10/5"
  xmlns:desktop6="http://schemas.microsoft.com/appx/manifest/desktop/windows10/6"
  xmlns:uap10="http://schemas.microsoft.com/appx/manifest/uap/windows10/10"
  xmlns:com="http://schemas.microsoft.com/appx/manifest/com/windows10"
  IgnorableNamespaces="uap rescap desktop4 desktop5 desktop6 uap10 com">
  <Identity
    Name="$PackageName"
    Publisher="$Publisher"
    Version="$PackageVersion"
    ProcessorArchitecture="neutral" />
  <Properties>
    <DisplayName>Git Bash Here Context Menu</DisplayName>
    <PublisherDisplayName>OpenWith</PublisherDisplayName>
    <Logo>Assets\Logo150.png</Logo>
    <uap10:AllowExternalContent>true</uap10:AllowExternalContent>
    <desktop6:RegistryWriteVirtualization>disabled</desktop6:RegistryWriteVirtualization>
    <desktop6:FileSystemWriteVirtualization>disabled</desktop6:FileSystemWriteVirtualization>
  </Properties>
  <Resources>
    <Resource Language="en-us" />
    <Resource Language="zh-cn" />
  </Resources>
  <Dependencies>
    <TargetDeviceFamily Name="Windows.Desktop" MinVersion="10.0.19041.0" MaxVersionTested="10.0.26200.0" />
  </Dependencies>
  <Capabilities>
    <rescap:Capability Name="runFullTrust" />
    <rescap:Capability Name="unvirtualizedResources" />
  </Capabilities>
  <Applications>
    <Application Id="GitBashHereContextMenu"
      Executable="git-bash.exe"
      uap10:TrustLevel="mediumIL"
      uap10:RuntimeBehavior="win32App">
      <uap:VisualElements
        AppListEntry="none"
        DisplayName="Git Bash Here"
        Description="Open Git Bash in this directory"
        BackgroundColor="transparent"
        Square150x150Logo="Assets\Logo150.png"
        Square44x44Logo="Assets\Logo44.png" />
      <Extensions>
        <desktop4:Extension Category="windows.fileExplorerContextMenus">
          <desktop4:FileExplorerContextMenus>
            <desktop5:ItemType Type="Directory">
              <desktop5:Verb Id="$VerbId" Clsid="$ClassId" />
            </desktop5:ItemType>
            <desktop5:ItemType Type="Directory\Background">
              <desktop5:Verb Id="$VerbId" Clsid="$ClassId" />
            </desktop5:ItemType>
            <desktop5:ItemType Type="*">
              <desktop5:Verb Id="$VerbId" Clsid="$ClassId" />
            </desktop5:ItemType>
          </desktop4:FileExplorerContextMenus>
        </desktop4:Extension>
        <com:Extension Category="windows.comServer">
          <com:ComServer>
            <com:SurrogateServer DisplayName="Git Bash Here Context Menu">
              <com:Class Id="$ClassId" Path="GitBashHereExplorerCommand.dll" ThreadingModel="STA" />
            </com:SurrogateServer>
          </com:ComServer>
        </com:Extension>
      </Extensions>
    </Application>
  </Applications>
</Package>
"@ | Set-Content -LiteralPath $ManifestPath -Encoding UTF8
}

function Remove-ExistingPackage {
	Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue | ForEach-Object {
		Remove-AppxPackage -Package $_.PackageFullName -ErrorAction Stop
	}
}

function Set-ContextMenuSettings {
	New-Item -Path $SettingsKey -Force | Out-Null
	New-ItemProperty -Path $SettingsKey -Name 'Title' -Value $Title -PropertyType ExpandString -Force | Out-Null
	New-ItemProperty -Path $SettingsKey -Name 'ExePath' -Value $GitBashExe -PropertyType ExpandString -Force | Out-Null
}

function Remove-LegacyRegistryVerbs {
	$keys = @(
		'HKCU:\Software\Classes\*\shell\OpenWithGitBashHere',
		'HKCU:\Software\Classes\Directory\shell\OpenWithGitBashHere',
		'HKCU:\Software\Classes\Directory\Background\shell\OpenWithGitBashHere',
		'HKLM:\Software\Classes\*\shell\OpenWithGitBashHere',
		'HKLM:\Software\Classes\Directory\shell\OpenWithGitBashHere',
		'HKLM:\Software\Classes\Directory\Background\shell\OpenWithGitBashHere'
	)

	foreach ($key in $keys) {
		if (Test-Path -LiteralPath $key) {
			try {
				Remove-Item -LiteralPath $key -Recurse -Force -ErrorAction Stop
			} catch {
				Write-Warning "Could not remove legacy key ${key}: $($_.Exception.Message)"
			}
		}
	}
}

function Ensure-SigningCertificate {
	New-Item -ItemType Directory -Force -Path $PackageDir | Out-Null
	$cert = Get-ChildItem Cert:\CurrentUser\My |
		Where-Object { $_.Subject -eq $Publisher -and $_.HasPrivateKey } |
		Sort-Object NotAfter -Descending |
		Select-Object -First 1

	if (-not $cert) {
		$cert = New-SelfSignedCertificate `
			-Type Custom `
			-Subject $Publisher `
			-FriendlyName 'OpenWith Git Bash Here Context Menu' `
			-CertStoreLocation 'Cert:\CurrentUser\My' `
			-KeyUsage DigitalSignature `
			-TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3', '2.5.29.19={text}')
	}

	Export-Certificate -Cert $cert -FilePath $CertPath -Force | Out-Null
	Import-Certificate -FilePath $CertPath -CertStoreLocation 'Cert:\CurrentUser\TrustedPeople' | Out-Null
	Import-Certificate -FilePath $CertPath -CertStoreLocation 'Cert:\CurrentUser\Root' | Out-Null
	return $cert
}

function Install-LoosePackage {
	Add-AppxPackage -Register $ManifestPath -ExternalLocation $ExternalDir -ForceApplicationShutdown -ErrorAction Stop
}

function Install-SignedSparsePackage {
	$makeappx = Find-WindowsSdkTool 'makeappx.exe'
	$signtool = Find-WindowsSdkTool 'signtool.exe'
	$cert = Ensure-SigningCertificate

	New-Item -ItemType Directory -Force -Path $PackageDir | Out-Null
	if (Test-Path -LiteralPath $AppxPath) {
		Remove-Item -LiteralPath $AppxPath -Force
	}

	Invoke-Native $makeappx @('pack', '/d', $ManifestDir, '/p', $AppxPath, '/nv')
	Invoke-Native $signtool @('sign', '/fd', 'SHA256', '/sha1', $cert.Thumbprint, $AppxPath)
	Add-AppxPackage -Path $AppxPath -ExternalLocation $ExternalDir -ForceApplicationShutdown -ErrorAction Stop
}

$GitBashExe = Resolve-GitBashExe $GitBashExe
Assert-FileExists $GitBashExe 'git-bash.exe'
Compile-Dll
Assert-FileExists $DllPath 'Explorer command DLL'
Write-Manifest
Set-ContextMenuSettings
Remove-LegacyRegistryVerbs
Remove-ExistingPackage

$mode = 'loose manifest'
try {
	Install-LoosePackage
} catch {
	Write-Warning "Loose package registration failed: $($_.Exception.Message)"
	$mode = 'signed sparse package'
	Install-SignedSparsePackage
}

$package = Get-AppxPackage -Name $PackageName -ErrorAction Stop
[PSCustomObject]@{
	Mode = $mode
	PackageName = $package.Name
	PackageFullName = $package.PackageFullName
	ExternalLocation = $ExternalDir
	DllPath = $DllPath
	GitBashExe = $GitBashExe
	Title = $Title
}
