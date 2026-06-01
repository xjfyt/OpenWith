@{
	ToolId = 'windsurf'
	PackageName = 'OpenWith.WindsurfContextMenu'
	Publisher = 'CN=OpenWith Windsurf Context Menu'
	DisplayName = 'Windsurf Context Menu'
	ApplicationId = 'WindsurfContextMenu'
	AppDisplayName = 'Windsurf'
	Description = 'Open with Windsurf'
	RuntimeName = 'WindsurfContextMenu'
	ClassId = '720E89AC-5B6D-4DB1-908A-6AF8477BCF1F'
	VerbId = 'OpenWithWindsurf'
	DefaultTitle = "$([char]0x901A)$([char]0x8FC7) Windsurf $([char]0x6253)$([char]0x5F00)"
	LaunchMode = 'OpenPath'
	LogoText = 'W'
	ItemTypes = @('Directory', 'Directory\Background', '*')
	ExeLabel = 'Windsurf.exe'
	ExeCandidates = @(
		'%LOCALAPPDATA%\Programs\Windsurf\Windsurf.exe',
		'%LOCALAPPDATA%\Programs\windsurf\Windsurf.exe',
		'%ProgramFiles%\Windsurf\Windsurf.exe',
		'%ProgramFiles(x86)%\Windsurf\Windsurf.exe'
	)
	CommandNames = @('windsurf.cmd', 'windsurf.exe')
	UninstallPatterns = @('*Windsurf*')
	InstallLocationExeNames = @('Windsurf.exe')
	LegacyVerbIds = @('OpenWithWindsurf')
	LegacySettingsKeys = @()
}
