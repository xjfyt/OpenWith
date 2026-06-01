@{
	ToolId = 'cursor'
	PackageName = 'OpenWith.CursorContextMenu'
	Publisher = 'CN=OpenWith Cursor Context Menu'
	DisplayName = 'Cursor Context Menu'
	ApplicationId = 'CursorContextMenu'
	AppDisplayName = 'Cursor'
	Description = 'Open with Cursor'
	RuntimeName = 'CursorContextMenu'
	ClassId = 'BDACEFBC-1329-4780-A158-32D585ADA8B2'
	VerbId = 'OpenWithCursor'
	DefaultTitle = "$([char]0x901A)$([char]0x8FC7) Cursor $([char]0x6253)$([char]0x5F00)"
	LaunchMode = 'OpenPath'
	LogoText = 'C'
	ItemTypes = @('Directory', 'Directory\Background', '*')
	ExeLabel = 'Cursor.exe'
	ExeCandidates = @(
		'%LOCALAPPDATA%\Programs\Cursor\Cursor.exe',
		'%LOCALAPPDATA%\Programs\cursor\Cursor.exe',
		'%ProgramFiles%\Cursor\Cursor.exe',
		'%ProgramFiles(x86)%\Cursor\Cursor.exe'
	)
	CommandNames = @('cursor.cmd', 'cursor.exe')
	UninstallPatterns = @('*Cursor*')
	InstallLocationExeNames = @('Cursor.exe')
	LegacyVerbIds = @('OpenWithCursor')
	LegacySettingsKeys = @()
}
