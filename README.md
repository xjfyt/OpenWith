一、项目介绍

1、项目目标

OpenWith 用来给 Windows 11 资源管理器添加一线右键菜单，让常用开发工具获得类似 VSCode “通过 Code 打开”的入口。

普通 `.reg` 写入 `*\shell`、`Directory\shell`、`Directory\Background\shell` 的方式在 Windows 11 上通常只会出现在“显示更多选项”里。本项目使用 AppX `fileExplorerContextMenus` 加 COM `IExplorerCommand` 的方式，把菜单注册到 Windows 11 新版一线右键菜单。

2、当前支持

| 工具 ID | 菜单用途 |
| --- | --- |
| `vscode` | 通过 Code 打开 |
| `antigravity` | 通过 Antigravity 打开 |
| `trae` | 通过 Trae 打开 |
| `cursor` | 通过 Cursor 打开 |
| `windsurf` | 通过 Windsurf 打开 |
| `jetbrains` | 通过 JetBrains IDE 打开 |
| `git-bash` | Git Bash Here |
| `windows-terminal` | Windows Terminal Here |
| `wsl` | WSL Here |

3、项目结构

| 路径 | 说明 |
| --- | --- |
| `tools/<tool-id>/tool.ps1` | 工具配置，包含菜单名、CLSID、检测路径、启动模式 |
| `tools/<tool-id>/install-win11-context-menu.ps1` | 单个工具的兼容安装入口 |
| `tools/<tool-id>/uninstall-win11-context-menu.ps1` | 单个工具的兼容卸载入口 |
| `scripts/install-tool.ps1` | 通用安装脚本 |
| `scripts/uninstall-tool.ps1` | 通用卸载脚本 |
| `scripts/build-prebuilt-dll.ps1` | 编译共享 COM DLL |
| `src/OpenWithExplorerCommand.cpp` | 共享 `IExplorerCommand` COM 实现 |
| `bin/x64/OpenWithExplorerCommand.dll` | 可直接分发的预编译 x64 DLL |
| `docs/win11-context-menu.md` | 实现原理和扩展说明 |

二、前置条件

1、目标电脑

目标电脑只需要：

- Windows 11
- PowerShell 5.1+
- 已安装对应目标软件
- 仓库里的 `bin/x64/OpenWithExplorerCommand.dll`

目标电脑不需要安装 Visual Studio 或 Windows SDK，除非你要在目标电脑上重新编译 DLL。
默认的 loose manifest 注册路径不需要 Windows SDK；只有在 loose manifest 被系统拒绝、脚本回退到 signed sparse package 时，才会需要 SDK 里的 `makeappx.exe` 和 `signtool.exe`。

2、开发电脑

只有在修改了 `src/OpenWithExplorerCommand.cpp` 并需要重新生成 DLL 时，才需要：

- Visual Studio 2022 C++ Build Tools 或 Visual Studio 2022
- Windows 10/11 SDK

重新编译命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-prebuilt-dll.ps1
```

三、安装

1、通用安装方式

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-tool.ps1 -Tool vscode
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-tool.ps1 -Tool cursor
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-tool.ps1 -Tool windsurf
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-tool.ps1 -Tool windows-terminal
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-tool.ps1 -Tool wsl
```

2、单工具入口

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\vscode\install-win11-context-menu.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\cursor\install-win11-context-menu.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\windsurf\install-win11-context-menu.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\windows-terminal\install-win11-context-menu.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\wsl\install-win11-context-menu.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\jetbrains\install-win11-context-menu.ps1
```

3、指定软件路径

如果软件不在默认路径，可以手动传入 exe：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-tool.ps1 -Tool cursor -ExePath "C:\Path\To\Cursor.exe"
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\jetbrains\install-win11-context-menu.ps1 -JetBrainsExe "C:\Path\To\webstorm64.exe" -Title "通过 WebStorm 打开"
```

4、WSL 指定发行版

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\wsl\install-win11-context-menu.ps1 -Distro Ubuntu
```

四、卸载

1、通用卸载方式

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall-tool.ps1 -Tool vscode -RemoveGeneratedFiles
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall-tool.ps1 -Tool cursor -RemoveGeneratedFiles
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall-tool.ps1 -Tool windsurf -RemoveGeneratedFiles
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall-tool.ps1 -Tool windows-terminal -RemoveGeneratedFiles
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall-tool.ps1 -Tool wsl -RemoveGeneratedFiles
```

2、单工具入口

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\vscode\uninstall-win11-context-menu.ps1 -RemoveGeneratedFiles
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\jetbrains\uninstall-win11-context-menu.ps1 -RemoveGeneratedFiles
```

五、实现概览

1、核心流程

安装脚本会读取 `tools/<tool-id>/tool.ps1`，检测目标软件路径，把共享 DLL 复制到：

```powershell
%LOCALAPPDATA%\OpenWith\<RuntimeName>\external
```

然后生成 AppX manifest，写入当前用户注册表配置，并通过：

```powershell
Add-AppxPackage -Register AppxManifest.xml -ExternalLocation <external-dir>
```

注册 Windows 11 一线右键菜单。

2、共享 DLL

所有工具共用 `OpenWithExplorerCommand.dll`。Explorer 激活 COM 类时，DLL 会根据 CLSID 到注册表映射中找到工具 ID，再读取该工具的标题、目标 exe 和启动模式。

3、预编译 DLL

`bin/x64/OpenWithExplorerCommand.dll` 可以先在开发电脑编译好，再复制到目标电脑直接使用。目标电脑运行安装脚本时会优先使用这个 DLL；只有传入 `-ForceCompile` 或缺少预编译 DLL 时，才需要本机编译环境。

六、注意事项

1、菜单缓存

安装后如果菜单没有马上出现，可以重启资源管理器或注销重登。

2、JetBrains 检测

`jetbrains` 会按配置顺序自动检测 IntelliJ IDEA、WebStorm、PyCharm、GoLand、Rider、CLion、PhpStorm、RubyMine、DataGrip。多款 IDE 同时存在时，可以用 `-JetBrainsExe` 和 `-Title` 指定具体入口。

3、旧式菜单

如果旧式 `.reg` 写到了 `HKLM`，普通用户可能无法删除，它可能仍留在“显示更多选项”里。一线菜单由本项目的 AppX/COM 扩展提供。
