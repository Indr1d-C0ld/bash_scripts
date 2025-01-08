#!/usr/bin/env bash
#
# Script di esempio per RIPRISTINO di un’immagine su un dispositivo (es. SD)
# - Legge un file immagine locale (possibilmente .gz)
# - Scrive sul device di destinazione con dd (o gunzip + dd)
# - Genera un log leggero (solo ultime righe)
# - Può spegnere la macchina a fine procedura, a scelta dell'utente

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
lsblk -o NAME,TYPE,SIZE,FSTYPE,MOUNTPOINT
echo
echo -e "Ulteriori dettagli? Esegui manualmente:\n- fdisk -l\n- df -h"
echo

##################################################
# 3. Richiesta percorso file immagine da ripristinare
##################################################
echo -e "${BOLD}Inserisci il percorso dell'immagine da ripristinare.${RESET}"
echo "Esempio: /home/randolph/Documenti/backup_sd.img oppure /home/randolph/Documenti/backup_sd.img.gz"
read -e -p "File immagine: " IMAGE_FILE

# Controlla che il file esista
if [[ ! -f "$IMAGE_FILE" ]]; then
  echo -e "${RED}ERRORE: il file $IMAGE_FILE non esiste.${RESET}"
  exit 1
fi

##################################################
# 4. Verifica se l'immagine è compressa (.gz)     #
##################################################
IS_GZ=false
if [[ "$IMAGE_FILE" == *.gz ]]; then
  IS_GZ=true
  echo -e "${YELLOW}Rilevata estensione .gz, utilizzeremo gunzip in streaming...${RESET}"
else
  echo -e "${GREEN}File immagine non compresso (.gz).${RESET}"
fi

#########################################
# 5. Richiesta percorso/nome file di log
#########################################
LOGFILE_DEFAULT="/home/randolph/Documenti/restore_sd.log"
echo
echo -e "${BOLD}Inserisci il percorso/nome completo del file di log.${RESET}"
read -e -i "$LOGFILE_DEFAULT" -p "Percorso di default: " LOGFILE
echo "File di log selezionato: $LOGFILE"

###################################
# 6. Scelta del device target     #
###################################
echo
echo -e "${BOLD}Quale dispositivo vuoi usare come destinazione per il ripristino?${RESET}"
echo "Esempio: /dev/sdb, /dev/mmcblk0, ecc."
read -e -p "Inserisci il percorso del device destinazione: " DEVICE_DST

# Verifica minima sul device inserito
if [[ ! -b "$DEVICE_DST" ]]; then
  echo -e "${RED}ERRORE: $DEVICE_DST non è un device a blocchi valido.${RESET}"
  exit 1
fi

###########################################
# 7. Vuoi spegnere la macchina a fine job? 
###########################################
echo
echo -e "${BOLD}Desideri spegnere la macchina al termine dell'operazione?${RESET}"
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

###################################
#  RIEPILOGO E CONFERMA           #
###################################
banner "RIEPILOGO OPERAZIONI" "$BLUE"
echo -e "${CYAN}File immagine:        ${RESET}${BOLD}$IMAGE_FILE${RESET}"
echo -e "${CYAN}File di log:          ${RESET}${BOLD}$LOGFILE${RESET}"
echo -e "${CYAN}Device destinazione:  ${RESET}${BOLD}$DEVICE_DST${RESET}"
if $IS_GZ; then
  echo -e "${CYAN}Riconosciuto formato: ${RESET}${BOLD}gzip (.gz)${RESET}"
else
  echo -e "${CYAN}Riconosciuto formato: ${RESET}${BOLD}non compresso${RESET}"
fi
if $SHUTDOWN_AT_END; then
  echo -e "${CYAN}Spegnimento finale:   ${RESET}${BOLD}SÌ${RESET}"
else
  echo -e "${CYAN}Spegnimento finale:   ${RESET}${BOLD}NO${RESET}"
fi

echo
read -p "Confermi di voler procedere con il ripristino? (s/n): " CONFERMA
if [[ "$CONFERMA" != "s" && "$CONFERMA" != "S" ]]; then
  echo "Operazione annullata dall'utente."
  exit 0
fi

##########################################
# 8. Esecuzione ripristino con dd        #
##########################################
banner "AVVIO DEL RIPRISTINO..." "$MAGENTA"
echo "Attenzione: verrà sovrascritto il contenuto di $DEVICE_DST!"
echo "Potrebbe richiedere molto tempo..."
echo "Verrà mostrato il progresso a schermo."
echo

TMP_LOG="/tmp/dd_restore_$$.log"
rm -f "$TMP_LOG" 2>/dev/null

if $IS_GZ; then
  # Il file è compresso: gunzip -c <file> | dd of=DEVICE
  gunzip -c "$IMAGE_FILE" 2>>"$TMP_LOG" | dd of="$DEVICE_DST" bs=4M conv=sync,noerror status=progress 2>&1 \
    | tee -a "$TMP_LOG"
else
  # File non compresso
  dd if="$IMAGE_FILE" of="$DEVICE_DST" bs=4M conv=sync,noerror status=progress 2>&1 \
    | tee "$TMP_LOG"
fi

############################################
# 9. Mostra e salva SOLO le ultime righe   #
############################################
echo
banner "FINE RIPRISTINO" "$GREEN"
echo "Salvataggio ultime righe del log in $LOGFILE..."
tail -n 20 "$TMP_LOG" > "$LOGFILE"
echo "Ecco un estratto del log finale:"
echo "-------------------------------------"
cat "$LOGFILE"
echo "-------------------------------------"

rm -f "$TMP_LOG"

################################
# 10. Spegnimento del sistema  #
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
