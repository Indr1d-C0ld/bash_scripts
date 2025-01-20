#!/bin/bash

# Configurazione
TRACKER_FILE="/path/to/trackers.txt"  # Percorso del file locale dei tracker
TRACKER_URL="https://example.com/trackers.txt"  # URL della lista aggiornata
TEMP_FILE="/tmp/trackers_new.txt"  # File temporaneo per il confronto
LOG_FILE="/var/log/update_trackers.log"  # Log degli aggiornamenti

# Funzione per loggare
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Controllo aggiornamenti
update_trackers() {
    # Scarica la lista dal URL
    curl -s "$TRACKER_URL" -o "$TEMP_FILE"

    if [[ $? -ne 0 ]]; then
        log_message "Errore: Non è stato possibile scaricare l'URL $TRACKER_URL."
        return 1
    fi

    # Verifica che il file scaricato non sia vuoto e contenga tracker
    if [[ ! -s "$TEMP_FILE" || ! $(grep -E "^(http|udp)://" "$TEMP_FILE") ]]; then
        log_message "Errore: Il file scaricato da $TRACKER_URL non è valido."
        rm -f "$TEMP_FILE"
        return 1
    fi

    # Confronta il contenuto con il file esistente
    if cmp -s "$TRACKER_FILE" "$TEMP_FILE"; then
        log_message "Nessun aggiornamento disponibile per i tracker."
        rm -f "$TEMP_FILE"
        return 0
    else
        # Aggiorna il file locale con la nuova lista
        mv "$TEMP_FILE" "$TRACKER_FILE"
        log_message "File dei tracker aggiornato con successo da $TRACKER_URL."
        return 0
    fi
}

# Esegui l'aggiornamento
update_trackers
