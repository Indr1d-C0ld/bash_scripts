#!/bin/bash

# Colori
RESET="\033[0m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
BOLD="\033[1m"

CONFIG_FILE="/etc/wpa_supplicant/wpa_supplicant.conf"
INTERFACE="wlp1s0b1"

# Funzione per disegnare il menu
function draw_menu() {
    clear
    echo -e "${CYAN}${BOLD}Wi-Fi Manager (wpa_supplicant)${RESET}"
    echo -e "${GREEN}1.${RESET} Scansiona reti disponibili"
    echo -e "${GREEN}2.${RESET} Connetti a una rete"
    echo -e "${GREEN}3.${RESET} Mostra stato attuale"
    echo -e "${GREEN}4.${RESET} Esci"
    echo -n -e "${BOLD}Seleziona un'opzione: ${RESET}"
}

# Loop principale
while true; do
    draw_menu
    read -r scelta

    case $scelta in
        1) # Scansiona reti disponibili
            echo -e "\n${YELLOW}${BOLD}Reti disponibili:${RESET}"
            sudo iwlist "$INTERFACE" scan | grep -E "ESSID|Signal" | while IFS= read -r line; do
                if [[ $line == *"ESSID"* ]]; then
                    echo -e "${CYAN}$line${RESET}"
                elif [[ $line == *"Signal level"* ]]; then
                    echo -e "${MAGENTA}$line${RESET}"
                else
                    echo "$line"
                fi
            done
            echo -e "\nPremi ${BOLD}Invio${RESET} per continuare..."
            read -r
            ;;
        2) # Connetti a una rete
            echo -n -e "${BOLD}Inserisci il nome della rete (SSID): ${RESET}"
            read -r ssid
            echo -n -e "${BOLD}Inserisci la password: ${RESET}"
            read -rs password
            echo

            # Aggiunge la rete al file di configurazione
            sudo wpa_passphrase "$ssid" "$password" | sudo tee -a "$CONFIG_FILE" > /dev/null

            # Ricarica wpa_supplicant
            sudo wpa_cli -i "$INTERFACE" reconfigure
            echo -e "\n${GREEN}Connesso a ${CYAN}$ssid${GREEN} (se le credenziali sono corrette).${RESET}"
            echo -e "Premi ${BOLD}Invio${RESET} per continuare..."
            read -r
            ;;
        3) # Mostra stato attuale
            echo -e "\n${YELLOW}${BOLD}Stato attuale:${RESET}"
            sudo wpa_cli -i "$INTERFACE" status | while IFS= read -r line; do
                # Colora campi specifici
                if [[ $line == *"State="* ]]; then
                    echo -e "${CYAN}$(echo "$line" | sed 's/State=/Stato: /')${RESET}"
                elif [[ $line == *"ssid="* ]]; then
                    echo -e "${GREEN}$(echo "$line" | sed 's/ssid=/SSID: /')${RESET}"
                elif [[ $line == *"ip_address="* ]]; then
                    echo -e "${MAGENTA}$(echo "$line" | sed 's/ip_address=/Indirizzo IP: /')${RESET}"
                else
                    echo -e "${BLUE}$line${RESET}" # Colore per qualsiasi altra riga
                fi
            done
            echo -e "\nPremi ${BOLD}Invio${RESET} per continuare..."
            read -r
            ;;
        4) # Esci
            echo -e "\n${GREEN}${BOLD}Uscita. Buona giornata!${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}${BOLD}Opzione non valida!${RESET} Riprova."
            sleep 1
            ;;
    esac
done

