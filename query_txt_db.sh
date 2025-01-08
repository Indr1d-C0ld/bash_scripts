#!/usr/bin/env bash

# Assicuriamoci che lo script sia eseguibile: chmod +x search_fb_italy.sh
# E poi eseguiamo con: ./search_fb_italy.sh

# Nome del file su cui eseguire la ricerca (nella stessa cartella dello script)
FILE_NAME="fb_italy.txt"

# Controlliamo che esista
if [[ ! -f "$FILE_NAME" ]]; then
  echo "Errore: il file $FILE_NAME non esiste nella cartella corrente!"
  exit 1
fi

# Chiediamo le parole chiave all'utente
read -p "Inserisci le parole chiave (separate da spazio): " -a KEYWORDS

# Se l'utente non inserisce alcuna keyword, usciamo
if [[ ${#KEYWORDS[@]} -eq 0 ]]; then
  echo "Nessuna parola chiave inserita. Esco."
  exit 0
fi

# Creiamo una regex che rappresenti la condizione:
# "la riga deve contenere TUTTE le parole chiave, in qualunque ordine".
#
# Per farlo usiamo lookahead multiple in un'unica espressione regolare,
# ognuna del tipo (?=.*\bKEYWORD\b).
# L'aggiunta di '^(?i)' serve a rendere la ricerca case-insensitive
# direttamente nell'espressione regolare (equivalente a rg -i, ma qui è "inline").
#
# Esempio:
# Se le KEYWORDS sono ["pippo", "pluto"],
# la pattern sarà: "^(?i)(?=.*\bpippo\b)(?=.*\bpluto\b).*"

REGEX="^(?i)"

for kw in "${KEYWORDS[@]}"; do
  # Escapare eventuali caratteri speciali nella keyword
  # (in molti casi va bene così, per massima robustezza potresti usare sed o perl)
  safe_kw=$(echo "$kw" | sed 's/[]\/$*.^|[]/\\&/g')
  # Aggiungiamo la lookahead per questa parola chiave
  REGEX+="(?=.*\\b${safe_kw}\\b)"
done

# Aggiungiamo ".*" alla fine per accogliere l'intera riga
REGEX+=".*"

# Ora utilizziamo ripgrep con la regex costruita:
# -i (opzionale) -> ricerche case-insensitive
# -e "$REGEX"    -> pattern da cercare
# --no-heading   -> non mostrare l'intestazione del file
# --line-number  -> facoltativo: mostra il numero di riga
echo -e "\nCerco nel file '$FILE_NAME' le righe che contengono tutte queste parole chiave: ${KEYWORDS[*]}\n"
rg --pcre2 -e "$REGEX" --no-heading --line-number "$FILE_NAME"

