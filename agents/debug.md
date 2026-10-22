# Aidlux 调试与日志拉取
> 内容：Aidlux 调试命令、设备日志文件位置（优先拉取到本地分析）。

## Aidlux 系统调试方法

```bash
# 调试/拉取日志前开启调试模式
adb shell setprop aidlux.test true
# Aidlux 调试命令
adb shell su root aid exec aidluxd lsusb
adb shell su root aid exec aidluxd python
```


### 日志文件（优先拉取到本地分析）

```bash
# 调试/拉取日志前开启调试模式
adb shell setprop aidlux.test true
# 查看都有那些日志文件 kern.log*、dmesg*等日志比较有用
adb shell su root ls /data/data/com.aidlux/files/home/debian-fs/var/log
# boot*.log 主要包含最近三次开机日志，序号自增
/sdcard/boot*.log
```
