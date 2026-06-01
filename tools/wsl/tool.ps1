@{
	ToolId = 'wsl'
	PackageName = 'OpenWith.WslHereContextMenu'
	Publisher = 'CN=OpenWith WSL Here Context Menu'
	DisplayName = 'WSL Here Context Menu'
	ApplicationId = 'WslHereContextMenu'
	AppDisplayName = 'WSL'
	Description = 'Open WSL here'
	RuntimeName = 'WslHereContextMenu'
	ClassId = '8CEDFD3D-3BEA-4866-8CA0-0267E5EBF157'
	VerbId = 'WslHere'
	DefaultTitle = 'WSL Here'
	DefaultDistro = ''
	LaunchMode = 'WslHere'
	LogoText = 'W'
	ItemTypes = @('Directory', 'Directory\Background', '*')
	ExeLabel = 'wsl.exe'
	ExeCandidates = @(
		'%WINDIR%\System32\wsl.exe',
		'%WINDIR%\Sysnative\wsl.exe'
	)
	CommandNames = @('wsl.exe')
	UninstallPatterns = @()
	InstallLocationExeNames = @('wsl.exe')
	LegacyVerbIds = @('WslHere')
	LegacySettingsKeys = @()
}
