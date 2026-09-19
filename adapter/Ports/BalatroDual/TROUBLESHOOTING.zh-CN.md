# 安装与排错

只从 Releases 下载适配 ZIP，将正版 `Balatro.exe` 放到
`Ports/BalatroDual/gamedata/Balatro.exe`，然后从 Ports 启动
`Balatro for RGDSplus`。

支持的本体内容为 `1.0.1o-FULL / 1.0.1o / PROD_PC_Console`。
游戏更新后请等待对应适配，不要尝试绕过内容校验。

| 提示 | 检查内容 |
| --- | --- |
| Game file not found | EXE 是否放在正确位置，是否多套了一层文件夹 |
| Unsupported or modified game file | 本体是否为支持版本、是否修改过、复制是否完整 |
| Adapter files are damaged | 重新下载并校验适配 ZIP，保留存档后覆盖适配文件 |
| Cannot write cache | SD 卡空间、写保护、文件系统及目录权限 |
| SD card write verification failed | 检查内存卡状态，不要反复强制断电 |
| Ports 未显示入口 | 刷新游戏列表，确认 `.sh` 位于 Ports 目录外层 |
| Permission denied | 检查数据分区可执行权限与脚本、运行时执行权限 |

首次安装建议至少留出 500 MB 空间。游戏不会执行 Windows EXE，
安装器使用其中的原始游戏数据并应用适配差分；不会修改原始 EXE。
后续启动检查已生成的缓存；损坏时尝试重新生成。

## 日志

位置：`Ports/BalatroDual/logs/`。

- `.log`：启动、安装、游戏状态及退出信息。
- `.lua-error.txt`：进入 Lua 报错画面前尝试立即保存的调用栈和上下文。
- `.resources.log`：运行期间的资源状态。
- `.crash.txt`：游戏非零退出时保存的摘要；不保证捕获所有原生崩溃。

断电、磁盘满、系统完全卡死等情况可能没有完整日志。
请提交复现步骤与相关日志片段；不要公开上传完整游戏或缓存。
日志和截图请先脱敏，存档仅在必要时经检查后提供。

## 兼容与验收

仅针对目前验证的 RGDSplus Linux/Wayland 环境。
不保证其他 H700/RK3566 设备、不同固件或其他分辨率可运行。
现有实机检查不代表全部玩法、长时间运行及所有外围设备都已验收。
