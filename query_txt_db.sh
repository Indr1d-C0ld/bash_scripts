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

# Verifica che il file esista
if [[ ! -f "$FILE_NAME" ]]; then
  echo "Errore: il file $FILE_NAME non esiste nella cartella corrente!"
  exit 1
fi

# Chiediamo le parole chiave separate da spazio
read -p "Inserisci le parole chiave (separate da spazio): " -a KEYWORDS

# Se non inserisce nulla, esci
if [[ ${#KEYWORDS[@]} -eq 0 ]]; then
  echo "Nessuna parola chiave inserita. Esco."
  exit 0
fi

# ------------------------------------------------------------------------------
# 1) COSTRUZIONE DELLA PIPELINE DI RIPGREP PER RICERCA “AND” (case-insensitive)
#    --color=never: evitiamo sequenze di escape indesiderate
# ------------------------------------------------------------------------------
RESULT="rg --color=never -i \"${KEYWORDS[0]}\" \"$FILE_NAME\""
for KW in "${KEYWORDS[@]:1}"; do
  RESULT="$RESULT | rg --color=never -i \"$KW\""
done

# ------------------------------------------------------------------------------
# 2) SCRIPT AWK PER COLORARE I CAMPI, EVIDENZIARE KEYWORD E GLI INDIRIZZI EMAIL
# ------------------------------------------------------------------------------
AWK_SCRIPT='
BEGIN {
  # Array di colori ANSI per i PRIMI 9 campi
  color[1] = "\033[31m"; # rosso
  color[2] = "\033[32m"; # verde
  color[3] = "\033[33m"; # giallo
  color[4] = "\033[34m"; # blu
  color[5] = "\033[35m"; # magenta
  color[6] = "\033[36m"; # ciano
  color[7] = "\033[91m"; # rosso chiaro
  color[8] = "\033[92m"; # verde chiaro
  color[9] = "\033[95m"; # magenta chiaro

  # Dal 10° campo in poi, usiamo SEMPRE questo colore
  color10plus = "\033[37m"  # es: bianco/grigio chiaro

  # Scompongo la variabile "keywords" passata da Bash
  nKeys = split(keywords, kwArray, " ")

  # Colore per evidenziare le keyword (case-sensitive)
  kwColorStart = "\033[1;93m"  # bold + fg giallo chiaro
  kwColorEnd   = "\033[0m"

  # Colore per evidenziare gli indirizzi email
  emailColorStart = "\033[1;96m"  # bold + ciano chiaro
  emailColorEnd   = "\033[0m"
}

{
  # Suddivido la riga in campi, usando ":" come separatore
  nFields = split($0, field, ":")

  # Ricostruisco la riga colorando campo per campo
  coloredLine = ""

  for (j = 1; j <= nFields; j++) {
    # Scelgo il colore:
    #  - se j <= 9, uso color[j]
    #  - altrimenti uso color10plus
    if (j <= 9) {
      c = color[j]
    } else {
      c = color10plus
    }

    # --- Evidenziazione delle KEYWORD (case-sensitive) ---
    for (k = 1; k <= nKeys; k++) {
      toFind = kwArray[k]
      gsub(toFind, kwColorStart toFind kwColorEnd, field[j])
    }

    # --- Evidenziazione degli INDIRIZZI EMAIL (regex semplificata) ---
    # Avvertenza: AWK standard usa RE POSIX, quindi la regex è semplificata
    # [[:alnum:]._%+\-]+@[[:alnum:].-]+\.[[:alpha:]]+
    # Se AWK non lo supporta, potrebbe servire "mawk" o "gawk" con --posix o similar.
    gsub(/[[:alnum:]._%+\-]+@[[:alnum:].-]+\.[[:alpha:]]+/, emailColorStart "&" emailColorEnd, field[j])

    # Aggiungo il campo con il colore scelto
    coloredLine = coloredLine c field[j] "\033[0m"

    # Se non siamo all’ultimo campo, metto di nuovo il delimitatore ":"
    if (j < nFields) {
      coloredLine = coloredLine ":"
    }
  }

  # Stampa la riga colorata
  print coloredLine
}
'

# ------------------------------------------------------------------------------
# 3) COSTRUZIONE DEL COMANDO FINALE E ESECUZIONE
# ------------------------------------------------------------------------------
COMMAND="$RESULT | awk -F ':' -v keywords=\"${KEYWORDS[*]}\" '$AWK_SCRIPT'"

echo -e "\nCerco nel file '$FILE_NAME' le righe contenenti (AND) tutte le keyword (case-insensitive): ${KEYWORDS[*]}"
echo -e "Coloro i campi, evidenzio le keyword (case-sensitive) in giallo bold, e gli indirizzi email in ciano.\n"

eval "$COMMAND"

