@{
	ToolId = 'trae'
	PackageName = 'OpenWith.TraeContextMenu'
	Publisher = 'CN=OpenWith Trae Context Menu'
	DisplayName = 'Trae Context Menu'
	ApplicationId = 'TraeContextMenu'
	AppDisplayName = 'Trae'
	Description = 'Open with Trae'
	RuntimeName = 'TraeContextMenu'
	ClassId = 'B8B07D8E-1327-41D0-86ED-DC7E1A243B3D'
	VerbId = 'OpenWithTrae'
	DefaultTitle = "$([char]0x901A)$([char]0x8FC7) Trae $([char]0x6253)$([char]0x5F00)"
	LaunchMode = 'OpenPath'
	LogoText = 'T'
	ItemTypes = @('Directory', 'Directory\Background', '*')
	ExeLabel = 'Trae.exe'
	ExeCandidates = @(
		'%LOCALAPPDATA%\Programs\Trae\Trae.exe',
		'%LOCALAPPDATA%\Programs\Trae CN\Trae.exe',
		'%LOCALAPPDATA%\Programs\trae\Trae.exe',
		'%LOCALAPPDATA%\Trae\Trae.exe',
		'%ProgramFiles%\Trae\Trae.exe',
		'%ProgramFiles(x86)%\Trae\Trae.exe'
	)
	CommandNames = @()
	UninstallPatterns = @('*Trae*')
	InstallLocationExeNames = @('Trae.exe')
	LegacyVerbIds = @('OpenWithTrae')
	LegacySettingsKeys = @('HKCU:\Software\Classes\TraeContextMenu')
}
