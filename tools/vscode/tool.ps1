@{
	ToolId = 'vscode'
	PackageName = 'OpenWith.VSCodeContextMenu'
	Publisher = 'CN=OpenWith VSCode Context Menu'
	DisplayName = 'VSCode Context Menu'
	ApplicationId = 'VSCodeContextMenu'
	AppDisplayName = 'Visual Studio Code'
	Description = 'Open with Code'
	RuntimeName = 'VSCodeContextMenu'
	ClassId = '0D3AA95C-38CC-410B-AD0D-D4C74EC3C2B1'
	VerbId = 'OpenWithVSCode'
	DefaultTitle = "$([char]0x901A)$([char]0x8FC7) Code $([char]0x6253)$([char]0x5F00)"
	LaunchMode = 'OpenPath'
	LogoText = 'C'
	ItemTypes = @('Directory', 'Directory\Background', '*')
	ExeLabel = 'Code.exe'
	ExeCandidates = @(
		'%LOCALAPPDATA%\Programs\Microsoft VS Code\Code.exe',
		'%ProgramFiles%\Microsoft VS Code\Code.exe',
		'%ProgramFiles(x86)%\Microsoft VS Code\Code.exe',
		'%LOCALAPPDATA%\Programs\Microsoft VS Code Insiders\Code - Insiders.exe',
		'%ProgramFiles%\Microsoft VS Code Insiders\Code - Insiders.exe',
		'%ProgramFiles(x86)%\Microsoft VS Code Insiders\Code - Insiders.exe'
	)
	CommandNames = @('code.cmd', 'code.exe')
	UninstallPatterns = @('*Visual Studio Code*', '*VSCode*', '*Code.exe*')
	InstallLocationExeNames = @('Code.exe', 'Code - Insiders.exe')
	LegacyVerbIds = @('OpenWithVSCode')
	LegacySettingsKeys = @('HKCU:\Software\Classes\OpenWithVSCodeContextMenu')
}
