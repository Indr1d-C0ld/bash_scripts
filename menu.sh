#!/bin/bash

# ============================
# Funzioni di utilità
# ============================

check_cmd() {
    # Controlla se un comando è presente nel PATH
    # Uso: check_cmd comando
    # Ritorna 0 se presente, 1 se assente
    command -v "$1" &>/dev/null
}

error_dialog() {
    # Mostra un messaggio di errore con dialog e attende pressione tasto
    # Uso: error_dialog "Messaggio di errore"
    dialog --msgbox "$1" 10 60
}

# Funzione per ottenere indirizzo IP locale
get_local_ip() {
    ip addr show | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1 | head -n 1
}

# Funzione per ottenere indirizzo IP esterno
get_external_ip() {
    curl -s ifconfig.me
}

# ============================
# Controllo dipendenze minime
# ============================
REQUIRED_CMDS="dialog curl ip awk grep cut date whoami"
for cmd in $REQUIRED_CMDS; do
    if ! check_cmd "$cmd"; then
        echo "Errore: Il comando '$cmd' non è installato o non è nel PATH."
        exit 1
    fi
done

# Comandi opzionali (verranno controllati prima dell'uso)
OPT_CMDS_HTOP="htop"
OPT_CMDS_SENSORS="sensors"
OPT_CMDS_SPEEDTEST="speedtest-cli"
OPT_CMDS_NEOMUTT="neomutt"
OPT_CMDS_ELINKS="elinks"
OPT_CMDS_MC="mc"
OPT_CMDS_SC="sc"
OPT_CMDS_CALCURSE="calcurse"
OPT_CMDS_CALC="calc"
OPT_CMDS_SSH="ssh"
OPT_CMDS_TAR="tar"
OPT_CMDS_NANO="nano"
OPT_CMDS_PYTHON3="python3"  # Per EvoDiary

while true; do
    DATE=$(date '+%d-%m-%Y')
    TIME=$(date '+%H:%M:%S')
    LOCAL_IP=$(get_local_ip)
    EXTERNAL_IP=$(get_external_ip)
    USER=$(whoami)

    CHOICE=$(dialog --clear --title "Launcher Testuale" \
        --backtitle "Data: $DATE | Ora: $TIME | Utente: $USER | IP Locale: $LOCAL_IP | IP Esterno: $EXTERNAL_IP" \
        --menu "Seleziona un'opzione" 20 70 10 \
        1 "Diagnostica" \
        2 "Rete" \
        3 "Gestione files" \
        4 "Ufficio" \
        5 "Sistema" \
        6 "Altro" \
        0 "Esci" \
        3>&1 1>&2 2>&3)

    [ $? -ne 0 ] && break # Se l'utente preme ESC o Annulla

    case $CHOICE in
        1) # Diagnostica di sistema
            DIAG_CHOICE=$(dialog --clear --title "Diagnostica di Sistema" \
                --menu "Scegli un'opzione" 20 70 10 \
                1 "Visualizza processi attivi (htop)" \
                2 "Mostra memoria (free -h)" \
                3 "Spazio su disco (df -h)" \
                4 "Dettagli rete (ip addr show)" \
                5 "Temperatura CPU (sensors)" \
                6 "Ultimi log di sistema (journalctl)" \
                7 "Test velocità connessione (speedtest-cli)" \
                0 "Torna indietro" \
                3>&1 1>&2 2>&3)

            [ $? -ne 0 ] && continue

            TEMP_FILE=$(mktemp)
            case $DIAG_CHOICE in
                1)
                    if check_cmd "$OPT_CMDS_HTOP"; then
                        htop
                    else
                        error_dialog "htop non installato. Installarlo per usare questa funzione."
                    fi
                    ;;
                2) free -h > "$TEMP_FILE" && dialog --textbox "$TEMP_FILE" 20 70 ;;
                3) df -h > "$TEMP_FILE" && dialog --textbox "$TEMP_FILE" 20 70 ;;
                4) ip addr show > "$TEMP_FILE" && dialog --textbox "$TEMP_FILE" 20 70 ;;
                5)
                    if check_cmd "$OPT_CMDS_SENSORS"; then
                        sensors > "$TEMP_FILE" 2>/dev/null || echo "Nessun sensore disponibile" > "$TEMP_FILE"
                        dialog --textbox "$TEMP_FILE" 20 70
                    else
                        error_dialog "lm-sensors non installato. Installarlo per questa funzione."
                    fi
                    ;;
                6) journalctl -q | tail -50 > "$TEMP_FILE" && dialog --textbox "$TEMP_FILE" 20 110 ;;
                7)
                    if check_cmd "$OPT_CMDS_SPEEDTEST"; then
                        speedtest-cli > "$TEMP_FILE" 2>&1 || echo "Errore nell'esecuzione di speedtest-cli" > "$TEMP_FILE"
                        dialog --textbox "$TEMP_FILE" 20 70
                    else
                        error_dialog "speedtest-cli non installato. Installarlo per questa funzione."
                    fi
                    ;;
                0) ;;
            esac
            rm -f "$TEMP_FILE"
            ;;
        2) # Rete
            NEOMUTT_LABEL="Avvia Neomutt"
            check_cmd "$OPT_CMDS_NEOMUTT" || NEOMUTT_LABEL="$NEOMUTT_LABEL (NON DISPONIBILE)"

            ELINKS_LABEL="Avvia eLinks"
            check_cmd "$OPT_CMDS_ELINKS" || ELINKS_LABEL="$ELINKS_LABEL (NON DISPONIBILE)"

            # --- Modifica Feed RSS -> Archivio RSS ---
            ARCHIVIO_RSS_LABEL="Archivio RSS (esterno)"
            # Comando aggiornato per Archivio RSS
            RSS_COMMAND="/home/randolph/rss_archiver/./rss_archiver.py"

            SCAN_LAN_LABEL="Scansione LAN (esterno)"
            TOR_LABEL="TOR Network (esterno)"
            WIFI_LABEL="WiFi Manager (esterno)"
            TORRENTS_LABEL="Gestione Torrents (esterno)"
            SSH_LAUNCHER_LABEL="Connessioni SSH (esterno)"

            NETWORK_CHOICE=$(dialog --clear --title "Rete" \
                --backtitle "Utilizzo: Seleziona uno strumento di rete" \
                --menu "Scegli un'opzione" 20 70 10 \
                1 "$NEOMUTT_LABEL" \
                2 "$ELINKS_LABEL" \
                3 "$ARCHIVIO_RSS_LABEL" \
                4 "$SCAN_LAN_LABEL" \
                5 "$TOR_LABEL" \
                6 "$WIFI_LABEL" \
                7 "$TORRENTS_LABEL" \
                8 "$SSH_LAUNCHER_LABEL" \
                0 "Torna indietro" \
                3>&1 1>&2 2>&3)

            [ $? -ne 0 ] && continue

            case $NETWORK_CHOICE in
                1)
                    if check_cmd "$OPT_CMDS_NEOMUTT"; then
                        clear && neomutt
                    else
                        error_dialog "neomutt non installato."
                    fi
                    ;;
                2)
                    if check_cmd "$OPT_CMDS_ELINKS"; then
                        clear && elinks
                    else
                        error_dialog "elinks non installato."
                    fi
                    ;;
                3) # Archivio RSS
                    if [ -x "$RSS_COMMAND" ]; then
                        clear && "$RSS_COMMAND"
                    else
                        error_dialog "Script $RSS_COMMAND non trovato o non eseguibile."
                    fi
                    ;;
                4)
                    if [ -x /home/randolph/scan_lan.sh ]; then
                        clear && /home/randolph/scan_lan.sh
                    else
                        error_dialog "Script /home/randolph/scan_lan.sh non trovato o non eseguibile."
                    fi
                    ;;
                5)
                    if [ -x /home/randolph/tor_proxy.sh ]; then
                        clear && /home/randolph/tor_proxy.sh
                    else
                        error_dialog "Script /home/randolph/tor_proxy.sh non trovato o non eseguibile."
                    fi
                    ;;
                6)
                    if [ -x /home/randolph/wifi_manager.sh ]; then
                        clear && /home/randolph/wifi_manager.sh
                    else
                        error_dialog "Script /home/randolph/wifi_manager.sh non trovato o non eseguibile."
                    fi
                    ;;
                7)
                    if [ -x /home/randolph/torrents_manager.sh ]; then
                        clear && /home/randolph/torrents_manager.sh
                    else
                        error_dialog "Script /home/randolph/torrents_manager.sh non trovato o non eseguibile."
                    fi
                    ;;
                8)
                    if [ -x /home/randolph/ssh_launcher.sh ]; then
                        clear && /home/randolph/ssh_launcher.sh
                    else
                        error_dialog "Script /home/randolph/ssh_launcher.sh non trovato o non eseguibile."
                    fi
                    ;;
                0) ;;
            esac
            ;;
        3) # Gestione file
            FILE_CHOICE=$(dialog --clear --title "Gestione File" \
                --menu "Scegli un'opzione" 20 70 10 \
                1 "Midnight Commander (mc)" \
                2 "Cerca file nel sistema" \
                3 "Visualizza file di testo" \
                4 "Rimuovi file o directory" \
                0 "Torna indietro" \
                3>&1 1>&2 2>&3)

            [ $? -ne 0 ] && continue

            case $FILE_CHOICE in
                1)
                    if check_cmd "$OPT_CMDS_MC"; then
                        mc
                    else
                        error_dialog "Midnight Commander (mc) non installato."
                    fi
                    ;;
                2)
                    QUERY=$(dialog --inputbox "Inserisci il nome del file da cercare:" 10 50 3>&1 1>&2 2>&3)
                    [ $? -ne 0 ] && continue
                    [ -z "$QUERY" ] && error_dialog "Nessun nome file inserito." && continue
                    TEMP_FILE=$(mktemp)
                    find / -name "$QUERY" 2>/dev/null > "$TEMP_FILE"
                    if [ -s "$TEMP_FILE" ]; then
                        dialog --textbox "$TEMP_FILE" 20 70
                    else
                        error_dialog "Nessun file trovato con il nome: $QUERY"
                    fi
                    rm -f "$TEMP_FILE"
                    ;;
                3)
                    FILE=$(dialog --fselect / 15 50 3>&1 1>&2 2>&3)
                    [ $? -ne 0 ] && continue
                    [ ! -f "$FILE" ] && error_dialog "Il file selezionato non esiste." && continue
                    cat "$FILE" | dialog --textbox - 20 70
                    ;;
                4)
                    FILE=$(dialog --fselect / 15 50 3>&1 1>&2 2>&3)
                    [ $? -ne 0 ] && continue
                    if [ -e "$FILE" ]; then
                        rm -r "$FILE" && dialog --msgbox "Rimosso: $FILE" 10 50 || error_dialog "Errore nella rimozione di $FILE."
                    else
                        error_dialog "Il file o directory selezionato non esiste."
                    fi
                    ;;
                0) ;;
            esac
            ;;
        4) # Strumenti di ufficio
            SC_LABEL="sc (foglio elettronico)"
            check_cmd "$OPT_CMDS_SC" || SC_LABEL="$SC_LABEL (NON DISPONIBILE)"

            NANO_LABEL="nano (editor di testo)"
            check_cmd "$OPT_CMDS_NANO" || NANO_LABEL="$NANO_LABEL (NON DISPONIBILE)"

            CALCURSE_LABEL="calcurse (calendario)"
            check_cmd "$OPT_CMDS_CALCURSE" || CALCURSE_LABEL="$CALCURSE_LABEL (NON DISPONIBILE)"

            CALC_LABEL="calc (calcolatrice)"
            check_cmd "$OPT_CMDS_CALC" || CALC_LABEL="$CALC_LABEL (NON DISPONIBILE)"

            # --- Aggiunta EvoDiary ---
            EVODIARY_LABEL="EvoDiary (esterno)"
            if ! check_cmd "$OPT_CMDS_PYTHON3"; then
                EVODIARY_LABEL="$EVODIARY_LABEL (NON DISPONIBILE)"
            fi

            OFFICE_CHOICE=$(dialog --clear --title "Strumenti di Ufficio" \
                --menu "Scegli uno strumento" 20 70 10 \
                1 "$SC_LABEL" \
                2 "$NANO_LABEL" \
                3 "$CALCURSE_LABEL" \
                4 "$CALC_LABEL" \
                5 "$EVODIARY_LABEL" \
                0 "Torna indietro" \
                3>&1 1>&2 2>&3)

            [ $? -ne 0 ] && continue

            case $OFFICE_CHOICE in
                1)
                    if check_cmd "$OPT_CMDS_SC"; then
                        sc
                    else
                        error_dialog "sc non installato."
                    fi
                    ;;
                2)
                    if check_cmd "$OPT_CMDS_NANO"; then
                        FILE=$(dialog --inputbox "Inserisci il nome del file da creare/modificare:" 10 50 3>&1 1>&2 2>&3)
                        [ $? -ne 0 ] && continue
                        nano "$FILE"
                    else
                        error_dialog "nano non installato."
                    fi
                    ;;
                3)
                    if check_cmd "$OPT_CMDS_CALCURSE"; then
                        calcurse
                    else
                        error_dialog "calcurse non installato."
                    fi
                    ;;
                4)
                    if check_cmd "$OPT_CMDS_CALC"; then
                        calc
                    else
                        error_dialog "calc non installato."
                    fi
                    ;;
                5) # EvoDiary
                    if check_cmd "$OPT_CMDS_PYTHON3"; then
                        # --- Modifica comando EvoDiary ---
                        /home/randolph/my_diary/./main.py
                    else
                        error_dialog "python3 non installato. Impossibile eseguire EvoDiary."
                    fi
                    ;;
                0) ;;
            esac
            ;;
        5) # Sistema
            SYSTEM_CHOICE=$(dialog --clear --title "Sistema" \
                --menu "Scegli un'opzione" 20 70 10 \
                1 "Reboot" \
                2 "Shutdown" \
                3 "Display OFF (esterno)" \
                4 "Display ON (esterno)" \
                5 "Gestore APT (esterno)" \
                0 "Torna indietro" \
                3>&1 1>&2 2>&3)

            [ $? -ne 0 ] && continue

            case $SYSTEM_CHOICE in
                1)
                    dialog --yesno "Sei sicuro di voler riavviare il sistema?" 10 50
                    [ $? -eq 0 ] && sudo reboot
                    ;;
                2)
                    dialog --yesno "Sei sicuro di voler spegnere il sistema?" 10 50
                    [ $? -eq 0 ] && sudo poweroff
                    ;;
                3)
                    [ -x /home/randolph/display_off.sh ] && /home/randolph/display_off.sh || error_dialog "Script display_off.sh non trovato o non eseguibile."
                    ;;
                4)
                    [ -x /home/randolph/display_on.sh ] && /home/randolph/display_on.sh || error_dialog "Script display_on.sh non trovato o non eseguibile."
                    ;;
                5) # --- Aggiunta Gestore APT ---
                    if [ -x /home/randolph/gestore_apt.sh ]; then
                        clear && /home/randolph/gestore_apt.sh
                    else
                        error_dialog "Script /home/randolph/gestore_apt.sh non trovato o non eseguibile."
                    fi
                    ;;
                0) ;;
            esac
            ;;
        6) # Altro
            OTHER_CHOICE=$(dialog --clear --title "Altro" \
                --menu "Scegli un'opzione" 20 70 10 \
                1 "Comando personalizzato" \
                2 "Backup rapido directory (tar)" \
                3 "Database ADS-B (esterno)" \
                4 "SkyTool (esterno)" \
                0 "Torna indietro" \
                3>&1 1>&2 2>&3)

            [ $? -ne 0 ] && continue

            case $OTHER_CHOICE in
                1)
                    CMD=$(dialog --inputbox "Inserisci un comando da eseguire:" 10 50 3>&1 1>&2 2>&3)
                    [ $? -ne 0 ] && continue
                    [ -z "$CMD" ] && error_dialog "Nessun comando inserito." && continue
                    OUTPUT=$(eval "$CMD" 2>&1)
                    dialog --msgbox "$OUTPUT" 20 70
                    ;;
                2)
                    if ! check_cmd "$OPT_CMDS_TAR"; then
                        error_dialog "tar non installato. Impossibile eseguire il backup."
                        continue
                    fi
                    DIR=$(dialog --dselect / 15 50 3>&1 1>&2 2>&3)
                    [ $? -ne 0 ] && continue
                    [ -z "$DIR" ] && error_dialog "Nessuna directory selezionata." && continue
                    OUTPUT=$(dialog --inputbox "Nome del file di backup (es. backup.tar.gz):" 10 50 3>&1 1>&2 2>&3)
                    [ $? -ne 0 ] && continue
                    [ -z "$OUTPUT" ] && error_dialog "Nessun nome di output inserito." && continue
                    if tar -czf "$OUTPUT" "$DIR" 2>/dev/null; then
                        dialog --msgbox "Backup completato! File: $OUTPUT" 10 50
                    else
                        error_dialog "Errore durante la creazione del backup."
                    fi
                    ;;
                3)
                    if check_cmd "$OPT_CMDS_SSH"; then
                        clear && ssh pi@192.168.178.32 "/home/pi/query.sh" || error_dialog "Errore nell'esecuzione di SSH o dello script remoto."
                    else
                        error_dialog "ssh non installato."
                    fi
                    ;;
                4)
                    if [ -x /home/randolph/skytool/./skyinfo.sh ]; then
                        clear && /home/randolph/skytool/./skyinfo.sh
                    else
                        error_dialog "Script /home/randolph/skytool/skyinfo.sh non trovato o non eseguibile."
                    fi
                    ;;
                0) ;;
            esac
            ;;
        0)
            break
            ;;
    esac
done

