#!/usr/bin/env bash
#
# query2tg.sh
# ------------------------------------------------------------------------------

FILE_NAME="fb_italy.txt"

# Configura questi parametri con i tuoi dati Telegram
BOT_TOKEN=""  # Sostituisci con il tuo token Bot Telegram
CHAT_ID=""  # Sostituisci con il tuo ID chat o gruppo

# Funzione per inviare messaggi su Telegram
send_to_telegram() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        -d "text=${message}" \
        -d "parse_mode=Markdown" > /dev/null
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
RESULT="rg --color=never -i \"${KEYWORDS[0]}\" \"$FILE_NAME\""
for KW in "${KEYWORDS[@]:1}"; do
  RESULT="$RESULT | rg --color=never -i \"$KW\""
done

# ------------------------------------------------------------------------------
# 2) ESECUZIONE DEL COMANDO E SALVATAGGIO DELL'OUTPUT
# ------------------------------------------------------------------------------
query_output=$(eval "$RESULT")

# Mostra il risultato a schermo
echo -e "\nCerco nel file '$FILE_NAME' le righe contenenti (AND) tutte le keyword (case-insensitive): ${KEYWORDS[*]}"
echo -e "Risultati trovati:\n$query_output"

# Se l'output non è vuoto, invialo su Telegram
if [[ -n "$query_output" ]]; then
    send_to_telegram "🔍 Risultati ricerca:\n$query_output"
else
    send_to_telegram "❌ Nessun risultato trovato per: ${KEYWORDS[*]}"
fi
