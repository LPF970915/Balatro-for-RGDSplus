# Balatro for RGDSplus

RGDSplus 双屏适配项目，移植维护：**Blood_roc**。

> **本仓库及 Releases 仅发布适配包，不包含 Balatro 游戏本体。**
> **请购买正版游戏，并自行放入正版 Windows 版 `Balatro.exe` 后启动。**
> **任何对外传播的包含游戏本体的包体，均不是本人公开发布或授权发布。**
> 积极支持正版游戏，尊重游戏开发者及各第三方作者的劳动成果。

## 下载

进入本仓库的 [Releases](https://github.com/LPF970915/Balatro-for-RGDSplus/releases)，下载
`Balatro for RGDSplus.zip`。

这是适配测试版本，不是游戏，也不是 Windows 游戏安装程序。无需支付下载费用。
GitHub 自动生成的 “Source code” ZIP 是仓库快照，不是直接解压到内存卡的安装包。

## 安装

适用范围：目前验证的 **RGDSplus、双 1024×768 屏幕、gt9xx 触屏、
Linux/Wayland 固件环境**。不保证适用于其他机型或固件。

目前支持已验证的正版 PC 本体：
`1.0.1o-FULL / 1.0.1o / PROD_PC_Console`。
本体实际内容会被校验；其他版本、安装过修改或损坏的文件可能不兼容。

1. 退出游戏。升级前备份内存卡中的 `Ports/BalatroDual/saves/`。
2. 将适配包解压到内存卡的游戏数据分区根目录，合并 `Ports` 文件夹。
3. 在 Steam 中右键 Balatro，选择“管理 → 浏览本地文件”，找到正版 `Balatro.exe`。
4. **只复制这个 EXE** 到内存卡 `Ports/BalatroDual/gamedata/Balatro.exe`。
5. 插卡开机，从 Ports 选择 **Balatro for RGDSplus**。
6. 首次启动会离线读取本体、应用适配补丁并校验，然后进入游戏。期间请勿断电或拔卡。

正确结构：

```text
内存卡根目录/
  Ports/
    Balatro for RGDSplus.sh
    BalatroDual/
      launch.sh
      installer/
      runtime/
      gamedata/
        Balatro.exe       <- 用户自行放入；本项目不提供
      cache/
      saves/
      logs/
```

压缩包根目录只有 `Ports/`，其中只有 `BalatroDual/` 和
`Balatro for RGDSplus.sh`。说明与许可放在 `BalatroDual/` 内。

不要解压 EXE，不要改名为 ZIP，不需要复制 DLL、Steam 账号文件或整个 Steam 目录。
不要形成 `Ports/Ports/`。建议预留至少 500 MB 空间。

安装器不会执行 Windows EXE，而是读取其中的游戏内容。它不登录 Steam，
不读取 Steam 凭据；内容校验用于判断兼容性，**不是购买凭证或所有权认证**。
请只使用你合法取得的正版文件。

## 更新与存档

覆盖适配文件时保留 `gamedata`、`saves`、`logs`。
内部目录继续使用 `BalatroDual`，存档标识继续使用 `balatro-dual`，以兼容旧版本。
旧版用户可以删除旧入口 `Ports/Balatro Dual.sh`，避免 Ports 菜单重复；
**不要删除 `Ports/BalatroDual` 文件夹**。

生成缓存位于 `Ports/BalatroDual/cache/`。不同补丁使用独立缓存；
安装失败不会静默启动其他补丁版本。保留正版 EXE，便于重新生成损坏缓存。

## 当前适配

- 上屏显示盲注、筹码 × 倍率、关卡分数及回合信息；顶部面板等高排列。
- 下屏承担牌桌、手牌、商店、盲注选择与主要按钮。
- 上下屏开场漩涡和白光同步，Logo 与飞牌保留在上屏。
- 下屏触控适配；保留游戏原有的选牌、拖动和按钮交互。
- 版本署名右对齐；启动、资源状态及可捕获的报错写入日志。

R4.4 已完成隔离实机结算、商店、下一盲注发牌检查及安装后 311 个生成文件校验。
这些检查不等同于全部牌组、全部机制或长期稳定性验收；没有在本轮重新完成手指实测。

## 问题反馈

先阅读 [故障排查](https://github.com/LPF970915/Balatro-for-RGDSplus/blob/main/docs/TROUBLESHOOTING.md)，然后提交 Issue，说明版本、机型、
固件、复现步骤和发生时间。

报错信息保存在 `Ports/BalatroDual/logs/`。公开回传前请检查、脱敏：
日志可能包含设备环境、文件路径及操作状态。
**不要上传正版 EXE、生成缓存、完整游戏文件、账号信息或未经检查的存档。**

## 发布与权利声明

本人仅通过本仓库及其 Releases 公开发布**不含游戏本体的适配包**。
任何对外传播的包含游戏本体的包体，均不是本人公开发布或授权发布。
本项目不提供游戏本体的下载、代购、破解、授权绕过或任何盗版支持。

对于第三方擅自捆绑游戏本体、冒用作者身份、盗用成果、收费售卖或其他违法行为，
本人不授权、不参与、不认可；相关行为及其后果由行为人自行承担。
在适用法律允许的范围内，本人不对上述第三方行为承担法律责任。
**此声明不排除法律规定不得排除的责任，不构成绝对免责承诺。**

禁止未经授权盗用本人原创适配成果、署名或项目名义从事商业行为，包括收费售卖、
付费下载、商业整合包、付费预装及冒充官方服务。本人可授权部分仅授予
保留署名的非商业使用权限，详见 [项目使用条款](https://github.com/LPF970915/Balatro-for-RGDSplus/blob/main/LICENSE.md)。

第三方代码和运行时继续适用各自许可证；上述限制不撤销其原有授权，
也不将 Balatro 的任何权利授予使用者。详见
[第三方来源与许可](https://github.com/LPF970915/Balatro-for-RGDSplus/blob/main/THIRD_PARTY_NOTICES.md)。

这是非官方适配项目，与 Balatro 的权利人不存在官方隶属、授权背书或合作关系。
Balatro 及其游戏内容、商标等权利归相应权利人所有。
**请积极购买并支持正版游戏，不传播本体或本机生成的完整游戏内容。**

## 仓库结构

```text
adapter/       发布用适配文件；无游戏本体
metadata/      文件校验清单、补丁来源映射
tools/         仅适配包构建与审计工具
docs/          安装排错、发布说明
```

本仓库是可审计的适配发布快照，不包含私有开发目录、游戏源码快照、
远程设备凭据、个人存档或实机原始日志。补丁载荷是 UTF-8 文本，
文件名按 SHA-256 寻址；映射见 `metadata/patch-map.json`。

使用 Python 3.10 或更新版本运行：

```sh
python tools/build_release.py
python -m unittest discover -s tests
```

构建不需要游戏本体，不会联网获取本体。首次游戏安装才需要用户自行提供正版文件。
构建会检查白名单、校验和及敏感信息；输出 ZIP 与 SHA-256 到本地 `dist/`。
该目录不进入 Git。公开可见不等于不受限制的开源授权，请遵守分组件许可。
