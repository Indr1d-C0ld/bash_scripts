#!/bin/bash

# Configurazione
KNOWN_SSIDS=("rete1" "rete2" "rete3")  # Elenco reti WiFi conosciute
HOTSPOT_SSID="ssid"               # Nome rete Hotspot
HOTSPOT_PASSWORD="password"        # Password rete Hotspot
HIDE_SSID=0                           # 1 per nascondere l'SSID, 0 per visibile
HOTSPOT_CHANNEL=6                     # Canale WiFi per l'hotspot

# Funzione per controllare se una rete conosciuta è disponibile
check_wifi() {
    for ssid in "${KNOWN_SSIDS[@]}"; do
        if iwlist wlan0 scan | grep -q "ESSID:\"$ssid\""; then
            echo "Rete WiFi conosciuta trovata: $ssid"
            return 0
        fi
    done
    return 1
}

# Funzione per attivare l'hotspot
start_hotspot() {
    echo "Nessuna rete WiFi conosciuta trovata. Avvio dell'hotspot..."
    
    # Configurazione statica IP per l'hotspot
    cat <<EOF >/etc/dhcpcd.conf
interface wlan0
    static ip_address=192.168.4.1/24
    nohook wpa_supplicant
EOF
    service dhcpcd restart

    # Configurazione dnsmasq
    cat <<EOF >/etc/dnsmasq.conf
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
EOF
    systemctl restart dnsmasq

    # Configurazione hostapd
    cat <<EOF >/etc/hostapd/hostapd.conf
interface=wlan0
driver=nl80211
ssid=$HOTSPOT_SSID
wpa_passphrase=$HOTSPOT_PASSWORD
hw_mode=g
channel=$HOTSPOT_CHANNEL
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=$HIDE_SSID
wmm_enabled=1
EOF

    sed -i 's|#DAEMON_CONF=".*"|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd
    systemctl unmask hostapd
    systemctl enable hostapd
    systemctl restart hostapd

    echo "Hotspot attivato: SSID=$HOTSPOT_SSID, Password=$HOTSPOT_PASSWORD"
}

# Funzione per connettersi a una rete WiFi conosciuta
connect_wifi() {
    echo "Rete WiFi conosciuta trovata. Connessione in corso..."
    wpa_cli -i wlan0 reconfigure
    if dhclient wlan0; then
        echo "Connesso con successo a una rete WiFi."
    else
        echo "Errore durante la connessione. Avvio dell'hotspot..."
        start_hotspot
    fi
}

# Logica principale
if check_wifi; then
    connect_wifi
else
    start_hotspot
fi

