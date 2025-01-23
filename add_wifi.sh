#!/bin/bash

# Verifica se lo script è eseguito come root
if [[ $EUID -ne 0 ]]; then
   echo "Per favore, esegui questo script come root o con sudo."
   exit 1
fi

# Funzione per aggiungere una nuova rete WiFi
add_wifi() {
    echo "Inserisci i dettagli della rete WiFi da configurare:"
    
    # Chiedi il nome della rete (SSID)
    read -rp "Nome della rete (SSID): " ssid

    # Chiedi il tipo di autenticazione
    echo "Seleziona il tipo di protezione:"
    echo "1) WPA/WPA2 Personal"
    echo "2) Open (nessuna password)"
    read -rp "Seleziona (1 o 2): " auth_type

    if [[ $auth_type == "1" ]]; then
        # Chiedi la password per WPA/WPA2
        read -rsp "Password WiFi: " wifi_password
        echo
    elif [[ $auth_type == "2" ]]; then
        wifi_password=""
        echo "Configurazione per rete aperta selezionata."
    else
        echo "Opzione non valida. Uscita."
        exit 1
    fi

    # Configura la connessione con NetworkManager
    if [[ $auth_type == "1" ]]; then
        nmcli dev wifi con "$ssid" password "$wifi_password" ifname wlan0
    else
        nmcli dev wifi con "$ssid" ifname wlan0
    fi

    # Aggiungi la connessione come persistente
    nmcli con mod "$ssid" connection.autoconnect yes

    # Conferma l'aggiunta della rete
    if [[ $? -eq 0 ]]; then
        echo "La rete WiFi '$ssid' è stata configurata correttamente."
    else
        echo "Errore nella configurazione della rete WiFi."
    fi
}

# Funzione per elencare le reti conosciute
list_known_networks() {
    echo "Reti WiFi configurate:"
    nmcli con show | grep wifi | awk '{print $1}'
}

# Menu principale
while true; do
    echo
    echo "Gestione delle reti WiFi conosciute:"
    echo "1) Aggiungi una nuova rete WiFi"
    echo "2) Visualizza le reti WiFi configurate"
    echo "3) Esci"
    read -rp "Seleziona un'opzione: " option

    case $option in
        1)
            add_wifi
            ;;
        2)
            list_known_networks
            ;;
        3)
            echo "Uscita dallo script."
            exit 0
            ;;
        *)
            echo "Opzione non valida. Riprova."
            ;;
    esac
done

