@echo off
title Windows 10 22H2 - Dell E6540 HDD 極限性能優化
color 0A

echo ================================
echo 停止並禁用 SysMain（HDD 最大卡頓源）
echo ================================
sc stop "SysMain"
sc config "SysMain" start= disabled

echo ================================
echo 停止並禁用 Windows Search（索引）
echo ================================
sc stop "WSearch"
sc config "WSearch" start= disabled

echo ================================
echo 停止並禁用 Windows Update（保留手動）
echo ================================
sc stop "wuauserv"
sc config "wuauserv" start= demand

echo ================================
echo 停止 Delivery Optimization
echo ================================
sc stop "DoSvc"
sc config "DoSvc" start= disabled

echo ================================
echo 停止所有 Xbox 服務
echo ================================
for %%x in (
XblAuthManager
XblGameSave
XboxNetApiSvc
XboxGipSvc
) do (
sc stop "%%x"
sc config "%%x" start= disabled
)

echo ================================
echo 停止遙測與診斷
echo ================================
for %%x in (
DiagTrack
dmwappushservice
diagnosticshub.standardcollector.service
) do (
sc stop "%%x"
sc config "%%x" start= disabled
)

echo ================================
echo 停止無用 UWP 推送服務
echo ================================
for %%x in (
WpnService
WpnUserService
) do (
sc stop "%%x"
sc config "%%x" start= disabled
)

echo ================================
echo 禁用 OneDrive
echo ================================
taskkill /f /im OneDrive.exe
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v OneDrive /t REG_SZ /d "" /f

echo ================================
echo 禁用 Cortana
echo ================================
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCortana /t REG_DWORD /d 0 /f

echo ================================
echo 禁用後台應用
echo ================================
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /t REG_DWORD /d 1 /f

echo ================================
echo 禁用驅動自動更新
echo ================================
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching" /v SearchOrderConfig /t REG_DWORD /d 0 /f

echo ================================
echo 禁用 Windows Spotlight / 推薦 / 廣告
echo ================================
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v RotatingLockScreenEnabled /t REG_DWORD /d 0 /f
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 0 /f

echo ================================
echo 禁用 Edge 後台任務
echo ================================
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v BackgroundModeEnabled /t REG_DWORD /d 0 /f

echo ================================
echo 啟用內存壓縮（HDD 必備）
echo ================================
powershell -command "Enable-MMAgent -MemoryCompression"

echo ================================
echo 設置高性能電源
echo ================================
powercfg -setactive SCHEME_MIN

echo ================================
echo 清理臨時文件
echo ================================
del /s /q %temp%\*
del /s /q C:\Windows\Temp\*

echo ================================
echo 啟用 HDD 自動碎片整理（每週）
echo ================================
schtasks /Change /TN "\Microsoft\Windows\Defrag\ScheduledDefrag" /ENABLE

echo ================================
echo 極限優化完成！建議立即重啟
echo ================================
pause
exit
