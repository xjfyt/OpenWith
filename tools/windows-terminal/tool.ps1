@{
	ToolId = 'windows-terminal'
	PackageName = 'OpenWith.WindowsTerminalHereContextMenu'
	Publisher = 'CN=OpenWith Windows Terminal Here Context Menu'
	DisplayName = 'Windows Terminal Here Context Menu'
	ApplicationId = 'WindowsTerminalHereContextMenu'
	AppDisplayName = 'Windows Terminal'
	Description = 'Open Windows Terminal here'
	RuntimeName = 'WindowsTerminalHereContextMenu'
	ClassId = '37B4640A-CA7E-4714-BD0C-1E6E1D5E75EC'
	VerbId = 'WindowsTerminalHere'
	DefaultTitle = 'Windows Terminal Here'
	LaunchMode = 'WindowsTerminalHere'
	LogoText = 'T'
	ItemTypes = @('Directory', 'Directory\Background', '*')
	ExeLabel = 'wt.exe'
	ExeCandidates = @(
		'%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe',
		'%ProgramFiles%\WindowsApps\Microsoft.WindowsTerminal_*\wt.exe',
		'%ProgramFiles%\WindowsApps\Microsoft.WindowsTerminalPreview_*\wt.exe'
	)
	CommandNames = @('wt.exe')
	UninstallPatterns = @('*Windows Terminal*')
	InstallLocationExeNames = @('wt.exe')
	LegacyVerbIds = @('WindowsTerminalHere')
	LegacySettingsKeys = @()
}
