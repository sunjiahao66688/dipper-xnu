@echo off
chcp 65001 >nul
setlocal

set "SERIAL=64b8b34e"
set "PAYLOAD_DIR=D:\mi8foriios16.5\other\other"

if not exist "%PAYLOAD_DIR%\boot-dipper.img" goto missing
if not exist "%PAYLOAD_DIR%\flashboot.apfs" goto missing
if not exist "%PAYLOAD_DIR%\payload-daily.bin" goto missing

echo [1/5] RAM 启动双引导 UEFI...
fastboot -s %SERIAL% boot "%PAYLOAD_DIR%\boot-dipper.img"
if errorlevel 1 goto fail

echo [2/5] 等待 xnuloader...
timeout /t 8 /nobreak >nul
fastboot -s xnuloader getvar product
if errorlevel 1 goto fail

echo [3/5] 上传内存盘...
fastboot -s xnuloader oem ramdisk
if errorlevel 1 goto fail

echo [4/5] 上传 flashboot.apfs 与 iOS 载荷...
fastboot -s xnuloader stage "%PAYLOAD_DIR%\flashboot.apfs"
if errorlevel 1 goto fail
fastboot -s xnuloader stage "%PAYLOAD_DIR%\payload-daily.bin"
if errorlevel 1 goto fail

echo [5/5] 启动 iOS...
fastboot -s xnuloader oem run
if errorlevel 1 goto fail

echo 已下发启动命令，请在手机屏幕上确认。
goto end

:missing
echo 缺少文件，请检查 %PAYLOAD_DIR%
goto end

:fail
echo 执行失败。长按电源 10 秒重启即可回到 MIUI。
goto end

:end
endlocal
pause
