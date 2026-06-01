一、项目介绍

1、目标

本项目把编辑器、IDE、终端等开发工具加入 Windows 11 资源管理器一线右键菜单。目标效果类似 VSCode 安装器里的“通过 Code 打开”，但不依赖安装器是否勾选对应选项，也能覆盖便携安装或后补安装的场景。

2、为什么不只写注册表

传统注册表写法通常是：

```reg
HKEY_CLASSES_ROOT\*\shell\AppName\command
HKEY_CLASSES_ROOT\Directory\shell\AppName\command
HKEY_CLASSES_ROOT\Directory\Background\shell\AppName\command
```

这种方式仍然有效，但在 Windows 11 新版右键菜单中通常会进入“显示更多选项”。要直接显示在一线菜单，需要使用 Windows 11 的 Explorer command 扩展方式。

二、VSCode 官方实现方式

1、关键文件

VSCode 主仓库中和 Windows 11 右键菜单相关的位置是：

- `resources/win32/appx/AppxManifest.xml`
- `build/win32/code.iss`
- `build/win32/explorer-dll-fetcher.ts`

2、核心流程

VSCode 安装器会准备一个实现 `IExplorerCommand` 的 COM DLL，再准备 AppX/MSIX manifest，在 manifest 中声明：

- `windows.fileExplorerContextMenus`
- `windows.comServer`
- `Directory`
- `Directory\Background`
- `*`

Explorer 渲染右键菜单时通过 manifest 中的 CLSID 激活 COM DLL，DLL 负责返回标题、图标、显示状态，并在点击时启动目标程序。

三、本项目的新结构

1、共享层

当前项目已经从“每个工具复制一份脚本和 C++”调整为共享结构：

| 路径 | 作用 |
| --- | --- |
| `src/OpenWithExplorerCommand.cpp` | 所有工具共用的 COM DLL 源码 |
| `scripts/install-tool.ps1` | 通用安装器 |
| `scripts/uninstall-tool.ps1` | 通用卸载器 |
| `scripts/build-prebuilt-dll.ps1` | 编译预置 DLL |
| `bin/x64/OpenWithExplorerCommand.dll` | 预编译 DLL |
| `tools/<tool-id>/tool.ps1` | 单个工具的声明式配置 |

2、工具配置

每个 `tool.ps1` 返回一个 hashtable，主要字段包括：

- `ToolId`：工具 ID，例如 `cursor`
- `PackageName`：AppX package name
- `ClassId`：该菜单项的 COM CLSID
- `VerbId`：Explorer context menu verb
- `DefaultTitle`：菜单标题
- `LaunchMode`：点击后的启动模式
- `ExeCandidates`：默认扫描路径
- `CommandNames`：可通过 PATH 查找的命令名
- `UninstallPatterns`：从卸载注册表中辅助查找安装目录

四、安装流程

1、路径解析

安装脚本按顺序解析目标 exe：

1. 用户显式传入的 `-ExePath`
2. `tool.ps1` 中的 `ExeCandidates`
3. `Get-Command` 查找的 `CommandNames`
4. 卸载注册表中的 `DisplayName`、`InstallLocation`、`DisplayIcon`

如果都找不到，脚本会提示用户使用 `-ExePath` 指定路径。

2、运行时目录

每个工具的运行时目录为：

```powershell
%LOCALAPPDATA%\OpenWith\<RuntimeName>
```

里面会生成：

- `external/OpenWithExplorerCommand.dll`
- `external/Assets/Logo44.png`
- `external/Assets/Logo150.png`
- `manifest/AppxManifest.xml`
- `package/*.appx` 和证书文件，仅在 loose manifest 失败后才需要

3、注册表配置

共享 DLL 不再把某个工具写死在 C++ 中，而是通过注册表映射：

```powershell
HKCU:\Software\Classes\OpenWithContextMenus\ClassMap\{CLSID}
HKCU:\Software\Classes\OpenWithContextMenus\Tools\<ToolId>
```

`ClassMap` 负责把 Explorer 传入的 CLSID 映射到工具 ID。`Tools\<ToolId>` 保存菜单标题、目标 exe、图标路径和启动模式。

4、AppX manifest

安装脚本会动态生成 manifest，声明：

- package identity
- file explorer context menus
- COM surrogate server
- 目标 `ItemType`

当前支持的 `ItemType` 是：

- `Directory`
- `Directory\Background`
- `*`

`Drive` 不是 `fileExplorerContextMenus` schema 支持的 `ItemType`，所以盘符根目录场景通过进入盘符后在空白处右键触发 `Directory\Background`。

五、共享 DLL 逻辑

1、激活流程

Explorer 激活 COM 类时会调用：

```cpp
DllGetClassObject(REFCLSID clsid, REFIID riid, void** object)
```

DLL 会把 `clsid` 转成 `{GUID}` 字符串，然后读取：

```powershell
HKCU:\Software\Classes\OpenWithContextMenus\ClassMap\{GUID}
```

拿到 `ToolId` 后，后续 `GetTitle()`、`GetIcon()`、`GetState()`、`Invoke()` 都读取对应工具配置。

2、菜单状态

`GetState()` 会读取 `ExePath`。如果目标 exe 存在，菜单显示并可点击；如果 exe 不存在，菜单隐藏。

3、启动模式

| LaunchMode | 行为 |
| --- | --- |
| `OpenPath` | 把当前选中文件或目录作为参数传给目标程序 |
| `OpenDirectory` | 把当前目录作为参数传给目标程序 |
| `GitBashHere` | 执行 `git-bash.exe --cd=<directory>` |
| `WindowsTerminalHere` | 执行 `wt.exe -d <directory>` |
| `WslHere` | 执行 `wsl.exe --cd <directory>`，可选 `-Distro` |

六、预编译 DLL

1、是否可以直接分发

可以。`OpenWithExplorerCommand.dll` 是一个通用 x64 原生 COM DLL，不包含某台电脑特有的信息。工具差异都在 manifest 和注册表配置里，所以可以先在一台装好 VS Build Tools 和 Windows SDK 的开发电脑上编译好，再把整个项目复制到目标电脑运行安装脚本。

2、目标电脑需要什么

目标电脑需要：

- Windows 11
- PowerShell 5.1+
- `bin/x64/OpenWithExplorerCommand.dll`
- 要注册的目标软件本身

目标电脑不需要：

- Visual Studio
- Windows SDK
- C++ 编译工具链

默认安装走 loose manifest 注册，不需要 Windows SDK。只有当 loose manifest 被系统拒绝，脚本回退到 signed sparse package 时，才会用到 SDK 中的 `makeappx.exe` 和 `signtool.exe`。

3、什么时候需要重新编译

只有修改了 `src/OpenWithExplorerCommand.cpp` 时才需要重新编译：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-prebuilt-dll.ps1
```

如果只是新增工具、改标题、改路径检测、改 CLSID 或改启动模式，只需要修改 `tools/<tool-id>/tool.ps1`，不需要重新编译 DLL。

七、新增工具

1、复制配置目录

新增工具时复制一个现有目录，例如：

```powershell
Copy-Item .\tools\cursor .\tools\new-tool -Recurse
```

2、修改配置

编辑 `tools/new-tool/tool.ps1`：

- 生成新的 `ClassId`
- 修改 `ToolId`
- 修改 `PackageName`
- 修改 `VerbId`
- 修改 `DefaultTitle`
- 修改 `LaunchMode`
- 修改 `ExeCandidates`

3、保留入口脚本

单工具入口脚本只负责把参数转发给 `scripts/install-tool.ps1` 和 `scripts/uninstall-tool.ps1`。新增工具时建议保留这种薄入口，避免再复制通用安装逻辑。

八、当前工具说明

1、编辑器和 IDE

| Tool | 默认行为 |
| --- | --- |
| `vscode` | 通过 Code 打开文件或目录 |
| `antigravity` | 通过 Antigravity 打开文件或目录 |
| `trae` | 通过 Trae 打开文件或目录 |
| `cursor` | 通过 Cursor 打开文件或目录 |
| `windsurf` | 通过 Windsurf 打开文件或目录 |
| `jetbrains` | 自动检测 JetBrains 系列 IDE，或通过 `-JetBrainsExe` 指定 |

2、终端

| Tool | 默认行为 |
| --- | --- |
| `git-bash` | 在当前目录打开 Git Bash |
| `windows-terminal` | 在当前目录打开 Windows Terminal |
| `wsl` | 在当前目录打开 WSL，可用 `-Distro` 指定发行版 |

九、注意事项

1、Explorer 缓存

Explorer 可能缓存菜单。安装后如果没有立刻出现，可以重启资源管理器或注销重登。

2、旧式菜单残留

如果旧式 `.reg` 写到了 `HKLM`，普通用户可能无法删除，它可能仍然留在“显示更多选项”里；一线菜单由本项目的 AppX/COM 扩展提供。

3、DLL 文件不要删除

安装完成后，运行时目录里的 DLL 仍然会被 Explorer 使用。不要删除：

```powershell
%LOCALAPPDATA%\OpenWith\<RuntimeName>\external
```

如果要删除，请先运行对应卸载脚本。
