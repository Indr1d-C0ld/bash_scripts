#!/bin/bash

# Funzione per richiedere la durata
ask_duration() {
    while true; do
        read -p "Inserisci la durata (es. 25s, 14:15, 02:15PM): " duration
        if [[ $duration =~ ^[0-9]+s$ || $duration =~ ^[0-9]{1,2}:[0-9]{2}$ || $duration =~ ^[0-9]{2}:[0-9]{2}(AM|PM)$ ]]; then
            break
        else
            echo "Formato non valido. Riprova."
        fi
    done
}

# Chiede se abilitare l'opzione -say
ask_say() {
    read -p "Vuoi attivare l'annuncio vocale del tempo rimanente? (s/n): " say_choice
    [[ "$say_choice" =~ ^[sS]$ ]] && SAY_OPTION="-say" || SAY_OPTION=""
}

# Chiede se attivare il conteggio progressivo
ask_up() {
    read -p "Vuoi attivare il conteggio progressivo da zero? (s/n): " up_choice
    [[ "$up_choice" =~ ^[sS]$ ]] && UP_OPTION="-up" || UP_OPTION=""
}

# Chiede i parametri all'utente
ask_duration
ask_say
ask_up

# Costruisce il comando finale
CMD="countdown $UP_OPTION $SAY_OPTION $duration"

# Esegue il comando
echo "Eseguo: $CMD"
$CMD
