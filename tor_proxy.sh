#!/bin/bash

# Colori per il terminale
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
RESET="\e[0m"

# Funzione per avviare il servizio TOR
start_tor_service() {
    echo -e "${CYAN}Avvio del servizio TOR...${RESET}"
    sudo systemctl start tor
    if systemctl is-active --quiet tor; then
        echo -e "${GREEN}Servizio TOR avviato con successo.${RESET}"
    else
        echo -e "${RED}Errore nell'avvio del servizio TOR.${RESET}"
    fi
}

# Funzione per fermare il servizio TOR
stop_tor_service() {
    echo -e "${CYAN}Arresto del servizio TOR...${RESET}"
    sudo systemctl stop tor
    if systemctl is-active --quiet tor; then
        echo -e "${RED}Errore nell'arresto del servizio TOR.${RESET}"
    else
        echo -e "${GREEN}Servizio TOR arrestato con successo.${RESET}"
    fi
}

# Funzione per verificare se il servizio TOR è in esecuzione
check_tor_service() {
    if systemctl is-active --quiet tor; then
        echo -e "${GREEN}Il servizio TOR è attivo.${RESET}"
    else
        echo -e "${YELLOW}Il servizio TOR non è attivo.${RESET}"
    fi
}

# Funzione per abilitare il proxy TOR
enable_tor_proxy() {
    check_tor_service
    export TOR_ENABLED=true
    echo -e "${CYAN}\nProxy TOR attivato. Ora tutte le applicazioni supportate da torsocks useranno TOR.${RESET}"
    echo -e "${YELLOW}Per verificare: usa 'torsocks curl ifconfig.me' per controllare l'indirizzo IP.${RESET}"
}

# Funzione per disabilitare il proxy TOR
disable_tor_proxy() {
    unset TOR_ENABLED
    echo -e "${CYAN}\nProxy TOR disattivato. Le applicazioni non useranno più TOR.${RESET}"
}

# Funzione per monitorare TOR con nyx
monitor_tor() {
    echo -e "${CYAN}Avvio di nyx per il monitoraggio delle statistiche di TOR...${RESET}"
    nyx
}

# Funzione per mostrare lo stato del proxy e del servizio TOR
status_tor() {
    if [ -z "$TOR_ENABLED" ]; then
        echo -e "${RED}Proxy TOR non abilitato.${RESET}"
    else
        echo -e "${GREEN}Proxy TOR abilitato.${RESET}"
    fi
    check_tor_service
}

# Mostra il menu
menu() {
    echo -e "${MAGENTA}-------------------------------${RESET}"
    echo -e "${BLUE}    Gestione Proxy e Servizio TOR${RESET}"
    echo -e "${MAGENTA}-------------------------------${RESET}"
    echo -e "${CYAN}1) Abilita Servizio TOR${RESET}"
    echo -e "${CYAN}2) Disabilita Servizio TOR${RESET}"
    echo -e "${CYAN}3) Abilita Proxy TOR${RESET}"
    echo -e "${CYAN}4) Disabilita Proxy TOR${RESET}"
    echo -e "${CYAN}5) Monitor TOR (nyx)${RESET}"
    echo -e "${CYAN}6) Stato TOR${RESET}"
    echo -e "${CYAN}7) Esci${RESET}"
    echo -e "${MAGENTA}-------------------------------${RESET}"
    echo -n -e "${YELLOW}Scegli un'opzione: ${RESET}"
}

# Main loop
while true; do
    menu
    read -r scelta
    case $scelta in
        1)
            start_tor_service
            ;;
        2)
            stop_tor_service
            ;;
        3)
            enable_tor_proxy
            ;;
        4)
            disable_tor_proxy
            ;;
        5)
            monitor_tor
            ;;
        6)
            status_tor
            ;;
        7)
            echo -e "${BLUE}Uscita dallo script.${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}Opzione non valida!${RESET}"
            ;;
    esac
done

