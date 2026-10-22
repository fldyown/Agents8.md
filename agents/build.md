# 编译方法（SM8550 / Kalama）

服务器：`iro@192.168.110.200`  
源码：`/data3/tinch/haier`  
脚本：本地 `agents/agent_build.sh`，服务器 `/data3/tinch/haier/agent_build.sh`

## 同步并执行

```bash
# 更新服务器脚本
scp agents/agent_build.sh iro@192.168.110.200:/data3/tinch/haier/agent_build.sh

# 清理缓存历史编译
# LA.QSSI.13.0
ssh iro@192.168.110.200 "cd /data3/tinch/haier/LA.QSSI.13.0 && git clean -dxf . && git checkout . && echo CLEAN_DONE"
# LA.VENDOR.13.2.6
ssh iro@192.168.110.200 "cd /data3/tinch/haier/LA.VENDOR.13.2.6 && git clean -dxf . && git checkout . && echo CLEAN_DONE"

# 编译 user，122 为 AP 版本号，按需替换
ssh iro@192.168.110.200 'bash /data3/tinch/haier/agent_build.sh user 122'

# 编译 userdebug
ssh iro@192.168.110.200 'bash /data3/tinch/haier/agent_build.sh userdebug 122'

# 强制停止当前编译并重新开始
ssh iro@192.168.110.200 'FORCE=1 bash /data3/tinch/haier/agent_build.sh user 122'
```

说明：脚本固定使用 `kalama`，完整执行 QSSI、内核、vendor、super、OTA 和 ZIP 打包。检测到 `haier_build` 容器正在运行 `MC940_A13_build.sh` 会返回 `3`；`FORCE=1` 会停止该编译并重新开始。容器 `haier_build` 退出时自动删除；日志为 `LA.VENDOR.13.2.6/build.log` 和 `vendor/vendorcode/build/build_log/*.txt`；固件 ZIP 在 `LA.VENDOR.13.2.6/*.zip`；脚本不自动执行 `git clean`。耗时较长，Agent 建议用 `nohup` 或 `tmux` 后台运行并轮询日志。