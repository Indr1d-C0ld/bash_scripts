#!/bin/bash

# 1. Controlla se lo script è eseguito come root, altrimenti si riavvia con sudo
if [ "$EUID" -ne 0 ]; then
    echo "Lo script deve essere eseguito come root. Riavvio con sudo..."
    exec sudo "$0" "$@"
fi

# 2. Verifica se la chiavetta USB con UUID 4EC9BD07704582C3 è montata
MOUNTPOINT=$(findmnt -rn -S UUID=4EC9BD07704582C3 -o TARGET)
if [ -z "$MOUNTPOINT" ]; then
    echo "La chiavetta USB con UUID 4EC9BD07704582C3 non è montata. Interrompo l'esecuzione del backup."
    exit 1
fi

# 3. Variabili per il backup
SOURCE_DIR="/home/pi"
EXCLUDE_FILE="/home/pi/rsync/esclusioni.txt"
DEST_DIR="$MOUNTPOINT/serverpi"

# Assicura che la directory di destinazione esista
mkdir -p "$DEST_DIR"

# 4. Esegue il comando rsync per il backup
rsync -av --delete --exclude-from="$EXCLUDE_FILE" "$SOURCE_DIR" "$DEST_DIR"
