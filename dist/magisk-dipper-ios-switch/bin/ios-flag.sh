#!/system/bin/sh
# One-shot dual-boot flag in darwin's unused blocks (see xnuloader/loader.c).
#   ios-flag.sh status    show whether flashboot is provisioned and the flag state
#   ios-flag.sh on        request iOS on the next boot, then reboot
#   ios-flag.sh off       clear the request
#   ios-flag.sh provision /path/to/flashboot.apfs
set -u

DARWIN=${DARWIN:-/dev/block/by-name/darwin}
[ -e "$DARWIN" ] || DARWIN=$(readlink -f /dev/block/by-name/darwin 2>/dev/null)
FLAG_LBA=5000000
FB_LBA=5001024
BLOCK=4096

die() { echo "$*" >&2; exit 1; }

[ -n "${DARWIN:-}" ] && [ -e "$DARWIN" ] || die "找不到 darwin 分区"

read_flag() {
    dd if="$DARWIN" bs=$BLOCK skip=$FLAG_LBA count=1 2>/dev/null
}

magic_ok() {
    local m
    m=$(read_flag | dd bs=1 count=4 2>/dev/null | od -An -tx1 | tr -d ' \n')
    [ "$m" = "584e4631" ]
}

fb_size() {
    read_flag | dd bs=1 skip=8 count=4 2>/dev/null | od -An -tu4 | tr -d ' '
}

case "${1:-status}" in
status)
    if magic_ok; then
        echo "标志块: 已部署"
        echo "flashboot: $(fb_size) 字节"
        st=$(read_flag | dd bs=1 skip=4 count=4 2>/dev/null | od -An -tu4 | tr -d ' ')
        [ "${st:-0}" = "1" ] && echo "下次启动: iOS（一次性）" || echo "下次启动: Android"
    else
        echo "标志块: 未部署"
        echo "先运行: ios-flag.sh provision /sdcard/flashboot.apfs"
    fi
    ;;
on)
    magic_ok || die "标志块未部署，先运行 provision"
    printf '\001\000\000\000' | dd of="$DARWIN" bs=1 seek=$((FLAG_LBA * BLOCK + 4)) conv=notrunc 2>/dev/null || die "写标志失败"
    sync
    echo "已请求 iOS，即将重启"
    ;;
off)
    [ "$(read_flag | dd bs=1 count=4 2>/dev/null | od -An -tx1 | tr -d ' \n')" = "584e4631" ] || die "标志块未部署"
    printf '\000\000\000\000' | dd of="$DARWIN" bs=1 seek=$((FLAG_LBA * BLOCK + 4)) conv=notrunc 2>/dev/null || die "写标志失败"
    sync
    echo "已清除请求，下次启动 Android"
    ;;
provision)
    img=${2:-}
    [ -n "$img" ] && [ -f "$img" ] || die "用法: ios-flag.sh provision /path/to/flashboot.apfs"
    size=$(stat -c %s "$img")
    [ $((size % BLOCK)) -eq 0 ] || die "flashboot.apfs 大小不是 4096 的倍数"
    [ $((size / BLOCK)) -le 1024 ] || die "flashboot.apfs 超过 4 MiB"
    magic=$(dd if="$img" bs=1 skip=32 count=4 2>/dev/null)
    [ "$magic" = "NXSB" ] || die "不是 APFS 镜像（偏移 32 应为 NXSB）"
    echo "写入镜像 ($size 字节)..."
    dd if="$img" of="$DARWIN" bs=$BLOCK seek=$FB_LBA conv=notrunc 2>/dev/null || die "写镜像失败"
    echo "写入标志块..."
    esc=$(printf '\\%03o\\%03o\\%03o\\%03o' \
        $((size & 255)) $(((size >> 8) & 255)) $(((size >> 16) & 255)) $(((size >> 24) & 255)))
    { printf '\130\116\106\061'; printf '\000\000\000\000'; printf '%b' "$esc"
      head -c $((BLOCK - 12)) /dev/zero
    } | dd of="$DARWIN" bs=$BLOCK seek=$FLAG_LBA conv=notrunc 2>/dev/null || die "写标志块失败"
    sync
    echo "完成。现在可运行: ios-flag.sh on"
    ;;
*)
    die "用法: ios-flag.sh status|on|off|provision <flashboot.apfs>"
    ;;
esac
