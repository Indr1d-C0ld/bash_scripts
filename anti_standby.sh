#!/bin/bash

INTERVALLO=60  # Intervallo in secondi tra ogni azione

echo "Script attivo: movimento del mouse ogni $INTERVALLO secondi per evitare lo standby."

while true; do
    xdotool mousemove_relative 1 0  # Muove il mouse di 1 pixel a destra
    sleep 0.1
    xdotool mousemove_relative -- -1 0  # Torna alla posizione originale
    sleep "$INTERVALLO"
done
