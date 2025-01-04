#!/bin/bash

# Intervallo in secondi tra i controlli
INTERVALLO=60

# Soglie per notifiche
SOGLIA_BASSA=20
SOGLIA_CRITICA=10
SOGLIA_ALTA=90
SOGLIA_INCREMENTO=10  # Incremento significativo per notifiche

# Variabili per lo stato precedente
ultimo_stato=""
ultima_percentuale=-1

# Funzione per controllare lo stato della batteria
controlla_batteria() {
    # Ottieni informazioni sulla batteria
    local stato=$(acpi -b)
    local percentuale=$(echo "$stato" | grep -oP '\d+%' | tr -d '%')
    local stato_carica=$(echo "$stato" | grep -oP 'Charging|Discharging|Full')

    # Controlla se c'è una variazione significativa
    if [[ "$stato_carica" != "$ultimo_stato" || \
          ( $percentuale -ne $ultima_percentuale && \
            $((percentuale % SOGLIA_INCREMENTO)) -eq 0 ) ]]; then

        # Aggiorna lo stato precedente
        ultimo_stato="$stato_carica"
        ultima_percentuale=$percentuale

        # Notifiche basate sullo stato della batteria
        if [[ "$stato_carica" == "Charging" ]]; then
            if [[ $percentuale -ge $SOGLIA_ALTA ]]; then
                echo "[INFO] Batteria in carica e vicina al 100% ($percentuale%)."
            elif [[ $percentuale -lt $SOGLIA_ALTA ]]; then
                echo "[INFO] Batteria in carica: $percentuale%."
            fi
        elif [[ "$stato_carica" == "Discharging" ]]; then
            if [[ $percentuale -le $SOGLIA_CRITICA ]]; then
                echo "[CRITICO] Batteria molto scarica! Solo $percentuale% rimasti. Collegare il caricatore!"
            elif [[ $percentuale -le $SOGLIA_BASSA ]]; then
                echo "[ATTENZIONE] Batteria scarica: $percentuale%."
            else
                echo "[INFO] Batteria in uso: $percentuale%."
            fi
        elif [[ "$stato_carica" == "Full" ]]; then
            echo "[INFO] Batteria completamente carica e collegata alla corrente."
        fi
    fi
}

# Loop infinito per il monitoraggio
while true; do
    controlla_batteria
    sleep $INTERVALLO
done

