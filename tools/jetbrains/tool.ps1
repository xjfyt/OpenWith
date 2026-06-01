@{
	ToolId = 'jetbrains'
	PackageName = 'OpenWith.JetBrainsContextMenu'
	Publisher = 'CN=OpenWith JetBrains Context Menu'
	DisplayName = 'JetBrains Context Menu'
	ApplicationId = 'JetBrainsContextMenu'
	AppDisplayName = 'JetBrains IDE'
	Description = 'Open with JetBrains IDE'
	RuntimeName = 'JetBrainsContextMenu'
	ClassId = 'FCEAFB2C-0DF2-4091-A65D-33250DE8BD04'
	VerbId = 'OpenWithJetBrains'
	DefaultTitle = "$([char]0x901A)$([char]0x8FC7) JetBrains $([char]0x6253)$([char]0x5F00)"
	LaunchMode = 'OpenPath'
	LogoText = 'J'
	ItemTypes = @('Directory', 'Directory\Background', '*')
	ExeLabel = 'JetBrains IDE executable'
	ExeCandidates = @(
		'%LOCALAPPDATA%\JetBrains\Toolbox\apps\IDEA-U\ch-0\*\bin\idea64.exe',
		'%LOCALAPPDATA%\JetBrains\Toolbox\apps\IDEA-C\ch-0\*\bin\idea64.exe',
		'%ProgramFiles%\JetBrains\IntelliJ IDEA*\bin\idea64.exe',
		'%LOCALAPPDATA%\Programs\IntelliJ IDEA*\bin\idea64.exe',
		'%LOCALAPPDATA%\JetBrains\Toolbox\apps\WebStorm\ch-0\*\bin\webstorm64.exe',
		'%ProgramFiles%\JetBrains\WebStorm*\bin\webstorm64.exe',
		'%LOCALAPPDATA%\Programs\WebStorm*\bin\webstorm64.exe',
		'%LOCALAPPDATA%\JetBrains\Toolbox\apps\PyCharm-P\ch-0\*\bin\pycharm64.exe',
		'%LOCALAPPDATA%\JetBrains\Toolbox\apps\PyCharm-C\ch-0\*\bin\pycharm64.exe',
		'%ProgramFiles%\JetBrains\PyCharm*\bin\pycharm64.exe',
		'%LOCALAPPDATA%\Programs\PyCharm*\bin\pycharm64.exe',
		'%LOCALAPPDATA%\JetBrains\Toolbox\apps\GoLand\ch-0\*\bin\goland64.exe',
		'%ProgramFiles%\JetBrains\GoLand*\bin\goland64.exe',
		'%LOCALAPPDATA%\Programs\GoLand*\bin\goland64.exe',
		'%LOCALAPPDATA%\JetBrains\Toolbox\apps\Rider\ch-0\*\bin\rider64.exe',
		'%ProgramFiles%\JetBrains\Rider*\bin\rider64.exe',
		'%LOCALAPPDATA%\Programs\Rider*\bin\rider64.exe',
		'%LOCALAPPDATA%\JetBrains\Toolbox\apps\CLion\ch-0\*\bin\clion64.exe',
		'%ProgramFiles%\JetBrains\CLion*\bin\clion64.exe',
		'%LOCALAPPDATA%\Programs\CLion*\bin\clion64.exe',
		'%LOCALAPPDATA%\JetBrains\Toolbox\apps\PhpStorm\ch-0\*\bin\phpstorm64.exe',
		'%ProgramFiles%\JetBrains\PhpStorm*\bin\phpstorm64.exe',
		'%LOCALAPPDATA%\Programs\PhpStorm*\bin\phpstorm64.exe',
		'%LOCALAPPDATA%\JetBrains\Toolbox\apps\RubyMine\ch-0\*\bin\rubymine64.exe',
		'%ProgramFiles%\JetBrains\RubyMine*\bin\rubymine64.exe',
		'%LOCALAPPDATA%\Programs\RubyMine*\bin\rubymine64.exe',
		'%LOCALAPPDATA%\JetBrains\Toolbox\apps\DataGrip\ch-0\*\bin\datagrip64.exe',
		'%ProgramFiles%\JetBrains\DataGrip*\bin\datagrip64.exe',
		'%LOCALAPPDATA%\Programs\DataGrip*\bin\datagrip64.exe'
	)
	CommandNames = @(
		'idea64.exe',
		'idea.cmd',
		'webstorm64.exe',
		'webstorm.cmd',
		'pycharm64.exe',
		'pycharm.cmd',
		'goland64.exe',
		'goland.cmd',
		'rider64.exe',
		'rider.cmd',
		'clion64.exe',
		'clion.cmd',
		'phpstorm64.exe',
		'phpstorm.cmd',
		'rubymine64.exe',
		'rubymine.cmd',
		'datagrip64.exe',
		'datagrip.cmd'
	)
	UninstallPatterns = @(
		'*IntelliJ IDEA*',
		'*WebStorm*',
		'*PyCharm*',
		'*GoLand*',
		'*Rider*',
		'*CLion*',
		'*PhpStorm*',
		'*RubyMine*',
		'*DataGrip*',
		'*JetBrains*'
	)
	InstallLocationExeNames = @(
		'bin\idea64.exe',
		'bin\webstorm64.exe',
		'bin\pycharm64.exe',
		'bin\goland64.exe',
		'bin\rider64.exe',
		'bin\clion64.exe',
		'bin\phpstorm64.exe',
		'bin\rubymine64.exe',
		'bin\datagrip64.exe',
		'idea64.exe',
		'webstorm64.exe',
		'pycharm64.exe',
		'goland64.exe',
		'rider64.exe',
		'clion64.exe',
		'phpstorm64.exe',
		'rubymine64.exe',
		'datagrip64.exe'
	)
	LegacyVerbIds = @('OpenWithJetBrains')
	LegacySettingsKeys = @()
}
