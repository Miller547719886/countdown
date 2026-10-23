# 截点

在任意 macOS 应用里选中一句话，按 `⌘ 1`，为它填写截止时间。截下来的原话和期限只保存在本机。

## 构建与启动

```sh
swift scripts/generate-icon.swift "$PWD"
sh scripts/build-app.sh
open "dist/截点.app"
```

开发时可用一条命令重新构建并重启应用：

```sh
sh scripts/restart-app.sh
```

首次按 `⌘ 1` 后，在“系统设置 → 隐私与安全性 → 辅助功能”中允许“截点”。如果没有授予权限，截取面板仍会打开，可以手动输入事项；也可以使用剪贴板路径，它会短暂模拟 `⌘ C` 并恢复原剪贴板内容。

数据位于 `~/Library/Application Support/Jiedian/items.json`。开发时可设置 `JIEDIAN_STORAGE_PATH` 指向临时文件，避免污染日常数据。

## 验证

```sh
swift run JiedianChecks
```

检查事项校验、按期限排序、持久化、逾期、完成与恢复。
