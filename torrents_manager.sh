#!/usr/bin/env bash

###########################################
# Configurazione
###########################################
TR_USER="randolph"
TR_PASS="arkham666"
TR_HOST="localhost"
TR_PORT="9091"
AUTH_ARGS="-n ${TR_USER}:${TR_PASS}"

###########################################
# Funzioni per colori e formattazione
###########################################
RESET="\e[0m"
BOLD="\e[1m"
DIM="\e[2m"
UNDERLINE="\e[4m"

BLACK="\e[30m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
WHITE="\e[37m"

info() {
    echo -e "${CYAN}${BOLD}[INFO]${RESET} $1"
}

warn() {
    echo -e "${YELLOW}${BOLD}[ATTENZIONE]${RESET} $1"
}

error() {
    echo -e "${RED}${BOLD}[ERRORE]${RESET} $1"
}

success() {
    echo -e "${GREEN}${BOLD}[OK]${RESET} $1"
}

###########################################
# Funzioni di utilità
###########################################

# Funzione per mostrare una barra di progresso in base alla percentuale.
draw_progress_bar() {
    local percent="$1"
    # Rimuove il simbolo %
    local num=${percent%\%}
    # Lunghezza barra
    local bar_length=20
    local filled=$(( (num * bar_length) / 100 ))
    local empty=$(( bar_length - filled ))

    local bar="${GREEN}$(printf '#%.0s' $(seq 1 $filled))${RESET}$(printf ' %.0s' $(seq 1 $empty))"
    echo -e "[${bar}] ${percent}"
}

list_torrents_once() {
    local raw_list
    raw_list="$(transmission-remote ${TR_HOST}:${TR_PORT} ${AUTH_ARGS} -l)"
    
    # Rimuove la prima riga (header) e la riga del sum finale
    local data_lines
    data_lines=$(echo "$raw_list" | tail -n +2 | grep -v '^Sum:')

    echo -e "${BOLD}${UNDERLINE}${MAGENTA}Lista dei Torrent:${RESET}\n"

    if [[ -z "$data_lines" ]]; then
        echo "Nessun torrent trovato."
        echo
        return
    fi

    echo "$data_lines" | while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        field_count=$(echo "$line" | awk '{print NF}')
        if (( field_count < 9 )); then
            continue
        fi
        
        id=$(echo "$line" | awk '{print $1}')
        donep=$(echo "$line" | awk '{print $2}')
        have=$(echo "$line" | awk '{print $3" "$4}')
        eta=$(echo "$line" | awk '{print $5}')
        up=$(echo "$line" | awk '{print $6}')
        down=$(echo "$line" | awk '{print $7}')
        ratio=$(echo "$line" | awk '{print $8}')
        status=$(echo "$line" | awk '{print $9}')
        name=$(echo "$line" | awk '{for (i=10; i<=NF; i++) printf $i" ";print ""}')
        name=$(echo "$name" | sed 's/[[:space:]]*$//')

        # Barra di progresso
        local progress_bar=$(draw_progress_bar "$donep")

        # Colore dello stato
        local color_status
        case "$status" in
            Idle|Stopped) color_status="${YELLOW}${BOLD}";;
            Downloading) color_status="${GREEN}${BOLD}";;
            Seeding) color_status="${BLUE}${BOLD}";;
            *) color_status="${WHITE}${BOLD}";;
        esac

        # Mostriamo le info con colori differenziati
        # ID in ciano brillante, Nome in magenta, Stato colorato come definito
        echo -e "${CYAN}${BOLD}ID:${RESET} ${id}"
        echo -e "${BOLD}Nome:${RESET} ${MAGENTA}${name}${RESET}"
        echo -e "${BOLD}Completato:${RESET} ${progress_bar}"
        echo -e "${BOLD}Stato:${RESET} ${color_status}${status}${RESET}"
        echo -e "${BOLD}ETA:${RESET} ${eta}\t${BOLD}Up:${RESET} ${up}\t${BOLD}Down:${RESET} ${down}\t${BOLD}Ratio:${RESET} ${ratio}"
        echo
    done
    echo
}

monitor_torrents() {
    # Schermata che si aggiorna ogni 2 secondi, premere q per uscire
    while true; do
        clear
        list_torrents_once
        echo -e "${CYAN}${BOLD}Premi 'q' per tornare al menu. Aggiornamento ogni 2s...${RESET}"
        # Attendi 2 secondi o esci se 'q' premuto
        read -t 2 -n 1 key
        if [[ "$key" == "q" || "$key" == "Q" ]]; then
            break
        fi
    done
}

show_torrent_info() {
    local torrent_id="$1"
    # Acquisisco le info in una variabile, poi colore e passo a less
    local info_data
    info_data="$(transmission-remote ${TR_HOST}:${TR_PORT} ${AUTH_ARGS} -t "$torrent_id" -i | sed '1d')"

    # Processiamo l'output per aggiungere colori
    # Chiavi note: Name, Id, Status, Tracker, Total size, Downloaded, Uploaded, Ratio, ETA, Location
    # Coloriamo le chiavi in ciano e grassetto, i valori in bianco, lo stato in base al valore
    info_colored=$(echo "$info_data" | while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*(Name|Id|Status|Tracker|Total size|Downloaded|Uploaded|Ratio|ETA|Location): ]]; then
            key=$(echo "$line" | awk -F: '{print $1}')
            value=$(echo "$line" | cut -d':' -f2- | sed 's/^ *//g')
            
            # Colora lo Status come prima
            if [[ "$key" == "Status" ]]; then
                case "$value" in
                    *Stopped*) color_status="${YELLOW}${BOLD}" ;;
                    *Download*) color_status="${GREEN}${BOLD}" ;;
                    *Seed*) color_status="${BLUE}${BOLD}" ;;
                    *) color_status="${WHITE}${BOLD}" ;;
                esac
                echo -e "${CYAN}${BOLD}${key}:${RESET} ${color_status}${value}${RESET}"
            else
                echo -e "${CYAN}${BOLD}${key}:${RESET} ${WHITE}${value}${RESET}"
            fi
        else
            echo -e "${DIM}${line}${RESET}"
        fi
    done)

    # Mostra con less -R (R per mantenere i codici colore)
    echo -e "${BOLD}${UNDERLINE}Informazioni per il torrent ID ${torrent_id}:${RESET}\n${info_colored}" | less -R
}

start_torrent() {
    local torrent_id="$1"
    transmission-remote ${TR_HOST}:${TR_PORT} ${AUTH_ARGS} -t "$torrent_id" -s && success "Torrent ${torrent_id} avviato" || error "Impossibile avviare il torrent ${torrent_id}"
}

pause_torrent() {
    local torrent_id="$1"
    transmission-remote ${TR_HOST}:${TR_PORT} ${AUTH_ARGS} -t "$torrent_id" -S && success "Torrent ${torrent_id} in pausa" || error "Impossibile mettere in pausa il torrent ${torrent_id}"
}

remove_torrent() {
    local torrent_id="$1"
    read -p "Sei sicuro di voler rimuovere il torrent ID ${torrent_id}? [y/N] " resp
    if [[ "$resp" =~ ^[Yy]$ ]]; then
        transmission-remote ${TR_HOST}:${TR_PORT} ${AUTH_ARGS} -t "$torrent_id" -r && success "Torrent ${torrent_id} rimosso" || error "Impossibile rimuovere il torrent ${torrent_id}"
    else
        info "Rimozione annullata."
    fi
}

add_torrent() {
    read -p "Inserisci il magnet link: " magnet_link
    if [[ -z "$magnet_link" ]]; then
        warn "Nessun magnet link inserito."
        return
    fi
    transmission-remote ${TR_HOST}:${TR_PORT} ${AUTH_ARGS} -a "$magnet_link" && success "Torrent aggiunto con successo." || error "Impossibile aggiungere il torrent."
}

###########################################
# Menu Principale
###########################################
while true; do
    clear
    echo -e "${BOLD}${MAGENTA}*** Transmission Manager ***${RESET}"
    echo "Scegli un'azione:"
    echo "1) Lista Torrents (aggiornamento in tempo reale)"
    echo "2) Avvia Torrent"
    echo "3) Metti in pausa Torrent"
    echo "4) Rimuovi Torrent"
    echo "5) Mostra Info su un Torrent"
    echo "6) Aggiungi Torrent (magnet link)"
    echo "q) Esci"
    echo
    read -p "Scelta: " choice

    case "$choice" in
        1)
            monitor_torrents
            ;;
        2)
            read -p "Inserisci l'ID del torrent da avviare: " tid
            start_torrent "$tid"
            read -p "Premi Invio per continuare..." ;;
        3)
            read -p "Inserisci l'ID del torrent da mettere in pausa: " tid
            pause_torrent "$tid"
            read -p "Premi Invio per continuare..." ;;
        4)
            read -p "Inserisci l'ID del torrent da rimuovere: " tid
            remove_torrent "$tid"
            read -p "Premi Invio per continuare..." ;;
        5)
            read -p "Inserisci l'ID del torrent: " tid
            show_torrent_info "$tid"
            ;;
        6)
            add_torrent
            read -p "Premi Invio per continuare..." ;;
        q|Q)
            info "Uscita dal programma."
            exit 0 ;;
        *)
            warn "Scelta non valida."
            read -p "Premi Invio per continuare..." ;;
    esac
done
