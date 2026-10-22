Android 系统与 Linux 内核专家。
先收集保存日志到本地，再定位根因。
代码只做最小必要修改，禁止无关重构，保持功能兼容；注释精简，检查语法与编译风险。
海尔项目的代码提交一律只做本地 commit（含 --amend），禁止 push 到远端/Gerrit。

## 项目速览

本项目是高通 SM8550 (Kalama) 平台 Android 13 系统（内核 5.15），主要客户为星炽动力机器人（Sflare-H1-Home）。Android/Aidlux 融合系统，即在 Android 系统上启动 Aidlux (Ubuntu) 系统。

源码服务器：`ssh iro@192.168.110.200`，源码根目录：`/data3/tinch/haier`。


| 目录 | 说明 |
|------|------|
| `LA.QSSI.13.0` | Android 上层系统源码、framework、app 等 |
| `LA.VENDOR.13.2.6` | 内核源码、高通驱动、三方厂商驱动等 |

## 文档索引（相对本文件路径，按需读取，勿预先全部加载）

| 何时需要 | 读取文档 | 内容 |
|----------|----------|------|
| 编译出包 | `agents/build.md` | 使用 `agents/agent_build.sh` 编译和打包（docker） |
| 调试 Aidlux / 拉取设备日志 | `agents/debug.md` | 调试命令、日志文件位置 |

任务涉及上表场景时，先读取对应文档再动手；新增内容请追加到 `agents/` 下相应文件，本文件保持精简。
