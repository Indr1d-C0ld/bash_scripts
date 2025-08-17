#!/bin/bash
#
# Script di aggiornamento driver NVIDIA su Kali Linux
# Autore: [tuo nome]
# Uso: sudo ./nvidia-upgrade.sh /percorso/NVIDIA-Linux-x86_64-XXX.XX.run

set -e

# Controllo privilegi
if [[ $EUID -ne 0 ]]; then
   echo "❌ Devi eseguire questo script come root (usa sudo)."
   exit 1
fi

# Controllo argomento
if [[ -z "$1" ]]; then
   echo "Uso: sudo $0 /percorso/NVIDIA-Linux-x86_64-XXX.XX.run"
   exit 1
fi

INSTALLER="$1"

if [[ ! -f "$INSTALLER" ]]; then
   echo "❌ File $INSTALLER non trovato!"
   exit 1
fi

echo "🔄 Aggiornamento sistema..."
apt update && apt full-upgrade -y

echo "🔧 Preparazione ambiente build..."
apt install -y build-essential dkms linux-headers-$(uname -r)

echo "🧹 Rimozione driver NVIDIA precedenti..."
systemctl stop lightdm || true
nvidia-uninstall --silent || true
apt purge -y 'nvidia-*' || true
apt autoremove --purge -y
update-initramfs -u

echo "🚫 Verifica blacklist Nouveau..."
BLACKLIST_FILE="/etc/modprobe.d/blacklist-nouveau.conf"
if ! grep -q "blacklist nouveau" "$BLACKLIST_FILE" 2>/dev/null; then
   echo "blacklist nouveau" > "$BLACKLIST_FILE"
   echo "options nouveau modeset=0" >> "$BLACKLIST_FILE"
   update-initramfs -u
   echo "✅ Nouveau disabilitato."
fi

echo "📦 Installazione driver NVIDIA da $INSTALLER..."
chmod +x "$INSTALLER"
bash "$INSTALLER" --silent --dkms --utility-prefix=/usr --opengl-prefix=/usr

echo "⚙️  Configurazione X11..."
nvidia-xconfig || true

echo "🚀 Riavvio LightDM..."
systemctl start lightdm

echo "✅ Installazione completata! Controlla con: nvidia-smi"
