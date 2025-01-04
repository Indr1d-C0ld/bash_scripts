#!/usr/bin/env bash
#
# Esempio di script per backup di un dispositivo (es. SD)
# con possibilità di compressione, cattura log (solo ultime righe)
# e spegnimento finale del sistema.

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
  # Funzione di comodità per stampare un banner colorato
  local message="$1"
  local color="${2:-$GREEN}"
  echo -e "${color}==============================================================${RESET}"
  echo -e "${color}${BOLD}${message}${RESET}"
  echo -e "${color}==============================================================${RESET}"
}

##### 1. Controllo privilegi di root #####
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}Questo script deve essere eseguito con privilegi di root o sudo.${RESET}"
  echo "Provo a rieseguire con sudo..."
  sudo "$0" "$@"
  exit $?
fi

###############################
# 2. Mostra dispositivi       #
###############################
banner "ELENCO DISPOSITIVI DISPONIBILI" "$CYAN"
# lsblk dà un elenco leggibile di device con dimensioni, tipo FS, mountpoint, ecc.
lsblk -o NAME,TYPE,SIZE,FSTYPE,MOUNTPOINT
echo
echo -e "Se desideri più dettagli, esegui manualmente:\n- fdisk -l\n- df -h"
echo

################################
# 3. Richiesta device sorgente #
################################
echo -e "${BOLD}Quale dispositivo vuoi usare come sorgente per il backup?${RESET}"
echo "Ad esempio: /dev/sdb, /dev/mmcblk0, ecc."

# Abilitiamo l'auto-completamento dei percorsi con -e
read -e -p "Inserisci il percorso del device (es. /dev/sdb): " DEVICE_SRC

# Verifica minima sul device inserito
if [[ ! -b "$DEVICE_SRC" ]]; then
  echo -e "${RED}ERRORE: $DEVICE_SRC non è un device a blocchi valido.${RESET}"
  exit 1
fi

#########################################
# 4. Richiesta percorso/nome file di log
#########################################
# Usiamo -e (per auto-completion) e -i (per suggerire un valore di default)
LOGFILE_DEFAULT="/home/randolph/Documenti/backup_sd.log"
echo
echo -e "${BOLD}Inserisci il percorso/nome completo del file di log.${RESET}"
read -e -i "$LOGFILE_DEFAULT" -p "Percorso di default: " LOGFILE
echo "File di log selezionato: $LOGFILE"

###################################################
# 5. Richiesta posizione/nome immagine destinazione
###################################################
echo
echo -e "${BOLD}Inserisci il percorso/nome completo dove salvare l'immagine.${RESET}"
echo "Esempio: /home/randolph/Documenti/backup_sd.img"
read -e -p "Nome file immagine: " IMGFILE

###################################
# 6. Scelta della compressione    #
###################################
echo
echo -e "${BOLD}Vuoi comprimere l'immagine con gzip?${RESET}"
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

if $COMPRESS; then
  echo
  echo "Scegli un livello di compressione gzip (1 = veloce, 9 = massima compressione)."
  read -p "Inserisci un valore tra 1 e 9 [default 6]: " GZIP_LEVEL
  # Valore di default se non inserito
  if [[ -z "$GZIP_LEVEL" ]]; then
    GZIP_LEVEL=6
  fi
fi

###################################
#  RIEPILOGO E CONFERMA           #
###################################
banner "RIEPILOGO OPERAZIONI" "$BLUE"
echo -e "${CYAN}Dispositivo sorgente: ${RESET}${BOLD}$DEVICE_SRC${RESET}"
echo -e "${CYAN}File di log:          ${RESET}${BOLD}$LOGFILE${RESET}"
echo -e "${CYAN}Immagine destinazione:${RESET}${BOLD}$IMGFILE${RESET}"
if $COMPRESS; then
  echo -e "${CYAN}Compressione:         ${RESET}${BOLD}gzip livello $GZIP_LEVEL${RESET}"
else
  echo -e "${CYAN}Compressione:         ${RESET}${BOLD}nessuna${RESET}"
fi
echo
read -p "Confermi di voler procedere con il backup? (s/n): " CONFERMA
if [[ "$CONFERMA" != "s" && "$CONFERMA" != "S" ]]; then
  echo "Operazione annullata dall'utente."
  exit 0
fi

############################################
# 7. Esecuzione del backup con dd + gzip   #
############################################
banner "AVVIO DEL BACKUP..." "$MAGENTA"
echo "Potrebbe richiedere molto tempo..."
echo "Verrà mostrato il progresso a schermo."
echo "Al termine, le ultime righe di log verranno salvate in: $LOGFILE"
echo

TMP_LOG="/tmp/dd_backup_$$.log"   # file temporaneo per il log completo
rm -f "$TMP_LOG" 2>/dev/null      # rimuoviamo eventuali precedenti

if $COMPRESS; then
  # Backup + compressione gzip
  # Usiamo status=progress e reindirizziamo stderr (il progresso) su stdout.
  # tee mostrerà a video e salverà tutto in TMP_LOG
  dd if="$DEVICE_SRC" bs=4M conv=sync,noerror status=progress 2>&1 \
    | gzip -${GZIP_LEVEL} \
    | tee "$TMP_LOG" \
    > "${IMGFILE}.gz"
else
  # Backup senza compressione
  dd if="$DEVICE_SRC" of="$IMGFILE" bs=4M conv=sync,noerror status=progress 2>&1 \
    | tee "$TMP_LOG"
fi

############################################
# 8. Mostra e salva SOLO le ultime righe   #
############################################
# Vogliamo un file di log leggero, quindi salviamo solo le ultime 20 righe.
echo
banner "FINE BACKUP" "$GREEN"
echo "Salvataggio ultime righe del log in $LOGFILE..."
tail -n 20 "$TMP_LOG" > "$LOGFILE"
echo "Ecco un estratto del log finale:"
echo "-------------------------------------"
cat "$LOGFILE"
echo "-------------------------------------"

# Pulizia del file temporaneo
rm -f "$TMP_LOG"

################################
# 9. Spegnimento del sistema   #
################################
echo
echo -e "${YELLOW}Il sistema si spegnerà tra 5 secondi...${RESET}"
sleep 5
shutdown -h now

