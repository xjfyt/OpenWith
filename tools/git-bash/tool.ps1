@{
	ToolId = 'git-bash'
	PackageName = 'OpenWith.GitBashHereContextMenu'
	Publisher = 'CN=OpenWith Git Bash Here Context Menu'
	DisplayName = 'Git Bash Here Context Menu'
	ApplicationId = 'GitBashHereContextMenu'
	AppDisplayName = 'Git Bash'
	Description = 'Open Git Bash here'
	RuntimeName = 'GitBashHereContextMenu'
	ClassId = 'EE3EDDBD-613B-4D0C-B65F-50B21BB8F678'
	VerbId = 'GitBashHere'
	DefaultTitle = 'Git Bash Here'
	LaunchMode = 'GitBashHere'
	LogoText = 'G'
	ItemTypes = @('Directory', 'Directory\Background', '*')
	ExeLabel = 'git-bash.exe'
	ExeCandidates = @(
		'%ProgramFiles%\Git\git-bash.exe',
		'%ProgramFiles(x86)%\Git\git-bash.exe',
		'%LOCALAPPDATA%\Programs\Git\git-bash.exe'
	)
	CommandNames = @('git-bash.exe')
	UninstallPatterns = @('*Git*')
	InstallLocationExeNames = @('git-bash.exe')
	LegacyVerbIds = @('GitBashHere')
	LegacySettingsKeys = @('HKCU:\Software\Classes\GitBashHereContextMenu')
}
