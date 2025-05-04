# Start 


# nano start.sh
# chmod +x start.sh
# sudo ./start.sh
 



# Per leggere le password del db
sudo cat /opt/claude-env/mysql_credentials.conf


#test per automatizzare l'installazione
wget -qO- https://raw.githubusercontent.com/danielesyrus/claude-code/main/install-system.sh | sudo bash
wget -qO- https://raw.githubusercontent.com/danielesyrus/claude-code/main/start.sh | sudo bash
