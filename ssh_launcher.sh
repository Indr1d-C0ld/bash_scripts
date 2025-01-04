#!/bin/bash

# File che contiene la lista delle connessioni
SSH_CONFIG_FILE="$HOME/.ssh/ssh_connections"
DEFAULT_TIMEOUT=5

# Funzione per assicurarsi che il file di configurazione esista
ensure_config_file() {
    if [[ ! -f "$SSH_CONFIG_FILE" ]]; then
        touch "$SSH_CONFIG_FILE"
    fi
}

# Backup automatico
backup_config() {
    cp "$SSH_CONFIG_FILE" "$SSH_CONFIG_FILE.bak.$(date +%F_%T)"
}

# Menu principale
main_menu() {
    ensure_config_file
    backup_config

    local options=()
    local count=1
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local name
        name=$(echo "$line" | cut -d ';' -f 1)
        options+=("$count" "$name")
        ((count++))
    done < "$SSH_CONFIG_FILE"

    options+=("A" "Aggiungi Connessione")
    options+=("I" "Importa Configurazioni")
    options+=("E" "Esporta Configurazioni")
    options+=("T" "Imposta Timeout")
    options+=("Q" "Esci")

    CHOICE=$(dialog --clear --title "Gestione Connessioni SSH" \
        --menu "Seleziona un'opzione" 15 50 8 "${options[@]}" 2>&1 >/dev/tty)

    case $CHOICE in
        A) add_connection ;;
        I) import_connections ;;
        E) export_connections ;;
        T) set_timeout ;;
        Q) clear; exit 0 ;;
        *) manage_connection "$CHOICE" ;;
    esac
}

# Aggiunta di una connessione SSH
add_connection() {
    local name host user port
    name=$(dialog --inputbox "Inserisci un nome per la connessione:" 8 40 2>&1 >/dev/tty)
    host=$(dialog --inputbox "Inserisci Host SSH:" 8 40 2>&1 >/dev/tty)
    user=$(dialog --inputbox "Inserisci Utente SSH:" 8 40 2>&1 >/dev/tty)
    port=$(dialog --inputbox "Inserisci Porta SSH (default 22):" 8 40 "22" 2>&1 >/dev/tty)

    if [[ -n "$name" && -n "$host" && -n "$user" && $port -gt 0 ]]; then
        echo "$name;$user@$host;$port" >> "$SSH_CONFIG_FILE"
        dialog --msgbox "Connessione aggiunta con successo!" 6 40
    else
        dialog --msgbox "Errore: Dati non validi!" 6 40
    fi

    main_menu
}

# Importa configurazioni SSH
import_connections() {
    local import_file
    import_file=$(dialog --inputbox "Inserisci il percorso del file da importare:" 8 40 2>&1 >/dev/tty)
    
    if [[ -f "$import_file" ]]; then
        cat "$import_file" >> "$SSH_CONFIG_FILE"
        dialog --msgbox "Connessioni importate con successo!" 6 40
    else
        dialog --msgbox "Errore: File non trovato!" 6 40
    fi
    main_menu
}

# Esporta le configurazioni
export_connections() {
    local export_file
    export_file=$(dialog --inputbox "Inserisci il percorso del file di esportazione:" 8 40 2>&1 >/dev/tty)
    
    if [[ -n "$export_file" ]]; then
        cp "$SSH_CONFIG_FILE" "$export_file"
        dialog --msgbox "Connessioni esportate in $export_file" 6 40
    else
        dialog --msgbox "Errore: Percorso non valido!" 6 40
    fi

    main_menu
}

# Imposta il timeout
set_timeout() {
    DEFAULT_TIMEOUT=$(dialog --inputbox "Imposta il timeout (secondi):" 8 40 "$DEFAULT_TIMEOUT" 2>&1 >/dev/tty)
    if [[ ! $DEFAULT_TIMEOUT -gt 0 ]]; then
        DEFAULT_TIMEOUT=5
    fi
    dialog --msgbox "Timeout impostato a $DEFAULT_TIMEOUT secondi." 6 40
    main_menu
}

# Gestione di una connessione selezionata
manage_connection() {
    local line name user_host port
    line=$(sed -n "${1}p" "$SSH_CONFIG_FILE")
    name=$(echo "$line" | cut -d ';' -f 1)
    user_host=$(echo "$line" | cut -d ';' -f 2)
    port=$(echo "$line" | cut -d ';' -f 3)

    local options=("1" "Connetti" "2" "Modifica" "3" "Rimuovi" "4" "Test Connessione")
    CHOICE=$(dialog --menu "Gestisci connessione: $name" 15 50 8 "${options[@]}" 2>&1 >/dev/tty)

    case $CHOICE in
        1) ssh -p "$port" "$user_host"; log_connection "$name" ;;
        2) edit_connection "$1" ;;
        3) delete_connection "$1" ;;
        4) test_connection "$user_host" "$port" ;;
    esac

    main_menu
}

# Modifica una connessione
edit_connection() {
    local line name user_host port
    line=$(sed -n "${1}p" "$SSH_CONFIG_FILE")
    name=$(echo "$line" | cut -d ';' -f 1)
    user_host=$(echo "$line" | cut -d ';' -f 2)
    port=$(echo "$line" | cut -d ';' -f 3)

    local new_name new_host new_user new_port
    new_name=$(dialog --inputbox "Nuovo Nome (attuale: $name):" 8 40 "$name" 2>&1 >/dev/tty)
    new_host=$(dialog --inputbox "Nuovo Host SSH (attuale: ${user_host#*@}):" 8 40 "${user_host#*@}" 2>&1 >/dev/tty)
    new_user=$(dialog --inputbox "Nuovo Utente SSH (attuale: ${user_host%@*}):" 8 40 "${user_host%@*}" 2>&1 >/dev/tty)
    new_port=$(dialog --inputbox "Nuova Porta SSH (attuale: $port):" 8 40 "$port" 2>&1 >/dev/tty)

    if [[ -n "$new_name" && -n "$new_host" && -n "$new_user" && $new_port -gt 0 ]]; then
        sed -i "${1}s|.*|$new_name;$new_user@$new_host;$new_port|" "$SSH_CONFIG_FILE"
        dialog --msgbox "Connessione modificata con successo!" 6 40
    else
        dialog --msgbox "Errore: Dati non validi!" 6 40
    fi
}

# Elimina una connessione
delete_connection() {
    sed -i "${1}d" "$SSH_CONFIG_FILE"
    dialog --msgbox "Connessione rimossa con successo!" 6 40
}

# Testa una connessione
test_connection() {
    local result
    result=$(ssh -o BatchMode=yes -o ConnectTimeout="$DEFAULT_TIMEOUT" -p "$2" "$1" exit 2>&1)
    if [[ $? -eq 0 ]]; then
        dialog --msgbox "Connessione riuscita!" 6 40
    else
        dialog --msgbox "Connessione fallita: $result" 8 50
    fi
}

# Log delle connessioni
log_connection() {
    echo "$(date) - Connessione a $1" >> "$HOME/.ssh/ssh_connections.log"
}

# Avvio del programma
main_menu

