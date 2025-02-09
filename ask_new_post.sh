#!/bin/bash
# Script per automatizzare la creazione e pubblicazione di un nuovo post per Hugo

# 1. Richiedi all'utente le parole chiave per il nome del post e convertilo in uno slug
read -p "Inserisci le parole chiave per il nome del post (verranno convertite in slug): " words_input
slug=$(echo "$words_input" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g')

# 2. Prepara il nome file aggiungendo la data attuale (formato aaaa-mm-dd) e l'estensione .md
current_date=$(date +'%Y-%m-%d')
filename="${current_date}-${slug}.md"

# 3. Richiedi interattivamente la directory di salvataggio (con autocompletion)
#    La root è /home/pi/blog/content/posts/ e, per default, si usa la cartella dell'anno corrente
default_dir="/home/pi/blog/content/posts/$(date +'%Y')"
read -e -p "Inserisci la directory dove salvare il post (relativa a /home/pi/blog/content/posts/), [default: ${default_dir}]: " user_dir
if [ -z "$user_dir" ]; then
  target_dir="$default_dir"
else
  # Se l'utente inserisce un percorso relativo, lo prependiamo alla root
  if [[ "$user_dir" != /* ]]; then
    target_dir="/home/pi/blog/content/posts/$user_dir"
  else
    target_dir="$user_dir"
  fi
fi
# Crea la directory se non esiste
mkdir -p "$target_dir"
# Percorso completo del file
filepath="${target_dir}/${filename}"

# 4. Richiedi il titolo del post
read -p "Inserisci il titolo del post: " title

# 5. Richiedi i tag (inseriti separati da virgola) e formatta in array YAML
read -p "Inserisci i tag separati da virgola (es. tag1, tag2): " tags_input
# Rimuove eventuali spazi dopo la virgola
tags=$(echo "$tags_input" | sed 's/, */,/g')
IFS=',' read -ra tag_array <<< "$tags"
final_tags="["
first=1
for tag in "${tag_array[@]}"; do
  # Elimina eventuali spazi iniziali e finali
  trimmed=$(echo "$tag" | sed 's/^ *//;s/ *$//')
  if [ $first -eq 1 ]; then
    final_tags="$final_tags\"$trimmed\""
    first=0
  else
    final_tags="$final_tags, \"$trimmed\""
  fi
done
final_tags="$final_tags]"

# 6. Imposta la data completa per la front matter (formato ISO 8601, es. 2025-02-08T13:57:09+01:00)
date_full=$(date -Iseconds)

# 7. Richiedi il corpo del post (input multilinea: termina digitando una linea contenente solo "EOF")
echo "Inserisci il corpo del post. Termina l'input digitando una linea contenente solo 'EOF':"
body_content=""
first_line=1
while IFS= read -r line; do
  if [ "$line" == "EOF" ]; then
    break
  fi
  if [ $first_line -eq 1 ]; then
    body_content="$line"
    first_line=0
  else
    body_content="${body_content}"$'\n'"$line"
  fi
done

# 8. Crea il file con la struttura front matter e il corpo del post
cat > "$filepath" <<EOF
---
title: "$title"
date: $date_full
tags: $final_tags
---

$body_content
EOF

echo "Post creato in: $filepath"

# 9. Rigenera il sito con Hugo (assicurati di essere nella directory corretta del sito)
cd /home/pi/blog
hugo

echo "Sito rigenerato."

