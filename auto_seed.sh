#!/bin/bash

# Configurazione
WATCH_DIR="/path/to/torrents"  # Directory da monitorare
TORRENT_OUTPUT_DIR="/path/to/torrents_created"  # Dove salvare i .torrent
TRANSMISSION_HOST="localhost"  # Host di Transmission
TRANSMISSION_PORT="9091"       # Porta di Transmission
USERNAME="user"                # Username di Transmission (se configurato)
PASSWORD="password"            # Password di Transmission (se configurata)
TRACKER_URL="udp://tracker.opentrackr.org:1337/announce,udp://opentracker.i2p.rocks:6969/announce,udp://tracker.openbittorrent.com:6969/announce,udp://open.stealth.si:80/announce,udp://tracker.torrent.eu.org:451/announce,udp://tracker.moeking.me:6969/announce,udp://tracker.zerobytes.xyz:1337/announce,udp://tracker.dler.org:6969/announce,udp://tracker1.bt.moack.co.kr:80/announce,udp://tracker.cyberia.is:6969/announce" # Tracker per i .torrent

# Creazione e aggiunta torrent
create_and_add_torrent() {
    local target="$1"
    local torrent_name="$(basename "$target").torrent"
    local torrent_file="$TORRENT_OUTPUT_DIR/$torrent_name"

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
