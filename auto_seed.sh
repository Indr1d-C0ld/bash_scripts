#!/bin/bash

# Configurazione
WATCH_DIR="/path/to/torrents"  # Directory da monitorare
TORRENT_OUTPUT_DIR="/path/to/torrents_created"  # Dove salvare i .torrent
TRACKER_FILE="/path/to/trackers.txt"  # File contenente i tracker
TRANSMISSION_HOST="localhost"  # Host di Transmission
TRANSMISSION_PORT="9091"       # Porta di Transmission
USERNAME="user"                # Username di Transmission (se configurato)
PASSWORD="password"            # Password di Transmission (se configurata)
STABILITY_WAIT=5               # Tempo di attesa per la stabilità del file (in secondi)

# Funzione per controllare la stabilità del file
is_file_stable() {
    local file="$1"
    local prev_size=0
    local curr_size=0

    for ((i=0; i<$STABILITY_WAIT; i++)); do
        curr_size=$(stat -c%s "$file" 2>/dev/null || echo 0)
        if [[ "$curr_size" -eq "$prev_size" && "$curr_size" -ne 0 ]]; then
            return 0  # Il file è stabile
        fi
        prev_size=$curr_size
        sleep 1
    done

    return 1  # Il file non è stabile
}

# Funzione per controllare se un file o directory è già gestito da Transmission
is_managed_by_transmission() {
    local target="$1"
    local torrents
    torrents=$(transmission-remote "$TRANSMISSION_HOST:$TRANSMISSION_PORT" -n "$USERNAME:$PASSWORD" --list | awk -F '|' 'NR>1 {print $NF}' | sed 's/^ *//')

    for torrent in $torrents; do
        if [[ "$torrent" == "$target" ]]; then
            return 0  # Il file o directory è già gestito da Transmission
        fi
    done

    return 1  # Il file o directory non è gestito da Transmission
}

# Creazione e aggiunta torrent
create_and_add_torrent() {
    local target="$1"
    local torrent_name="$(basename "$target").torrent"
    local torrent_file="$TORRENT_OUTPUT_DIR/$torrent_name"

    if [[ -f "$TRACKER_FILE" ]]; then
        TRACKER_URL=$(tr '\n' ',' < "$TRACKER_FILE" | sed 's/,$//')
    else
        echo "Errore: Il file dei tracker $TRACKER_FILE non esiste."
        exit 1
    fi

    mktorrent -a "$TRACKER_URL" -o "$torrent_file" "$target"
    if [[ $? -eq 0 ]]; then
        echo "Creato torrent: $torrent_file"
        transmission-remote "$TRANSMISSION_HOST:$TRANSMISSION_PORT" -n "$USERNAME:$PASSWORD" --add "$torrent_file"
        echo "Aggiunto torrent a Transmission: $torrent_file"
    else
        echo "Errore nella creazione del torrent per: $target"
    fi
}

# Monitoraggio con inotifywait
inotifywait -m -e moved_to -e create --format "%w%f" "$WATCH_DIR" | while read NEW_ITEM
do
    if [[ -f "$NEW_ITEM" || -d "$NEW_ITEM" ]]; then
        echo "Rilevato nuovo elemento: $NEW_ITEM"

        if is_file_stable "$NEW_ITEM"; then
            echo "Il file è stabile: $NEW_ITEM"

            if is_managed_by_transmission "$NEW_ITEM"; then
                echo "Il file è già gestito da Transmission: $NEW_ITEM"
            else
                create_and_add_torrent "$NEW_ITEM"
            fi
        else
            echo "Errore: Il file $NEW_ITEM non è stabile o è stato rimosso."
        fi
    fi
done
