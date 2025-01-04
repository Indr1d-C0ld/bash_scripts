#!/usr/bin/env bash
#
# gestore_apt_esteso2.sh
# Script testuale basato su 'dialog' per gestire i comandi apt da menù,
# con funzionalità ancora più estese.

############################
# 1. Controllo privilegi   #
############################

# Se l'utente non è root, richiede la password una sola volta all'avvio.
if [[ $EUID -ne 0 ]]; then
    echo "Devi avere privilegi di root per eseguire questo script."
    sudo -v || {
        echo "Autenticazione fallita. Uscita."
        exit 1
    }
fi

# Se non è installato 'dialog', prova a installarlo silenziosamente.
if ! command -v dialog &>/dev/null; then
    echo "dialog non è installato, provo ad installarlo..."
    sudo apt-get update -qq && sudo apt-get install -y dialog
fi

####################################
# 2. Impostazioni e variabili      #
####################################

# File temporaneo per salvare le scelte/risposte del menù
TMPFILE=$(mktemp) || {
    echo "Impossibile creare file temporaneo!"
    exit 1
}

# File di log
LOGFILE="/var/log/gestore_apt.log"

# Directory da backuppare
SOURCES_DIR="/etc/apt/sources.list.d"
# Cartella di backup (se non esiste, verrà creata)
BACKUP_DIR="/var/backups/apt_sources_list_d"
mkdir -p "$BACKUP_DIR"

# Funzione generica per fare clean-up finale
clean_up() {
    rm -f "$TMPFILE"
}
trap clean_up EXIT

# Funzione di logging
log_action() {
    local MSG="$1"
    # Data e ora nel formato AAAA-MM-GG HH:MM:SS
    local TIMESTAMP
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$TIMESTAMP] $MSG" | sudo tee -a "$LOGFILE" >/dev/null
}

################################################
# 3. Verifica dell’input (pacchetti esistenti) #
################################################

# Questa funzione utilizza apt-cache per verificare che il pacchetto esista.
# Restituisce 0 (vero) se esiste almeno un risultato, 1 (falso) in caso contrario.
verify_package() {
    local pkg="$1"
    local results
    # Se apt-cache show su un pacchetto inesistente non restituisce nulla
    results=$(apt-cache show "$pkg" 2>/dev/null)
    if [[ -z "$results" ]]; then
        return 1
    else
        return 0
    fi
}

# Funzione di utilità per verificare multipli pacchetti (separati da spazi).
# Ritorna 0 se almeno uno dei pacchetti è valido, 1 se TUTTI sono invalidi.
verify_packages_multiple() {
    local pkgs=("$@")
    local valid=1  # se rimane 1 vuol dire che nessun pacchetto è valido
    for p in "${pkgs[@]}"; do
        if verify_package "$p"; then
            valid=0
            break
        fi
    done
    return $valid
}

################################################
# 4. Funzioni di utilità per le azioni di menù #
################################################

function apt_update() {
    log_action "Esecuzione apt-get update"
    if sudo apt-get update; then
        dialog --title "apt update" --msgbox "Comando 'apt-get update' completato con successo." 6 50
    else
        dialog --title "Errore" --msgbox "Si è verificato un errore in 'apt-get update'." 6 50
        log_action "ERRORE durante l'esecuzione di apt-get update"
    fi
}

function apt_upgrade() {
    log_action "Esecuzione apt-get upgrade"
    if sudo apt-get upgrade -y; then
        dialog --title "apt upgrade" --msgbox "Comando 'apt-get upgrade' completato con successo." 6 50
    else
        dialog --title "Errore" --msgbox "Si è verificato un errore in 'apt-get upgrade'." 6 50
        log_action "ERRORE durante l'esecuzione di apt-get upgrade"
    fi
}

function apt_full_upgrade() {
    log_action "Esecuzione apt-get full-upgrade"
    if sudo apt-get full-upgrade -y; then
        dialog --title "apt full-upgrade" --msgbox "Comando 'apt-get full-upgrade' completato con successo." 6 50
    else
        dialog --title "Errore" --msgbox "Si è verificato un errore in 'apt-get full-upgrade'." 6 50
        log_action "ERRORE durante l'esecuzione di apt-get full-upgrade"
    fi
}

function apt_dist_upgrade() {
    log_action "Esecuzione apt-get dist-upgrade"
    if sudo apt-get dist-upgrade -y; then
        dialog --title "apt dist-upgrade" --msgbox "Comando 'apt-get dist-upgrade' completato con successo." 6 50
    else
        dialog --title "Errore" --msgbox "Si è verificato un errore in 'apt-get dist-upgrade'." 6 50
        log_action "ERRORE durante l'esecuzione di apt-get dist-upgrade"
    fi
}

function apt_search() {
    local keyword
    keyword=$(dialog --inputbox "Inserisci la keyword da cercare:" 8 50 3>&1 1>&2 2>&3)
    [[ -z "$keyword" ]] && return

    log_action "Esecuzione apt-cache search '$keyword'"
    local results
    results=$(apt-cache search "$keyword")

    if [[ -z "$results" ]]; then
        dialog --title "Risultati ricerca" --msgbox "Nessun risultato trovato per '$keyword'." 6 50
        log_action "Nessun risultato trovato per la keyword: $keyword"
    else
        dialog --title "Risultati ricerca per '$keyword'" --msgbox "$results" 20 80
    fi
}

function apt_info() {
    local pkg
    pkg=$(dialog --inputbox "Inserisci il nome del pacchetto per info:" 8 50 3>&1 1>&2 2>&3)
    [[ -z "$pkg" ]] && return

    # Verifichiamo prima se esiste
    if ! verify_package "$pkg"; then
        dialog --title "Errore" --msgbox "Il pacchetto '$pkg' non esiste nei repository." 6 50
        log_action "Tentativo di info su pacchetto inesistente: $pkg"
        return
    fi

    log_action "Esecuzione apt-cache show '$pkg'"
    local info
    info=$(apt-cache show "$pkg" 2>&1)
    if [[ -z "$info" ]]; then
        dialog --title "Errore" --msgbox "Nessuna informazione trovata per '$pkg'." 6 50
        log_action "Nessuna informazione trovata per il pacchetto: $pkg"
    else
        dialog --title "Info su '$pkg'" --msgbox "$info" 20 80
    fi
}

function apt_autoremove() {
    log_action "Esecuzione apt-get autoremove"
    if sudo apt-get autoremove -y; then
        dialog --title "apt autoremove" --msgbox "Comando 'apt-get autoremove' completato con successo." 6 50
    else
        dialog --title "Errore" --msgbox "Si è verificato un errore in 'apt-get autoremove'." 6 50
        log_action "ERRORE durante l'esecuzione di apt-get autoremove"
    fi
}

function apt_autoclean() {
    log_action "Esecuzione apt-get autoclean"
    if sudo apt-get autoclean; then
        dialog --title "apt autoclean" --msgbox "Comando 'apt-get autoclean' completato con successo." 6 50
    else
        dialog --title "Errore" --msgbox "Si è verificato un errore in 'apt-get autoclean'." 6 50
        log_action "ERRORE durante l'esecuzione di apt-get autoclean"
    fi
}

########################################################
# 5. Installazione e rimozione pacchetti (multipli)    #
########################################################

function apt_install_pkg() {
    local pkg
    pkg=$(dialog --inputbox "Inserisci il/i pacchetto/i da installare (separati da spazio):" 8 50 3>&1 1>&2 2>&3)
    [[ -z "$pkg" ]] && return

    # Dividiamo la stringa in array
    local pkgs=($pkg)

    # Verifica se almeno uno esiste
    if ! verify_packages_multiple "${pkgs[@]}"; then
        dialog --title "Errore" --msgbox "Nessuno dei pacchetti inseriti esiste nei repository." 7 50
        log_action "Tentativo di installare pacchetti inesistenti: $pkg"
        return
    fi

    log_action "Esecuzione apt-get install per: $pkg"
    if sudo apt-get install -y ${pkgs[@]}; then
        dialog --title "apt install" --msgbox "Pacchetto/i '$pkg' installato/i con successo." 6 50
    else
        dialog --title "Errore" --msgbox "Installazione di '$pkg' fallita." 6 50
        log_action "ERRORE durante l'installazione di $pkg"
    fi
}

function apt_remove_pkg() {
    local pkg
    pkg=$(dialog --inputbox "Inserisci il/i pacchetto/i da rimuovere (separati da spazio):" 8 50 3>&1 1>&2 2>&3)
    [[ -z "$pkg" ]] && return

    local pkgs=($pkg)

    # Verifica se almeno uno esiste
    if ! verify_packages_multiple "${pkgs[@]}"; then
        dialog --title "Errore" --msgbox "Nessuno dei pacchetti inseriti esiste sul sistema o nei repository." 7 50
        log_action "Tentativo di rimuovere pacchetti inesistenti: $pkg"
        return
    fi

    log_action "Esecuzione apt-get remove per: $pkg"
    if sudo apt-get remove -y ${pkgs[@]}; then
        dialog --title "apt remove" --msgbox "Pacchetto/i '$pkg' rimosso/i con successo." 6 50
    else
        dialog --title "Errore" --msgbox "Rimozione di '$pkg' fallita." 6 50
        log_action "ERRORE durante la rimozione di $pkg"
    fi
}

function apt_purge_pkg() {
    local pkg
    pkg=$(dialog --inputbox "Inserisci il/i pacchetto/i da rimuovere con purge (separati da spazio):" 8 50 3>&1 1>&2 2>&3)
    [[ -z "$pkg" ]] && return

    local pkgs=($pkg)

    # Verifica se almeno uno esiste
    if ! verify_packages_multiple "${pkgs[@]}"; then
        dialog --title "Errore" --msgbox "Nessuno dei pacchetti inseriti esiste sul sistema o nei repository." 7 50
        log_action "Tentativo di purge pacchetti inesistenti: $pkg"
        return
    fi

    log_action "Esecuzione apt-get remove --purge per: $pkg"
    if sudo apt-get remove --purge -y ${pkgs[@]}; then
        dialog --title "apt purge" --msgbox "Pacchetto/i '$pkg' rimosso/i (purge) con successo." 6 50
    else
        dialog --title "Errore" --msgbox "Purge di '$pkg' fallita." 6 50
        log_action "ERRORE durante la purge di $pkg"
    fi
}

#####################################################
# 6. Backup automatico di /etc/apt/sources.list.d/   #
#####################################################

function backup_sources_list_d() {
    local backup_file="$BACKUP_DIR/sources_list_d_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    log_action "Esecuzione backup di $SOURCES_DIR in $backup_file"

    if sudo tar -czf "$backup_file" -C / "$(echo "$SOURCES_DIR" | sed 's|^/||')" 2>/dev/null; then
        dialog --title "Backup completato" --msgbox "Backup creato in:\n$backup_file" 7 60
    else
        dialog --title "Errore backup" --msgbox "Si è verificato un errore durante il backup di $SOURCES_DIR." 6 50
        log_action "ERRORE durante il backup di $SOURCES_DIR"
    fi
}

#####################################################
# 7. Modifica dei file in /etc/apt/sources.list.d/   #
#####################################################

function edit_sources_list_d() {
    # Prima facciamo il backup automatico
    backup_sources_list_d

    local files
    files=($(ls /etc/apt/sources.list.d/*.list 2>/dev/null))

    if [[ ${#files[@]} -eq 0 ]]; then
        dialog --title "No File" --msgbox "Nessun file .list in /etc/apt/sources.list.d/" 6 50
        return
    fi

    # Creiamo una lista di opzioni per il menù di dialog
    local options=()
    for f in "${files[@]}"; do
        options+=("$f" "$f")
    done

    # Dialog per scegliere quale file modificare
    dialog --clear --title "File in /etc/apt/sources.list.d/" \
        --menu "Seleziona un file da modificare (è già stato fatto un backup)." 0 0 10 \
        "${options[@]}" 2>"$TMPFILE"

    local ret=$?
    local choice
    choice=$(<"$TMPFILE")

    # Se l'utente preme ESC o Annulla, o non sceglie niente, esce
    if [ $ret -ne 0 ] || [ -z "$choice" ]; then
        return
    fi

    log_action "Modifica file $choice"
    sudo nano "$choice"
}

############################################
# 8. Modifica del file /etc/apt/sources.list
############################################

function edit_sources() {
    # Anche qui facciamo un backup prima di modificare
    local backup_file="$BACKUP_DIR/sources_list_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    log_action "Esecuzione backup di /etc/apt/sources.list in $backup_file"

    # Backup del singolo file /etc/apt/sources.list
    sudo tar -czf "$backup_file" -C / "$(echo "/etc/apt/sources.list" | sed 's|^/||')" 2>/dev/null

    log_action "Modifica file /etc/apt/sources.list"
    sudo nano /etc/apt/sources.list
}

#################################################
# 9. Sottomenù di gestione log (pulizia, salvataggio...)
#################################################

function submenu_log_management() {
    while true; do
        dialog --clear --title "Gestione Log" \
            --menu "Scegli un'opzione:" 0 0 5 \
            1 "Visualizza log completo" \
            2 "Pulizia log (svuota il file)" \
            3 "Salva log in un altro file" \
            0 "Torna al menù principale" 2>"$TMPFILE"

        local ret=$?
        local choice
        choice=$(<"$TMPFILE")

        if [ $ret -ne 0 ] || [ "$choice" = "0" ]; then
            break
        fi

        case "$choice" in
            1)
                view_log
                ;;
            2)
                clean_log
                ;;
            3)
                save_log_as
                ;;
        esac
    done
}

function view_log() {
    if [[ ! -f "$LOGFILE" ]]; then
        dialog --title "Log non disponibile" --msgbox "Il file di log '$LOGFILE' non esiste ancora o è vuoto." 7 50
        return
    fi

    local content
    content=$(sudo cat "$LOGFILE")
    if [[ -z "$content" ]]; then
        dialog --title "Log vuoto" --msgbox "Il log è vuoto." 6 50
        return
    fi

    dialog --title "Visualizzazione Log" --msgbox "$content" 20 80
}

function clean_log() {
    # Svuotiamo il file di log
    if [[ -f "$LOGFILE" ]]; then
        sudo sh -c "cat /dev/null > '$LOGFILE'"
        dialog --title "Pulizia Log" --msgbox "Il file di log è stato svuotato." 6 50
        log_action "Log pulito su richiesta dell'utente."
    else
        dialog --title "Nessun Log" --msgbox "Il file di log non esiste o è già vuoto." 6 50
    fi
}

function save_log_as() {
    local path
    path=$(dialog --inputbox "Inserisci il percorso/nome del file dove salvare il log:" 8 60 3>&1 1>&2 2>&3)
    [[ -z "$path" ]] && return

    if [[ ! -f "$LOGFILE" ]]; then
        dialog --title "Log non disponibile" --msgbox "Il file di log '$LOGFILE' non esiste ancora o è vuoto." 7 50
        return
    fi

    # Copia del log
    if sudo cp "$LOGFILE" "$path"; then
        dialog --title "Log salvato" --msgbox "Il log è stato salvato in: $path" 6 50
        log_action "Log salvato in $path su richiesta dell'utente."
    else
        dialog --title "Errore" --msgbox "Impossibile salvare il log in $path." 6 50
    fi
}

###############################################
# 10. Menù principale con ciclo di selezione  #
###############################################

while true; do
    dialog --clear --backtitle "Gestione pacchetti APT" \
        --title "Menù Principale" \
        --menu "Seleziona un'operazione tra quelle disponibili:" 0 0 16 \
        1  "Esegui apt update" \
        2  "Esegui apt upgrade" \
        3  "Esegui apt full-upgrade" \
        4  "Esegui apt dist-upgrade" \
        5  "Cerca un pacchetto (apt-cache search)" \
        6  "Mostra info su un pacchetto (apt-cache show)" \
        7  "Modifica /etc/apt/sources.list (backup automatico)" \
        8  "Modifica file in /etc/apt/sources.list.d/ (backup automatico)" \
        9  "Esegui apt autoremove" \
        10 "Esegui apt autoclean" \
        11 "Installa uno o più pacchetti (apt-get install)" \
        12 "Rimuovi uno o più pacchetti (apt-get remove)" \
        13 "Rimuovi (purge) uno o più pacchetti (apt-get remove --purge)" \
        14 "Gestione Log (visualizza, pulisci, salva)" \
        0  "Esci" 2>"$TMPFILE"

    RET=$?
    CHOICE=$(<"$TMPFILE")

    # Se l'utente preme ESC, Annulla o sceglie "0", esce
    if [ $RET -ne 0 ] || [ "$CHOICE" = "0" ]; then
        dialog --title "Uscita" --msgbox "Grazie per aver utilizzato questo gestore di pacchetti." 6 50
        break
    fi

    case "$CHOICE" in
        1)  apt_update ;;
        2)  apt_upgrade ;;
        3)  apt_full_upgrade ;;
        4)  apt_dist_upgrade ;;
        5)  apt_search ;;
        6)  apt_info ;;
        7)  edit_sources ;;
        8)  edit_sources_list_d ;;
        9)  apt_autoremove ;;
        10) apt_autoclean ;;
        11) apt_install_pkg ;;
        12) apt_remove_pkg ;;
        13) apt_purge_pkg ;;
        14) submenu_log_management ;;
        *)  ;;
    esac
done

clear
exit 0

