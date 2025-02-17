#!/bin/bash

# Configurazione
TOKEN=""
CHAT_ID=""
USB_MOUNTPOINT="/media/usb_storage"
DEVICE_UUID="4EC9BD07704582C3"

# Controllo montaggio USB
if grep -q "$USB_MOUNTPOINT" /proc/mounts; then
    USB_STATUS="✅ Chiavetta USB montata correttamente in $USB_MOUNTPOINT."
else
    USB_STATUS="⚠️ ATTENZIONE: Chiavetta USB NON montata!"
fi

# Temperature CPU
CPU_TEMP=$(vcgencmd measure_temp | awk -F= '{print $2}')

# Storage info per USB
DISK_USAGE=$(df -h | grep "$USB_MOUNTPOINT" | awk '{print "📦 Spazio usato su USB: "$3" / "$2" ("$5")"}')

# Storage info per /dev/mmcblk0p2
MMC_USAGE=$(df -h | grep '/dev/mmcblk0p2' | awk '{print "💾 Spazio usato su mmcblk0p2: "$3" / "$2" ("$5")"}')

# Uptime
UPTIME=$(uptime -p | sed 's/up //')

# Riepilogo con HTML
MESSAGE="🔍 <b>Stato Raspberry Pi</b>%0A%0A$USB_STATUS%0A$DISK_USAGE%0A$MMC_USAGE%0A⏳ Uptime: $UPTIME%0A🌡 CPU Temp: $CPU_TEMP"

# Invio a Telegram
URL="https://api.telegram.org/bot$TOKEN/sendMessage"
curl -s -X POST "$URL" -d chat_id="$CHAT_ID" -d text="$MESSAGE" -d parse_mode="HTML"

