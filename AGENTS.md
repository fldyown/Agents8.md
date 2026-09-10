Android 系统与 Linux 内核专家。
先收集保存日志到本地，再定位根因。
代码只做最小必要修改，禁止无关重构，保持功能兼容；注释精简，检查语法与编译风险。

---

# Project Context: Qualcomm SM8550 (Kalama) Android 13 Kernel 5.15

本项目是高通 SM8550 (Kalama) 平台 Android 13 系统，主要客户为星炽动力机器人（Sflare-H1-Home）。Android/Aidlux 融合系统，即在 Android 系统上启动 Aidlux (Ubuntu) 系统。


## 源码目录

```bash
# 登录服务器
ssh iro@192.168.110.200
# 源码根目录
cd /data3/tinch/haier
```

| 目录 | 说明 |
|------|------|
| `LA.QSSI.13.0` | Android 上层系统源码、framework、app 等 |
| `LA.VENDOR.13.2.6` | 内核源码、高通驱动、三方厂商驱动等 |


## 编译方法

### Agent编译步骤

```bash
# 1. 清理历史编译
# LA.QSSI.13.0
ssh iro@192.168.110.200 "cd /data3/tinch/haier/LA.QSSI.13.0 && git clean -dxf . && git checkout . && echo CLEAN_DONE"
# LA.VENDOR.13.2.6
ssh iro@192.168.110.200 "cd /data3/tinch/haier/LA.VENDOR.13.2.6 && git clean -dxf . && git checkout . && echo CLEAN_DONE"

# 2. 创建容器
ssh iro@192.168.110.200 "docker rm -f haier_build 2>/dev/null; docker run -d --privileged --name haier_build -v /data3/tinch/haier:/home/build -v /home/iro/.ssh:/home/iro/.ssh iro/androidbuilder:u22 sleep infinity; docker exec haier_build ls /home/build/ && echo MOUNT_OK"

# 3. 执行编译(user版本：user debug版本：userdebug 固定参数：kalama 版本号：116)
ssh iro@192.168.110.200 'docker exec -t haier_build su -l iro -c "cd /home/build/LA.VENDOR.13.2.6 && ./MC940_A13_build.sh user kalama 116 > build.log 2>&1"; echo BUILD_EXIT=$?'

# 4. 清理容器
ssh iro@192.168.110.200 "docker rm -f haier_build 2>/dev/null && echo CLEAN_DONE"
```


## Aidlux 系统调试方法

```bash
# 开启 Aidlux 调试模式（可执行 su 权限）
adb shell setprop aidlux.test true
# Aidlux 调试命令
adb shell su root aid exec aidluxd lsusb
adb shell su root aid exec aidluxd python
```


### 日志文件（优先拉取到本地分析）

```bash
# 先开启调试再抓日志
adb shell setprop aidlux.test true
# 查看都有那些日志文件 kern.log*、dmesg*等日志比较有用
adb shell su root ls /data/data/com.aidlux/files/home/debian-fs/var/log
# boot*.log 主要包含最近三次开机日志，序号自增
/sdcard/boot*.log
```