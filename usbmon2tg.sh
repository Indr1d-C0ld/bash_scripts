#!/bin/bash

# Configurazione
TOKEN="8010444488:AAF1T4CAtY1At2QFiPz3m5A9b7tvnfTX2B4"
CHAT_ID="273068741"
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

# Carico di sistema (load average)
LOAD=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ //')

# IP locali e WAN
LOCAL_IP=$(hostname -I | awk '{print $1}')
WAN_IP=$(curl -s ifconfig.me)

# Stato dei servizi personalizzati
SERVICES_LIST=("auto_seed.service" "irc_bot.service" "bbs_server.service" "monitor_transmission.service" "pihole-FTL.service" "fbquery_bot.service" "transmission-daemon.service" "usbmon2tg.service" "weechat.service" "hugo2tg.service")
SERVICE_STATUS=""
for SERVICE in "${SERVICES_LIST[@]}"; do
    STATUS=$(systemctl is-active "$SERVICE")
    if [ "$STATUS" = "active" ]; then
        ICON="✅"
    else
        ICON="❌"
    fi
    SERVICE_STATUS+="$ICON $SERVICE%0A"
done

# Composizione del messaggio con HTML (usa %0A per nuove linee)
MESSAGE="🔍 <b>Stato Raspberry Pi</b>%0A%0A"
MESSAGE+="$USB_STATUS%0A"
MESSAGE+="$DISK_USAGE%0A"
MESSAGE+="$MMC_USAGE%0A"
MESSAGE+="⏳ Uptime: $UPTIME%0A"
MESSAGE+="🌡 CPU Temp: $CPU_TEMP%0A"
MESSAGE+="📶 IP Locale: $LOCAL_IP%0A"
MESSAGE+="🌐 IP WAN: $WAN_IP%0A"
MESSAGE+="⚙️ Load: $LOAD%0A%0A"
MESSAGE+="<b>Stato Servizi</b>%0A"
MESSAGE+="$SERVICE_STATUS"

# Invio a Telegram
URL="https://api.telegram.org/bot$TOKEN/sendMessage"
curl -s -X POST "$URL" -d chat_id="$CHAT_ID" -d text="$MESSAGE" -d parse_mode="HTML"
