#!/bin/bash

# File di log per la diagnostica
LOG_FILE="/home/randolph/Documenti/conky_log.txt"

# Array degli indirizzi IP e relativi file di configurazione di Conky
MACHINES=(
    "192.168.178.30:/home/randolph/.config/conky/adsb.conf"
    "192.168.178.32:/home/randolph/.config/conky/serverpi.conf"
    "192.168.178.59:/home/randolph/.config/conky/hp_mini.conf"
)

# Stato attuale delle macchine
declare -A MACHINE_STATUS

# Funzione per aggiungere messaggi al file di log
log_message() {
    echo "$(date): $1" >> "$LOG_FILE"
}

# Inizia il log
log_message "Script avviato"

# Verifica se la rete è pronta
while ! ping -c 1 -W 1 8.8.8.8 &> /dev/null; do
    log_message "In attesa della connessione di rete..."
    sleep 5
done

log_message "Rete pronta. Avvio il monitoraggio delle macchine."

# Primo controllo completo
for MACHINE in "${MACHINES[@]}"; do
    REMOTE_IP=$(echo "$MACHINE" | cut -d':' -f1)
    CONKY_CONFIG=$(echo "$MACHINE" | cut -d':' -f2)

    if ping -c 1 -W 1 "$REMOTE_IP" &> /dev/null; then
        log_message "Il sistema remoto $REMOTE_IP è online. Avvio Conky con il file di configurazione $CONKY_CONFIG."
        conky -c "$CONKY_CONFIG" --daemonize --pause=1 &
        MACHINE_STATUS["$REMOTE_IP"]="online"
    else
        MACHINE_STATUS["$REMOTE_IP"]="offline"
    fi
done

# Ciclo principale
while true; do
    for MACHINE in "${MACHINES[@]}"; do
        REMOTE_IP=$(echo "$MACHINE" | cut -d':' -f1)
        CONKY_CONFIG=$(echo "$MACHINE" | cut -d':' -f2)

        # Verifica lo stato attuale
        if ping -c 1 -W 1 "$REMOTE_IP" &> /dev/null; then
            if [[ "${MACHINE_STATUS["$REMOTE_IP"]}" != "online" ]]; then
                log_message "Il sistema remoto $REMOTE_IP è tornato online. Avvio Conky con il file di configurazione $CONKY_CONFIG."
                conky -c "$CONKY_CONFIG" --daemonize --pause=1 &
                MACHINE_STATUS["$REMOTE_IP"]="online"
            fi
        else
            if [[ "${MACHINE_STATUS["$REMOTE_IP"]}" != "offline" ]]; then
                log_message "Il sistema remoto $REMOTE_IP è offline. Chiudo Conky associato a $CONKY_CONFIG."
                pkill -f "conky.*$CONKY_CONFIG"
                MACHINE_STATUS["$REMOTE_IP"]="offline"
            fi
        fi
    done

    # Attendi 10 secondi prima di controllare di nuovo
    sleep 10
done
