# Windows 11 一级右键菜单实现说明

本项目的目标是把编辑器类软件加入 Windows 11 资源管理器的一级右键菜单，效果类似 VSCode 的“通过 Code 打开”。

## 为什么普通 `.reg` 不够

传统注册表写法通常是：

```reg
HKEY_CLASSES_ROOT\*\shell\AppName\command
HKEY_CLASSES_ROOT\Directory\shell\AppName\command
HKEY_CLASSES_ROOT\Directory\Background\shell\AppName\command
```

这种方式仍然有效，但在 Windows 11 的新版右键菜单中会被放进“显示更多选项”。如果希望直接出现在一级菜单，需要使用 Windows 11 支持的 Explorer command 扩展方式。

## VSCode 的方式

VSCode 主仓库里的关键文件：

- `vscode/resources/win32/appx/AppxManifest.xml`
- `vscode/build/win32/code.iss`
- `vscode/build/win32/explorer-dll-fetcher.ts`

VSCode 的流程是：

1. 准备一个实现 `IExplorerCommand` 的 COM DLL。
2. 准备一个 AppX/MSIX manifest，声明 `windows.fileExplorerContextMenus`。
3. 在 manifest 中把 `Directory`、`Directory\Background`、`*` 绑定到同一个 `Verb` 和 COM `Clsid`。
4. 在 manifest 中声明 `windows.comServer`，让 Explorer 通过 COM surrogate 加载这个 DLL。
5. 通过 `Add-AppxPackage -Register ... -ExternalLocation ...` 或 sparse package 方式注册。
6. DLL 在 `Invoke()` 中读取右键目标路径并启动目标应用。

## 本项目的实现

本项目为每个软件单独生成一套：

- `install-win11-context-menu.ps1`
- `uninstall-win11-context-menu.ps1`
- `win11-context-menu/src/*ExplorerCommand.cpp`

安装脚本会：

1. 编译 `IExplorerCommand` COM DLL。
2. 生成运行时目录：`%LOCALAPPDATA%\OpenWith\<AppName>ContextMenu`。
3. 生成 AppX manifest 和占位 logo。
4. 写入 `HKCU:\Software\Classes\<AppName>ContextMenu`：
   - `Title`
   - `ExePath`
5. 删除当前用户下旧式 `shell\<AppName>` 菜单，避免重复。
6. 使用 loose manifest 注册 AppX：

```powershell
Add-AppxPackage -Register AppxManifest.xml -ExternalLocation <external-dir>
```

如果 loose manifest 注册失败，脚本会退回到签名 sparse AppX 的方式。

COM DLL 会：

- `GetTitle()`：从注册表读取菜单标题。
- `GetIcon()`：使用目标 exe 作为图标。
- `GetState()`：目标 exe 存在时显示，否则隐藏。
- `Invoke()`：对每个选中的文件/目录执行 `<ExePath> "<target-path>"`。

## Antigravity

文件：

- `antigravity/install-win11-context-menu.ps1`
- `antigravity/uninstall-win11-context-menu.ps1`
- `antigravity/win11-context-menu/src/AntigravityExplorerCommand.cpp`

默认目标：

```powershell
%LOCALAPPDATA%\Programs\Antigravity\Antigravity.exe
```

安装：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\antigravity\install-win11-context-menu.ps1
```

卸载：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\antigravity\uninstall-win11-context-menu.ps1 -RemoveGeneratedFiles
```

## Trae

文件：

- `trae/install-win11-context-menu.ps1`
- `trae/uninstall-win11-context-menu.ps1`
- `trae/win11-context-menu/src/TraeExplorerCommand.cpp`

安装脚本会自动尝试常见路径：

- `%LOCALAPPDATA%\Programs\Trae\Trae.exe`
- `%LOCALAPPDATA%\Programs\Trae CN\Trae.exe`
- `%LOCALAPPDATA%\Programs\trae\Trae.exe`
- `%LOCALAPPDATA%\Trae\Trae.exe`
- `%ProgramFiles%\Trae\Trae.exe`
- `%ProgramFiles(x86)%\Trae\Trae.exe`
- 注册表卸载项中的 `InstallLocation` / `DisplayIcon`

如果自动探测不到，手动传入路径：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\trae\install-win11-context-menu.ps1 -TraeExe "C:\Path\To\Trae.exe"
```

卸载：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\trae\uninstall-win11-context-menu.ps1 -RemoveGeneratedFiles
```

## Git Bash Here

文件：

- `git-bash/install-win11-context-menu.ps1`
- `git-bash/uninstall-win11-context-menu.ps1`
- `git-bash/win11-context-menu/src/GitBashHereExplorerCommand.cpp`

默认目标：

```powershell
C:\Program Files\Git\git-bash.exe
```

安装：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\git-bash\install-win11-context-menu.ps1
```

如果 Git Bash 在非标准路径：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\git-bash\install-win11-context-menu.ps1 -GitBashExe "C:\Path\To\git-bash.exe"
```

卸载：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\git-bash\uninstall-win11-context-menu.ps1 -RemoveGeneratedFiles
```

Git Bash 的 COM DLL 会把右键目标转换为目录：

- 目录、文件夹空白处：使用该目录。
- 文件：使用文件所在目录。

Windows 11 的 `fileExplorerContextMenus` schema 不接受 `Drive` 作为 `ItemType`。如果要在盘符根目录打开 Git Bash，进入盘符后在空白处右键即可走 `Directory\Background`。

然后执行：

```powershell
git-bash.exe --cd=<directory>
```

## 新增其他软件的步骤

1. 复制一个现有目录，例如 `trae`。
2. 替换软件名、默认 exe 路径、注册表 key、package name。
3. 生成新的 CLSID，替换脚本和 C++ 源码中的 class id。
4. 修改 manifest 中的 `Verb Id` 和 DLL 文件名。
5. 运行安装脚本并验证：

```powershell
Get-AppxPackage -Name OpenWith.<AppName>ContextMenu
reg query "HKCU\Software\Classes\<AppName>ContextMenu" /s
```

## 注意事项

- 运行时目录不能删除，否则菜单的 COM DLL 会失效。
- Explorer 可能缓存菜单，安装后如果没有立刻出现，可重启资源管理器或注销重登。
- 如果旧式 `.reg` 写到了 `HKLM`，普通用户无法删除，它可能仍然留在“显示更多选项”里；一级菜单由新的 AppX/COM 扩展提供。
- 修改 C++ 源码后重新运行安装脚本即可重新编译并注册。
