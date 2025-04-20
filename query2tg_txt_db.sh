#!/usr/bin/env bash
#
# query.sh
# ------------------------------------------------------------------------------
# Esegue una pipeline di ricerche "AND" su fb_italy.txt con ripgrep --color=never,
# poi passa l'output "pulito" ad AWK, che:
#   - divide la riga in campi con ':'
#   - per i primi 9 campi applica un colore "ciclico"
#   - dal 10° campo in poi applica SEMPRE un colore fisso
#   - evidenzia le keyword (case-sensitive) con gsub
#   - evidenzia anche gli indirizzi email con un colore diverso
# ------------------------------------------------------------------------------

FILE_NAME="fb_italy.txt"

# Configura questi parametri con i tuoi dati Telegram
BOT_TOKEN=""  # Sostituisci con il tuo token Bot Telegram
CHAT_ID=""  # Sostituisci con il tuo ID chat o gruppo

# Funzione per inviare messaggi su Telegram, spezzandoli se troppo lunghi
send_to_telegram() {
    local message="$1"
    local max_length=4096  # Limite massimo di caratteri per messaggio Telegram
    local msg_length=${#message}

    if (( msg_length <= max_length )); then
        # Se il messaggio rientra nel limite, lo invio direttamente
        curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
            -d "chat_id=${CHAT_ID}" \
            -d "text=${message}" \
            -d "parse_mode=Markdown" > /dev/null
    else
        # Se il messaggio è troppo lungo, lo suddivido in parti
        local start=0
        while (( start < msg_length )); do
            # Estraggo un pezzo del messaggio di massimo max_length caratteri
            local chunk="${message:start:max_length}"
            curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
                -d "chat_id=${CHAT_ID}" \
                -d "text=${chunk}" \
                -d "parse_mode=Markdown" > /dev/null
            (( start += max_length ))
        done
    fi
}

# Verifica che il file esista
if [[ ! -f "$FILE_NAME" ]]; then
  echo "Errore: il file $FILE_NAME non esiste nella cartella corrente!"
  send_to_telegram "Errore: il file $FILE_NAME non esiste nella cartella corrente!"
  exit 1
fi

# Chiediamo le parole chiave separate da spazio
read -p "Inserisci le parole chiave (separate da spazio): " -a KEYWORDS

# Se non inserisce nulla, esci
if [[ ${#KEYWORDS[@]} -eq 0 ]]; then
  echo "Nessuna parola chiave inserita. Esco."
  send_to_telegram "Nessuna parola chiave inserita. Esco."
  exit 0
fi

# ------------------------------------------------------------------------------
# 1) COSTRUZIONE DELLA PIPELINE DI RIPGREP PER RICERCA “AND” (case-insensitive)
# ------------------------------------------------------------------------------
RESULT="rg -a -uu --no-config --no-mmap --color=never -i \"${KEYWORDS[0]}\" \"$FILE_NAME\""
for KW in "${KEYWORDS[@]:1}"; do
  RESULT="$RESULT | rg -a -uu --no-config --no-mmap --color=never -i \"$KW\""
done

# ------------------------------------------------------------------------------
# 2) ESECUZIONE DEL COMANDO E SALVATAGGIO DELL'OUTPUT
# ------------------------------------------------------------------------------
query_output=$(eval "$RESULT")

# Mostra il risultato a schermo
echo -e "\nCerco nel file '$FILE_NAME' le righe contenenti (AND) tutte le keyword (case-insensitive): ${KEYWORDS[*]}"
echo -e "Risultati trovati:\n$query_output"

# Invia l'output su Telegram, gestendo la possibilità che sia troppo lungo
if [[ -n "$query_output" ]]; then
    send_to_telegram "🔍 Risultati ricerca:\n$query_output"
else
    send_to_telegram "❌ Nessun risultato trovato per: ${KEYWORDS[*]}"
fi
