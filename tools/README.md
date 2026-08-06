# 本地工具

## Godot CLI

- **版本**：4.7.1.stable.official（对齐 G2=Godot 4.7）
- **路径**：`tools/godot/Godot_v4.7.1-stable_win64_console.exe`
- **快捷命令**：`tools/godot.cmd`（已加入用户 PATH；新开终端后可直接 `godot`）

```bat
:: 版本
godot --version

:: 打开工程
godot --path "%USERPROFILE%\Desktop\大航海\client"

:: 无头冒烟（推荐场景入口；autoload 齐全）
godot --headless --path "%USERPROFILE%\Desktop\大航海\client" res://tests/Smoke.tscn
```

来源：https://github.com/godotengine/godot/releases/tag/4.7.1-stable  
标准版（非 .NET），GDScript 工程足够。
