#!/system/bin/sh
MODDIR=${0%/*}
"$MODDIR/bin/ios-flag.sh" on || exit 1
sync
sleep 2
reboot
