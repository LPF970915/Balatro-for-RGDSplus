# RGDSplus 双屏与触控移植手册

整理日期：2026-09-19。基线：Balatro for RGDSplus R4.4。

本文记录本项目已经实现和验证的设备接口、显示与输入方案，供后续游戏移植复用。
不包含游戏本体、设备凭据、玩家存档或原始系统日志。
新游戏的选型见 [双屏游戏候选分析](DUAL_SCREEN_CANDIDATES.zh-CN.md)。

## 1. 结论与证据边界

**采用现有 Linux 单屏移植作为运行基础，在同一个游戏实例内拆分显示与交互。**
不启动两个游戏进程，不复制两份规则状态，也不借用 3DS 运行时。

本项目可复用的部分是：设备发现、启动退出管理、两屏坐标约定、输入状态机、
缓存安装、日志与验收流程。Balatro 的 Lua 对象路由和 UI 布局不是通用双屏插件。

| 状态 | 含义 |
| --- | --- |
| 已取证 | 2026-09-18 至 19 日的设备记录、运行代码或验证结果支持 |
| 用户实测 | 用户实际使用设备反馈；不扩大为所有场景已通过 |
| 待采集 | 当前没有足够实机证据，不能写成硬件定论 |
| 设计建议 | 下一项目建议遵守的约定，不代表已有实现 |

2026-09-19 已重新连接设备，并归档运行中的 FDT、sysfs 设备树快照、
Weston/DRM/Wayland 信息和触摸参数。私有证据目录位于
`PortMaster-RGDSplus/validation/device-tree-reference-20260919-211504/`；
公开仓库只保留脱敏后的结论，不提交原始 DTB、完整系统日志或序列信息。
运行时快照不是厂商原始 DTS 源码，仍不能代表未加载的 overlay/include 历史。

## 2. 设备与系统基线

| 项目 | 已有证据 / 限制 |
| --- | --- |
| 设备 | RGDSplus，当前已验证固件 |
| 架构 | `aarch64` |
| 内核 | `Linux 6.1.141`，构建标识 `#43 SMP Tue Sep 15 05:45:19 UTC 2026` |
| 合成器 | Weston `14.0.2`，启动命令 `/usr/bin/weston --warm-up` |
| 输出 | 两路 DSI，各 `1024×768 @ 60.2 Hz`；记录的像素时钟约 `62.8 MHz` |
| DRM | `/dev/dri/card0`；该次会话报告不支持 atomic modesetting / GBM modifiers |
| EGL / GLES | EGL `1.5`，客户端 API `OpenGL_ES`，GL 版本字符串为 OpenGL ES `3.2` |
| 驱动报告 | ARM `Bifrost-g24p0` 系列，renderer 字符串 `Mali-G52` |
| SoC / 内存 | DT 明确为 RK3568；`MemTotal` 976760 kB，Swap 0，CMA 49152 kB |
| 触摸 | `gt9xx-0`，Type-B 多点输入，当前按单指交互消费 |
| 系统用户空间 | Buildroot 2024.02，glibc 2.41 |
| CPU | 4 个在线 Cortex-A55，最高频率 1992000 kHz；当前 governor 为 performance |

SoC、CPU 数量、内存和系统版本均来自本次运行时 DT/proc/sysfs 采集。
GPU 的 `Mali-G52` 是驱动 renderer 报告；DT 节点本身是 `arm,mali-bifrost`，
不要把 renderer 字符串当成完整 GPU 型号证明。

### 2.1 运行时拓扑

以下是已归档的 Linux 设备路径，地址不是推测出的 DTS：

```text
/sys/devices/platform/
  fdd40000.i2c/i2c-0/0-0020/
    rk805-pwrkey/input/input0        -> rk805 pwrkey
  fe5e0000.i2c/i2c-5/5-0014/
    input/input1                    -> gt9xx-0
  rk817-sound/
    input/input2                    -> headset-keys
    sound/card0/input3              -> rockchip-rk817 Headset
  gpio-keys-polled/...              -> ANBERNIC-rk3568-keys

DRM / Weston logical layout:
  /dev/dri/card0
    DSI-1                           -> x=0,    1024×768, physical 229×143 mm
    DSI-2                           -> x=1024, 1024×768, physical 119×143 mm
```

设备树别名为 `dsi0 -> /dsi@fe060000`、`dsi1 -> /dsi@fe070000`，
但当前 Weston/DRM 的物理布局是：

```text
逻辑 x=0..1023     DSI-1 -> /dsi@fe070000 -> 物理宽 229 mm
逻辑 x=1024..2047  DSI-2 -> /dsi@fe060000 -> 物理宽 119 mm
```

因此程序应以 Wayland/DRM 输出位置和运行时探测为准，不能把 DT 的 dsi0/dsi1
直接当作上屏/下屏顺序。Balatro 当前使用左半上屏、右半下屏，和该运行时布局一致。

触摸在该次启动中是 I2C 总线 5、地址 `0x14`、`/dev/input/event1`。
对应 by-path 为 `/dev/input/by-path/platform-fe5e0000.i2c-event`。
DT 节点为 `i2c@fe5e0000/gt9xx-0@14`，轴上限为 X `1024`、Y `768`、slot `15`。

| 归档中的事件号 | 设备名 |
| --- | --- |
| event0 | rk805 pwrkey |
| event1 | gt9xx-0 |
| event2 | headset-keys |
| event3 | rockchip-rk817 Headset |
| event4 | adc-keys |
| event5 | ANBERNIC-rk3568-keys |
| event6 | dierct-keys-polled |

`dierct` 是设备报告的拼写。event 编号、input 编号、DRM connector/CRTC ID 和
PID 都可能改变，程序不能以这张表中的编号作为永久配置。

### 2.2 已确认的运行时设备树

优先读取 `/sys/firmware/devicetree/base`；部分系统也提供 `/proc/device-tree`。
本次确认 `/sys/firmware/fdt` 存在，大小约 188 KiB；`/proc/device-tree` 是它的
符号链接。设备上没有 `dtc`，因此工作机保存了原始 `runtime.dtb` 和无类型解释的
属性十六进制快照，未伪造可直接编译的厂商 DTS。

已确认的关键节点：

- 根节点：`model = Rockchip RK3568 DEEP LP3 V10 Board`，
  `compatible = rockchip,rk3568-deep-lp3-v10, rockchip,rk3568`。
- GPU：`/gpu@fde60000`，`compatible = arm,mali-bifrost`，状态 `okay`。
- 两个 DSI：`/dsi@fe060000` 与 `/dsi@fe070000`，均为
  `rockchip,rk3568-mipi-dsi`、双 lane、状态 `okay`。
- 两块 panel：`simple-panel-dsi`，均 `1024×768`、RGB888、62.8 MHz、
  水平时序 `1024/120/80/80`、垂直时序 `768/16/8/8`。
- 显示 route：`route-dsi0` 与 `route-dsi1` 均 `okay`，HDMI、LVDS、eDP、RGB route
  为 `disabled`；endpoint 连接到 VOP 的两个输出端口。
- 触摸：`goodix,gt9xx`、I2C `0x14`、`max-x=1024`、`max-y=768`；
  DT 中 reset/touch GPIO 均挂在 `/pinctrl/gpio@fdd60000`。

DT GPIO 数字是 Linux GPIO controller 引用与 pin 编码，不能直接当成物理 SoC
编号；移植只需要按设备节点发现触摸，不应主动复位屏幕或触摸。

启动存储和路径也已确认：

```text
/dev/mmcblk1p7  label ports     # 本机 /mnt/mmc
/dev/mmcblk1p8  label vendor    # 本机 /mnt/vendor
/dev/mmcblk1p11 label ROMS
/dev/mmcblk2p1  label Basic data partition # 本机 /mnt/sdcard
```

系统根分区是 `/dev/root`，`/boot` 目录不存在。不要由这些分区名推断刷机工具、
升级流程或 DTB 文件位置；`runtime.dtb` 是启动时正在使用的 FDT，不是原始固件包。

尚需留意但不影响当前移植的边界：

- 厂商原始 DTS 的 include、overlay 和构建来源未取得。
- 物理屏幕“上/下”是机壳语义，设备树只给出 DSI 节点；应继续用输出坐标确认。
- Weston 配置中 `DSI-1` 与 `DSI-2` 未写 `pos`，当前顺序由运行时输出布局提供。

在设备上可先执行以下只读检查：

```sh
uname -a
tr '\000' '\n' < /sys/firmware/devicetree/base/model
tr '\000' '\n' < /sys/firmware/devicetree/base/compatible
grep -E '^(MemTotal|MemAvailable|SwapTotal):' /proc/meminfo
for d in /sys/class/input/event*/device; do
    printf '%s: ' "$d"
    cat "$d/name"
done
for d in /sys/class/drm/card*-*; do
    printf '%s\n' "$d"
    cat "$d/status" "$d/enabled" "$d/modes" 2>/dev/null
done
cat /sys/class/anbernic_misc/tpctrl
```

如果以后设备提供 `dtc`，可把运行中的树反编译到标准输出并在工作机保存：

```sh
dtc -I fs -O dts /sys/firmware/devicetree/base
```

这不等于拿到了原始 DTS 源码及其 include/overlay 历史。当前设备没有 `dtc`，
不需要为游戏移植临时安装。
公开前检查 serial、MAC 等字段；不要为采集信息写 sysfs、抓取触摸独占权或替换 DTB。

## 3. 路径约定

### 3.1 固件接口

| 路径 | 用途 / 注意 |
| --- | --- |
| `/mnt/mmc/Ports/` | `ports` 分区挂载点中的 Ports 安装目录，大小写有意义 |
| `/mnt/sdcard/` | `Basic data partition` 挂载点；不是当前 Ports 入口 |
| `/dev/mmcblk1p7` | `ports` 分区块设备 |
| `/dev/mmcblk1p8` | `vendor` 分区块设备 |
| `/dev/mmcblk2p1` | `Basic data partition` 块设备 |
| `/mnt/vendor/ctrl/loadapp.sh` | 已归档的固件前端启动脚本 |
| `/mnt/vendor/bin/dmenu.bin` | 已归档的前端程序 |
| `/etc/xdg/weston/weston.ini` | Weston 配置，采集时只读 |
| `/var/log/weston.log` | 输出布局、输入绑定和 GLES 初始化证据 |
| `/usr/lib/libweston-14/drm-backend.so` | 该固件 DRM 后端 |
| `/usr/lib/libweston-14/gl-renderer.so` | 该固件 GL renderer |
| `/var/run` | 当前 `XDG_RUNTIME_DIR`；Weston 报告权限不是 0700，应用沿用现状 |
| `/tmp/pulse-socket` | 已验证的 PulseAudio socket |
| `/sys/class/input/event*/device/name` | 通过设备名发现触摸 |
| `/dev/input/event*` | evdev 输入节点，需要有读取/抓取权限 |
| `/sys/class/anbernic_misc/tpctrl` | 本固件触摸模式开关 |
| `/sys/class/drm/`、`/dev/dri/` | 输出与图形设备探测 |

上游 PortMaster 常用 `/$directory/ports/` 和其他 control 目录。
它们不是本固件 `/mnt/mmc/Ports/` 的同义词，不能照抄启动脚本后假设适用。

### 3.2 当前游戏目录

```text
/mnt/mmc/Ports/
  Balatro for RGDSplus.sh
  BalatroDual/
    launch.sh
    dual_touch.sh
    runtime/
      love.aarch64
      libs.aarch64/
    gamedata/
      Balatro.exe                  # 用户自行提供正版文件
    installer/
      main.lua
      conf.lua
      recipe.lua
      build-id.txt
      payload/*.bin
    cache/love/balatro-dual-installer/builds/<recipe_id>/
      ready.txt
      game/                        # 本机生成，不公开发布
    saves/love/balatro-dual/
      settings.jkr
      1/save.jkr
    logs/
```

产品改名不等于改内部目录。保留 `BalatroDual` 和 `balatro-dual`，避免旧存档失联。
Linux 的 `love` 路径区分大小写，不要照搬 Windows 验证环境的 `LOVE`。
`<recipe_id>` 来自安装器构建标识，不要写死某一版本的哈希。
旧记录里的预构建 `.love` 包不是当前发布包的安装方式。

公开包仍只有 `Ports/`，其中一个应用目录和一个入口脚本。
文档新增不改变包结构，不把开发工具、采集脚本或原始日志塞进发布包。

### 3.3 启动环境

当前入口设置 Wayland、GLES、PulseAudio 和应用独立数据目录：

```text
SDL_VIDEODRIVER=wayland
WAYLAND_DISPLAY=wayland-0                 # 默认值，允许已有环境覆盖
XDG_RUNTIME_DIR=/var/run                  # 默认值，允许已有环境覆盖
SDL_VIDEO_DOUBLE_BUFFER=1
SDL_RENDER_VSYNC=1
LOVE_GRAPHICS_USE_OPENGLES=1
SDL_AUDIODRIVER=pulse
ALSOFT_DRIVERS=pulse
PULSE_SERVER=unix:/tmp/pulse-socket
LD_LIBRARY_PATH=<app>/runtime/libs.aarch64:/usr/lib:/lib
BALATRO_RGDS_ROOT=<app>
BALATRO_PM_PERF_OPTIMIZATIONS=1
BALATRO_PM_FPS_CAP=60                      # 默认值
XDG_DATA_HOME=<app>/saves
XDG_CONFIG_HOME=<app>/saves
```

安装器子进程单独把 XDG 数据/配置目录指向 `<app>/cache`。
校验成功并出现匹配的 `ready.txt` 后才启动游戏；失败不回退到旧缓存蒙混启动。
正式入口清除测试和 fixture 开关。垂直同步保持开启，性能优化另行验证。

## 4. 双屏画面实现

### 4.1 三种坐标不能混淆

| 坐标空间 | 尺寸与作用 |
| --- | --- |
| 物理单屏 | 每块 `1024×768` |
| 合成器窗口 | `2048×768`，左半显示在上屏，右半显示在下屏 |
| 游戏逻辑视口 | 单屏 `1024×768`；游戏自身还存在 tile 等布局单位 |

```text
真实窗口： [ DSI-1 / 上屏 x=0..1023 ][ DSI-2 / 下屏 x=1024..2047 ]  y=0..767

反馈截图： [ 上屏 1024×768 ]
          [ 下屏 1024×768 ]  -> 1024×1536
```

跨屏窗口使用无边框、非独占全屏模式，定位在该次 Wayland 合成器布局的原点。
本机 `wayland-info` 已确认 DSI-1 的 logical x 为 0，DSI-2 的 logical x 为 1024。
`love.graphics.getWidth/getHeight/getDimensions` 对原游戏返回逻辑单屏尺寸；
需要真实 drawable 大小时使用保存的底层接口，不能被自己的包装误导。
这套输出顺序只在当前固件已验证，换固件先画左右不同颜色和坐标网格重新确认。

### 4.2 对象路由，不是整幅画面拉伸

`rgds_dual.lua` 的 `screen_for` 决定对象属于哪块屏幕，
`route` 设置水平平移和本屏 scissor。对象的 area、parent 用于继承归属。
同一个更新循环维护卡牌、规则、动画和存档。

| 场景 / 对象 | 当前归属 |
| --- | --- |
| 标题 Logo、开场飞牌 | 上屏 |
| HUD、盲注信息、筹码 × 倍率、目标分数 | 上屏 |
| 打出的牌、计分展示、回合结算展示 | 上屏 |
| 手牌、选牌、主要操作、提现按钮 | 下屏 |
| 盲注选择、商店、菜单与主要弹窗操作 | 下屏 |
| 程序背景、开场白光 | 分屏绘制、统一时序 |

路由需要插入实际 draw 调用，并处理独立粒子、拖动层、弹窗和工具提示。
仅移动面板坐标，或只裁剪一张已经完成的单屏截图，都不能实现正确交互。
从手牌区移入出牌区时，由对象归属切换决定其显示屏，不新建一张规则卡牌。

渲染边界要管理 transform、scissor、shader、canvas，不能把上一屏的状态泄漏到下一屏。
尤其检查对象内部再次改变 canvas/shader、跨屏拖动、全屏后处理和离开场景的清理。

R4.4 上屏顶部顺序为：
`盲注 -> 筹码 × 倍率 -> 当前分数 / 目标 -> 其他回合信息`。
黑色底板在同一行等高。布局使用游戏逻辑单位，不照着截图固定像素硬改所有窗口。

### 4.3 背景、白光、加载

- 流动背景使用可复用的 `512×384` canvas，按每个视口绘制后放大到单屏。
- 两屏使用一致的时间、色系和背景参数，不让下屏先进入稳定漩涡、上屏还在开场。
- 不再把一个宽背景拉伸成两屏；也不把下屏单独改成低对比色系。
- 白光覆盖真实双屏宽度，但 shader 的水平坐标按 `mod(x, 1024)` 局部化，
  每屏都以自己的中心计算，避免白光集中在两屏接缝。
- 加载进度条按逻辑 `1024×768` 定位，上屏中心是 `(512,384)`。
- 只有程序背景降分辨率，文字、卡牌和按钮保持原清晰度。

半分辨率背景减少的是该 shader 的像素工作，不等于整个游戏帧率必然翻倍。
一个 `2048×768` RGBA8 全尺寸颜色缓冲约 6 MiB，额外中间缓冲、双/三缓冲、
深度附件和纹理会继续占内存。先测量再增加离屏层，不以关闭垂直同步作为默认移植步骤。

## 5. 下屏触控实现

### 5.1 为什么原生窗口触摸没有直接生效

Weston 当前把 `gt9xx-0` 绑定到 `DSI-1`，报告未由 udev 明确指定输出；
这是合成器的输入关联，不表示触摸硬件在上屏。DT 触摸节点自身没有声明屏幕输出
关系，所以应用层仍要按下屏本地坐标处理。
历史规则还出现过 `platform-xfe5e0000.i2c` 与实际 `platform-fe5e0000.i2c`
不一致。**这些是排查证据，不应把单个拼写问题写成唯一根因。**

实际修复同时处理了固件触摸模式、物理输入读取、坐标映射和游戏事件消费。
本方案不永久改 udev，不停止系统 Weston，不要求先启动 3DS 版本来“激活”触摸。

### 5.2 输入链路

```text
gt9xx-0
  -> 非阻塞 evdev 读取
  -> Type-B slot / tracking-id 状态机
  -> SYN_REPORT 提交一个完整报告
  -> 下屏本地 1024×768 坐标
  -> 统一 pointer 队列
  -> 原游戏按下、移动、松开 / 点击拖动逻辑
```

`dual_touch.sh` 进入游戏前读取 `tpctrl`，已知值为 `0` 或 `1` 才切为 `0`。
退出时仅在当前值仍是 `0` 的情况下恢复原值，避免覆盖其他程序后续改变。
未知值或接口缺失时不乱写。`EXIT` trap 不是断电或 SIGKILL 后的恢复保证。

`rgds_evdev.lua` 通过 `device/name == gt9xx-0` 发现节点，
目前扫描 event0..31，不把 event1 写死为触摸。
使用 Linux LuaJIT FFI 和 `O_RDONLY | O_NONBLOCK`，读取：

| 字段 | code | 含义 |
| --- | --- | --- |
| ABS_MT_SLOT | 47 | 当前 slot |
| ABS_MT_POSITION_X | 53 | 原始 X |
| ABS_MT_POSITION_Y | 54 | 原始 Y |
| ABS_MT_TRACKING_ID | 57 | 接触生命周期；-1 表示离开 |
| SYN_REPORT | EV_SYN / 0 | 本批状态提交 |
| SYN_DROPPED | EV_SYN / 3 | 丢事件，需要取消并重同步 |

已取证的轴范围是 X `0..1024`、Y `0..768`、16 slots。
代码以 ioctl 实际读出的边界为准；aarch64 上 `input_event` 为 24 字节，
移到其他 ABI 必须重新确认，不能生搬二进制结构。

```text
lower_x = clamp((raw_x - min_x) * 1023 / (max_x - min_x), 0, 1023)
lower_y = clamp((raw_y - min_y) *  767 / (max_y - min_y), 0,  767)
```

最大值按包含端点处理，避免右下角超出有效范围。
**物理 evdev 已是下屏本地坐标，不再减 1024。**

### 5.3 三类输入分开映射

| 来源 | 规则 |
| --- | --- |
| 窗口鼠标 | 真实窗口 X 减 1024 才是下屏坐标；上屏鼠标点击不送入下屏 |
| 原生 LÖVE touch | 兼容固件可能报告的左右半区原点，按手势锁定原点 |
| evdev | 直接映射为下屏本地坐标，绕开错误输出绑定 |

evdev 有效时不重复消费原生 touch；由触摸合成的 `istouch` 鼠标事件也要过滤。
只在聚焦时持有 `EVIOCGRAB`，失焦和关闭时释放，不能全程霸占系统输入。
evdev 不可用时保留原生输入回退，但回退并不保证固件原有错误映射已经消失。

### 5.4 必须保留的状态机保护

- 每个手势只有一个 owner，第二根手指不能抢走拖动对象；必要时等所有手指抬起。
- 在 `SYN_REPORT` 时合并轴状态，不能只收到 X 就发出半更新事件。
- `SYN_DROPPED` 取消当前操作并通过 ioctl 重同步，不能沿用旧按下状态。
- 保留位置缓存，处理再次点击同一位置时驱动不重发坐标的情况。
- pointer 队列上限 64，连续 move 可合并，down/up 的语义不能合并丢失。
- 每个游戏 update 只消费一个队列事件，使游戏控制器能看到短促的按下和抬起。
- 切换场景、菜单、暂停、失焦、拖动目标被删除和队列溢出时取消手势。
- 清除悬空的 pressed/dragged/hovered 引用；原生输入还有 15 秒空闲保护。

底层设备解码可以移植到 C/JNI 等语言，但本项目 Lua 回调不能直接接到 Java 游戏。
新引擎需要自己的焦点管理、线程投递和输入适配器。

## 6. 已踩过的坑

| 现象 | 已验证的问题与处理 |
| --- | --- |
| 触摸事件有记录但按钮不动 | 检查输入来源、原点、短促 down/up 被同帧吞掉、重复输入和模式开关 |
| 商店后点下一盲注崩溃 | 教程仍持有已销毁 CardArea，`cardarea.lua:332` 读取失效 `cards`；不是 evdev 本身崩溃 |
| 教程清理不完整 | 过滤 removed 对象及 removed 父节点，并在离店时调用原有章节清理 |
| 提现文字残留在牌桌 | 结算展示必须随所属界面结束清理，不能变成脱离父节点的常驻绘制 |
| 加载条被两屏接缝裁开 | 错用了真实宽度 2048；改为单屏逻辑尺寸定位 |
| 开场白光贴右边 | shader 仍以双屏宽度计算中心；改为每屏局部坐标 |
| 下屏背景提前显现 | 两屏必须共用开场时间轴，不能让下屏背景独立常亮 |
| 模拟输入通过、手指仍无效 | 模拟事件不能证明物理驱动、模式切换与合成器整条链路有效 |

## 7. 日志与验收

`logs/latest-path.txt` 指向本次 `.log`；同时有 `.resources.log`、可捕获的
`.lua-error.txt`、异常退出时的 `.crash.txt` 和运行中的 `game.pid`。
启动器每 10 秒采样 RSS/峰值/线程及系统可用内存。
突然断电、磁盘满、进程被强制终止时，不保证尾部日志或退出报告完整。
设备旧日志用 UTC，本地归档采用 Asia/Shanghai；分析时先对齐时间与 session。

验收顺序：

1. 单屏基线：正常启动、读档、保存退出，不破坏原 Ports 游戏或菜单。
2. 输出基线：真实跨屏尺寸、左右输出对应关系、上下拼接截图无拉伸。
3. 场景路由：开场、菜单、选关、战斗、计分、结算、商店、弹窗逐项检查。
4. 输入单测：边界、多指、同坐标连点、丢事件、失焦、短促触摸、拖动目标删除。
5. 隔离实机回归：副本存档下运行真实更新循环；不直接调用按钮回调冒充输入。
6. 物理验收：手指点四角、快速连点、拖牌、抬手取消、按键混用、休眠恢复。
7. 完整流程：多局、长时间运行、跨状态保存恢复与异常退出；最后才优化性能。

R3 留存了 15 项 pointer、14 项 evdev 及渲染/教程回归；商店到下一盲注通过
真实 evdev 节点的模拟事件验证。用户此前确认物理触摸已经生效。
R4.4 留存结算、商店、下一盲注发牌检查与 311 个安装生成文件校验。
**这些不等于 R4.4 已重新通过所有手指测试或全部游戏机制。**

截图用原始 `2048×768` 图裁左右各半，上屏在上、下屏在下，输出 `1024×1536`。
同时保留 raw、stacked、布局坐标记录和对应日志，不能只留缩略图。
临时测试目录可以在 `/tmp`，但会随重启丢失；测试存档必须与玩家目录隔离。

## 8. 源码导航与复用边界

本公开仓库是发布快照。映射见 [patch-map.json](../metadata/patch-map.json)，
其中 `path` 是安装后的逻辑路径，`payload` 相对
`adapter/Ports/BalatroDual/installer/`，不是相对 `metadata/`。
新增模块是 UTF-8 文本；原游戏修改项可能是差分载荷，不应把所有 `.bin` 当完整源码。

| 模块 | 职责 |
| --- | --- |
| `rgds_dual.lua` | 尺寸包装、对象归属、分屏路由与生命周期衔接 |
| `rgds_background.lua` | 分屏程序背景与局部白光 |
| `rgds_input.lua` | pointer 队列、输入来源去重、取消与事件投递 |
| `rgds_evdev.lua` | 设备发现、Type-B 解码、抓取与重同步 |
| `portmaster/dual_layout.lua` | Balatro 专用布局 |
| `launch.sh`、`dual_touch.sh` | 进程环境、安装、日志与固件模式恢复 |

可以直接复用的是设计约定和测试用例；允许复用的代码还须遵守对应组件许可。
SDL/C++ 或 Java/libGDX 项目优先重用原引擎的事件入口和绘制接口，
不要为了双屏把它们强行搬到 LÖVE。不要把本机 Lua 游戏更新策略误写为所有引擎的唯一方案。

新增游戏先证明：单屏能稳定运行、窗口能跨屏、触摸能命中、规则仍只有一份，
再重排全部 UI。尤其是上屏存在可点击对象时，必须先给下屏安排等价操作入口。
