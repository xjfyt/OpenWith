一、项目介绍

1、项目目标

OpenWith 用来给 Windows 11 资源管理器添加一级右键菜单，让常用开发工具获得类似 VSCode “通过 Code 打开”的入口。

普通 `.reg` 写入 `*\shell`、`Directory\shell` 的方式在 Windows 11 上通常只会出现在“显示更多选项”里。本项目使用 AppX `fileExplorerContextMenus` 加 COM `IExplorerCommand` 的方式，把菜单注册到 Windows 11 新版一级右键菜单。

2、当前支持

- Visual Studio Code：`通过 Code 打开`
- Antigravity：`通过 Antigravity 打开`
- Trae：`通过 Trae 打开`
- Git Bash：`Git Bash Here`

3、目录说明

- `visual-studio-code/`：VSCode 右键菜单脚本。
- `antigravity/`：Antigravity 右键菜单脚本。
- `trae/`：Trae 右键菜单脚本。
- `git-bash/`：Git Bash Here 右键菜单脚本。
- `docs/`：实现说明和扩展说明。
- `vscode/`：本地 VSCode 源码参考目录，已被 `.gitignore` 排除，不属于本项目提交内容。

二、前置条件

1、系统要求

- Windows 11
- PowerShell 5.1+
- Visual Studio 2022 C++ Build Tools 或 Visual Studio 2022 Community
- Windows 10/11 SDK

2、运行时位置

安装脚本会编译一个很小的 COM DLL，并把运行时文件放到：

```powershell
%LOCALAPPDATA%\OpenWith\<ToolName>ContextMenu
```

不要删除这些运行时目录，否则右键菜单无法激活。

三、安装

1、Visual Studio Code

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\visual-studio-code\install-win11-context-menu.ps1
```

如果 VSCode 不在常见路径：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\visual-studio-code\install-win11-context-menu.ps1 -VSCodeExe "C:\Path\To\Code.exe"
```

2、Antigravity

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\antigravity\install-win11-context-menu.ps1
```

3、Trae

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\trae\install-win11-context-menu.ps1 -TraeExe "C:\Path\To\Trae.exe"
```

4、Git Bash

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\git-bash\install-win11-context-menu.ps1
```

如果 Git Bash 不在常见路径：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\git-bash\install-win11-context-menu.ps1 -GitBashExe "C:\Program Files\Git\git-bash.exe"
```

四、卸载

1、卸载命令

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\visual-studio-code\uninstall-win11-context-menu.ps1 -RemoveGeneratedFiles
powershell -NoProfile -ExecutionPolicy Bypass -File .\antigravity\uninstall-win11-context-menu.ps1 -RemoveGeneratedFiles
powershell -NoProfile -ExecutionPolicy Bypass -File .\trae\uninstall-win11-context-menu.ps1 -RemoveGeneratedFiles
powershell -NoProfile -ExecutionPolicy Bypass -File .\git-bash\uninstall-win11-context-menu.ps1 -RemoveGeneratedFiles
```

五、实现概览

1、核心流程

1. 生成 AppX manifest，声明 `windows.fileExplorerContextMenus`。
2. 为 `Directory`、`Directory\Background`、必要时 `*` 绑定菜单 verb。
3. 注册 `windows.comServer`，让 Explorer 通过 COM surrogate 激活 DLL。
4. DLL 实现 `IExplorerCommand`，负责菜单标题、图标、显示状态和点击执行。
5. 使用 `Add-AppxPackage -Register ... -ExternalLocation ...` 注册。

2、详细说明

详细设计见 [docs/win11-context-menu.md](docs/win11-context-menu.md)。

六、注意事项

1、菜单缓存

安装后如果菜单没有马上出现，可以重启资源管理器或注销重登。

2、旧式菜单

如果旧式 `.reg` 写到了 `HKLM`，普通用户无法删除，它可能仍留在“显示更多选项”里。一级菜单由新的 AppX/COM 扩展提供。
