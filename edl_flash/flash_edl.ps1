# ============================================================
# A8550BM1_EQ000_2774 (SM8550 / kalama, Android 13 + Aidlux) EDL 命令行刷机脚本
#
# 用法:
#   pwsh -NoProfile -File .\flash_edl.ps1                 # 自动 reboot edl + 全刷(默认 rawprogram0_split.xml)
#   pwsh -NoProfile -File .\flash_edl.ps1 -NoAutoEdl      # 设备已在 EDL 时跳过 adb reboot edl
#   pwsh -NoProfile -File .\flash_edl.ps1 -FWDir <dir>    # 指定固件目录(本地或 UNC)
#   pwsh -NoProfile -File .\flash_edl.ps1 -Serial <sn>    # 指定 adb 序列号(默认自动取唯一在线设备)
#   pwsh -NoProfile -File .\flash_edl.ps1 -Xml <name>     # 指定主 rawprogram xml
#   pwsh -NoProfile -File .\flash_edl.ps1 -Prog <name>    # 指定 firehose programmer(默认 xbl_s_devprg_ns.melf)
#
# 流程: 固件检查 -> (自动进EDL) -> 找活动 9008 口 ->
#       step1 QSaharaServer 载 firehose (ID 13)  [QSaharaServer 必须是第一个开口的程序] ->
#       step2 fh_loader 主xml -> step3 fh_loader patch0.xml ->
#       step4 fh_loader setactivepartition=1 -> step5 fh_loader reset ->
#       step6 等 adb 恢复并校验 fingerprint
#
# 依据: D:\Workspace\haier\134339284680525613.log (QFIL 2026-09-15 14:43-14:47 成功日志)
#       该日志实测: programmer=xbl_s_devprg_ns.melf, 主xml=rawprogram0_split.xml,
#       patch0.xml, setactivepartition=1, reset; --memoryname=ufs;
#       固件源=服务器 build 目录(UNC), COM13
# 教训: QSaharaServer 之前不得有任何程序先打开 9008 口(尤其 .NET SerialPort 拉 DTR/RTS),
#       否则目标一次性 HELLO 丢失 -> "read 0 bytes", 口变僵尸只能物理重插 USB。
#       (-Wake 仅用于已确认 HELLO 死锁的场合)
# ============================================================
param(
  [string]$FWDir = '\\192.168.110.200\tinch\haier\LA.VENDOR.13.2.6\A8550BM1_EQ000_2774.DA54D9B33.A7FD7A55B.95C9A9E8D_260914_100_V01_U100',
  [int]$Com = 0,
  [string]$Serial = '',
  [switch]$NoAutoEdl,
  [switch]$Wake,
  [string]$Xml = 'rawprogram0_split.xml',
  [string]$Prog = 'xbl_s_devprg_ns.melf'
)
$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path $Here 'logs'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$log = Join-Path $LogDir ('flash_' + (Get-Date -Format yyyyMMdd_HHmmss) + '.log')
function Say($m) { $l = ('[' + (Get-Date -Format HH:mm:ss) + '] ' + $m); Write-Host $l; Add-Content $log $l }

# 活动 9008 口: 只认 Status=OK 的 (历史遗留的鬼口 Status=Unknown 会被忽略)
function FindEdlPort() {
  $c = @(Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match 'QDLoader 9008 \(COM\d+\)' -and $_.Status -eq 'OK' } |
    ForEach-Object { [int]([regex]::Match($_.Name, '\(COM(\d+)\)').Groups[1].Value) })
  if ($c.Count -gt 0) { return $c[0] }
  $c2 = @(Get-PnpDevice -PresentOnly -Class Ports -ErrorAction SilentlyContinue |
    Where-Object { $_.FriendlyName -match 'QDLoader 9008 \(COM\d+\)' } |
    ForEach-Object { [int]([regex]::Match($_.FriendlyName, '\(COM(\d+)\)').Groups[1].Value) })
  if ($c2.Count -gt 0) { return $c2[0] }
  return $null
}
# 自动取唯一在线 adb 设备序列号
function FindAdbSerial() {
  $out = (adb devices 2>&1 | Out-String)
  $m = [regex]::Matches($out, '(?m)^([0-9A-Za-z_\-\.]+)\s+device\s*$')
  if ($m.Count -ge 1) { return $m[0].Groups[1].Value }
  return $null
}

if (-not (Test-Path (Join-Path $FWDir $Xml))) { Say ('FAIL: 固件目录不可访问或缺少 ' + $Xml + ' -> ' + $FWDir); exit 1 }
Say ('EDL flash | FWDir=' + $FWDir + ' | xml=' + $Xml + ' | prog=' + $Prog + ' | serial=' + ($(if ($Serial) { $Serial } else { 'auto' })))
# --- 固件完整性检查
$needed = @($Prog, $Xml, 'patch0.xml', 'xbl_config.elf', 'boot.img', 'vendor_boot.img', 'dtbo.img', 'super_1.img', 'userdata_1.img', 'gpt_main0.bin')
foreach ($f in $needed) {
  if (-not (Test-Path (Join-Path $FWDir $f))) { Say ('FAIL: missing fw file ' + $f); exit 1 }
}
Say 'fw files complete'
# --- 进 EDL / 找口
$com = $null
if ($Com -gt 0) { $com = $Com }
if (-not $NoAutoEdl -and -not $com) {
  adb start-server 2>&1 | Out-Null
  if (-not $Serial) { $Serial = FindAdbSerial }
  if (-not $Serial) { Say 'FAIL: 无在线 adb 设备, 无法 reboot edl; 请确认 USB 连接或用 -Serial 指定'; exit 1 }
  $st = adb -s $Serial get-state 2>$null
  if ($st -ne 'device') { Say ('FAIL: adb ' + $Serial + ' 不在线 (state=' + $st + ')'); exit 1 }
  Say ('AutoEDL: adb -s ' + $Serial + ' reboot edl')
  adb -s $Serial reboot edl 2>&1 | Out-Null
  Say '等待 9008 口出现 (最多90s)'
  $deadline = (Get-Date).AddSeconds(90)
  while (-not $com -and (Get-Date) -lt $deadline) { $com = FindEdlPort; if (-not $com) { Start-Sleep -Seconds 2 } }
}
if (-not $com) {
  $deadline = (Get-Date).AddSeconds(30)
  while (-not $com -and (Get-Date) -lt $deadline) { $com = FindEdlPort; if (-not $com) { Start-Sleep -Seconds 2 } }
}
if (-not $com) {
  Say 'FAIL: 未检测到活动 QDLoader 9008 口。设备在线时 adb reboot edl; 关机态按住 音量上+音量下 插 USB; 或 -Com 指定(Status=Unknown 的鬼口不可用)'
  exit 1
}
$port = '\\.\COM' + $com
Say ('EDL port: COM' + $com + ' (' + $port + ')')
# --- step0 (仅 -Wake): 默认不发任何唤醒字节, QSaharaServer 是第一个开口者
if ($Wake) {
  Say 'step0: -Wake, send Sahara RESET (0x07), DTR/RTS held low'
  try {
    $wk = New-Object System.IO.Ports.SerialPort -ArgumentList ('COM' + $com), 115200, 'None', 8, 'One'
    $wk.ReadTimeout = 500
    $wk.DtrEnable = $false
    $wk.RtsEnable = $false
    $wk.Open()
    $wk.Write([byte[]]@(0x07,0,0,0,0x08,0,0,0), 0, 8)
    Start-Sleep -Milliseconds 500
    $wk.Close()
    Say 'RESET sent, port closed'
  } catch { Say ('FAIL: wake failed: ' + $_.Exception.Message); exit 1 }
} else {
  Say 'step0: skipped (QSaharaServer opens port first)'
}
# --- step1: 加载 firehose (Sahara ID 13)
Say ('step1: QSaharaServer load firehose (ID 13, ' + $Prog + ')')
$sahara = Join-Path $Here 'tools\QSaharaServer.exe'
$prog = Join-Path $FWDir $Prog
$sout = (& $sahara -u $com -s ('13:' + $prog) 2>&1 | Out-String)
$sout | Add-Content $log
if ($LASTEXITCODE -ne 0) {
  $hint = if ($sout -match 'read 0 bytes') { ' | 未收到 HELLO: 目标可能已僵尸/死锁 -> 物理重插 USB 重新进 EDL 后用 -NoAutoEdl 重试' } elseif ($sout -match 'Failed to open com port') { ' | 9008 口打不开(僵尸态): 物理重插 USB 重新枚举' } else { '' }
  Say ('FAIL: sahara RC=' + $LASTEXITCODE + $hint); exit 1
}
if (-not ($sout -match 'Sahara protocol completed')) { Say 'FAIL: no "Sahara protocol completed"'; exit 1 }
Say 'step1 done'
# --- step2-5: fh_loader 四段 (与 QFIL 日志完全一致)
$fh = Join-Path $Here 'tools\fh_loader.exe'
function RunFh($desc, $expectReset, $argStr) {
  Say ('step ' + $desc + ': fh_loader ' + $argStr)
  $tmpOut = Join-Path $env:TEMP ('fh_out_' + [guid]::NewGuid().ToString('N') + '.txt')
  $tmpErr = Join-Path $env:TEMP ('fh_err_' + [guid]::NewGuid().ToString('N') + '.txt')
  $p = Start-Process -FilePath $fh -ArgumentList $argStr -NoNewWindow -Wait -PassThru -RedirectStandardOutput $tmpOut -RedirectStandardError $tmpErr
  $out = ((Get-Content $tmpOut -Raw -ErrorAction SilentlyContinue) + "`n" + (Get-Content $tmpErr -Raw -ErrorAction SilentlyContinue))
  Remove-Item $tmpOut, $tmpErr -ErrorAction SilentlyContinue
  $out | Add-Content $log
  if ($p.ExitCode -ne 0) { Say ('FAIL: fh_loader RC=' + $p.ExitCode); exit 1 }
  if ($expectReset) {
    if (-not ($out -match 'bsp_target_reset')) { Say 'FAIL: no bsp_target_reset marker'; exit 2 }
  } elseif (-not ($out -match 'All Finished Successfully')) {
    Say 'FAIL: no "All Finished Successfully"'; exit 1
  }
  Say ($desc + ' done')
}
$base = ' --noprompt --showpercentagecomplete --zlpawarehost=1 --memoryname=ufs'
RunFh ('main xml (' + $Xml + ')') $false ('--port=' + $port + ' --sendxml=' + $Xml + ' --search_path=' + $FWDir + $base)
RunFh 'patch0.xml' $false ('--port=' + $port + ' --sendxml=patch0.xml --search_path=' + $FWDir + $base)
RunFh 'setactivepartition=1' $false ('--port=' + $port + ' --setactivepartition=1' + $base)
RunFh 'reset' $true ('--port=' + $port + ' --reset' + $base)
# --- step6: 等设备重启, adb 恢复
Say 'step6: wait reboot, adb back (up to 5min)'
adb start-server 2>&1 | Out-Null
$back = $null
for ($i = 0; $i -lt 60; $i++) {
  Start-Sleep -Seconds 5
  if ($Serial) { $st = adb -s $Serial get-state 2>$null; if ($st -eq 'device') { $back = $Serial; break } }
  else { $s2 = FindAdbSerial; if ($s2) { $back = $s2; break } }
}
if (-not $back) { Say 'WARN: adb 5分钟内未恢复, 再等2-3分钟(首开初始化慢)或重进 EDL 查日志'; exit 3 }
$fp = adb -s $back shell getprop ro.vendor.build.fingerprint 2>$null
$bd = adb -s $back shell getprop ro.vendor.build.date 2>$null
$bt = adb -s $back shell getprop ro.build.type 2>$null
Say ('device back: ' + $back)
Say ('fingerprint: ' + $fp)
Say ('vendor build date: ' + $bd)
Say ('build type: ' + $bt)
Say ('log: ' + $log)
Say 'FLASH_OK'
