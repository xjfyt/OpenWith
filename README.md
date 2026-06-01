# OpenWith

OpenWith 是一组 Windows 11 资源管理器一级右键菜单脚本，用来给常用开发工具添加类似 VSCode “通过 Code 打开”的菜单项。

普通 `.reg` 写入 `*\shell` / `Directory\shell` 的方式在 Windows 11 上通常只会出现在“显示更多选项”里。本项目使用 VSCode 同类方案：`AppX fileExplorerContextMenus + COM IExplorerCommand`。

## 当前支持

- Antigravity：`通过 Antigravity 打开`
- Trae：`通过 Trae 打开`
- Git Bash：`Git Bash Here`

## 前置条件

- Windows 11
- Visual Studio 2022 C++ Build Tools 或 Visual Studio 2022 Community
- Windows 10/11 SDK
- PowerShell 5.1+

安装脚本会编译一个很小的 COM DLL，并把运行时文件放到：

```powershell
%LOCALAPPDATA%\OpenWith\<ToolName>ContextMenu
```

## 安装

Antigravity：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\antigravity\install-win11-context-menu.ps1
```

Trae：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\trae\install-win11-context-menu.ps1 -TraeExe "C:\Path\To\Trae.exe"
```

Git Bash：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\git-bash\install-win11-context-menu.ps1
```

如果 Git Bash 不在常见路径，可以显式指定：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\git-bash\install-win11-context-menu.ps1 -GitBashExe "C:\Program Files\Git\git-bash.exe"
```

## 卸载

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\antigravity\uninstall-win11-context-menu.ps1 -RemoveGeneratedFiles
powershell -NoProfile -ExecutionPolicy Bypass -File .\trae\uninstall-win11-context-menu.ps1 -RemoveGeneratedFiles
powershell -NoProfile -ExecutionPolicy Bypass -File .\git-bash\uninstall-win11-context-menu.ps1 -RemoveGeneratedFiles
```

## 实现说明

详细设计见 [docs/win11-context-menu.md](docs/win11-context-menu.md)。

核心流程：

1. 生成 AppX manifest，声明 `windows.fileExplorerContextMenus`。
2. 为 `Directory`、`Directory\Background`、必要时 `*` 绑定菜单 verb。
3. 注册 `windows.comServer`，让 Explorer 通过 COM surrogate 激活 DLL。
4. DLL 实现 `IExplorerCommand`，负责菜单标题、图标、显示状态和点击执行。
5. 使用 `Add-AppxPackage -Register ... -ExternalLocation ...` 注册。

## 备注

- `vscode/` 目录只作为参考源码，不纳入本仓库提交。
- 安装后如果菜单没有马上出现，重启资源管理器或注销重登。
- 不要删除 `%LOCALAPPDATA%\OpenWith\...` 里的运行时文件，否则菜单无法激活。
