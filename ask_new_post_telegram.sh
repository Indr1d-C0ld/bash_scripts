#!/bin/bash
# newpost.sh: Script non interattivo che crea il post usando le variabili d'ambiente

# Verifica che le variabili siano impostate, altrimenti esce con un messaggio di errore
if [ -z "$POST_TITLE" ] || [ -z "$POST_TAGS" ] || [ -z "$POST_KEYWORDS" ] || [ -z "$POST_BODY" ]; then
    echo "Errore: Una o più variabili d'ambiente non sono definite. Assicurati che POST_TITLE, POST_TAGS, POST_KEYWORDS e POST_BODY siano impostate."
    exit 1
fi

# Crea lo slug: converte in minuscolo e sostituisce spazi con "-"
slug=$(echo "$POST_KEYWORDS" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g')

# Prepara il nome del file con la data attuale (aaaa-mm-dd) e lo slug
current_date=$(date +'%Y-%m-%d')
filename="${current_date}-${slug}.md"

# Definisce la directory di salvataggio (usa per default la cartella dell'anno corrente)
target_dir="/home/pi/blog/content/posts/$(date +'%Y')"
mkdir -p "$target_dir"
filepath="${target_dir}/${filename}"

# Prepara la data in formato ISO 8601
date_full=$(date -Iseconds)

# Format tags: trasforma la stringa dei tag in un array tipo YAML
IFS=',' read -ra tag_array <<< "$POST_TAGS"
final_tags="["
first=1
for tag in "${tag_array[@]}"; do
    trimmed=$(echo "$tag" | sed 's/^ *//;s/ *$//')
    if [ $first -eq 1 ]; then
        final_tags="$final_tags\"$trimmed\""
        first=0
    else
        final_tags="$final_tags, \"$trimmed\""
    fi
done
final_tags="$final_tags]"

# Crea il file Markdown con front matter e corpo
cat > "$filepath" <<EOF
---
title: "$POST_TITLE"
date: $date_full
tags: $final_tags
---

$POST_BODY
EOF

echo "Post creato in: $filepath"

# Rigenera il sito con Hugo
cd /home/pi/blog
hugo
