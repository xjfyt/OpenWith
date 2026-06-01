## 一、项目介绍

### 1、项目目标

OpenWith 用来给 Windows 11 资源管理器添加一线右键菜单，让常用开发工具获得类似 VSCode “通过 Code 打开”的入口。

传统 `.reg` 写入 `*\shell`、`Directory\shell`、`Directory\Background\shell` 的方式在 Windows 11 上通常只会进入“显示更多选项”。本项目使用 AppX `fileExplorerContextMenus` 加 COM `IExplorerCommand`，把菜单注册到 Windows 11 新版一线右键菜单。

### 2、适用场景

- 安装软件时忘记勾选“添加到右键菜单”。
- 软件本身没有提供 Windows 11 一线右键菜单。
- 想给多台电脑快速补齐统一的开发工具右键入口。
- 想给便携版、非标准安装路径的软件添加右键入口。

### 3、文档规则

项目文档不使用一级标题。章标题使用二级标题，例如 `## 一、项目介绍`；节标题使用三级标题，例如 `### 1、项目目标`。

## 二、当前支持

### 1、工具列表

| 工具 ID | 菜单用途 | 默认启动方式 |
| --- | --- | --- |
| `vscode` | 通过 Code 打开 | 打开选中的文件或目录 |
| `antigravity` | 通过 Antigravity 打开 | 打开选中的文件或目录 |
| `trae` | 通过 Trae 打开 | 打开选中的文件或目录 |
| `cursor` | 通过 Cursor 打开 | 打开选中的文件或目录 |
| `windsurf` | 通过 Windsurf 打开 | 打开选中的文件或目录 |
| `jetbrains` | 通过 JetBrains IDE 打开 | 打开选中的文件或目录 |
| `git-bash` | Git Bash Here | 在当前目录打开 Git Bash |
| `windows-terminal` | Windows Terminal Here | 在当前目录打开 Windows Terminal |
| `wsl` | WSL Here | 在当前目录打开 WSL |

### 2、编辑器和 IDE

`vscode`、`antigravity`、`trae`、`cursor`、`windsurf` 都使用 `OpenPath` 模式：右键文件时把文件路径传给目标程序，右键目录或目录空白处时把目录路径传给目标程序。

`jetbrains` 会按配置顺序自动检测 IntelliJ IDEA、WebStorm、PyCharm、GoLand、Rider、CLion、PhpStorm、RubyMine、DataGrip。多款 IDE 同时存在时，建议手动指定 exe 和菜单标题。

### 3、终端类工具

`git-bash`、`windows-terminal`、`wsl` 会把右键目标转换为目录：

- 右键目录：使用该目录。
- 右键目录空白处：使用当前目录。
- 右键文件：使用文件所在目录。

Windows 11 的 `fileExplorerContextMenus` schema 不支持 `Drive` 作为 `ItemType`。如果要在盘符根目录打开终端，进入盘符后在空白处右键即可触发 `Directory\Background`。

## 三、快速开始

### 1、目标电脑要求

目标电脑只需要：

- Windows 11
- PowerShell 5.1+
- 已安装对应目标软件
- 仓库里的 `bin/x64/OpenWithExplorerCommand.dll`

默认安装走 loose manifest 注册，不需要 Visual Studio、Windows SDK 或 C++ 编译工具链。只有当 loose manifest 被系统拒绝，脚本回退到 signed sparse package 时，才会用到 Windows SDK 里的 `makeappx.exe` 和 `signtool.exe`。

### 2、安装一个工具

推荐使用根目录的通用入口：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-tool.ps1 -Tool vscode
```

也可以使用单工具目录下的兼容入口：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\vscode\install-win11-context-menu.ps1
```

### 3、安装常用组合

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-tool.ps1 -Tool vscode
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-tool.ps1 -Tool cursor
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-tool.ps1 -Tool windsurf
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-tool.ps1 -Tool windows-terminal
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-tool.ps1 -Tool wsl
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-tool.ps1 -Tool jetbrains
```

### 4、指定软件路径

如果软件不在默认路径，可以手动指定 exe：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-tool.ps1 -Tool cursor -ExePath "C:\Path\To\Cursor.exe"
```

单工具入口也保留了更直观的参数名：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\cursor\install-win11-context-menu.ps1 -CursorExe "C:\Path\To\Cursor.exe"
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\jetbrains\install-win11-context-menu.ps1 -JetBrainsExe "C:\Path\To\webstorm64.exe" -Title "通过 WebStorm 打开"
```

### 5、WSL 指定发行版

默认 `wsl` 使用系统默认发行版。需要指定发行版时：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\wsl\install-win11-context-menu.ps1 -Distro Ubuntu
```

## 四、卸载

### 1、通用卸载

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall-tool.ps1 -Tool vscode -RemoveGeneratedFiles
```

### 2、卸载多个工具

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall-tool.ps1 -Tool vscode -RemoveGeneratedFiles
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall-tool.ps1 -Tool cursor -RemoveGeneratedFiles
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall-tool.ps1 -Tool windsurf -RemoveGeneratedFiles
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall-tool.ps1 -Tool windows-terminal -RemoveGeneratedFiles
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall-tool.ps1 -Tool wsl -RemoveGeneratedFiles
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall-tool.ps1 -Tool jetbrains -RemoveGeneratedFiles
```

### 3、单工具卸载入口

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\vscode\uninstall-win11-context-menu.ps1 -RemoveGeneratedFiles
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\jetbrains\uninstall-win11-context-menu.ps1 -RemoveGeneratedFiles
```

`-RemoveGeneratedFiles` 会删除 `%LOCALAPPDATA%\OpenWith\<RuntimeName>` 下生成的 manifest、assets、DLL 副本和临时包文件。

## 五、项目结构

### 1、目录说明

| 路径 | 说明 |
| --- | --- |
| `install-tool.ps1` | 根目录通用安装入口 |
| `uninstall-tool.ps1` | 根目录通用卸载入口 |
| `tools/<tool-id>/tool.ps1` | 工具配置，包含菜单名、CLSID、检测路径、启动模式 |
| `tools/<tool-id>/install-win11-context-menu.ps1` | 单工具安装入口，转发到通用安装脚本 |
| `tools/<tool-id>/uninstall-win11-context-menu.ps1` | 单工具卸载入口，转发到通用卸载脚本 |
| `scripts/install-tool.ps1` | 通用安装实现 |
| `scripts/uninstall-tool.ps1` | 通用卸载实现 |
| `scripts/build-prebuilt-dll.ps1` | 编译共享 COM DLL |
| `src/OpenWithExplorerCommand.cpp` | 共享 `IExplorerCommand` COM 实现 |
| `bin/x64/OpenWithExplorerCommand.dll` | 可直接分发的预编译 x64 DLL |

### 2、为什么这样组织

早期版本是每个工具复制一份 PowerShell 和 C++。随着工具变多，这种方式会导致重复代码过多，也容易出现某个工具修了问题、另一个工具漏修的问题。

现在的结构把差异收敛到 `tools/<tool-id>/tool.ps1`，把安装、卸载、manifest 生成、注册表写入和 COM DLL 逻辑放到共享层。新增工具时主要改配置，不需要复制几百行脚本。

### 3、工具配置职责

每个 `tools/<tool-id>/tool.ps1` 返回一个 hashtable。配置只描述该工具的差异：

| 字段 | 说明 |
| --- | --- |
| `ToolId` | 工具 ID，必须和目录名一致 |
| `PackageName` | AppX package name |
| `Publisher` | AppX identity publisher |
| `RuntimeName` | `%LOCALAPPDATA%\OpenWith` 下的运行时目录名 |
| `ClassId` | COM CLSID，每个工具必须唯一 |
| `VerbId` | Explorer context menu verb |
| `DefaultTitle` | 默认菜单标题 |
| `LaunchMode` | 点击后的启动模式 |
| `ItemTypes` | 绑定的 Explorer item type |
| `ExeCandidates` | 默认扫描路径 |
| `CommandNames` | 通过 PATH 查找的命令名 |
| `UninstallPatterns` | 从卸载注册表中辅助查找安装目录 |
| `InstallLocationExeNames` | 基于 `InstallLocation` 拼接的 exe 名 |

## 六、Windows 11 一线菜单原理

### 1、传统注册表方式的限制

传统右键菜单通常写入这些注册表位置：

```reg
HKEY_CLASSES_ROOT\*\shell\AppName\command
HKEY_CLASSES_ROOT\Directory\shell\AppName\command
HKEY_CLASSES_ROOT\Directory\Background\shell\AppName\command
```

这种方式在 Windows 10 和 Windows 11 的“显示更多选项”中仍然有效，但通常不会出现在 Windows 11 新版一线右键菜单里。

### 2、一线菜单需要的机制

Windows 11 新版一线右键菜单使用 Explorer command 扩展。核心组成是：

- AppX/MSIX manifest 中声明 `windows.fileExplorerContextMenus`。
- manifest 中为 `Directory`、`Directory\Background`、`*` 绑定一个 `Verb`。
- manifest 中声明 `windows.comServer`，让 Explorer 通过 COM surrogate 激活 DLL。
- DLL 实现 `IExplorerCommand`，负责菜单标题、图标、状态和点击行为。

### 3、VSCode 官方思路

VSCode 安装器也是这个方向。关键文件在 VSCode 主仓库中大致包括：

- `resources/win32/appx/AppxManifest.xml`
- `build/win32/code.iss`
- `build/win32/explorer-dll-fetcher.ts`

安装器会准备 Explorer command DLL 和 AppX manifest，再通过 sparse package 或 loose manifest 的方式注册到当前用户。

## 七、安装实现流程

### 1、解析目标程序路径

`scripts/install-tool.ps1` 会按顺序解析目标 exe：

1. 用户显式传入的 `-ExePath`。
2. `tool.ps1` 中的 `ExeCandidates`。
3. `Get-Command` 找到的 `CommandNames`。
4. 卸载注册表中的 `DisplayName`、`InstallLocation`、`DisplayIcon`。

如果全部失败，脚本会提示用户使用 `-ExePath` 指定路径。单工具入口脚本会把更具体的参数名转发给 `-ExePath`，例如 `-CursorExe`、`-JetBrainsExe`。

### 2、准备运行时目录

每个工具会生成独立运行时目录：

```powershell
%LOCALAPPDATA%\OpenWith\<RuntimeName>
```

目录内容包括：

| 路径 | 说明 |
| --- | --- |
| `external/OpenWithExplorerCommand.dll` | Explorer 实际加载的 DLL 副本 |
| `external/Assets/Logo44.png` | manifest 需要的 44px logo |
| `external/Assets/Logo150.png` | manifest 需要的 150px logo |
| `manifest/AppxManifest.xml` | 动态生成的 AppX manifest |
| `package/*.appx` | signed sparse package 回退时生成 |
| `package/*.cer` | signed sparse package 回退时生成 |

### 3、写入注册表配置

通用注册表根路径是：

```powershell
HKCU:\Software\Classes\OpenWithContextMenus
```

安装脚本会写入两类信息：

```powershell
HKCU:\Software\Classes\OpenWithContextMenus\ClassMap\{CLSID}
HKCU:\Software\Classes\OpenWithContextMenus\Tools\<ToolId>
```

`ClassMap\{CLSID}` 只保存 `ToolId`，用于把 Explorer 激活的 COM CLSID 映射到工具。`Tools\<ToolId>` 保存标题、目标 exe、图标路径、启动模式和可选参数。

### 4、生成 AppX manifest

manifest 会动态生成，核心声明包括：

- package identity
- visual elements
- `windows.fileExplorerContextMenus`
- `windows.comServer`
- `desktop5:ItemType`
- `com:SurrogateServer`

当前工具默认绑定：

- `Directory`
- `Directory\Background`
- `*`

`Drive` 不是 `fileExplorerContextMenus` schema 支持的 `ItemType`。盘符根目录场景可以进入盘符后在空白处右键，通过 `Directory\Background` 触发。

### 5、注册 AppX

脚本优先使用 loose manifest：

```powershell
Add-AppxPackage -Register AppxManifest.xml -ExternalLocation <external-dir>
```

如果 loose manifest 注册失败，脚本会回退到 signed sparse package：

1. 创建或复用当前用户证书。
2. 使用 `makeappx.exe` 打包。
3. 使用 `signtool.exe` 签名。
4. 使用 `Add-AppxPackage -Path ... -ExternalLocation ...` 注册。

默认成功路径不需要 Windows SDK；只有回退路径需要 SDK 工具。

## 八、共享 DLL 逻辑

### 1、COM 激活

Explorer 激活菜单项时会调用：

```cpp
DllGetClassObject(REFCLSID clsid, REFIID riid, void** object)
```

DLL 会把 `clsid` 转成 `{GUID}` 字符串，读取：

```powershell
HKCU:\Software\Classes\OpenWithContextMenus\ClassMap\{GUID}
```

拿到 `ToolId` 后，DLL 创建 `ExplorerCommandHandler`，后续所有行为都读取该工具配置。

### 2、标题和图标

`GetTitle()` 读取：

```powershell
Tools\<ToolId>\Title
```

`GetIcon()` 优先读取：

```powershell
Tools\<ToolId>\IconPath
```

如果没有 `IconPath`，则回退到：

```powershell
Tools\<ToolId>\ExePath
```

### 3、显示状态

`GetState()` 会检查 `ExePath`：

- exe 存在：返回 `ECS_ENABLED`。
- exe 不存在：返回 `ECS_HIDDEN`。

这能避免目标软件卸载后留下不可点击菜单。

### 4、点击行为

`Invoke()` 会从 Explorer 传入的 `IShellItemArray` 中取出路径，然后根据 `LaunchMode` 生成参数。

| LaunchMode | 行为 |
| --- | --- |
| `OpenPath` | 把当前选中文件或目录作为参数传给目标程序 |
| `OpenDirectory` | 把当前目录作为参数传给目标程序 |
| `GitBashHere` | 执行 `git-bash.exe --cd=<directory>` |
| `WindowsTerminalHere` | 执行 `wt.exe -d <directory>` |
| `WslHere` | 执行 `wsl.exe --cd <directory>`，可选 `-Distro` |

终端类启动模式会把文件路径转换为父目录，保证“Here”语义一致。

## 九、预编译 DLL 和分发

### 1、是否可以提交 bin 目录

可以。`bin/x64/OpenWithExplorerCommand.dll` 是项目运行所需的预编译 DLL，建议提交，让其他人拉取项目后可以直接使用，不必在每台电脑上安装 Visual Studio 和 Windows SDK。

当前 DLL 体积很小，约 160 KB，直接提交到 Git 更符合“拉取即可使用”的目标。如果后续增加更多架构、更多二进制产物，或者 DLL 体积明显变大，可以再改用 Git LFS。

### 2、是否需要 Git LFS

当前不强制使用 Git LFS。原因是：

- 普通 Git clone 可以直接拿到真实 DLL。
- 用户不需要额外安装 Git LFS。
- 当前 DLL 体积小，对仓库体积影响有限。

如果以后决定改用 Git LFS，可以添加 `.gitattributes`：

```gitattributes
bin/x64/*.dll filter=lfs diff=lfs merge=lfs -text
```

然后重新 add DLL。使用 LFS 后，其他人需要安装 Git LFS，并在 clone 后确保 `git lfs pull` 已拉取真实 DLL，否则拿到的可能只是指针文件。

### 3、什么时候需要重新编译

只有修改 `src/OpenWithExplorerCommand.cpp` 后才需要重新编译：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-prebuilt-dll.ps1
```

如果只是新增工具、改菜单标题、改检测路径、改 CLSID 或调整工具配置，不需要重新编译 DLL。

### 4、强制重新编译

安装时默认优先使用 `bin/x64/OpenWithExplorerCommand.dll`。需要在本机重新编译并使用新 DLL 时：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-tool.ps1 -Tool vscode -ForceCompile
```

重新编译 DLL 后，需要重新运行对应安装脚本。脚本会把新的 DLL 复制到对应工具的运行时目录，并重新注册 manifest。

## 十、新增或修改工具

### 1、新增工具目录

复制一个接近的工具目录：

```powershell
Copy-Item .\tools\cursor .\tools\new-tool -Recurse
```

### 2、生成新的 CLSID

```powershell
[guid]::NewGuid().ToString().ToUpperInvariant()
```

每个工具的 `ClassId` 必须唯一，不能复用已有工具。

### 3、修改 tool.ps1

至少需要修改：

- `ToolId`
- `PackageName`
- `Publisher`
- `RuntimeName`
- `ClassId`
- `VerbId`
- `DefaultTitle`
- `ExeCandidates`

如果是终端类工具，还需要选择合适的 `LaunchMode`。

### 4、修改入口脚本参数名

单工具入口脚本只是转发参数。为了使用体验，可以把通用 `-ExePath` 包装成具体参数名，例如：

```powershell
param(
	[string]$NewToolExe = ''
)
```

然后转发：

```powershell
if ($NewToolExe) { $args += @('-ExePath', $NewToolExe) }
```

## 十一、排查问题

### 1、菜单没有显示

先确认 package 是否注册：

```powershell
Get-AppxPackage -Name OpenWith.VSCodeContextMenu
```

再确认注册表配置是否存在：

```powershell
reg query "HKCU\Software\Classes\OpenWithContextMenus" /s
```

如果都存在但菜单没显示，可以重启资源管理器或注销重登。

### 2、菜单显示但点击无反应

检查工具配置中的 `ExePath`：

```powershell
reg query "HKCU\Software\Classes\OpenWithContextMenus\Tools\vscode" /v ExePath
```

目标软件更新路径后，重新运行安装脚本即可。

### 3、旧菜单仍在“显示更多选项”

旧式注册表菜单和本项目的一线菜单不是同一套机制。如果旧式 `.reg` 写到了 `HKLM`，普通用户可能无法删除，需要管理员权限清理。

### 4、删除运行时目录后菜单异常

安装完成后 Explorer 会从运行时目录加载 DLL：

```powershell
%LOCALAPPDATA%\OpenWith\<RuntimeName>\external
```

不要手动删除该目录。需要清理时运行卸载脚本：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall-tool.ps1 -Tool vscode -RemoveGeneratedFiles
```
