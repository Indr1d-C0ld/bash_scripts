#!/bin/bash

# Prerequisiti:
# sudo apt install arp-scan nmap -y

# Colori per l'output
GREEN="\033[1;32m"
CYAN="\033[1;36m"
RESET="\033[0m"

# Funzione per eseguire la scansione della rete locale
scan_network() {
    echo -e "${CYAN}Scansione della rete locale in corso...${RESET}"
    local subnet=$(ip route | grep 'kernel' | awk '{print $1}')
    
    if command -v arp-scan > /dev/null; then
        sudo arp-scan --localnet | awk -v green="$GREEN" -v cyan="$CYAN" -v reset="$RESET" '
        BEGIN { printf("%-20s %-20s %-30s\n", "Indirizzo IP", "Indirizzo MAC", "Produttore") }
        /([0-9]{1,3}\.){3}[0-9]{1,3}/ { printf("%s%-20s%s %-20s %-30s\n", cyan, $1, reset, green $2, $3) }'
    else
        echo -e "${CYAN}Utilità 'arp-scan' non trovata. Passaggio a nmap.${RESET}"
        sudo nmap -sn "$subnet" | grep -E "Nmap scan report|MAC Address" | awk -v green="$GREEN" -v cyan="$CYAN" -v reset="$RESET" '
        /Nmap scan report/ { printf("%s%-20s%s", cyan, $NF, reset) }
        /MAC Address/ { printf(" %-20s\n", green $3) }'
    fi
}

# Funzione per eseguire la scansione delle porte aperte
scan_ports() {
    echo -ne "${CYAN}Inserisci l'indirizzo IP da scansionare: ${RESET}"
    read ip
    if [[ -z "$ip" ]]; then
        echo -e "${CYAN}Indirizzo IP non fornito. Operazione annullata.${RESET}"
        return
    fi

    echo -e "${CYAN}Scansione delle porte aperte su ${GREEN}$ip${CYAN}...${RESET}"
    sudo nmap -Pn "$ip" | grep -E '^[0-9]+/' | awk -v green="$GREEN" -v reset="$RESET" '
    BEGIN { printf("%-10s %-15s %-20s\n", "PORTA", "STATO", "SERVIZIO") }
    { printf("%s%-10s%s %-15s %-20s\n", green, $1, reset, $2, $3) }'
}

# Menu principale
while true; do
    echo -e "\n${CYAN}Menu Scanner di Rete${RESET}"
    echo "1. Scansiona la rete locale"
    echo "2. Scansiona le porte aperte su un IP"
    echo "3. Esci"
    echo -ne "${CYAN}Seleziona un'opzione: ${RESET}"
    read choice

    case $choice in
        1) scan_network ;;
        2) scan_ports ;;
        3) echo -e "${CYAN}Uscita...${RESET}" && exit ;;
        *) echo -e "${CYAN}Opzione non valida!${RESET}" ;;
    esac
done
