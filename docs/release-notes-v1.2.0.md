# codexU v1.2.0

本版本把 codexU 从菜单栏统计工具扩展为轻量桌面状态入口：macOS 新增本机动态岛浮窗，Windows 增加可独立试验的动态岛原型，同时保留 Codex / OpenClaw / Claude Code / Hermes 的来源标记和各自统计口径。

## 主要变化

- 新增 macOS 动态岛模式，复用 codexU 现有 Codex、第二 Agent、任务看板和本机系统状态数据，不另建统计管线。
- 新增显示入口设置：可同时启用原有主窗口/菜单栏与灵动岛，也可只保留原有入口或只保留灵动岛。
- 动态岛支持顶部横向胶囊、左侧竖向胶囊和右侧竖向胶囊；左键保持展开/收起，左右键同时按住拖动可移动位置，并自动吸附到最近边缘。
- 动态岛会根据 Codex 实际返回的额度窗口自适应显示；只有 7 天额度时只显示 `7d`，不会伪造已经不存在的 `5h` 重置时间。
- 菜单栏和主界面继续显示本机 CPU、内存与温度/热状态；没有可用温度传感器时只显示 macOS 热状态，不编造温度。
- 新增 `WindowsIsland/` 轻量 Windows 动态岛原型，基于 MIT 开源项目做本地试验适配，通过本地 JSON 快照显示 Codex / OpenClaw / Hermes 状态。
- 保留 Codex 固定 + 一个第二 Agent 的选择模型，可在 OpenClaw、Claude Code、Hermes 中单选；未选中的 Agent 不扫描、不计入聚合。
- 补充第三方来源与许可证说明，感谢原始 codexU、OpenClaw、Hermes Agent、Codex Island、Ping Island 和 dynamic-island-on-windows 等开源项目。

## 验证

- macOS: `make build`
- macOS 自测：statistics time zone、status item、rate limits、particle animation、updates、task navigation、local system、agent selection、codex token events、dynamic island
- Parser/fixture: `CODEXU_SKIP_BUILD=1 ./scripts/test-parsers.sh`
- Windows JSON 样例：`python3 -m json.tool WindowsIsland/sample-status.json`
- Plist: `plutil -lint Resources/Info.plist`
- Diff: `git diff --check`

Windows WPF 原型未在本机编译，因为这台 Mac 未安装 `.NET` SDK。

## 安装包

正式 Release 打包时，产物名称将跟随 `Resources/Info.plist` 的版本：

- Apple Silicon: `codexU-1.2.0-mac-arm64.dmg`
- Intel: `codexU-1.2.0-mac-x86_64.dmg`

本版本仍是本机定制分支。自动上游更新保持关闭，只保留手动检查入口。
