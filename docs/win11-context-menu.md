一、项目介绍

1、目标

本项目把编辑器、终端等开发工具加入 Windows 11 资源管理器一级右键菜单。目标效果类似 VSCode 安装器中可选的“通过 Code 打开”，但不依赖安装器是否勾选对应选项。

2、为什么不用普通注册表

传统注册表写法通常是：

```reg
HKEY_CLASSES_ROOT\*\shell\AppName\command
HKEY_CLASSES_ROOT\Directory\shell\AppName\command
HKEY_CLASSES_ROOT\Directory\Background\shell\AppName\command
```

这种方式仍然有效，但在 Windows 11 的新版右键菜单中通常会进入“显示更多选项”。要直接显示在一级菜单，需要使用 Windows 11 的 Explorer command 扩展方式。

二、VSCode 官方实现方式

1、关键文件

VSCode 主仓库中的关键位置：

- `vscode/resources/win32/appx/AppxManifest.xml`
- `vscode/build/win32/code.iss`
- `vscode/build/win32/explorer-dll-fetcher.ts`

2、核心流程

VSCode 的安装器会：

1. 准备一个实现 `IExplorerCommand` 的 COM DLL。
2. 准备 AppX/MSIX manifest，声明 `windows.fileExplorerContextMenus`。
3. 在 manifest 中把 `Directory`、`Directory\Background`、`*` 绑定到同一个 `Verb` 和 COM `Clsid`。
4. 在 manifest 中声明 `windows.comServer`，让 Explorer 通过 COM surrogate 加载 DLL。
5. 通过 `Add-AppxPackage -Register ... -ExternalLocation ...` 或 sparse package 方式注册。
6. DLL 在 `Invoke()` 中读取右键目标路径并启动目标应用。

三、本项目实现方式

1、文件结构

每个软件单独维护一套文件：

- `install-win11-context-menu.ps1`
- `uninstall-win11-context-menu.ps1`
- `win11-context-menu/src/*ExplorerCommand.cpp`

2、安装脚本做什么

安装脚本会：

1. 编译 `IExplorerCommand` COM DLL。
2. 生成运行时目录：`%LOCALAPPDATA%\OpenWith\<AppName>ContextMenu`。
3. 生成 AppX manifest 和占位 logo。
4. 写入 `HKCU:\Software\Classes\<AppName>ContextMenu`，保存 `Title` 和 `ExePath`。
5. 删除当前用户下旧式 `shell\<AppName>` 菜单，避免重复。
6. 使用 loose manifest 注册 AppX：

```powershell
Add-AppxPackage -Register AppxManifest.xml -ExternalLocation <external-dir>
```

如果 loose manifest 注册失败，脚本会退回到签名 sparse AppX 的方式。

3、COM DLL 做什么

COM DLL 会：

- `GetTitle()`：从注册表读取菜单标题。
- `GetIcon()`：使用目标 exe 作为图标。
- `GetState()`：目标 exe 存在时显示，否则隐藏。
- `Invoke()`：执行目标程序并传入右键目标路径。

四、Visual Studio Code

1、文件

- `visual-studio-code/install-win11-context-menu.ps1`
- `visual-studio-code/uninstall-win11-context-menu.ps1`
- `visual-studio-code/win11-context-menu/src/VSCodeExplorerCommand.cpp`

2、默认探测路径

安装脚本会自动尝试：

- `%LOCALAPPDATA%\Programs\Microsoft VS Code\Code.exe`
- `%ProgramFiles%\Microsoft VS Code\Code.exe`
- `%ProgramFiles(x86)%\Microsoft VS Code\Code.exe`
- `%LOCALAPPDATA%\Programs\Microsoft VS Code Insiders\Code - Insiders.exe`
- `%ProgramFiles%\Microsoft VS Code Insiders\Code - Insiders.exe`
- `%ProgramFiles(x86)%\Microsoft VS Code Insiders\Code - Insiders.exe`
- 注册表卸载项中的 `InstallLocation` / `DisplayIcon`

3、安装

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\visual-studio-code\install-win11-context-menu.ps1
```

如果 VSCode 在非标准路径：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\visual-studio-code\install-win11-context-menu.ps1 -VSCodeExe "C:\Path\To\Code.exe"
```

4、卸载

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\visual-studio-code\uninstall-win11-context-menu.ps1 -RemoveGeneratedFiles
```

五、Antigravity

1、文件

- `antigravity/install-win11-context-menu.ps1`
- `antigravity/uninstall-win11-context-menu.ps1`
- `antigravity/win11-context-menu/src/AntigravityExplorerCommand.cpp`

2、默认目标

```powershell
%LOCALAPPDATA%\Programs\Antigravity\Antigravity.exe
```

3、安装

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\antigravity\install-win11-context-menu.ps1
```

4、卸载

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\antigravity\uninstall-win11-context-menu.ps1 -RemoveGeneratedFiles
```

六、Trae

1、文件

- `trae/install-win11-context-menu.ps1`
- `trae/uninstall-win11-context-menu.ps1`
- `trae/win11-context-menu/src/TraeExplorerCommand.cpp`

2、默认探测路径

安装脚本会自动尝试：

- `%LOCALAPPDATA%\Programs\Trae\Trae.exe`
- `%LOCALAPPDATA%\Programs\Trae CN\Trae.exe`
- `%LOCALAPPDATA%\Programs\trae\Trae.exe`
- `%LOCALAPPDATA%\Trae\Trae.exe`
- `%ProgramFiles%\Trae\Trae.exe`
- `%ProgramFiles(x86)%\Trae\Trae.exe`
- 注册表卸载项中的 `InstallLocation` / `DisplayIcon`

3、安装

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\trae\install-win11-context-menu.ps1 -TraeExe "C:\Path\To\Trae.exe"
```

4、卸载

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\trae\uninstall-win11-context-menu.ps1 -RemoveGeneratedFiles
```

七、Git Bash Here

1、文件

- `git-bash/install-win11-context-menu.ps1`
- `git-bash/uninstall-win11-context-menu.ps1`
- `git-bash/win11-context-menu/src/GitBashHereExplorerCommand.cpp`

2、默认目标

```powershell
C:\Program Files\Git\git-bash.exe
```

3、安装

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\git-bash\install-win11-context-menu.ps1
```

如果 Git Bash 在非标准路径：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\git-bash\install-win11-context-menu.ps1 -GitBashExe "C:\Path\To\git-bash.exe"
```

4、卸载

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\git-bash\uninstall-win11-context-menu.ps1 -RemoveGeneratedFiles
```

5、路径处理

Git Bash 的 COM DLL 会把右键目标转换为目录：

- 目录、文件夹空白处：使用该目录。
- 文件：使用文件所在目录。

然后执行：

```powershell
git-bash.exe --cd=<directory>
```

Windows 11 的 `fileExplorerContextMenus` schema 不接受 `Drive` 作为 `ItemType`。如果要在盘符根目录打开 Git Bash，进入盘符后在空白处右键即可走 `Directory\Background`。

八、新增其他软件

1、复制目录

复制一个现有目录，例如 `trae`。

2、替换标识

替换软件名、默认 exe 路径、注册表 key、package name、DLL 文件名。

3、生成 CLSID

生成新的 CLSID，并替换脚本和 C++ 源码中的 class id。

4、修改 manifest

修改 manifest 中的 `Verb Id` 和 DLL 文件名。

5、验证

```powershell
Get-AppxPackage -Name OpenWith.<AppName>ContextMenu
reg query "HKCU\Software\Classes\<AppName>ContextMenu" /s
```

九、注意事项

1、运行时目录

运行时目录不能删除，否则菜单的 COM DLL 会失效。

2、菜单缓存

Explorer 可能缓存菜单。安装后如果没有立刻出现，可以重启资源管理器或注销重登。

3、旧式菜单

如果旧式 `.reg` 写到了 `HKLM`，普通用户无法删除，它可能仍然留在“显示更多选项”里；一级菜单由新的 AppX/COM 扩展提供。

4、重新编译

修改 C++ 源码后重新运行安装脚本即可重新编译并注册。
