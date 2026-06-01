@{
	ToolId = 'antigravity'
	PackageName = 'OpenWith.AntigravityContextMenu'
	Publisher = 'CN=OpenWith Antigravity Context Menu'
	DisplayName = 'Antigravity Context Menu'
	ApplicationId = 'AntigravityContextMenu'
	AppDisplayName = 'Antigravity'
	Description = 'Open with Antigravity'
	RuntimeName = 'AntigravityContextMenu'
	ClassId = 'E07AE7AA-313B-418B-AB40-6FD29ABE24F1'
	VerbId = 'OpenWithAntigravity'
	DefaultTitle = "$([char]0x901A)$([char]0x8FC7) Antigravity $([char]0x6253)$([char]0x5F00)"
	LaunchMode = 'OpenPath'
	LogoText = 'A'
	ItemTypes = @('Directory', 'Directory\Background', '*')
	ExeLabel = 'Antigravity.exe'
	ExeCandidates = @(
		'%LOCALAPPDATA%\Programs\Antigravity\Antigravity.exe',
		'%ProgramFiles%\Antigravity\Antigravity.exe',
		'%ProgramFiles(x86)%\Antigravity\Antigravity.exe'
	)
	CommandNames = @()
	UninstallPatterns = @('*Antigravity*')
	InstallLocationExeNames = @('Antigravity.exe')
	LegacyVerbIds = @('OpenWithAntigravity')
	LegacySettingsKeys = @('HKCU:\Software\Classes\AntigravityContextMenu')
}
