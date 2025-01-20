#!/bin/bash

# Configurazione
WATCH_DIR="/path/to/torrents"  # Directory da monitorare
TORRENT_OUTPUT_DIR="/path/to/torrents_created"  # Dove salvare i .torrent
TRACKER_FILE="/path/to/trackers.txt"  # File contenente i tracker
TRANSMISSION_HOST="localhost"  # Host di Transmission
TRANSMISSION_PORT="9091"       # Porta di Transmission
USERNAME="user"                # Username di Transmission (se configurato)
PASSWORD="password"            # Password di Transmission (se configurata)

# Creazione e aggiunta torrent
create_and_add_torrent() {
    local target="$1"
    local torrent_name="$(basename "$target").torrent"
    local torrent_file="$TORRENT_OUTPUT_DIR/$torrent_name"

    # Leggere i tracker dal file e unirli in una stringa separata da virgole
    if [[ -f "$TRACKER_FILE" ]]; then
        TRACKER_URL=$(tr '\n' ',' < "$TRACKER_FILE" | sed 's/,$//')  # Rimuove la virgola finale
    else
        echo "Errore: Il file dei tracker $TRACKER_FILE non esiste."
        exit 1
    fi

    # Creare il file .torrent
    mktorrent -a "$TRACKER_URL" -o "$torrent_file" "$target"
    if [[ $? -eq 0 ]]; then
        echo "Creato torrent: $torrent_file"

        # Aggiungere il .torrent a Transmission
        transmission-remote "$TRANSMISSION_HOST:$TRANSMISSION_PORT" -n "$USERNAME:$PASSWORD" --add "$torrent_file"
        echo "Aggiunto torrent a Transmission: $torrent_file"
    else
        echo "Errore nella creazione del torrent per: $target"
    fi
}

# Monitoraggio con inotifywait
inotifywait -m -e moved_to -e create --format "%w%f" "$WATCH_DIR" | while read NEW_ITEM
do
    # Verifica se è un file o una directory
    if [[ -f "$NEW_ITEM" || -d "$NEW_ITEM" ]]; then
        create_and_add_torrent "$NEW_ITEM"
    fi
done
