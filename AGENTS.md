你是一名顶尖的 Android 系统底层（AOSP/HAL/Framework）与 Linux 内核/驱动开发专家。

证据驱动：必须以实际日志、代码、调用栈和错误码分析问题，优先将日志保存至本地工作目录再分析。
最小修改：仅做局部可控的修改，严禁无关重构，代码注释精简准确，不破坏现有功能，没有语法错误。

# Project Context: Qualcomm SM8550 (Kalama) Android 13 Kernel 5.15

本项目是高通 **SM8550 (Kalama)** 平台 Android 13 系统，主要客户为星炽动力机器人（Sflare-H1-Home）。Android/Aidlux 融合系统，即在 Android 系统上启动 Aidlux (Ubuntu) 系统。

---

## 源码目录

- **登录服务器**: `ssh iro@192.168.110.200`
- **源码根目录**: `cd /data3/tinch/haier`

| 目录 | 说明 |
|------|------|
| `LA.QSSI.13.0` | Android 上层系统源码、framework、app 等 |
| `LA.VENDOR.13.2.6` | 内核源码、高通驱动、三方厂商驱动等 |

---

## 编译方法

### 手动编译步骤

```bash
# 1. 清理历史编译（两个目录都要清）
cd /data3/tinch/haier/LA.QSSI.13.0
git clean -dxf . && git checkout .

cd /data3/tinch/haier/LA.VENDOR.13.2.6
git clean -dxf . && git checkout .

cd /data3/tinch/haier

# 2. 进入编译容器
android u22

# 3. 执行编译（容器内）
cd /home/build/LA.VENDOR.13.2.6
./MC940_A13_build.sh user kalama 100
```

### 编译参数说明

| 参数位置 | 选项 | 说明 |
|---------|------|------|
| 第1参数 (BUILD_TYPE) | `userdebug` | 开发调试版 |
| | `user` | 正式发布版 |
| 第2参数 (MDBRANCH) | `kalama` | 固定值，平台名 |
| 第3参数 (VERSION_NUM) | `100` (示例) | 版本号，对应 TEMP_AP_VERSION |

开发调试阶段优先编译 **userdebug** 版本，完整编译约 **2小时+**。

---

### Agent编译步骤

```bash
# 1. 清理历史编译
# LA.QSSI.13.0
ssh iro@192.168.110.200 "cd /data3/tinch/haier/LA.QSSI.13.0 && git clean -dxf . && git checkout . && echo CLEAN_DONE"
# LA.VENDOR.13.2.6
ssh iro@192.168.110.200 "cd /data3/tinch/haier/LA.VENDOR.13.2.6 && git clean -dxf . && git checkout . && echo CLEAN_DONE"

# 2. 创建容器
ssh iro@192.168.110.200 "docker rm -f haier_build 2>/dev/null; docker run -d --privileged --name haier_build -v /data3/tinch/haier:/home/build -v /home/iro/.ssh:/home/iro/.ssh iro/androidbuilder:u22 sleep infinity; docker exec haier_build ls /home/build/ && echo MOUNT_OK"

# 3. 执行编译
ssh iro@192.168.110.200 'docker exec -t haier_build su -l iro -c "cd /home/build/LA.VENDOR.13.2.6 && ./MC940_A13_build.sh user kalama 116 > build.log 2>&1"; echo BUILD_EXIT=$?'

# 4. 清理容器
ssh iro@192.168.110.200 "docker rm -f haier_build 2>/dev/null && echo CLEAN_DONE"
```

## Aidlux 系统调试方法

```bash
# 开启 Aidlux 调试模式（可执行 su 权限）
adb shell setprop aidlux.test true

# 验证：进入 Aidlux 容器内执行 root 命令
adb shell su root ls /data/

# Aidlux 调试命令
adb shell su root aid exec aidluxd lsusb
```