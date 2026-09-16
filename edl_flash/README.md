# MC940（海尔 Haier / Sflare-H1-Home）SM8550 kalama Android 13 + Aidlux — EDL 命令行刷机

关键词：MC940、MC940_A13、海尔、Haier、Sflare-H1-Home、星炽动力、SM8550、kalama、A8550BM1、QDLoader 9008、EDL、QFIL、fh_loader、QSaharaServer、刷机

| 项 | 值 |
|---|---|
| 目标 | adb 序列号 `006`，EDL 口 COM13；`ro.build.type=user`，slot `_a` |
| 固件 | `A8550BM1_EQ000_2774.DA54D9B33.A7FD7A55B.95C9A9E8D_260914_100_V01_U100` |
| 工具 | `tools\QSaharaServer.exe` + `tools\fh_loader.exe`（**19.06.10.18.44**，QFIL/QPST 同款） |
| 依据 | QFIL 日志 `134339284680525613.log`（09-15 14:43–14:47） |
| 实测 | 09-15 15:07–15:11 命令行全流程 `FLASH_OK`，日志 `logs\flash_20260915_150757.log` |
| 等价性 | 与 QFIL 协议层一致：program handler 99、patch handler 78，逐项相同 |

## 一键刷机

    # 设备在线: 自动 reboot edl → 自动找活动 9008 口 → 全流程 → 等 adb 恢复
    pwsh -NoProfile -File D:\Workspace\haier\edl_flash\flash_edl.ps1

    # 设备已在 EDL（失败后重刷）: 加 -NoAutoEdl

| 参数 | 说明 |
|---|---|
| `-FWDir` | 固件目录，默认服务器 build 目录 UNC，本地目录亦可 |
| `-Serial` | adb 序列号，默认自动取唯一在线设备 |
| `-Com` | EDL 串口号，0 = 自动检测活动 QDLoader 9008 口（只认 Status=OK） |
| `-NoAutoEdl` / `-Xml` / `-Prog` | 跳过 reboot edl / 主 xml / programmer（默认见下） |
| `-Wake` | 仅 HELLO 死锁时用；默认**不发**（见注意事项 7） |

成功标志：输出 **FLASH_OK**，日志存 `logs\flash_时间戳.log`。

## 手动命令（本次实测逐字命令；`<FW>` = 固件目录）

    adb -s 006 reboot edl                          # 进 EDL；关机态: 音量上+音量下 同时插 USB
    # !! 先关掉 QFIL / QPST（见注意事项 1）

    # 1. Sahara 载入 firehose（必须是第一个打开 9008 口的程序）
    & 'D:\Workspace\haier\edl_flash\tools\QSaharaServer.exe' -u 13 -s 13:<FW>\xbl_s_devprg_ns.melf
    #    → Sahara protocol completed

    # 2. 主刷（146 项分区）
    & 'D:\Workspace\haier\edl_flash\tools\fh_loader.exe' --port=\\.\COM13 --sendxml=rawprogram0_split.xml --search_path=<FW> --noprompt --showpercentagecomplete --zlpawarehost=1 --memoryname=ufs

    # 3. patch0.xml（GPT userdata 大小 + 尾地址，必刷）
    & 'D:\Workspace\haier\edl_flash\tools\fh_loader.exe' --port=\\.\COM13 --sendxml=patch0.xml --search_path=<FW> --noprompt --showpercentagecomplete --zlpawarehost=1 --memoryname=ufs

    # 4. 设活动启动分区（QFIL 第 3 段同款）
    & 'D:\Workspace\haier\edl_flash\tools\fh_loader.exe' --port=\\.\COM13 --setactivepartition=1 --noprompt --showpercentagecomplete --zlpawarehost=1 --memoryname=ufs
    #    → Using scheme of value= 1

    # 5. 复位开机（QFIL 第 4 段同款）
    & 'D:\Workspace\haier\edl_flash\tools\fh_loader.exe' --port=\\.\COM13 --reset --noprompt --showpercentagecomplete --zlpawarehost=1 --memoryname=ufs
    #    → bsp_target_reset() 1

    # fh_loader 必须整行 inline 或 Start-Process 单条字符串；PowerShell splat 会拆坏 --key=value
    # QSaharaServer 的 -u 已自动拼 \\.\COM<n>，不要手写 -p 端口名

## 固件源（默认 UNC，与 QFIL 一致）

    \\192.168.110.200\tinch\haier\LA.VENDOR.13.2.6\A8550BM1_EQ000_2774.DA54D9B33.A7FD7A55B.95C9A9E8D_260914_100_V01_U100

服务器 `/data3/tinch/haier/LA.VENDOR.13.2.6/` 下的 build 输出目录（111 文件 / 4.43 GB），版本编完**无需拷贝**即可刷。

- programmer `xbl_s_devprg_ns.melf`、主 xml `rawprogram0_split.xml`（146 项）、`patch0.xml`、`gpt_*` / `super_*` / `userdata_*`
- **别照搬 FV02/SM6490 那套**：SM6490 用 `prog_firehose_ddr.elf` + `rawprogram_update_unsparse.xml`；本板 build 目录**没有** unsparse 版，只有 `rawprogram0_split` / `rawprogram0` / `rawprogram0_WIPE_PARTITIONS` / `rawprogram0_BLANK_GPT` / `rawprogram0_FFBM*`

## 刷后验证

    adb get-state                                  # device
    adb shell getprop ro.build.fingerprint         # AP 全版本号（应含 260914_100_V01_U100）
    adb shell getprop ro.vendor.build.date         # Mon Sep 14 20:50:07 CST 2026
    adb shell 'pm path android'                    # 包管理就绪

`ro.vendor.build.fingerprint` 只带 vendor 构建 ID（本次 `iro09142050`），不是版本号，不能当验收判据。实测 reset 后约 41 s adb 恢复。

## 注意事项

1. **刷机前必须关 QFIL / QPST**：QFIL 会抢开 9008 口吃掉一次性 HELLO → Sahara `read 0 bytes`，严重时口僵尸只能物理重插 USB。（实测：QFIL PID 2144 在跑，先 `Stop-Process -Name QFIL -Force` 才开刷）
2. **QSaharaServer 必须是第一个打开 9008 口的程序**：前面不要有 pyserial / .NET `SerialPort.Open`（默认拉 DTR/RTS 会复位 CDC 口）。
3. **firehose 已加载后不要再跑 Sahara**：重跑必然 `Sahara protocol error`，此时直接跑 fh_loader。
4. **串口鬼口**：残留的 `QDLoader 9008 (COMxx)` 多为 `Status=Unknown`，只认 `Status=OK` 的；脚本已过滤。
5. **`patch0.xml` 必刷**：重写 userdata 实际大小与 GPT 尾地址，漏刷 GPT 不一致。
6. **默认全刷清数据**：`rawprogram0_split.xml` 覆盖 `userdata`(10 段)、`persist`、`fsg`、`fsc`、`devinfo`、`metadata`；标定数据先备份。
7. **别用 `-Wake`**：仅已确认 HELLO 被消费的死锁才用；干净进 EDL 先发 RESET 会破坏 HELLO。
8. **UNC 源偏慢**：本次 33 次 `FILE ACCESS SLOW`、≈21 MB/s、主刷段 153 s（QFIL 同源 117 s）。要快就拷本地后 `-FWDir <本地目录>`。
9. **COM 口 / adb 序列号都会变**：EDL 口不一定还是 COM13；序列号本板为 `006` 但跨启动可能变，脚本默认自动识别。

## 文件

| 文件 | 说明 |
|---|---|
| `flash_edl.ps1` | 一键刷机脚本（日志自动存 `logs\`） |
| `tools\QSaharaServer.exe` | Sahara 加载器（QFIL/QPST 同款） |
| `tools\fh_loader.exe` | Firehose 刷写器，**必须 19.06.10.18.44**（SHA256 `DEA55EC3…C5145`）；旧 20.06 见 `fh_loader_20.06.bak` |
| `tools\sahara_spec.txt` | Sahara 协议规范（排障参考） |
| `logs\` | 刷机日志 |
