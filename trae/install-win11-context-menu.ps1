param(
	[string]$TraeExe = '',
	[string]$Title = "$([char]0x901A)$([char]0x8FC7) Trae $([char]0x6253)$([char]0x5F00)",
	[switch]$SkipCompile
)

$ErrorActionPreference = 'Stop'

$PackageName = 'OpenWith.TraeContextMenu'
$Publisher = 'CN=OpenWith Trae Context Menu'
$PackageVersion = '1.0.0.0'
$ClassId = 'B8B07D8E-1327-41D0-86ED-DC7E1A243B3D'
$VerbId = 'OpenWithTrae'
$SettingsKey = 'HKCU:\Software\Classes\TraeContextMenu'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$WorkDir = Join-Path $ScriptDir 'win11-context-menu'
$RuntimeRoot = Join-Path $env:LOCALAPPDATA 'OpenWith\TraeContextMenu'
$SourcePath = Join-Path $WorkDir 'src\TraeExplorerCommand.cpp'
$ExternalDir = Join-Path $RuntimeRoot 'external'
$ManifestDir = Join-Path $RuntimeRoot 'manifest'
$PackageDir = Join-Path $RuntimeRoot 'package'
$AssetsDir = Join-Path $ExternalDir 'Assets'
$DllPath = Join-Path $ExternalDir 'TraeExplorerCommand.dll'
$ObjPath = Join-Path $ExternalDir 'TraeExplorerCommand.obj'
$ManifestPath = Join-Path $ManifestDir 'AppxManifest.xml'
$AppxPath = Join-Path $PackageDir 'TraeContextMenu.appx'
$CertPath = Join-Path $PackageDir 'OpenWithTraeContextMenu.cer'

function Assert-FileExists([string]$Path, [string]$Label) {
	if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
		throw "$Label not found: $Path"
	}
}

function Resolve-TraeExe([string]$ExplicitPath) {
	if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
		return $ExplicitPath
	}

	$candidates = @(
		"$env:LOCALAPPDATA\Programs\Trae\Trae.exe",
		"$env:LOCALAPPDATA\Programs\Trae CN\Trae.exe",
		"$env:LOCALAPPDATA\Programs\trae\Trae.exe",
		"$env:LOCALAPPDATA\Trae\Trae.exe",
		"$env:ProgramFiles\Trae\Trae.exe",
		"${env:ProgramFiles(x86)}\Trae\Trae.exe"
	)

	foreach ($candidate in $candidates) {
		if (Test-Path -LiteralPath $candidate -PathType Leaf) {
			return $candidate
		}
	}

	$uninstallRoots = @(
		'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
		'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
		'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
	)

	foreach ($root in $uninstallRoots) {
		if (-not (Test-Path $root)) {
			continue
		}

		foreach ($key in Get-ChildItem $root -ErrorAction SilentlyContinue) {
			$item = Get-ItemProperty $key.PSPath -ErrorAction SilentlyContinue
			if (($item.DisplayName -like '*Trae*') -or ($item.InstallLocation -like '*Trae*') -or ($item.DisplayIcon -like '*Trae*')) {
				$possiblePaths = @()
				if ($item.InstallLocation) {
					$possiblePaths += Join-Path $item.InstallLocation 'Trae.exe'
				}
				if ($item.DisplayIcon) {
					$possiblePaths += ($item.DisplayIcon -replace '^"', '' -replace '",.*$', '' -replace ',.*$', '')
				}

				foreach ($path in $possiblePaths) {
					if (Test-Path -LiteralPath $path -PathType Leaf) {
						return $path
					}
				}
			}
		}
	}

	throw 'Trae.exe was not found. Re-run with -TraeExe "C:\Path\To\Trae.exe".'
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
	$graphics.DrawString('A', $font, $brush, (New-Object System.Drawing.RectangleF 0, 0, $Size, $Size), $format)
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
    <DisplayName>Trae Context Menu</DisplayName>
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
    <Application Id="TraeContextMenu"
      Executable="Trae.exe"
      uap10:TrustLevel="mediumIL"
      uap10:RuntimeBehavior="win32App">
      <uap:VisualElements
        AppListEntry="none"
        DisplayName="Trae"
        Description="Open with Trae"
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
            <com:SurrogateServer DisplayName="Trae Context Menu">
              <com:Class Id="$ClassId" Path="TraeExplorerCommand.dll" ThreadingModel="STA" />
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
	New-ItemProperty -Path $SettingsKey -Name 'ExePath' -Value $TraeExe -PropertyType ExpandString -Force | Out-Null
}

function Remove-LegacyRegistryVerbs {
	$keys = @(
		'HKCU:\Software\Classes\*\shell\Trae',
		'HKCU:\Software\Classes\Directory\shell\Trae',
		'HKCU:\Software\Classes\Directory\Background\shell\Trae',
		'HKLM:\Software\Classes\*\shell\Trae',
		'HKLM:\Software\Classes\Directory\shell\Trae',
		'HKLM:\Software\Classes\Directory\Background\shell\Trae'
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
			-FriendlyName 'OpenWith Trae Context Menu' `
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

$TraeExe = Resolve-TraeExe $TraeExe
Assert-FileExists $TraeExe 'Trae.exe'
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
	TraeExe = $TraeExe
	Title = $Title
}
