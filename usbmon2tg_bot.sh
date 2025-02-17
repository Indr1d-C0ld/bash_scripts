#!/bin/bash

TOKEN=""
CHAT_ID=""
LAST_UPDATE_FILE="/home/pi/usbmon2tg/last_update_id.txt"

while true; do
    # Recupera ultimi messaggi
    UPDATE=$(curl -s "https://api.telegram.org/bot$TOKEN/getUpdates")

    # Estrai l'ultimo update_id
    LAST_UPDATE_ID=$(echo "$UPDATE" | jq '.result[-1].update_id')

    # Se il messaggio è nuovo, processalo
    if [[ "$LAST_UPDATE_ID" != "$(cat $LAST_UPDATE_FILE 2>/dev/null)" ]]; then
        echo "$LAST_UPDATE_ID" > "$LAST_UPDATE_FILE"
        
        # Controlla se il messaggio è il comando /status
        MESSAGE=$(echo "$UPDATE" | jq -r '.result[-1].message.text')
        SENDER_ID=$(echo "$UPDATE" | jq -r '.result[-1].message.chat.id')

        if [[ "$MESSAGE" == "/status" ]]; then
            bash /home/pi/usbmon2tg/usbmon2tg.sh
        fi
    fi
    
    sleep 5
done

