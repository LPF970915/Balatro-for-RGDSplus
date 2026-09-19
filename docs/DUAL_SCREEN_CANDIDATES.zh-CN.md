# 下一款双屏游戏：候选与《杀戮尖塔》预研

调查日期：2026-09-19。这里只讨论《杀戮尖塔》第一代。
这是代码与上游移植资料的预研，不是 RGDSplus 实机兼容列表。
设备方案见 [RGDSplus 移植手册](RGDSPLUS_PORTING_GUIDE.zh-CN.md)。

## 1. 建议

**推荐把《杀戮尖塔》列为下一款优先验证对象，但先做单屏运行验证，不直接开工全量双屏。**

理由是玩法有明确的“信息区 / 操作区”，并且已经确认 PortMaster 存在
`aarch64` 移植，用户提供正版 `desktop-1.0.jar`，不必从 Windows 可执行文件起步。[S1]
不过它使用 Java、原生依赖、图形转接和注入组件，不能视作另一个 Lua/LÖVE 游戏。[S2]

与 Balatro 相比，预期工程难度更高。主要风险不是写多少面板，
而是本机图形兼容性、进程总内存、渲染/命中测试能否拆开，以及上屏敌人的目标选择。
当前尚未提供该游戏正版本体，也没有在 RGDSplus 上启动它；不承诺帧率和完成周期。

## 2. 候选比较

下面“难度”是基于已有证据的工程判断，不是实测评分。
“已有 PortMaster”只代表存在移植基础，不表示支持当前固件。

| 游戏 | 双屏分工建议 | 已确认的基础 | 预期难度 / 优先级 |
| --- | --- | --- | --- |
| 杀戮尖塔 1 | 上屏战斗与敌人意图，下屏手牌、能量、动作 | ARM64 PortMaster，正版 JAR，Java 17 + 图形转接 [S1][S2] | 中高；玩法收益高，首选验证 |
| OpenXcom Extended | 上屏大地图/战场参考，下屏当前操作、物品栏、单位命令 | PortMaster 有 aarch64；C++/SDL 源码；需要正版旧 X-COM 资源 [S5] | 中高；源码可控性较好，但大量战场点选不能凭空丢掉 |
| 破碎的像素地牢 | 下屏地图与移动，上屏状态、日志、装备详情；背包操作仍留在下屏 | 开放源码，移动/桌面平台，Java/libGDX；桌面打包仍需适配 ARM64 [S6] | 中；适合源码重构研究，不是现成包即用 |
| Dungeon Crawl Stone Soup | 下屏地图/动作，上屏状态、日志与当前目标详情 | ARM64 PortMaster；开放源码，SDL tiles，GPLv2+ [S7] | 初始拆面板中，完整交互高；指令种类多 |
| 骰子地下城 | 上屏敌人与回合信息，下屏骰子和装备槽 | PortMaster 脚本实际调用 Box64 与 Westonpack [S8] | 高；布局很合适，但本轮不列为省力首选 |

如果优先“玩家收益”，先试《杀戮尖塔》。
如果优先“有源码、渲染和输入可改”，重点比较像素地牢与 OpenXcom；
但前者仍要打通 ARM64 桌面运行时，后者旧 SDL 显示链路和全量界面较重。
没有一个候选可以仅凭现有 Balatro 双屏模块实现低成本自动转换。

### 为什么没有把战场一律放上屏

上屏适合信息，并不意味着所有主画面都该上移。
需要频繁点击地图格子的游戏，地图留在下屏往往更自然，上屏展示辅助信息。
OpenXcom 如果上屏独占战场，就必须增加下屏可操作战术视图或明确的按键光标方案；
单纯搬走所有命中区域会让触摸体验倒退。这也是不同游戏不能套同一布局模板的原因。

## 3. 《杀戮尖塔》现有移植链路

查阅的 PortMaster 目录固定在提交：
`d4a4130059e2c8e8627bc55b78e3e0fae5b038f8`。
本节描述这个快照，不保证未来上游版本保持相同参数。

```text
用户的正版 desktop-1.0.jar
  -> 提取资源 / 音频处理 / xdelta 补丁
  -> desktoppatched.jar
  -> ARM64 Java 17
  -> controller-injector / texture compression agent / 原生库
  -> Westonpack + crusty_glx_gl4es
  -> 设备显示
```

上游元数据要求的运行时：[S1]

```text
weston_pkg_0.2.squashfs
zulu17.54.21-ca-jre17.0.13-linux.squashfs
```

启动脚本使用 `westonwrap.sh headless noop kiosk crusty_glx_gl4es`，
包含 `libwrap.so`、controller agent、纹理压缩 agent 等组件。
参数包括 `LIBGL_ES=3`、`LIBGL_FORCE16BITS=1`、`TEXCOMPRESS_FORCE=astc`；
Java 使用 `-Xms128M -Xmx140M -Xss512k -XX:MaxDirectMemorySize=60M`。[S2]

这些是上游参数，**不是 RGDSplus 推荐参数**。
140 MB Java 堆上限不代表总进程或系统只占 140 MB：
JNI、native buffers、线程栈、图形纹理、驱动和额外合成器还会占用内存。
目前不能据此承诺低内存设备稳定运行。

上游 README 提醒打补丁后第一次启动可能约 15 分钟；
这是上游提示，不是我们的设备计时，也不能把首次处理耗时当作卡死。[S3]

### 3.1 不能照搬的部分

- 上游寻找 PortMaster control 目录，并使用 `/$directory/ports/slaythespire`；
  当前设备实际目录是大写 `/mnt/mmc/Ports`。[S2]
- 上游挂载 `/tmp/weston`、`/tmp/javaruntime` 并启动包装链；
  本机已经有 Weston，必须核查输出、输入抓取、挂载点与退出清理是否冲突。[S2]
- 补丁脚本会重编码音频，并在完成路径中删除输入 JAR；
  我们应保留用户原件，在独立缓存副本上处理，校验完成后原子提交。[S4]
- `info.displayconfig`、游戏宽高参数和控制器光标坐标有联系；
  不能只把一个宽度改成 2048 就认为命中区域也正确。[S2]
- 需要核查 agents、GL 转接和原生库的源码来源及各自再分发许可；
  “PortMaster 有包”不能替代我们发布时的依赖审计。

建议先保留上游已工作的 Java/补丁组合，适配启动环境后验证单屏。
不要同时升级 JVM、更换渲染后端、安装大型 Mod 框架和改双屏，否则故障归因很困难。

## 4. 推荐界面

### 4.1 战斗

| 上屏：观察与反馈 | 下屏：可操作区域 |
| --- | --- |
| 敌人、意图、血量、格挡和状态 | 手牌、选牌、拖动、放大阅读 |
| 玩家战斗表现、攻击动画、伤害数字 | 能量、结束回合、取消操作 |
| 遗物/增益摘要和行动结果 | 药水、抽牌/弃牌/消耗牌入口 |
| 当前选中目标的醒目标识 | 敌方目标选择条、必要的详细提示 |

**不建议把“手指拖牌穿过铰链到上屏敌人”作为交互。**
推荐主流程为“点卡牌 -> 下屏出现目标选择条 -> 点目标”。
目标选择条可以展示敌人头像、血量与意图，并在上屏同步高亮。
按键玩家可用肩键轮换目标并确认，但不能用这个补救方案取消完整触摸支持。

无目标牌、群体牌和指向牌要分开处理；同时覆盖：
取消、无效目标、敌人死亡/召唤后目标索引变化、选牌弹窗、抽弃牌浏览及药水指向。
目标选择条应引用同一份敌人对象/稳定标识，而不是生成另一套战斗状态。

### 4.2 非战斗

| 场景 | 上屏 | 下屏 |
| --- | --- | --- |
| 标题 | Logo / 背景 | 开始、继续、设置 |
| 地图 | 路线总览或当前层信息 | 可点击路线，明确当前可选节点 |
| 商店 | 金币/牌组概况、选中商品详情 | 商品、移除卡牌、购买与返回 |
| 事件 | 插图和结果摘要 | 完整可读叙述或可展开文本、选项 |
| 营火 | 当前状态、选项说明 | 休息/升级等选择及卡牌选择 |
| 奖励 | 战斗结果与当前构筑摘要 | 奖励卡牌、药水、领取/跳过 |
| 牌组浏览 | 选中卡牌大图 / 描述 | 列表、筛选、确认/关闭 |

关键决策文本不能只剩上屏小字；不应为了“上屏有东西”重复所有内容。
复杂弹窗先保持原流程可用，再逐项重排，不一次改完所有场景。

## 5. 技术切入点

### 5.1 可以复用

应用独立目录、正版资源导入、构建标识与缓存校验、进程日志、存档隔离、
设备发现、触摸模式恢复、单指手势 ownership、取消规则、截图和验收方法。

### 5.2 必须重做

Java/libGDX 渲染分层、camera/viewport 或离屏缓冲管理、命中区域变换、
窗口大小与游戏逻辑宽高的区分、触摸到游戏线程的投递、卡牌与敌人目标交互。
LuaJIT FFI 输入代码不能原样在 JVM 中运行。

建议只有一个 JVM、一个规则循环。
可验证两组 viewport/camera，或受控的离屏层；但不能把整幅最终单屏画面复制两次
当作 UI 拆分。绘制偏移、命中检测和弹窗坐标必须共享同一套变换。
libGDX 输入与渲染坐标的方向及 viewport unproject 应按实际后端验证，
不要直接假设与 LÖVE 坐标相同。

ModTheSpire 与 BaseMod 是有用的补丁入口候选。[S9]
不过其已读取 README 仍写 Java 8，而当前 PortMaster 启动 Java 17 并带其他 agents。
README 可能保留历史说明，不能据此断言绝对不兼容，也不能假定直接组合可用。
先做最小 hook 验证，再决定使用小型 agent、现有 Mod 框架或版本绑定补丁。

### 5.3 分阶段准入

| 阶段 | 验证内容 | 通过标准 / 不通过时 |
| --- | --- | --- |
| P0 单屏 | 正版本体版本、ARM64 依赖、显示/音频、战斗/地图/商店/事件/保存 | 连续场景转换、退出回菜单、重启读档正常；记录冷/热启动、峰值内存、内核 OOM；失败先修基础 |
| P1 双屏外壳 | 2048×768 跨屏测试图、两屏输出次序、下屏触摸坐标 | 四角命中、焦点恢复、图形转接无重复输入；失败暂缓 UI 重构 |
| P2 最小战斗 | 上屏敌人，下屏手牌，打出一张指定目标牌和无目标牌 | 目标选择/取消/结束回合正确，规则与单屏一致 |
| P3 完整交互 | 卡牌浏览、药水、目标增减、tooltip、拖动与按键混用 | 切场景不残留手势，不引用已销毁目标 |
| P4 全流程 | 地图/商店/事件/营火/奖励/首领与多角色 | 多轮完整流程、保存恢复、长时间资源曲线；再决定发布 |
| P5 发布 | 适配包、依赖许可、日志、升级回退、原创件校验 | 无游戏本体/生成完整 JAR/个人存档，干净卡目录可安装 |

P0 先测试一次完整单屏流程，不能用“标题能打开”代替运行稳定。
P2 通过前不要投入大量美术与全部菜单重排。
第一版不叠加第三方玩法 Mod，也不默认关闭垂直同步或盲目扩大 Java 堆。

## 6. 其他候选的取舍

OpenXcom Extended 的优势是原生 ARM64 移植和可修改引擎源码。
难点是已有旧 SDL 路径、多种分辨率布局、大量精细战场交互。
PortMaster 目录名为 `openxcom`，实际发布对象是 **OpenXcom Extended**，
不能把基础 OpenXcom 和 OXCE 的分支、二进制或补丁直接混用。[S5]

像素地牢的优势是源码可控、原生触摸交互基础以及回合制节奏。
当前桌面 Gradle 使用 libGDX LWJGL3，Linux 打包 JDK 配置仍指向 x64；
某个 tinyfd 依赖包含 arm64 natives，不等于整个桌面依赖链已经支持本机。
应先查完 JRE、LWJGL、GLFW、freetype 等原生库，再谈双屏布局。[S6]

DCSS 的状态与日志天然适合上屏，也已有 ARM64 PortMaster。
但上游自己提示控制复杂，快捷键/菜单/目标选择的全面触摸化可能比显示拆分费时，
不应把它列为“几乎不用改就能完成”的项目。[S7]

骰子地下城的“敌人上屏、骰子和装备下屏”很自然；
可是查到的启动脚本运行的是 Box64 包装的本地二进制，不是 Balatro 的 LÖVE 模块。
额外转接和渲染 hook 成本使它不适合充当最省力的第二个项目。[S8]

## 7. 发布边界

商业游戏继续采用“适配包 + 用户自备正版资源”，不公开生成后的完整游戏。
不要假设所有游戏都能只复制一个 EXE；《杀戮尖塔》上游要求的是 JAR。[S1]

开放源码游戏必须按自身及依赖许可证安排源码、修改说明与二进制发布。
例如像素地牢仓库提供 GPLv3 许可文本，DCSS 为 GPLv2+；
不能把 Balatro 项目的原创适配非商业条款整体套给这些第三方代码。[S6][S7]
具体发布时应再审计对应版本和组合方式，本预研不代替完整许可审查。

## 8. 一手来源

下列材料已直接读取。S1 至 S4 固定在上述提交，其余为 2026-09-19 读取的分支快照。
PortMaster 元数据与脚本是移植维护者的直接资料，不是 RGDSplus 实测结果。
本地研究记录保留部分来源正文、SHA-256 与读取日期，便于未来对比。

- [S1] PortMaster《杀戮尖塔》元数据：`https://raw.githubusercontent.com/PortsMaster/PortMaster-New/d4a4130059e2c8e8627bc55b78e3e0fae5b038f8/ports/slaythespire/port.json`
- [S2] 同一版本启动脚本：`https://raw.githubusercontent.com/PortsMaster/PortMaster-New/d4a4130059e2c8e8627bc55b78e3e0fae5b038f8/ports/slaythespire/Slay%20the%20Spire.sh`
- [S3] 同一版本 README：`https://raw.githubusercontent.com/PortsMaster/PortMaster-New/d4a4130059e2c8e8627bc55b78e3e0fae5b038f8/ports/slaythespire/README.md`
- [S4] 同一版本补丁流程：`https://raw.githubusercontent.com/PortsMaster/PortMaster-New/d4a4130059e2c8e8627bc55b78e3e0fae5b038f8/ports/slaythespire/slaythespire/tools/patch.txt`
- [S5] OXCE 元数据：`https://raw.githubusercontent.com/PortsMaster/PortMaster-New/main/ports/openxcom/port.json`；启动脚本：`https://raw.githubusercontent.com/PortsMaster/PortMaster-New/main/ports/openxcom/OpenXcomEX.sh`；引擎分支：`https://github.com/MeridianOXC/OpenXcom/tree/oxce-plus`
- [S6] 像素地牢源码：`https://github.com/00-Evan/shattered-pixel-dungeon`；桌面构建：`https://raw.githubusercontent.com/00-Evan/shattered-pixel-dungeon/master/desktop/build.gradle`；许可：`https://raw.githubusercontent.com/00-Evan/shattered-pixel-dungeon/master/LICENSE.txt`
- [S7] DCSS 元数据：`https://raw.githubusercontent.com/PortsMaster/PortMaster-New/main/ports/dungeoncrawlstonesoup/port.json`；官方 README：`https://raw.githubusercontent.com/crawl/crawl/master/README.md`
- [S8] 骰子地下城启动脚本：`https://raw.githubusercontent.com/PortsMaster/PortMaster-New/main/ports/diceydungeons/Dicey%20Dungeons.sh`
- [S9] ModTheSpire：`https://raw.githubusercontent.com/kiooeht/ModTheSpire/master/README.md`；BaseMod：`https://raw.githubusercontent.com/daviscook477/BaseMod/master/README.md`
