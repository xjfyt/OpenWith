param(
	[Parameter(Mandatory = $true)]
	[string]$Tool,
	[string]$ExePath = '',
	[string]$Title = '',
	[string]$Distro = '',
	[ValidateSet('auto', 'x64', 'arm64')]
	[string]$Architecture = 'auto',
	[switch]$ForceCompile,
	[switch]$UsePrebuilt
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ToolsRoot = Join-Path $ProjectRoot 'tools'
$SourcePath = Join-Path $ProjectRoot 'src\OpenWithExplorerCommand.cpp'
$PackageVersion = '1.0.0.0'
$PublisherDisplayName = 'OpenWith'
$SharedRegistryRoot = 'HKCU:\Software\Classes\OpenWithContextMenus'

function Assert-FileExists([string]$Path, [string]$Label) {
	if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
		throw "$Label not found: $Path"
	}
}

function ConvertTo-ExpandedPath([string]$Path) {
	return [Environment]::ExpandEnvironmentVariables($Path)
}

function Test-LikeAny([string]$Value, [object[]]$Patterns) {
	if ([string]::IsNullOrWhiteSpace($Value)) {
		return $false
	}

	foreach ($pattern in @($Patterns)) {
		if ($Value -like $pattern) {
			return $true
		}
	}

	return $false
}

function Resolve-PrebuiltArchitecture([string]$RequestedArchitecture) {
	if ($RequestedArchitecture -ne 'auto') {
		return $RequestedArchitecture
	}

	$nativeArchitecture = $env:PROCESSOR_ARCHITEW6432
	if ([string]::IsNullOrWhiteSpace($nativeArchitecture)) {
		$nativeArchitecture = $env:PROCESSOR_ARCHITECTURE
	}

	if ($nativeArchitecture -and $nativeArchitecture.ToUpperInvariant() -eq 'ARM64') {
		return 'arm64'
	}

	return 'x64'
}

function Resolve-WildcardCandidate([string]$Pattern) {
	$expanded = ConvertTo-ExpandedPath $Pattern
	$resolved = Resolve-Path -Path $expanded -ErrorAction SilentlyContinue |
		ForEach-Object { Get-Item -LiteralPath $_.Path -ErrorAction SilentlyContinue } |
		Where-Object { $_ -and -not $_.PSIsContainer } |
		Sort-Object FullName -Descending

	foreach ($item in $resolved) {
		$item.FullName
	}
}

function Resolve-ExecutableFromConfig([hashtable]$Config, [string]$ExplicitPath) {
	if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
		return (ConvertTo-ExpandedPath $ExplicitPath)
	}

	foreach ($candidate in @($Config.ExeCandidates)) {
		foreach ($path in Resolve-WildcardCandidate $candidate) {
			if (Test-Path -LiteralPath $path -PathType Leaf) {
				return $path
			}
		}
	}

	foreach ($commandName in @($Config.CommandNames)) {
		$command = Get-Command $commandName -ErrorAction SilentlyContinue | Select-Object -First 1
		if ($command -and $command.Source -and (Test-Path -LiteralPath $command.Source -PathType Leaf)) {
			return $command.Source
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
			$haystack = @($item.DisplayName, $item.InstallLocation, $item.DisplayIcon, $item.UninstallString) -join "`n"
			if (-not (Test-LikeAny $haystack $Config.UninstallPatterns)) {
				continue
			}

			$possiblePaths = @()
			if ($item.DisplayIcon) {
				$possiblePaths += ($item.DisplayIcon -replace '^"', '' -replace '",.*$', '' -replace ',.*$', '')
			}
			if ($item.InstallLocation) {
				foreach ($exeName in @($Config.InstallLocationExeNames)) {
					$possiblePaths += Join-Path $item.InstallLocation $exeName
				}
			}

			foreach ($path in $possiblePaths) {
				if (Test-Path -LiteralPath $path -PathType Leaf) {
					return $path
				}
			}
		}
	}

	$label = if ($Config.ExeLabel) { $Config.ExeLabel } else { 'target executable' }
	throw "$label was not found. Re-run with -ExePath `"C:\Path\To\App.exe`"."
}

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

	throw 'Visual Studio C++ build tools were not found. Use the prebuilt DLL in bin\x64, or install Visual Studio Build Tools.'
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

function New-Logo([string]$Path, [string]$Text, [int]$Size) {
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
	$graphics.DrawString($Text, $font, $brush, (New-Object System.Drawing.RectangleF 0, 0, $Size, $Size), $format)
	$bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
	$graphics.Dispose()
	$bitmap.Dispose()
	$brush.Dispose()
	$font.Dispose()
	$format.Dispose()
}

function Install-ExplorerCommandDll([string]$ExternalDir, [string]$DllPath, [string]$ObjPath, [string]$ResolvedArchitecture) {
	New-Item -ItemType Directory -Force -Path $ExternalDir | Out-Null
	$prebuiltDllPath = Join-Path $ProjectRoot "bin\$ResolvedArchitecture\OpenWithExplorerCommand.dll"

	if (-not $ForceCompile -and (Test-Path -LiteralPath $prebuiltDllPath -PathType Leaf)) {
		Copy-Item -LiteralPath $prebuiltDllPath -Destination $DllPath -Force
		return 'prebuilt'
	}

	if ($UsePrebuilt) {
		throw "Prebuilt DLL not found: $prebuiltDllPath"
	}

	Assert-FileExists $SourcePath 'Explorer command source'
	$buildScript = Join-Path $PSScriptRoot 'build-prebuilt-dll.ps1'
	& $buildScript -Architecture $ResolvedArchitecture -OutputPath $DllPath | Out-Host

	return 'compiled'
}

function Write-Manifest([hashtable]$Config, [string]$ManifestPath, [string]$AssetsDir, [string]$ClassId, [string]$DllName, [string]$TargetExePath) {
	New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ManifestPath), $AssetsDir | Out-Null
	New-Logo (Join-Path $AssetsDir 'Logo44.png') $Config.LogoText 44
	New-Logo (Join-Path $AssetsDir 'Logo150.png') $Config.LogoText 150

	$itemTypeXml = foreach ($itemType in @($Config.ItemTypes)) {
		$escapedItemType = [System.Security.SecurityElement]::Escape($itemType)
		"            <desktop5:ItemType Type=`"$escapedItemType`">`r`n              <desktop5:Verb Id=`"$($Config.VerbId)`" Clsid=`"$ClassId`" />`r`n            </desktop5:ItemType>"
	}

	$applicationExecutable = if ($Config.ApplicationExecutable) { $Config.ApplicationExecutable } else { 'OpenWithContextMenu.exe' }
	$manifest = @"
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
    Name="$($Config.PackageName)"
    Publisher="$($Config.Publisher)"
    Version="$PackageVersion"
    ProcessorArchitecture="neutral" />
  <Properties>
    <DisplayName>$([System.Security.SecurityElement]::Escape($Config.DisplayName))</DisplayName>
    <PublisherDisplayName>$PublisherDisplayName</PublisherDisplayName>
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
    <Application Id="$($Config.ApplicationId)"
      Executable="$applicationExecutable"
      uap10:TrustLevel="mediumIL"
      uap10:RuntimeBehavior="win32App">
      <uap:VisualElements
        AppListEntry="none"
        DisplayName="$([System.Security.SecurityElement]::Escape($Config.AppDisplayName))"
        Description="$([System.Security.SecurityElement]::Escape($Config.Description))"
        BackgroundColor="transparent"
        Square150x150Logo="Assets\Logo150.png"
        Square44x44Logo="Assets\Logo44.png" />
      <Extensions>
        <desktop4:Extension Category="windows.fileExplorerContextMenus">
          <desktop4:FileExplorerContextMenus>
$($itemTypeXml -join "`r`n")
          </desktop4:FileExplorerContextMenus>
        </desktop4:Extension>
        <com:Extension Category="windows.comServer">
          <com:ComServer>
            <com:SurrogateServer DisplayName="$([System.Security.SecurityElement]::Escape($Config.DisplayName))">
              <com:Class Id="$ClassId" Path="$DllName" ThreadingModel="STA" />
            </com:SurrogateServer>
          </com:ComServer>
        </com:Extension>
      </Extensions>
    </Application>
  </Applications>
</Package>
"@

	Set-Content -LiteralPath $ManifestPath -Value $manifest -Encoding UTF8
}

function Remove-ExistingPackage([string]$PackageName) {
	Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue | ForEach-Object {
		Remove-AppxPackage -Package $_.PackageFullName -ErrorAction Stop
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

function Set-ContextMenuSettings([hashtable]$Config, [string]$ClassId, [string]$ResolvedExePath, [string]$ResolvedTitle, [string]$ResolvedDistro) {
	$toolKey = Join-Path $SharedRegistryRoot "Tools\$($Config.ToolId)"
	$classMapKey = Join-Path $SharedRegistryRoot "ClassMap\{$ClassId}"

	New-Item -Path $toolKey -Force | Out-Null
	New-ItemProperty -Path $toolKey -Name 'ToolId' -Value $Config.ToolId -PropertyType String -Force | Out-Null
	New-ItemProperty -Path $toolKey -Name 'Title' -Value $ResolvedTitle -PropertyType ExpandString -Force | Out-Null
	New-ItemProperty -Path $toolKey -Name 'ExePath' -Value $ResolvedExePath -PropertyType ExpandString -Force | Out-Null
	New-ItemProperty -Path $toolKey -Name 'IconPath' -Value $ResolvedExePath -PropertyType ExpandString -Force | Out-Null
	New-ItemProperty -Path $toolKey -Name 'LaunchMode' -Value $Config.LaunchMode -PropertyType String -Force | Out-Null
	if ($ResolvedDistro) {
		New-ItemProperty -Path $toolKey -Name 'Distro' -Value $ResolvedDistro -PropertyType String -Force | Out-Null
	} elseif (Get-ItemProperty -Path $toolKey -Name 'Distro' -ErrorAction SilentlyContinue) {
		Remove-ItemProperty -Path $toolKey -Name 'Distro' -Force
	}

	New-Item -Path $classMapKey -Force | Out-Null
	New-ItemProperty -Path $classMapKey -Name 'ToolId' -Value $Config.ToolId -PropertyType String -Force | Out-Null
}

function Remove-LegacyRegistryVerbs([hashtable]$Config) {
	foreach ($verb in @($Config.LegacyVerbIds)) {
		$keys = @(
			"HKCU:\Software\Classes\*\shell\$verb",
			"HKCU:\Software\Classes\Directory\shell\$verb",
			"HKCU:\Software\Classes\Directory\Background\shell\$verb",
			"HKLM:\Software\Classes\*\shell\$verb",
			"HKLM:\Software\Classes\Directory\shell\$verb",
			"HKLM:\Software\Classes\Directory\Background\shell\$verb"
		)

		foreach ($key in $keys) {
			Remove-RegistryKeyIfPresent $key
		}
	}

	foreach ($key in @($Config.LegacySettingsKeys)) {
		Remove-RegistryKeyIfPresent $key
	}
}

function Ensure-SigningCertificate([hashtable]$Config, [string]$PackageDir, [string]$CertPath) {
	New-Item -ItemType Directory -Force -Path $PackageDir | Out-Null
	$cert = Get-ChildItem Cert:\CurrentUser\My |
		Where-Object { $_.Subject -eq $Config.Publisher -and $_.HasPrivateKey } |
		Sort-Object NotAfter -Descending |
		Select-Object -First 1

	if (-not $cert) {
		$cert = New-SelfSignedCertificate `
			-Type Custom `
			-Subject $Config.Publisher `
			-FriendlyName $Config.DisplayName `
			-CertStoreLocation 'Cert:\CurrentUser\My' `
			-KeyUsage DigitalSignature `
			-TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3', '2.5.29.19={text}')
	}

	Export-Certificate -Cert $cert -FilePath $CertPath -Force | Out-Null
	Import-Certificate -FilePath $CertPath -CertStoreLocation 'Cert:\CurrentUser\TrustedPeople' | Out-Null
	Import-Certificate -FilePath $CertPath -CertStoreLocation 'Cert:\CurrentUser\Root' | Out-Null
	return $cert
}

function Install-SignedSparsePackage([hashtable]$Config, [string]$ManifestDir, [string]$PackageDir, [string]$AppxPath, [string]$CertPath, [string]$ExternalDir) {
	$makeappx = Find-WindowsSdkTool 'makeappx.exe'
	$signtool = Find-WindowsSdkTool 'signtool.exe'
	$cert = Ensure-SigningCertificate $Config $PackageDir $CertPath

	New-Item -ItemType Directory -Force -Path $PackageDir | Out-Null
	if (Test-Path -LiteralPath $AppxPath) {
		Remove-Item -LiteralPath $AppxPath -Force
	}

	Invoke-Native $makeappx @('pack', '/d', $ManifestDir, '/p', $AppxPath, '/nv')
	Invoke-Native $signtool @('sign', '/fd', 'SHA256', '/sha1', $cert.Thumbprint, $AppxPath)
	Add-AppxPackage -Path $AppxPath -ExternalLocation $ExternalDir -ForceApplicationShutdown -ErrorAction Stop
}

$toolDir = Join-Path $ToolsRoot $Tool
$configPath = Join-Path $toolDir 'tool.ps1'
Assert-FileExists $configPath 'Tool config'

$config = & $configPath
$resolvedArchitecture = Resolve-PrebuiltArchitecture $Architecture
$resolvedTitle = if ($Title) { $Title } else { $config.DefaultTitle }
$resolvedDistro = if ($Distro) { $Distro } else { $config.DefaultDistro }
$resolvedExePath = Resolve-ExecutableFromConfig $config $ExePath
Assert-FileExists $resolvedExePath $config.ExeLabel

$runtimeRoot = Join-Path $env:LOCALAPPDATA "OpenWith\$($config.RuntimeName)"
$externalDir = Join-Path $runtimeRoot 'external'
$manifestDir = Join-Path $runtimeRoot 'manifest'
$packageDir = Join-Path $runtimeRoot 'package'
$assetsDir = Join-Path $externalDir 'Assets'
$dllName = 'OpenWithExplorerCommand.dll'
$dllPath = Join-Path $externalDir $dllName
$objPath = Join-Path $externalDir 'OpenWithExplorerCommand.obj'
$manifestPath = Join-Path $manifestDir 'AppxManifest.xml'
$appxPath = Join-Path $packageDir "$($config.RuntimeName).appx"
$certPath = Join-Path $packageDir "$($config.RuntimeName).cer"
$classId = ([guid]$config.ClassId).ToString('D').ToUpperInvariant()

$dllMode = Install-ExplorerCommandDll $externalDir $dllPath $objPath $resolvedArchitecture
Assert-FileExists $dllPath 'Explorer command DLL'
Write-Manifest $config $manifestPath $assetsDir $classId $dllName $resolvedExePath
Set-ContextMenuSettings $config $classId $resolvedExePath $resolvedTitle $resolvedDistro
Remove-LegacyRegistryVerbs $config
Remove-ExistingPackage $config.PackageName

$mode = 'loose manifest'
try {
	Add-AppxPackage -Register $manifestPath -ExternalLocation $externalDir -ForceApplicationShutdown -ErrorAction Stop
} catch {
	Write-Warning "Loose package registration failed: $($_.Exception.Message)"
	$mode = 'signed sparse package'
	Install-SignedSparsePackage $config $manifestDir $packageDir $appxPath $certPath $externalDir
}

$package = Get-AppxPackage -Name $config.PackageName -ErrorAction Stop
[PSCustomObject]@{
	Tool = $config.ToolId
	Architecture = $resolvedArchitecture
	Mode = $mode
	DllMode = $dllMode
	PackageName = $package.Name
	PackageFullName = $package.PackageFullName
	ExternalLocation = $externalDir
	DllPath = $dllPath
	ExePath = $resolvedExePath
	Title = $resolvedTitle
	Distro = $resolvedDistro
}
