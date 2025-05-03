#!/bin/bash

# nano start.sh
# chmod +x start.sh
# sudo ./start.sh
# wget -qO- https://raw.githubusercontent.com/danielesyrus/claude-code/main/install-dev-interface.sh | sudo bash
#######################################################################
# SCRIPT DI INSTALLAZIONE COMBINATO PER AMBIENTE WEB CLAUDE CODE
# ---------------------------------------------------------------------
# Questo script scarica ed esegue automaticamente entrambi gli script:
# 1. install-system.sh - Installazione componenti di base
# 2. install-dev-interface.sh - Installazione interfaccia di sviluppo
#
# Autore: Claude 3.7 Sonnet
# Data: 03/05/2025
#######################################################################

# Colori per output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Repository GitHub
GITHUB_REPO="https://raw.githubusercontent.com/danielesyrus/claude-code/main"

# Funzione per stampare messaggi con formattazione
print_message() {
    echo -e "\n${BLUE}🚀 $1${NC}\n"
}

print_error() {
    echo -e "\n${RED}❌ $1${NC}\n"
}

print_success() {
    echo -e "\n${GREEN}✅ $1${NC}\n"
}

print_warning() {
    echo -e "\n${YELLOW}⚠️ $1${NC}\n"
}

# Controllo se lo script è eseguito come root
if [ "$EUID" -ne 0 ]; then
  print_error "Questo script deve essere eseguito come root o con sudo"
  exit 1
fi

print_message "INSTALLAZIONE AMBIENTE CLAUDE CODE"
print_message "Questo script installerà tutti i componenti necessari per l'ambiente Claude Code"

# Verifica se curl è installato
if ! command -v curl &> /dev/null; then
    print_warning "curl non è installato. Installazione in corso..."
    apt update
    apt install -y curl
    
    if [ $? -ne 0 ]; then
        print_error "Impossibile installare curl. Installazione interrotta."
        exit 1
    fi
    
    print_success "curl installato con successo!"
fi

# Crea una directory temporanea
TMP_DIR=$(mktemp -d)
print_message "Directory temporanea creata: $TMP_DIR"

# Cleanup alla fine dell'esecuzione
cleanup() {
    print_message "Pulizia dei file temporanei..."
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Download del primo script
print_message "Download del primo script (Installazione Sistema)..."
curl -sSL "$GITHUB_REPO/install-system.sh" -o "$TMP_DIR/install-system.sh"

if [ $? -ne 0 ]; then
    print_error "Errore nel download del primo script. Installazione interrotta."
    exit 1
fi

# Rendi eseguibile il primo script
chmod +x "$TMP_DIR/install-system.sh"

# Esegui il primo script
print_message "Avvio installazione del sistema base..."
$TMP_DIR/install-system.sh

# Verifica che l'installazione del sistema base sia andata a buon fine
if [ $? -ne 0 ]; then
    print_error "Errore nell'installazione del sistema base. Installazione interrotta."
    exit 1
fi

print_success "Installazione del sistema base completata con successo!"

# Download del secondo script
print_message "Download del secondo script (Installazione Interfaccia di Sviluppo)..."
curl -sSL "$GITHUB_REPO/install-dev-interface.sh" -o "$TMP_DIR/install-dev-interface.sh"

if [ $? -ne 0 ]; then
    print_error "Errore nel download del secondo script. Installazione interrotta."
    exit 1
fi

# Rendi eseguibile il secondo script
chmod +x "$TMP_DIR/install-dev-interface.sh"

# Esegui il secondo script
print_message "Avvio installazione dell'interfaccia di sviluppo..."
$TMP_DIR/install-dev-interface.sh

# Verifica che l'installazione dell'interfaccia di sviluppo sia andata a buon fine
if [ $? -ne 0 ]; then
    print_error "Errore nell'installazione dell'interfaccia di sviluppo."
    exit 1
fi

print_success "Installazione dell'interfaccia di sviluppo completata con successo!"

print_message "============================================================"
print_message "              INSTALLAZIONE COMPLETATA!"
print_message "============================================================"
print_message "Il tuo ambiente Claude Code è ora pronto all'uso!"
print_message "Per utilizzare Claude Code:"
echo -e "  1. Connettiti al server via SSH"
echo -e "  2. Esegui il comando: \033[1mclaude-app\033[0m"
echo -e "  3. I file creati saranno disponibili nell'applicazione web"
print_message "============================================================"
print_message "Si consiglia di riavviare il server per assicurarsi che"
print_message "tutte le modifiche siano applicate correttamente."
print_message "Comando: sudo reboot"
print_message "============================================================"

exit 0
