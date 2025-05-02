#!/bin/bash

#######################################################################
# SCRIPT 1: INSTALLAZIONE DEL SISTEMA PER AMBIENTE WEB CLAUDE CODE
# ---------------------------------------------------------------------
# Questo script configura le componenti di base del server web:
# - Apache + PHP
# - MySQL e phpMyAdmin
# - Permessi e utenti
# - Node.js e Claude Code
#
# Autore: Claude 3.7 Sonnet
# Data: 03/05/2025
#######################################################################

# Impostazioni principali
WEB_ROOT="/var/www/html"
APP_DIR="$WEB_ROOT"  # Claude Code scrive direttamente nella root
DEV_INTERFACE_DIR="/var/www/dev-interface"
DEV_INTERFACE_PORT=8081
CURRENT_USER=$(whoami)
CURRENT_IP=$(hostname -I | awk '{print $1}')
CONFIG_DIR="/opt/claude-env"

# Determina la home directory corretta dell'utente
if [ "$CURRENT_USER" = "root" ]; then
    HOME_DIR="/root"
else
    HOME_DIR="/home/$CURRENT_USER"
fi

# Funzione per stampare messaggi con formattazione
print_message() {
    echo -e "\n\033[1;34m🚀 $1\033[0m\n"
}

# Controllo se lo script è eseguito come root
if [ "$EUID" -ne 0 ]; then
  echo "⚠️ Questo script deve essere eseguito come root o con sudo"
  exit 1
fi

print_message "Inizializzazione configurazione server web per Claude Code"

#######################################################################
# CREAZIONE DIRECTORY DI CONFIGURAZIONE
#######################################################################

print_message "Creazione directory di configurazione"

# Crea la directory di configurazione
mkdir -p $CONFIG_DIR

#######################################################################
# INSTALLAZIONE PACCHETTI DI BASE
#######################################################################

# Aggiornamento sistema
print_message "Aggiornamento pacchetti"
apt update && apt upgrade -y

# Installazione pacchetti di base
print_message "Installazione pacchetti di base"
apt install -y curl git build-essential ripgrep unzip acl screen expect sudo

#######################################################################
# INSTALLAZIONE E CONFIGURAZIONE APACHE
#######################################################################

print_message "Installazione e configurazione di Apache"
apt install -y apache2
systemctl enable apache2
systemctl start apache2

# Installazione PHP
print_message "Installazione di PHP e moduli necessari"
apt install -y php libapache2-mod-php php-mysql php-mbstring php-zip php-gd php-json php-curl php-xml

# Configurazione del VirtualHost per l'interfaccia di sviluppo
print_message "Configurazione del VirtualHost per l'interfaccia di sviluppo (porta $DEV_INTERFACE_PORT)"
mkdir -p $DEV_INTERFACE_DIR

# Creazione file di configurazione VirtualHost
cat > /etc/apache2/sites-available/dev-interface.conf << EOF
<VirtualHost *:$DEV_INTERFACE_PORT>
    ServerAdmin webmaster@localhost
    DocumentRoot $DEV_INTERFACE_DIR
    ErrorLog \${APACHE_LOG_DIR}/dev-interface-error.log
    CustomLog \${APACHE_LOG_DIR}/dev-interface-access.log combined
    <Directory $DEV_INTERFACE_DIR>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    # Configurazione per phpMyAdmin
    Alias /phpmyadmin /usr/share/phpmyadmin
    <Directory /usr/share/phpmyadmin>
        Options SymLinksIfOwnerMatch
        DirectoryIndex index.php
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

# Configurazione porta per interfaccia di sviluppo
echo "Listen $DEV_INTERFACE_PORT" >> /etc/apache2/ports.conf

# Assicuriamoci che Apache ascolti su tutte le interfacce, non solo localhost
sed -i 's/Listen 80/Listen 0.0.0.0:80/' /etc/apache2/ports.conf

# Abilitazione sito e moduli
a2ensite dev-interface.conf
a2enmod rewrite

# Configurazione del firewall per consentire il traffico web
print_message "Configurazione del firewall"
apt install -y ufw
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 8081/tcp  # Interfaccia di sviluppo
echo "y" | ufw enable
ufw status

# Riavvio di Apache per applicare tutte le configurazioni
systemctl restart apache2

#######################################################################
# INSTALLAZIONE E CONFIGURAZIONE MYSQL E PHPMYADMIN
#######################################################################

print_message "Installazione e configurazione di MySQL"
# Genera password casuale sicura
DB_PASSWORD=$(openssl rand -base64 12)
echo "mysql-server mysql-server/root_password password $DB_PASSWORD" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $DB_PASSWORD" | debconf-set-selections
apt install -y mysql-server

# Configurazione base per sicurezza
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -e "FLUSH PRIVILEGES;"

# Installazione di phpMyAdmin
print_message "Installazione e configurazione di phpMyAdmin"
# Configurazione automatica
echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
echo "phpmyadmin phpmyadmin/app-password-confirm password $DB_PASSWORD" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/admin-pass password $DB_PASSWORD" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/app-pass password $DB_PASSWORD" | debconf-set-selections
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections
apt install -y phpmyadmin

# Configurazione aggiuntiva per phpMyAdmin su porta 8081
a2disconf phpmyadmin   # Disabilita il collegamento diretto su porta 80

# Salvataggio delle credenziali MySQL in un file sicuro
print_message "Salvataggio credenziali MySQL"
mkdir -p $CONFIG_DIR
cat > $CONFIG_DIR/mysql_credentials.conf << EOF
# Credenziali MySQL generate durante l'installazione
# Data: $(date +"%d/%m/%Y %H:%M:%S")
DB_USER="root"
DB_PASSWORD="$DB_PASSWORD"
EOF

# Impostazione permessi restrittivi sul file delle credenziali
chmod 600 $CONFIG_DIR/mysql_credentials.conf

#######################################################################
# CONFIGURAZIONE DIRECTORY E PERMESSI
#######################################################################

print_message "Configurazione delle directory per l'applicazione web"
# Rimozione file di default
rm -f $WEB_ROOT/index.html

# Crea gruppo per utenti web
groupadd web-editors 2>/dev/null || true

# Aggiunta dell'utente corrente ai gruppi necessari
usermod -a -G www-data $CURRENT_USER
usermod -a -G web-editors $CURRENT_USER

# Configurazione estesa dei permessi
print_message "Configurazione avanzata dei permessi per Apache e Claude Code"

# Aggiungiamo l'utente www-data al gruppo dell'utente corrente per migliorare l'interoperabilità
usermod -a -G $CURRENT_USER www-data
usermod -a -G web-editors www-data

# Configurazione dei permessi sulle directory web con approccio più permissivo
find $WEB_ROOT -type d -exec chmod 2775 {} \;  # SetGID bit per mantenere il gruppo
find $WEB_ROOT -type f -exec chmod 664 {} \;
chown -R $CURRENT_USER:web-editors $WEB_ROOT
chown -R $CURRENT_USER:web-editors $DEV_INTERFACE_DIR

# Configurazione ACL per permessi più granulari
setfacl -Rm d:u:$CURRENT_USER:rwx,d:g:www-data:rwx,d:g:web-editors:rwx,d:o:r-x $WEB_ROOT
setfacl -Rm u:$CURRENT_USER:rwx,g:www-data:rwx,g:web-editors:rwx,o:r-x $WEB_ROOT

# Configurazione umask per nuovi file
echo "umask 002" >> $HOME_DIR/.bashrc
echo "umask 002" >> $HOME_DIR/.profile

# Aggiungiamo sudo senza password per alcune operazioni di file system per l'utente corrente
# Questo permetterà all'editor web di modificare file con permessi elevati
cat > /etc/sudoers.d/web-editor << EOF
# Allow web editor to perform file operations without password
$CURRENT_USER ALL=(ALL) NOPASSWD: /bin/chown
$CURRENT_USER ALL=(ALL) NOPASSWD: /bin/chmod
$CURRENT_USER ALL=(ALL) NOPASSWD: /usr/bin/find
$CURRENT_USER ALL=(ALL) NOPASSWD: /usr/bin/setfacl
EOF
chmod 440 /etc/sudoers.d/web-editor

#######################################################################
# INSTALLAZIONE DI NODE.JS E CLAUDE CODE
#######################################################################

print_message "Installazione di Node.js a livello di sistema"
# Installiamo Node.js dalla repository ufficiale
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Verifica dell'installazione
node_version=$(node -v)
npm_version=$(npm -v)
echo "Node.js installato: $node_version"
echo "npm installato: $npm_version"

# Installazione di Claude Code
print_message "Installazione di Claude Code a livello di sistema"
npm install -g @anthropic-ai/claude-code

# Creazione di uno script wrapper per Claude Code
print_message "Creazione dello script wrapper per Claude Code"

cat > /usr/local/bin/claude-app << EOF
#!/bin/bash

# Script wrapper per Claude Code
# Questo script permette a Claude Code di lavorare nella directory dell'applicazione
# e imposta correttamente i permessi per i file creati

# Assicurati di essere nella directory dell'applicazione
cd $APP_DIR
umask 002

# Messaggio informativo
echo "=== Claude Code Wrapper ==="
echo "Directory: \$(pwd)"
echo "I file creati saranno disponibili su: http://$CURRENT_IP/"
echo "========================================="

# Esegui Claude Code
claude "\$@"

# Correzione permessi dopo l'esecuzione
sudo find $APP_DIR -type d -exec chmod 2775 {} \;
sudo find $APP_DIR -type f -exec chmod 664 {} \;
sudo chown -R $CURRENT_USER:web-editors $APP_DIR

echo "===================================="
echo "Permessi dei file aggiornati correttamente"
echo "Per visualizzare l'applicazione: http://$CURRENT_IP/"
echo "===================================="
EOF

chmod +x /usr/local/bin/claude-app

# Crea un alias per comodità
echo "alias claude-app='/usr/local/bin/claude-app'" >> $HOME_DIR/.bashrc

#######################################################################
# CREAZIONE PAGINA INIZIALE DELL'APPLICAZIONE
#######################################################################

print_message "Creazione della pagina iniziale dell'applicazione"

cat > $APP_DIR/index.php << EOF
<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Web App Claude Code</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
            color: #333;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background-color: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 0 15px rgba(0,0,0,0.1);
        }
        h1 {
            color: #2c3e50;
            margin-top: 0;
        }
        .info {
            background-color: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
            margin-top: 20px;
        }
        a {
            color: #3498db;
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
        .instructions {
            background-color: #e8f4ff;
            padding: 15px;
            border-radius: 5px;
            margin-top: 20px;
            border-left: 4px solid #3498db;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Web App Claude Code</h1>
        <p>Questa è la tua applicazione web sviluppata con Claude Code.</p>
        
        <div class="info">
            <h3>Informazioni di Sistema</h3>
            <p><strong>Server:</strong> <?php echo \$_SERVER['SERVER_SOFTWARE']; ?></p>
            <p><strong>PHP versione:</strong> <?php echo phpversion(); ?></p>
            <p><strong>Data e ora:</strong> <?php echo date('d/m/Y H:i:s'); ?></p>
            <p><strong>IP Server:</strong> <?php echo \$_SERVER['SERVER_ADDR']; ?></p>
        </div>
        
        <div class="instructions">
            <h3>Come utilizzare Claude Code</h3>
            <ol>
                <li>Connettiti al server via SSH</li>
                <li>Esegui il comando <code>claude-app</code> (alias di <code>/usr/local/bin/claude-app</code>)</li>
                <li>Utilizza l'interfaccia di Claude Code per creare la tua applicazione</li>
                <li>I file verranno automaticamente salvati nella directory principale</li>
            </ol>
            <p>Per visualizzare e modificare i file, usa l'interfaccia di sviluppo: 
               <a href="http://$CURRENT_IP:$DEV_INTERFACE_PORT" target="_blank">http://$CURRENT_IP:$DEV_INTERFACE_PORT</a>
            </p>
        </div>
    </div>
</body>
</html>
EOF

#######################################################################
# RIEPILOGO FINALE
#######################################################################

print_message "INSTALLAZIONE DI BASE COMPLETATA CON SUCCESSO!"

echo -e "\n\033[1;32m=== INFORMAZIONI DI ACCESSO ===\033[0m"
echo -e "\033[1mApplicazione Web:\033[0m http://$CURRENT_IP/"
echo -e "\033[1mPassword MySQL root:\033[0m $DB_PASSWORD"

echo -e "\n\033[1;32m=== PASSAGGI SUCCESSIVI ===\033[0m"
echo -e "Per completare l'installazione, esegui il secondo script:"
echo -e "sudo ./install-dev-interface.sh"

# Salvataggio delle informazioni in un file
cat > $HOME_DIR/informazioni_ambiente.txt << EOF
============================================================
  AMBIENTE DI SVILUPPO WEB CON CLAUDE CODE - INFORMAZIONI
============================================================

ACCESSI:
--------
Applicazione Web: http://$CURRENT_IP/
Interfaccia di Sviluppo: http://$CURRENT_IP:$DEV_INTERFACE_PORT/
phpMyAdmin: http://$CURRENT_IP:$DEV_INTERFACE_PORT/phpmyadmin/
Password MySQL root: $DB_PASSWORD

DIRECTORY:
----------
Applicazione Web: $APP_DIR
Interfaccia di Sviluppo: $DEV_INTERFACE_DIR
Directory configurazione: $CONFIG_DIR

UTILIZZO DI CLAUDE CODE:
-----------------------
Per utilizzare Claude Code, segui questi passi:

1. Connettiti al server via SSH
2. Esegui il comando: claude-app
3. Utilizza Claude Code normalmente
4. I file creati saranno accessibili via web

GESTIONE DEI PERMESSI:
---------------------
Il sistema è configurato con:
- L'utente $CURRENT_USER fa parte del gruppo www-data
- I file hanno permessi 664 (rw-rw-r--)
- Le directory hanno permessi 2775 (rwxrwxr-x + SetGID)
- ACL configurati per mantenere i permessi corretti sui nuovi file

============================================================
EOF

chmod 600 $HOME_DIR/informazioni_ambiente.txt
chown $CURRENT_USER:$CURRENT_USER $HOME_DIR/informazioni_ambiente.txt

echo -e "\nLe informazioni sono state salvate in: $HOME_DIR/informazioni_ambiente.txt"
echo -e "\nInstallazione del sistema completata. Ora puoi eseguire il secondo script per installare l'interfaccia di sviluppo."
