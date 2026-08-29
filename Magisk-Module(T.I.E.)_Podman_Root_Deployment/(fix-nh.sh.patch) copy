#!/data/data/com.termux/files/usr/bin/bash
# Patch NH-Terminal's launcher to a stable Magisk+chroot shim
# Run from Termux or adb shell after a cold start if needed.

TARGET="/data/data/com.offsec.nhterm/files/usr/bin/kali"

cat > "$TARGET" <<'EOF'
#!/system/bin/sh
if [ -x /debug_ramdisk/magisk ]; then
  MAGISK=/debug_ramdisk/magisk
elif [ -x /sbin/magisk ]; then
  MAGISK=/sbin/magisk
else
  MAGISK="$(magisk --path 2>/dev/null)/magisk"
fi
[ -x "$MAGISK" ] || { echo "[nh] magisk CLI not found"; exit 127; }
KALIFS="/data/local/nhsystem/kalifs"
[ -d "$KALIFS" ] || { echo "[nh] missing $KALIFS"; exit 1; }
exec "$MAGISK" su --mount-master -c "/system/bin/chroot $KALIFS /bin/bash -l"
EOF

chmod 755 "$TARGET"
# normalize CRLF if any
sed -i 's/\r$//' "$TARGET" 2>/dev/null || true
echo "[*] Patched $TARGET"
