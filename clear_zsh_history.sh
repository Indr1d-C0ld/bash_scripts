#!/bin/zsh
# Assicurati di essere nella home
cd ~

# Svuota il file .zsh_history
echo "" > .zsh_history

# Ricarica la cronologia in memoria
fc -R .zsh_history

echo "La cronologia zsh è stata cancellata e ricaricata in memoria."
