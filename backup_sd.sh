#!/usr/bin/env bash
#
# Esempio di script interattivo che permette diversi tipi di backup:
# 1) Clonazione completa (dd)
# 2) Clonazione "sparse" (dd + conv=sparse)
# 3) Backup con partclone (solo blocchi usati)
# 4) Backup file-level (rsync)
# 5) (Opzionale) Riduzione partizione ext4 prima di clonare
# 6) Opzione di compressione e di spegnimento finale

########################################
#  SEZIONE COLORI E DECORAZIONI (ANSI) #
########################################
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
MAGENTA="\033[0;35m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

banner() {
  local message="$1"
  local color="${2:-$GREEN}"
  echo -e "${color}==============================================================${RESET}"
  echo -e "${color}${BOLD}${message}${RESET}"
  echo -e "${color}==============================================================${RESET}"
}

##################################
# Funzione per ridurre partizione
##################################
reduce_partition_ext4() {
  local dev_partition="$1"
  local new_size="$2"  # es. "10G"

  # 1. Smonta la partizione, se montata
  local mountpoint
  mountpoint=$(lsblk -no MOUNTPOINT "$dev_partition")
  if [[ -n "$mountpoint" ]]; then
    echo -e "${YELLOW}Smonto $dev_partition (era montato su $mountpoint)...${RESET}"
    umount "$dev_partition" || {
      echo -e "${RED}Impossibile smontare $dev_partition. Abort.${RESET}"
      return 1
    }
  fi

  # 2. e2fsck per controllare il filesystem
  echo -e "${YELLOW}Controllo del filesystem con e2fsck -f...${RESET}"
  e2fsck -f "$dev_partition" || {
    echo -e "${RED}e2fsck ha rilevato errori o si è interrotto. Abort.${RESET}"
    return 1
  }

  # 3. Riduzione del filesystem
  echo -e "${YELLOW}Riduzione del filesystem a $new_size con resize2fs...${RESET}"
  resize2fs "$dev_partition" "$new_size" || {
    echo -e "${RED}Errore nella riduzione del filesystem.${RESET}"
    return 1
  }

  # 4. Riduzione della partizione con parted
  #    - Qui assumiamo che $dev_partition sia tipo /dev/sdb1
  #    - Il disco è /dev/sdb, la partizione è "1"
  local disk device_number
  disk=$(echo "$dev_partition" | sed 's/[0-9]*$//')  # /dev/sdb
  device_number=$(echo "$dev_partition" | grep -o '[0-9]*$')  # 1

  echo -e "${YELLOW}Ridimensionamento partizione con parted...${RESET}"
  parted "$disk" resizepart "$device_number" "$new_size" || {
    echo -e "${RED}Errore nella riduzione della partizione con parted.${RESET}"
    return 1
  }

  echo -e "${GREEN}Partizione $dev_partition ridotta con successo a $new_size.${RESET}"
  return 0
}

#############################################
# Controllo privilegi di root (sudo o root) #
#############################################
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}Questo script deve essere eseguito con privilegi di root o sudo.${RESET}"
  echo "Provo a rieseguire con sudo..."
  sudo "$0" "$@"
  exit $?
fi

####################################
# Banner iniziale ed elenco device #
####################################
banner "BACKUP MANAGER - MULTI OPZIONI" "$CYAN"
echo -e "Questo script offre vari metodi di backup:\n"
echo -e "1) Clonazione completa con dd (tutti i settori)\n2) Clonazione 'sparse' con dd (ignora settori di zero)\n3) Backup con partclone (solo blocchi usati)\n4) Backup file-level con rsync\n\nOpzionalmente:\n- Riduzione partizione ext4 prima di clonare\n- Compressione gzip\n- Spegnimento finale"

banner "ELENCO DISPOSITIVI DISPONIBILI" "$CYAN"
lsblk -o NAME,TYPE,SIZE,FSTYPE,MOUNTPOINT
echo -e "Per maggiori dettagli:\n  fdisk -l\n  df -h\n"

############################################
# Scelta del metodo di backup (Menu)       #
############################################
while true; do
  echo -e "${BOLD}Scegli il metodo di backup:${RESET}"
  echo "1) Clonazione completa (dd)"
  echo "2) Clonazione 'sparse' (dd conv=sparse)"
  echo "3) Backup con partclone (solo blocchi usati)"
  echo "4) Backup file-level (rsync)"
  read -p "Inserisci il numero (1-4): " method

  if [[ "$method" =~ ^[1-4]$ ]]; then
    break
  else
    echo -e "${RED}Scelta non valida. Riprova.${RESET}"
  fi
done

#############################################
# Richiedi se ridurre prima la partizione  #
#############################################
REDUCE_BEFORE=false
REDUCE_SIZE=""
if [[ "$method" = "1" || "$method" = "2" || "$method" = "3" ]]; then
  # Ridurre la partizione ha senso per dd o partclone
  # (rsync è file-level, quindi la riduzione partizione è superflua).
  echo
  echo -e "${BOLD}Vuoi provare a ridurre una partizione ext4 prima di clonare?${RESET}"
  select riduci in "Sì" "No"; do
    case $riduci in
      "Sì") 
          REDUCE_BEFORE=true
          break
          ;;
      "No")
          REDUCE_BEFORE=false
          break
          ;;
      *)
          echo "Scelta non valida."
          ;;
    esac
  done

  if $REDUCE_BEFORE; then
    echo -e "${YELLOW}Indica quale partizione ridurre (es. /dev/sdb1). Assicurati che sia ext4.${RESET}"
    read -e -p "Partizione da ridurre: " PART_TO_REDUCE

    if [[ ! -b "$PART_TO_REDUCE" ]]; then
      echo -e "${RED}ERRORE: $PART_TO_REDUCE non è un device valido. Annulliamo la riduzione...${RESET}"
      REDUCE_BEFORE=false
    else
      echo "Quanta dimensione vuoi lasciare (es. 10G)?"
      read -p "Nuova dimensione: " REDUCE_SIZE
    fi
  fi
fi

###############################
# Scelta compressione (gzip)  #
###############################
COMPRESS=false
GZIP_LEVEL=6
echo
echo -e "${BOLD}Vuoi comprimere l'immagine con gzip?${RESET} (non si applica a rsync puro)"
select comprimi in "Sì" "No"; do
  case $comprimi in
    "Sì") 
        COMPRESS=true
        break
        ;;
    "No")
        COMPRESS=false
        break
        ;;
    *)
        echo "Scelta non valida."
        ;;
  esac
done

if $COMPRESS && [[ "$method" != "4" ]]; then
  echo
  echo "Scegli un livello di compressione gzip (1 = veloce, 9 = massima compressione)."
  read -p "Inserisci un valore tra 1 e 9 [default 6]: " level
  [[ -n "$level" ]] && GZIP_LEVEL=$level
fi

##############################################
# Opzione di spegnimento finale a fine job   #
##############################################
echo
echo -e "${BOLD}Desideri spegnere la macchina al termine?${RESET}"
select autospegni in "Sì" "No"; do
  case $autospegni in
    "Sì")
        SHUTDOWN_AT_END=true
        break
        ;;
    "No")
        SHUTDOWN_AT_END=false
        break
        ;;
    *)
        echo "Scelta non valida."
        ;;
  esac
done

###############################################
# Richiesta file di log, device, percorso ecc.
###############################################
LOGFILE_DEFAULT="/home/randolph/Documenti/backup.log"
echo
read -e -i "$LOGFILE_DEFAULT" -p "Inserisci il percorso/nome del file di log (default sopra): " LOGFILE

# Se metodo = rsync, chiederemo "sorgente" (device montato) e "destinazione" (cartella)
# Altrimenti chiediamo "device sorgente" e "file immagine destinazione"

if [[ "$method" = "4" ]]; then
  # Backup file-level (rsync)
  echo
  echo -e "${BOLD}Inserisci il percorso sorgente (cartella montata della SD)${RESET}"
  echo "Esempio: /media/utente/SDCARD"
  read -e -p "Percorso sorgente: " SRC_FOLDER

  if [[ ! -d "$SRC_FOLDER" ]]; then
    echo -e "${RED}La cartella sorgente non esiste. Annullato.${RESET}"
    exit 1
  fi

  echo
  echo -e "${BOLD}Inserisci la cartella di destinazione dove salvare il backup.${RESET}"
  echo "Esempio: /home/randolph/Documenti/backup_sd_folder"
  read -e -p "Cartella destinazione: " DST_FOLDER

  # Non ci serve un file immagine, perché rsync lavora file-level
  IMGFILE=""  

else
  # Metodi 1, 2, 3 => clonazione block-level
  echo
  echo -e "${BOLD}Quale dispositivo vuoi clonare?${RESET}"
  echo "Esempio: /dev/sdb"
  read -e -p "Device sorgente: " DEVICE_SRC

  if [[ ! -b "$DEVICE_SRC" ]]; then
    echo -e "${RED}ERRORE: $DEVICE_SRC non è un device a blocchi valido.${RESET}"
    exit 1
  fi

  echo
  echo -e "${BOLD}Inserisci il percorso/nome completo dove salvare l'immagine.${RESET}"
  echo "Esempio: /home/randolph/Documenti/backup_sd.img"
  read -e -p "Nome file immagine: " IMGFILE
fi

########################################
#  RIEPILOGO E CONFERMA                #
########################################
banner "RIEPILOGO OPERAZIONI" "$BLUE"
echo -e "${CYAN}Metodo di backup:         ${RESET}${BOLD}$method${RESET}"
if [[ "$method" = "4" ]]; then
  echo -e "${CYAN}Sorgente (cartella):      ${RESET}${BOLD}$SRC_FOLDER${RESET}"
  echo -e "${CYAN}Destinazione (cartella):  ${RESET}${BOLD}$DST_FOLDER${RESET}"
else
  echo -e "${CYAN}Device sorgente:          ${RESET}${BOLD}$DEVICE_SRC${RESET}"
  echo -e "${CYAN}File immagine destinazione:${RESET}${BOLD}$IMGFILE${RESET}"
fi

if $REDUCE_BEFORE; then
  echo -e "${CYAN}Ridurre partizione:       ${RESET}${BOLD}$PART_TO_REDUCE -> $REDUCE_SIZE${RESET}"
fi

if $COMPRESS && [[ "$method" != "4" ]]; then
  echo -e "${CYAN}Compressione:             ${RESET}${BOLD}gzip livello $GZIP_LEVEL${RESET}"
else
  echo -e "${CYAN}Compressione:             ${RESET}${BOLD}nessuna${RESET}"
fi

if $SHUTDOWN_AT_END; then
  echo -e "${CYAN}Spegnimento finale:        ${RESET}${BOLD}SÌ${RESET}"
else
  echo -e "${CYAN}Spegnimento finale:        ${RESET}${BOLD}NO${RESET}"
fi

echo -e "${CYAN}Log file:                  ${RESET}${BOLD}$LOGFILE${RESET}"
echo

read -p "Confermi di voler procedere? (s/n): " CONFERMA
if [[ "$CONFERMA" != "s" && "$CONFERMA" != "S" ]]; then
  echo "Operazione annullata dall'utente."
  exit 0
fi

#########################
#  Riduzione partizione #
#########################
if $REDUCE_BEFORE; then
  banner "RIDUZIONE PARTIZIONE" "$MAGENTA"
  echo -e "${YELLOW}Procedo con la riduzione di $PART_TO_REDUCE a $REDUCE_SIZE...${RESET}"
  reduce_partition_ext4 "$PART_TO_REDUCE" "$REDUCE_SIZE" || {
    echo -e "${RED}Riduzione fallita o annullata. Interrompo qui.${RESET}"
    exit 1
  }
fi

##########################################
#  ESECUZIONE DEL BACKUP (metodo scelto) #
##########################################
banner "AVVIO DEL BACKUP..." "$MAGENTA"
TMP_LOG="/tmp/backup_$$.log"
rm -f "$TMP_LOG" 2>/dev/null

case "$method" in
  "1") 
    # Clonazione completa con dd
    if $COMPRESS; then
      dd if="$DEVICE_SRC" bs=4M conv=sync,noerror status=progress 2>&1 \
        | gzip -$GZIP_LEVEL \
        | tee "$TMP_LOG" \
        > "${IMGFILE}.gz"
    else
      dd if="$DEVICE_SRC" of="$IMGFILE" bs=4M conv=sync,noerror status=progress 2>&1 \
        | tee "$TMP_LOG"
    fi
    ;;
  "2")
    # Clonazione "sparse" con dd
    # conv=sparse cerca di non scrivere fisicamente i blocchi di zero nell'immagine
    # (utile se il filesystem di destinazione supporta i file 'sparse')
    if $COMPRESS; then
      dd if="$DEVICE_SRC" bs=4M conv=sparse,sync,noerror status=progress 2>&1 \
        | gzip -$GZIP_LEVEL \
        | tee "$TMP_LOG" \
        > "${IMGFILE}.gz"
    else
      dd if="$DEVICE_SRC" of="$IMGFILE" bs=4M conv=sparse,sync,noerror status=progress 2>&1 \
        | tee "$TMP_LOG"
    fi
    ;;
  "3")
    # Backup con partclone
    # In base al filesystem, potresti usare partclone.ext4, partclone.vfat, ecc.
    # Partclone cercherà di copiare solo i blocchi effettivamente utilizzati.
    # Esempio generico (ext4):
    if $COMPRESS; then
      partclone.ext4 -c -s "$DEVICE_SRC" -o - 2>&1 \
        | gzip -$GZIP_LEVEL \
        | tee "$TMP_LOG" \
        > "${IMGFILE}.gz"
    else
      partclone.ext4 -c -s "$DEVICE_SRC" -o "$IMGFILE" 2>&1 \
        | tee "$TMP_LOG"
    fi
    ;;
  "4")
    # Backup file-level con rsync
    # Non prevede compressione "inline" (potresti compressare successivamente).
    # Se vuoi compressione "al volo", potresti usare un trucco con tar+gzip.
    echo "Avvio rsync da $SRC_FOLDER a $DST_FOLDER ..."
    rsync -avh --progress "$SRC_FOLDER/" "$DST_FOLDER/" 2>&1 | tee "$TMP_LOG"
    ;;
esac

###########################################
#  Salvataggio log finale (solo ultime 20) #
###########################################
banner "FINE BACKUP" "$GREEN"
echo "Salvataggio ultime righe del log in $LOGFILE..."
tail -n 20 "$TMP_LOG" > "$LOGFILE"
echo "Ecco un estratto del log finale:"
echo "-------------------------------------"
cat "$LOGFILE"
echo "-------------------------------------"

rm -f "$TMP_LOG"

################################
#  Spegnimento del sistema     #
################################
if $SHUTDOWN_AT_END; then
  echo
  echo -e "${YELLOW}Il sistema si spegnerà tra 5 secondi...${RESET}"
  sleep 5
  shutdown -h now
else
  echo
  echo -e "${GREEN}Operazione completata. Spegnimento NON richiesto.${RESET}"
fi
