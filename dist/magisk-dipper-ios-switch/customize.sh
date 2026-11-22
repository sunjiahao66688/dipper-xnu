#!/system/bin/sh
set_perm_recursive "$MODPATH/bin" 0 0 0755 0755
set_perm "$MODPATH/action.sh" 0 0 0755
ui_print "- Dipper iOS 启动开关已安装"
ui_print "- 首次使用：在 Termux/root shell 运行"
ui_print "  sh $MODPATH/bin/ios-flag.sh provision /sdcard/flashboot.apfs"
ui_print "- 之后点模块「操作」按钮即可重启进 iOS"
