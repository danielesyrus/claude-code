#!/bin/bash

#######################################################################
# SCRIPT 2: INSTALLAZIONE DELL'INTERFACCIA DI SVILUPPO
# ---------------------------------------------------------------------
# Questo script installa l'interfaccia web di sviluppo per Claude Code:
# - File manager avanzato
# - Editor di codice integrato
# - Preview browser
# - Integrazione con phpMyAdmin
#
# Autore: Claude 3.7 Sonnet
# Data: 03/05/2025
#######################################################################

# Impostazioni principali
WEB_ROOT="/var/www/html"
APP_DIR="$WEB_ROOT"
DEV_INTERFACE_DIR="/var/www/dev-interface"
DEV_INTERFACE_PORT=8081
CURRENT_USER=$(whoami)
CURRENT_IP=$(hostname -I | awk '{print $1}')
CONFIG_DIR="/opt/claude-env"

# Funzione per stampare messaggi con formattazione
print_message() {
    echo -e "\n\033[1;34m🚀 $1\033[0m\n"
}

# Controllo se lo script è eseguito come root
if [ "$EUID" -ne 0 ]; then
  echo "⚠️ Questo script deve essere eseguito come root o con sudo"
  exit 1
fi

# Verifica se esiste il file di configurazione
if [ ! -f "$CONFIG_DIR/mysql_credentials.conf" ]; then
  echo "⚠️ File di configurazione non trovato. Esegui prima lo script di installazione del sistema."
  exit 1
fi

# Carica le credenziali MySQL
source "$CONFIG_DIR/mysql_credentials.conf"

print_message "Installazione dell'interfaccia di sviluppo per Claude Code"

#######################################################################
# CREAZIONE DEL FILE-MANAGER.PHP MIGLIORATO
#######################################################################

print_message "Creazione del file manager PHP migliorato"

cat > $DEV_INTERFACE_DIR/file-manager.php << 'EOFPHP'
<?php
// File manager avanzato per l'interfaccia web con supporto per tutti i file
session_start();

// Impostazioni
$APP_DIR = '/var/www/html';
$SUDO_ENABLED = true;  // Abilita l'uso di sudo per operazioni specifiche
$CONFIG_DIR = '/opt/claude-env';

// Funzione per eseguire comandi shell in modo sicuro
function executeCommand($command, $useSudo = false) {
    $prefix = $useSudo ? 'sudo ' : '';
    $fullCommand = $prefix . escapeshellcmd($command) . ' 2>&1';
    
    exec($fullCommand, $output, $return_var);
    
    return [
        'output' => implode("\n", $output),
        'status' => $return_var
    ];
}

// Funzione per controllare se un file è protetto
function isSystemFile($path) {
    $systemPatterns = [
        '/^\/etc\//',
        '/^\/boot\//',
        '/^\/bin\//',
        '/^\/sbin\//',
        '/^\/usr\/bin\//',
        '/^\/usr\/sbin\//',
        '/^\/lib\//',
        '/^\/lib64\//',
        '/^\/usr\/lib\//',
        '/^\/opt\//',
        '/^\/root\//',
        '/^\/proc\//',
        '/^\/sys\//',
        '/^\/dev\//'
    ];
    
    foreach ($systemPatterns as $pattern) {
        if (preg_match($pattern, $path)) {
            return true;
        }
    }
    
    return false;
}

// Funzione per ottenere l'estensione di un file
function getFileExtension($filename) {
    return pathinfo($filename, PATHINFO_EXTENSION);
}

// Funzione per determinare l'icona in base all'estensione
function getFileIcon($filename) {
    $ext = strtolower(getFileExtension($filename));
    
    $iconMap = [
        'html' => 'html',
        'htm' => 'html',
        'css' => 'css',
        'js' => 'js',
        'json' => 'json',
        'php' => 'php',
        'md' => 'markdown',
        'sql' => 'database',
        'py' => 'python',
        'jpg' => 'image',
        'jpeg' => 'image',
        'png' => 'image',
        'gif' => 'image',
        'svg' => 'image',
        'pdf' => 'pdf',
        'txt' => 'alt',
        'doc' => 'word',
        'docx' => 'word',
        'xls' => 'excel',
        'xlsx' => 'excel',
        'ppt' => 'powerpoint',
        'pptx' => 'powerpoint',
        'sh' => 'terminal',
        'bash' => 'terminal',
        'conf' => 'cogs',
        'ini' => 'cogs',
        'xml' => 'code',
        'yaml' => 'code',
        'yml' => 'code'
    ];
    
    return isset($iconMap[$ext]) ? $iconMap[$ext] : 'code';
}

// Funzione per ottenere la grandezza di un file in formato leggibile
function getReadableFileSize($size) {
    $units = ['B', 'KB', 'MB', 'GB', 'TB'];
    $i = 0;
    while ($size >= 1024 && $i < count($units) - 1) {
        $size /= 1024;
        $i++;
    }
    return round($size, 2) . ' ' . $units[$i];
}

// Funzione per ottenere i permessi di un file in formato leggibile
function getFilePermissions($path) {
    if (!file_exists($path)) {
        return 'Sconosciuto';
    }
    
    $perms = fileperms($path);
    
    switch ($perms & 0xF000) {
        case 0xC000: // socket
            $info = 's';
            break;
        case 0xA000: // collegamento simbolico
            $info = 'l';
            break;
        case 0x8000: // regolare
            $info = '-';
            break;
        case 0x6000: // blocco speciale
            $info = 'b';
            break;
        case 0x4000: // directory
            $info = 'd';
            break;
        case 0x2000: // carattere speciale
            $info = 'c';
            break;
        case 0x1000: // fifo pipe
            $info = 'p';
            break;
        default: // sconosciuto
            $info = 'u';
    }
    
    // Proprietario
    $info .= (($perms & 0x0100) ? 'r' : '-');
    $info .= (($perms & 0x0080) ? 'w' : '-');
    $info .= (($perms & 0x0040) ?
                (($perms & 0x0800) ? 's' : 'x' ) :
                (($perms & 0x0800) ? 'S' : '-'));
    
    // Gruppo
    $info .= (($perms & 0x0020) ? 'r' : '-');
    $info .= (($perms & 0x0010) ? 'w' : '-');
    $info .= (($perms & 0x0008) ?
                (($perms & 0x0400) ? 's' : 'x' ) :
                (($perms & 0x0400) ? 'S' : '-'));
    
    // Altri
    $info .= (($perms & 0x0004) ? 'r' : '-');
    $info .= (($perms & 0x0002) ? 'w' : '-');
    $info .= (($perms & 0x0001) ?
                (($perms & 0x0200) ? 't' : 'x' ) :
                (($perms & 0x0200) ? 'T' : '-'));
    
    return $info;
}

// Funzione per ottenere i dettagli completi di un file
function getFileDetails($path) {
    if (!file_exists($path)) {
        return [
            'exists' => false,
            'error' => 'File non trovato'
        ];
    }
    
    $isDir = is_dir($path);
    $size = $isDir ? '-' : getReadableFileSize(filesize($path));
    $permissions = getFilePermissions($path);
    $owner = posix_getpwuid(fileowner($path))['name'];
    $group = posix_getgrgid(filegroup($path))['name'];
    $lastModified = date('Y-m-d H:i:s', filemtime($path));
    $isWritable = is_writable($path);
    $isReadable = is_readable($path);
    $isExecutable = is_executable($path);
    $isSystem = isSystemFile($path);
    
    return [
        'exists' => true,
        'path' => $path,
        'name' => basename($path),
        'type' => $isDir ? 'directory' : 'file',
        'size' => $size,
        'permissions' => $permissions,
        'owner' => $owner,
        'group' => $group,
        'last_modified' => $lastModified,
        'is_writable' => $isWritable,
        'is_readable' => $isReadable,
        'is_executable' => $isExecutable,
        'is_system' => $isSystem,
        'icon' => $isDir ? 'folder' : getFileIcon(basename($path))
    ];
}

// Funzione per ottenere le credenziali MySQL dal file di configurazione
function getMySQLCredentials() {
    global $CONFIG_DIR;
    $credentialsFile = $CONFIG_DIR . '/mysql_credentials.conf';
    
    if (!file_exists($credentialsFile)) {
        return [
            'error' => 'File di credenziali non trovato'
        ];
    }
    
    $content = file_get_contents($credentialsFile);
    $credentials = [];
    
    // Estrazione delle credenziali con espressioni regolari
    if (preg_match('/DB_USER="([^"]+)"/', $content, $matches)) {
        $credentials['user'] = $matches[1];
    }
    
    if (preg_match('/DB_PASSWORD="([^"]+)"/', $content, $matches)) {
        $credentials['password'] = $matches[1];
    }
    
    return $credentials;
}

// Gestione delle richieste GET
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $action = isset($_GET['action']) ? $_GET['action'] : 'list';
    
    // Ottieni credenziali MySQL
    if ($action === 'get_mysql_credentials') {
        $credentials = getMySQLCredentials();
        
        header('Content-Type: application/json');
        echo json_encode($credentials);
        exit;
    }
    
    // Lettura di un file
    if ($action === 'read' && isset($_GET['file'])) {
        $filePath = $_GET['file'];
        
        if (!file_exists($filePath)) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'File non trovato']);
            exit;
        }
        
        if (is_dir($filePath)) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Il percorso è una directory']);
            exit;
        }
        
        if (!is_readable($filePath)) {
            // Se il file non è leggibile normalmente, prova a usare sudo
            if ($SUDO_ENABLED) {
                $result = executeCommand("cat " . escapeshellarg($filePath), true);
                
                if ($result['status'] === 0) {
                    header('Content-Type: application/json');
                    echo json_encode([
                        'success' => true,
                        'content' => $result['output'],
                        'sudo_used' => true
                    ]);
                    exit;
                }
            }
            
            header('Content-Type: application/json');
            echo json_encode(['error' => 'File non leggibile']);
            exit;
        }
        
        $content = file_get_contents($filePath);
        
        header('Content-Type: application/json');
        echo json_encode([
            'success' => true,
            'content' => $content
        ]);
        exit;
    }
    
    // Ottenere i dettagli di un file
    if ($action === 'details' && isset($_GET['file'])) {
        $filePath = $_GET['file'];
        $details = getFileDetails($filePath);
        
        header('Content-Type: application/json');
        echo json_encode($details);
        exit;
    }
    
    // Elenco dei file in una directory
    if ($action === 'list') {
        $directory = isset($_GET['dir']) ? $_GET['dir'] : $APP_DIR;
        
        // Assicurati che il percorso sia valido
        if (!file_exists($directory) || !is_dir($directory)) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Directory non trovata']);
            exit;
        }
        
        // Se la directory non è leggibile normalmente, prova a usare sudo
        if (!is_readable($directory)) {
            if ($SUDO_ENABLED) {
                $files = [];
                $result = executeCommand("ls -la " . escapeshellarg($directory), true);
                
                if ($result['status'] === 0) {
                    // Parsing dell'output di ls -la
                    $lines = explode("\n", $result['output']);
                    array_shift($lines); // Rimuovi la prima riga (totale)
                    
                    foreach ($lines as $line) {
                        if (empty(trim($line))) continue;
                        
                        $parts = preg_split('/\s+/', $line, 9);
                        if (count($parts) >= 9) {
                            $permissions = $parts[0];
                            $owner = $parts[2];
                            $group = $parts[3];
                            $size = $parts[4];
                            $fileName = $parts[8];
                            
                            // Ignora . e ..
                            if ($fileName === '.' || $fileName === '..') continue;
                            
                            $isDir = $permissions[0] === 'd';
                            $path = rtrim($directory, '/') . '/' . $fileName;
                            
                            $files[] = [
                                'name' => $fileName,
                                'path' => $path,
                                'size' => $isDir ? '-' : $size,
                                'type' => $isDir ? 'directory' : 'file',
                                'icon' => $isDir ? 'folder' : getFileIcon($fileName),
                                'permissions' => $permissions,
                                'owner' => $owner,
                                'group' => $group,
                                'is_readable' => strpos($permissions, 'r') !== false,
                                'is_writable' => strpos($permissions, 'w') !== false,
                                'is_system' => isSystemFile($path)
                            ];
                        }
                    }
                    
                    header('Content-Type: application/json');
                    echo json_encode($files);
                    exit;
                }
            }
            
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Directory non leggibile']);
            exit;
        }
        
        $files = [];
        $directories = [];
        
        foreach (new DirectoryIterator($directory) as $fileInfo) {
            if ($fileInfo->isDot()) continue;
            
            $path = $fileInfo->getPathname();
            $isDir = $fileInfo->isDir();
            $size = $isDir ? '-' : getReadableFileSize($fileInfo->getSize());
            $permissions = getFilePermissions($path);
            $owner = posix_getpwuid(fileowner($path))['name'];
            $group = posix_getgrgid(filegroup($path))['name'];
            $lastModified = date('Y-m-d H:i:s', $fileInfo->getMTime());
            $isWritable = is_writable($path);
            $isReadable = is_readable($path);
            $isExecutable = is_executable($path);
            $isSystem = isSystemFile($path);
            
            $fileData = [
                'name' => $fileInfo->getFilename(),
                'path' => $path,
                'size' => $size,
                'type' => $isDir ? 'directory' : 'file',
                'icon' => $isDir ? 'folder' : getFileIcon($fileInfo->getFilename()),
                'permissions' => $permissions,
                'owner' => $owner,
                'group' => $group,
                'last_modified' => $lastModified,
                'is_writable' => $isWritable,
                'is_readable' => $isReadable,
                'is_executable' => $isExecutable,
                'is_system' => $isSystem
            ];
            
            if ($isDir) {
                $directories[] = $fileData;
            } else {
                $files[] = $fileData;
            }
        }
        
        // Ordina directories prima e poi i file, entrambi in ordine alfabetico
        usort($directories, function($a, $b) {
            return strcasecmp($a['name'], $b['name']);
        });
        
        usort($files, function($a, $b) {
            return strcasecmp($a['name'], $b['name']);
        });
        
        $allFiles = array_merge($directories, $files);
        
        header('Content-Type: application/json');
        echo json_encode($allFiles);
        exit;
    }
    
    // Ricerca di file
    if ($action === 'search' && isset($_GET['query'])) {
        $query = $_GET['query'];
        $directory = isset($_GET['dir']) ? $_GET['dir'] : $APP_DIR;
        
        if (strlen($query) < 2) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Query di ricerca troppo breve']);
            exit;
        }
        
        $escapedQuery = escapeshellarg($query);
        $escapedDir = escapeshellarg($directory);
        
        $command = "find $escapedDir -type f -name \"*$escapedQuery*\" -o -type d -name \"*$escapedQuery*\" | sort";
        $result = executeCommand($command);
        
        if ($result['status'] !== 0) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Errore nella ricerca: ' . $result['output']]);
            exit;
        }
        
        $paths = explode("\n", $result['output']);
        $results = [];
        
        foreach ($paths as $path) {
            if (empty(trim($path))) continue;
            
            $isDir = is_dir($path);
            
            $results[] = [
                'name' => basename($path),
                'path' => $path,
                'type' => $isDir ? 'directory' : 'file',
                'icon' => $isDir ? 'folder' : getFileIcon(basename($path))
            ];
        }
        
        header('Content-Type: application/json');
        echo json_encode($results);
        exit;
    }
    
    // Manutenzione: correzione permessi
    if ($action === 'fix_permissions') {
        if (!$SUDO_ENABLED) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Operazione non consentita senza sudo']);
            exit;
        }
        
        $directory = isset($_GET['dir']) ? $_GET['dir'] : $APP_DIR;
        $escapedDir = escapeshellarg($directory);
        
        $commands = [
            "find $escapedDir -type d -exec chmod 2775 {} \\;",
            "find $escapedDir -type f -exec chmod 664 {} \\;",
            "chown -R www-data:web-editors $escapedDir"
        ];
        
        $results = [];
        $success = true;
        
        foreach ($commands as $command) {
            $result = executeCommand($command, true);
            $results[] = $result;
            
            if ($result['status'] !== 0) {
                $success = false;
            }
        }
        
        header('Content-Type: application/json');
        echo json_encode([
            'success' => $success,
            'results' => $results
        ]);
        exit;
    }
    
    // Manutenzione: pulizia file temporanei
    if ($action === 'cleanup_tmp') {
        if (!$SUDO_ENABLED) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Operazione non consentita senza sudo']);
            exit;
        }
        
        $tmpDirs = ['/tmp', '/var/tmp'];
        $results = [];
        $success = true;
        
        foreach ($tmpDirs as $dir) {
            $escapedDir = escapeshellarg($dir);
            $command = "find $escapedDir -type f -name \"*.tmp\" -o -name \"*.temp\" -o -name \"*.bak\" -mtime +7 -delete";
            
            $result = executeCommand($command, true);
            $results[] = $result;
            
            if ($result['status'] !== 0) {
                $success = false;
            }
        }
        
        header('Content-Type: application/json');
        echo json_encode([
            'success' => $success,
            'results' => $results
        ]);
        exit;
    }
}

// Gestione delle richieste POST
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = isset($_POST['action']) ? $_POST['action'] : '';
    
    // Creazione di un nuovo file
    if ($action === 'create' && isset($_POST['file'])) {
        $directory = isset($_POST['dir']) ? $_POST['dir'] : $APP_DIR;
        $fileName = basename($_POST['file']);
        $filePath = rtrim($directory, '/') . '/' . $fileName;
        
        if (file_exists($filePath)) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Il file esiste già']);
            exit;
        }
        
        // Verifica se la directory è scrivibile
        if (!is_writable(dirname($filePath))) {
            if ($SUDO_ENABLED) {
                $command = "touch " . escapeshellarg($filePath);
                $result = executeCommand($command, true);
                
                if ($result['status'] === 0) {
                    // Imposta i permessi corretti
                    executeCommand("chmod 664 " . escapeshellarg($filePath), true);
                    executeCommand("chown www-data:web-editors " . escapeshellarg($filePath), true);
                    
                    header('Content-Type: application/json');
                    echo json_encode(['success' => true, 'sudo_used' => true]);
                    exit;
                } else {
                    header('Content-Type: application/json');
                    echo json_encode(['error' => 'Errore nella creazione del file: ' . $result['output']]);
                    exit;
                }
            } else {
                header('Content-Type: application/json');
                echo json_encode(['error' => 'Directory non scrivibile']);
                exit;
            }
        }
        
        if (file_put_contents($filePath, '') !== false) {
            // Imposta i permessi corretti
            chmod($filePath, 0664);
            chown($filePath, 'www-data');
            chgrp($filePath, 'web-editors');
            
            header('Content-Type: application/json');
            echo json_encode(['success' => true]);
            exit;
        } else {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Errore nella creazione del file']);
            exit;
        }
    }
    
    // Creazione di una nuova directory
    if ($action === 'create_dir' && isset($_POST['dir']) && isset($_POST['name'])) {
        $parentDir = $_POST['dir'];
        $dirName = basename($_POST['name']);
        $dirPath = rtrim($parentDir, '/') . '/' . $dirName;
        
        if (file_exists($dirPath)) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'La directory esiste già']);
            exit;
        }
        
        if (!is_writable($parentDir)) {
            if ($SUDO_ENABLED) {
                $command = "mkdir -p " . escapeshellarg($dirPath);
                $result = executeCommand($command, true);
                
                if ($result['status'] === 0) {
                    // Imposta i permessi corretti
                    executeCommand("chmod 2775 " . escapeshellarg($dirPath), true);
                    executeCommand("chown www-data:web-editors " . escapeshellarg($dirPath), true);
                    
                    header('Content-Type: application/json');
                    echo json_encode(['success' => true, 'sudo_used' => true]);
                    exit;
                } else {
                    header('Content-Type: application/json');
                    echo json_encode(['error' => 'Errore nella creazione della directory: ' . $result['output']]);
                    exit;
                }
            } else {
                header('Content-Type: application/json');
                echo json_encode(['error' => 'Directory non scrivibile']);
                exit;
            }
        }
        
        if (mkdir($dirPath, 0775, true)) {
            // Imposta i permessi corretti
            chmod($dirPath, 02775);  // 2775 in ottale con SetGID
            chown($dirPath, 'www-data');
            chgrp($dirPath, 'web-editors');
            
            header('Content-Type: application/json');
            echo json_encode(['success' => true]);
            exit;
        } else {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Errore nella creazione della directory']);
            exit;
        }
    }
    
    // Salvataggio di un file
    if ($action === 'save' && isset($_POST['file']) && isset($_POST['content'])) {
        $filePath = $_POST['file'];
        $content = $_POST['content'];
        $useSudo = isset($_POST['sudo']) && $_POST['sudo'] === 'true';
        
        // Controllo dell'esistenza del file
        if (!file_exists($filePath) && !$useSudo) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'File non trovato']);
            exit;
        }
        
        // Se il file non è scrivibile e sudo è abilitato, usalo
        if ((!file_exists($filePath) || !is_writable($filePath)) && $useSudo && $SUDO_ENABLED) {
            // Crea un file temporaneo
            $tempFile = tempnam(sys_get_temp_dir(), 'edit_');
            file_put_contents($tempFile, $content);
            
            // Copia il contenuto nel file di destinazione usando sudo
            $command = "cat " . escapeshellarg($tempFile) . " | sudo tee " . escapeshellarg($filePath) . " > /dev/null";
            $result = executeCommand($command);
            
            // Rimuovi il file temporaneo
            unlink($tempFile);
            
            if ($result['status'] === 0) {
                header('Content-Type: application/json');
                echo json_encode(['success' => true, 'sudo_used' => true]);
                exit;
            } else {
                header('Content-Type: application/json');
                echo json_encode(['error' => 'Errore nel salvataggio del file con sudo: ' . $result['output']]);
                exit;
            }
        }
        
        // Salvataggio normale
        if (is_writable($filePath) || is_writable(dirname($filePath))) {
            if (file_put_contents($filePath, $content) !== false) {
                // Se è un nuovo file, imposta i permessi corretti
                if (!file_exists($filePath)) {
                    chmod($filePath, 0664);
                    chown($filePath, 'www-data');
                    chgrp($filePath, 'web-editors');
                }
                
                header('Content-Type: application/json');
                echo json_encode(['success' => true]);
                exit;
            } else {
                header('Content-Type: application/json');
                echo json_encode(['error' => 'Errore nel salvataggio del file']);
                exit;
            }
        } else {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'File non scrivibile']);
            exit;
        }
    }
    
    // Eliminazione di un file o directory
    if ($action === 'delete' && isset($_POST['path'])) {
        $path = $_POST['path'];
        
        if (!file_exists($path)) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Percorso non trovato']);
            exit;
        }
        
        $isDir = is_dir($path);
        
        // Se non è scrivibile e sudo è abilitato, usalo
        if (!is_writable($path) && $SUDO_ENABLED) {
            $command = $isDir ? 
                       "rm -rf " . escapeshellarg($path) : 
                       "rm " . escapeshellarg($path);
            
            $result = executeCommand($command, true);
            
            if ($result['status'] === 0) {
                header('Content-Type: application/json');
                echo json_encode(['success' => true, 'sudo_used' => true]);
                exit;
            } else {
                header('Content-Type: application/json');
                echo json_encode(['error' => 'Errore nell\'eliminazione con sudo: ' . $result['output']]);
                exit;
            }
        }
        
        // Eliminazione normale
        if ($isDir) {
            // Elimina la directory ricorsivamente
            function rrmdir($dir) {
                if (is_dir($dir)) {
                    $objects = scandir($dir);
                    foreach ($objects as $object) {
                        if ($object != "." && $object != "..") {
                            if (is_dir($dir . "/" . $object)) {
                                rrmdir($dir . "/" . $object);
                            } else {
                                unlink($dir . "/" . $object);
                            }
                        }
                    }
                    rmdir($dir);
                    return true;
                }
                return false;
            }
            
            if (rrmdir($path)) {
                header('Content-Type: application/json');
                echo json_encode(['success' => true]);
                exit;
            } else {
                header('Content-Type: application/json');
                echo json_encode(['error' => 'Errore nell\'eliminazione della directory']);
                exit;
            }
        } else {
            // Elimina il file
            if (unlink($path)) {
                header('Content-Type: application/json');
                echo json_encode(['success' => true]);
                exit;
            } else {
                header('Content-Type: application/json');
                echo json_encode(['error' => 'Errore nell\'eliminazione del file']);
                exit;
            }
        }
    }
    
    // Rinomina un file o directory
    if ($action === 'rename' && isset($_POST['old_path']) && isset($_POST['new_name'])) {
        $oldPath = $_POST['old_path'];
        $newName = basename($_POST['new_name']);
        $newPath = dirname($oldPath) . '/' . $newName;
        
        if (!file_exists($oldPath)) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'File o directory non trovato']);
            exit;
        }
        
        if (file_exists($newPath)) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Esiste già un file o directory con questo nome']);
            exit;
        }
        
        // Se non è scrivibile e sudo è abilitato, usalo
        if ((!is_writable($oldPath) || !is_writable(dirname($oldPath))) && $SUDO_ENABLED) {
            $command = "mv " . escapeshellarg($oldPath) . " " . escapeshellarg($newPath);
            $result = executeCommand($command, true);
            
            if ($result['status'] === 0) {
                header('Content-Type: application/json');
                echo json_encode(['success' => true, 'new_path' => $newPath, 'sudo_used' => true]);
                exit;
            } else {
                header('Content-Type: application/json');
                echo json_encode(['error' => 'Errore nella rinomina con sudo: ' . $result['output']]);
                exit;
            }
        }
        
        // Rinomina normalmente
        if (rename($oldPath, $newPath)) {
            header('Content-Type: application/json');
            echo json_encode(['success' => true, 'new_path' => $newPath]);
            exit;
        } else {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Errore nella rinomina']);
            exit;
        }
    }
    
    // Caricamento file
    if ($action === 'upload' && isset($_FILES['file'])) {
        $directory = isset($_POST['dir']) ? $_POST['dir'] : $APP_DIR;
        $file = $_FILES['file'];
        
        if ($file['error'] !== UPLOAD_ERR_OK) {
            $errors = [
                UPLOAD_ERR_INI_SIZE => 'Il file supera la dimensione massima consentita',
                UPLOAD_ERR_FORM_SIZE => 'Il file supera la dimensione massima specificata nel form',
                UPLOAD_ERR_PARTIAL => 'Il file è stato caricato solo parzialmente',
                UPLOAD_ERR_NO_FILE => 'Nessun file è stato caricato',
                UPLOAD_ERR_NO_TMP_DIR => 'Directory temporanea mancante',
                UPLOAD_ERR_CANT_WRITE => 'Impossibile scrivere il file su disco',
                UPLOAD_ERR_EXTENSION => 'Caricamento interrotto da un\'estensione'
            ];
            
            $error = isset($errors[$file['error']]) ? $errors[$file['error']] : 'Errore sconosciuto';
            
            header('Content-Type: application/json');
            echo json_encode(['error' => $error]);
            exit;
        }
        
        $fileName = basename($file['name']);
        $targetPath = rtrim($directory, '/') . '/' . $fileName;
        
        // Verifica se la directory è scrivibile
        if (!is_writable($directory)) {
            if ($SUDO_ENABLED) {
                // Copia il file in posizione temporanea
                $tempFile = tempnam(sys_get_temp_dir(), 'upload_');
                move_uploaded_file($file['tmp_name'], $tempFile);
                
                // Usa sudo per spostarlo nella destinazione finale
                $command = "cp " . escapeshellarg($tempFile) . " " . escapeshellarg($targetPath);
                $result = executeCommand($command, true);
                
                // Rimuovi il file temporaneo
                unlink($tempFile);
                
                if ($result['status'] === 0) {
                    // Imposta i permessi corretti
                    executeCommand("chmod 664 " . escapeshellarg($targetPath), true);
                    executeCommand("chown www-data:web-editors " . escapeshellarg($targetPath), true);
                    
                    header('Content-Type: application/json');
                    echo json_encode(['success' => true, 'sudo_used' => true]);
                    exit;
                } else {
                    header('Content-Type: application/json');
                    echo json_encode(['error' => 'Errore nel caricamento del file con sudo: ' . $result['output']]);
                    exit;
                }
            } else {
                header('Content-Type: application/json');
                echo json_encode(['error' => 'Directory non scrivibile']);
                exit;
            }
        }
        
        // Caricamento normale
        if (move_uploaded_file($file['tmp_name'], $targetPath)) {
            chmod($targetPath, 0664);
            
            header('Content-Type: application/json');
            echo json_encode(['success' => true]);
            exit;
        } else {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Errore nel caricamento del file']);
            exit;
        }
    }
}

// Se siamo arrivati qui, l'azione richiesta non è valida
header('Content-Type: application/json');
echo json_encode(['error' => 'Azione non valida']);
EOFPHP

#######################################################################
# CREAZIONE DELL'INTERFACCIA WEB SEMPLIFICATA (2 COLONNE)
#######################################################################

print_message "Creazione dell'interfaccia web semplificata con File Explorer e Browser Preview"

cat > $DEV_INTERFACE_DIR/index.html << 'EOFHTML'
<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Claude Code IDE</title>
    
    <!-- Bootstrap CSS -->
    <link href="https://cdnjs.cloudflare.com/ajax/libs/bootstrap/5.3.0/css/bootstrap.min.css" rel="stylesheet">
    
    <!-- Font Awesome -->
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" rel="stylesheet">
    
    <!-- CodeMirror (editor di codice) -->
    <link href="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/codemirror.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/theme/monokai.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/search/matchesonscrollbar.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/dialog/dialog.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/hint/show-hint.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/fold/foldgutter.min.css" rel="stylesheet">
    
    <style>
        body, html {
            height: 100%;
            overflow: hidden;
        }
        
        .main-container {
            height: 100vh;
            display: flex;
            overflow: hidden;
        }
        
        .column {
            height: 100%;
            overflow: hidden;
            padding: 0;
            position: relative;
        }
        
        .column-left {
            width: 40%;
            border-right: 1px solid #dee2e6;
        }
        
        .column-right {
            width: 60%;
        }
        
        .panel {
            border: 1px solid #dee2e6;
            border-radius: 4px;
            background-color: #fff;
            overflow: hidden;
            position: relative;
            height: 100%;
        }
        
        .panel-header {
            background-color: #f8f9fa;
            padding: 10px;
            border-bottom: 1px solid #dee2e6;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .file-explorer {
            height: calc(100% - 50px);
            overflow: auto;
        }
        
        .file-list {
            list-style: none;
            padding: 0;
            margin: 0;
        }
        
        .file-list li {
            padding: 8px 15px;
            border-bottom: 1px solid #dee2e6;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }
        
        .file-list li:hover {
            background-color: #f8f9fa;
        }
        
        .file-list li i {
            margin-right: 10px;
        }
        
        .file-actions {
            display: flex;
            gap: 8px;
            opacity: 0.3;
            transition: opacity 0.2s;
        }
        
        .file-list li:hover .file-actions {
            opacity: 1;
        }
        
        .file-action-btn {
            background: none;
            border: none;
            color: #6c757d;
            cursor: pointer;
            padding: 0;
            font-size: 14px;
        }
        
        .file-action-btn:hover {
            color: #212529;
        }
        
        .file-name {
            display: flex;
            align-items: center;
            flex-grow: 1;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }
        
        .file-size {
            color: #6c757d;
            font-size: 0.8em;
            margin-left: 10px;
        }
        
        .browser-preview {
            height: 100%;
            display: flex;
            flex-direction: column;
        }
        
        .browser-address {
            padding: 10px;
            border-bottom: 1px solid #dee2e6;
            display: flex;
        }
        
        .browser-address input {
            flex: 1;
            padding: 5px 10px;
            border: 1px solid #ced4da;
            border-radius: 4px;
        }
        
        .browser-content {
            flex: 1;
            border: none;
            width: 100%;
            height: calc(100% - 56px);
        }
        
        .fullscreen-container {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background-color: #fff;
            z-index: 1000;
            display: none;
            flex-direction: column;
        }
        
        .fullscreen-header {
            background-color: #f8f9fa;
            padding: 10px;
            border-bottom: 1px solid #dee2e6;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .fullscreen-content {
            flex: 1;
            overflow: auto;
        }
        
        .code-editor {
            display: flex;
            flex-direction: column;
            width: 100%;
            height: 100%;
        }
        
        .code-editor-container {
            flex: 1;
            overflow: hidden;
        }
        
        .code-editor-toolbar {
            padding: 5px 10px;
            background-color: #f8f9fa;
            border-bottom: 1px solid #dee2e6;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .editor-tools {
            display: flex;
            gap: 10px;
        }
        
        .btn-icon {
            background: none;
            border: none;
            color: #6c757d;
            cursor: pointer;
        }
        
        .btn-icon:hover {
            color: #212529;
        }
        
        .btn-sm {
            padding: 0.25rem 0.5rem;
            font-size: 0.875rem;
        }
        
        .new-file-form, .new-folder-form {
            display: flex;
            padding: 8px 10px;
            background-color: #f8f9fa;
            border-bottom: 1px solid #dee2e6;
            align-items: center;
        }
        
        .new-file-form input, .new-folder-form input {
            flex-grow: 1;
            margin-right: 10px;
        }
        
        .CodeMirror {
            height: 100%;
            font-family: 'Courier New', monospace;
            font-size: 14px;
        }
        
        .notification {
            position: fixed;
            top: 20px;
            right: 20px;
            padding: 15px;
            background-color: #4CAF50;
            color: white;
            border-radius: 4px;
            z-index: 2000;
            display: none;
            box-shadow: 0 4px 8px rgba(0,0,0,0.2);
        }
        
        .notification.error {
            background-color: #f44336;
        }
        
        .notification.warning {
            background-color: #ff9800;
        }
        
        .help-panel {
            background-color: #f8f9fa;
            padding: 15px;
            margin-top: 15px;
            border-radius: 4px;
            border: 1px solid #dee2e6;
        }
        
        .help-panel h4 {
            margin-top: 0;
            color: #0066cc;
        }
        
        .help-panel ul {
            padding-left: 20px;
        }
        
        .path-navigator {
            display: flex;
            align-items: center;
            background-color: #f8f9fa;
            padding: 8px 10px;
            border-bottom: 1px solid #dee2e6;
            overflow-x: auto;
            white-space: nowrap;
        }
        
        .path-navigator .path-segment {
            display: inline-block;
            padding: 3px 5px;
            cursor: pointer;
            color: #0d6efd;
        }
        
        .path-navigator .path-segment:hover {
            text-decoration: underline;
        }
        
        .path-navigator .path-separator {
            color: #6c757d;
            margin: 0 3px;
        }
        
        .breadcrumb-container {
            flex-grow: 1;
            overflow-x: auto;
            white-space: nowrap;
        }
        
        .dialog-overlay {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background-color: rgba(0, 0, 0, 0.5);
            z-index: 2000;
            display: none;
            justify-content: center;
            align-items: center;
        }
        
        .dialog-box {
            background-color: white;
            border-radius: 8px;
            width: 400px;
            max-width: 90%;
            padding: 20px;
            box-shadow: 0 4px 8px rgba(0, 0, 0, 0.2);
        }
        
        .dialog-title {
            margin-top: 0;
            margin-bottom: 15px;
            font-size: 18px;
            font-weight: bold;
        }
        
        .dialog-buttons {
            display: flex;
            justify-content: flex-end;
            margin-top: 20px;
            gap: 10px;
        }
        
        .sidebar-tabs {
            display: flex;
            border-bottom: 1px solid #dee2e6;
        }
        
        .sidebar-tab {
            padding: 10px 15px;
            cursor: pointer;
            border-bottom: 2px solid transparent;
        }
        
        .sidebar-tab.active {
            border-bottom-color: #0d6efd;
            font-weight: bold;
        }
        
        .sidebar-content {
            display: none;
            height: calc(100% - 50px);
            overflow: auto;
        }
        
        .sidebar-content.active {
            display: block;
        }
        
        .context-menu {
            position: absolute;
            background-color: white;
            border: 1px solid #dee2e6;
            border-radius: 4px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
            padding: 5px 0;
            z-index: 1500;
            min-width: 180px;
            display: none;
        }
        
        .context-menu-item {
            padding: 8px 15px;
            cursor: pointer;
            display: flex;
            align-items: center;
        }
        
        .context-menu-item:hover {
            background-color: #f8f9fa;
        }
        
        .context-menu-item i {
            margin-right: 8px;
            width: 16px;
            text-align: center;
        }
        
        .context-menu-separator {
            height: 1px;
            background-color: #dee2e6;
            margin: 5px 0;
        }
        
        .search-container {
            padding: 10px;
            border-bottom: 1px solid #dee2e6;
        }
        
        .search-input {
            width: 100%;
            padding: 8px;
            border: 1px solid #ced4da;
            border-radius: 4px;
        }
        
        .search-results {
            list-style: none;
            padding: 0;
            margin: 0;
        }
        
        .search-results li {
            padding: 8px 15px;
            border-bottom: 1px solid #dee2e6;
            cursor: pointer;
        }
        
        .search-results li:hover {
            background-color: #f8f9fa;
        }
        
        .search-path {
            font-size: 0.8em;
            color: #6c757d;
            margin-top: 3px;
        }
        
        /* Editor tabs */
        .editor-tabs {
            display: flex;
            background-color: #f8f9fa;
            border-bottom: 1px solid #dee2e6;
            padding: 0;
            margin: 0;
            overflow-x: auto;
            white-space: nowrap;
            list-style: none;
        }
        
        .editor-tab {
            display: inline-flex;
            align-items: center;
            padding: 8px 15px;
            border-right: 1px solid #dee2e6;
            background-color: #f8f9fa;
            cursor: pointer;
            position: relative;
            max-width: 200px;
        }
        
        .editor-tab.active {
            background-color: #fff;
            border-bottom: 2px solid #0d6efd;
        }
        
        .editor-tab-name {
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
            max-width: 150px;
        }
        
        .editor-tab-close {
            margin-left: 8px;
            opacity: 0.5;
            transition: opacity 0.2s;
        }
        
        .editor-tab:hover .editor-tab-close {
            opacity: 1;
        }
        
        /* Stili per i file di sistema */
        .system-file {
            color: #dc3545;
        }
        
        .protected-file {
            color: #fd7e14;
        }
        
        /* Upload dropzone */
        .upload-dropzone {
            border: 2px dashed #ced4da;
            border-radius: 4px;
            padding: 20px;
            text-align: center;
            color: #6c757d;
            margin: 10px;
            background-color: #f8f9fa;
            transition: all 0.3s;
        }
        
        .upload-dropzone.active {
            border-color: #0d6efd;
            background-color: rgba(13, 110, 253, 0.1);
        }
        
        .upload-progress {
            margin-top: 10px;
            height: 5px;
            width: 100%;
            background-color: #e9ecef;
            border-radius: 3px;
            overflow: hidden;
            display: none;
        }
        
        .upload-progress-bar {
            height: 100%;
            background-color: #0d6efd;
            width: 0%;
            transition: width 0.3s;
        }
        
        /* Mode selector per l'editor */
        .mode-selector {
            margin-right: 10px;
        }
        
        /* Admin panel */
        .admin-panel {
            padding: 15px;
        }
        
        .admin-section {
            margin-bottom: 20px;
        }
        
        .admin-action-btn {
            margin-top: 10px;
        }
        
        /* DB credentials */
        .db-credentials {
            background-color: #f8f9fa;
            padding: 15px;
            border-radius: 4px;
            border: 1px solid #dee2e6;
            margin-top: 15px;
        }
        
        .db-credentials-table {
            width: 100%;
            margin-top: 10px;
        }
        
        .db-credentials-table td {
            padding: 5px 10px;
        }
        
        .db-credentials-table .label {
            font-weight: bold;
            width: 120px;
        }
        
        .db-credentials-value {
            font-family: monospace;
            background-color: #e9ecef;
            padding: 5px 8px;
            border-radius: 3px;
        }
        
        /* Responsive adjustments */
        @media (max-width: 768px) {
            .main-container {
                flex-direction: column;
            }
            
            .column-left, .column-right {
                width: 100%;
                height: 50%;
            }
            
            .column-left {
                border-right: none;
                border-bottom: 1px solid #dee2e6;
            }
        }
    </style>
</head>
<body>
    <div class="notification" id="notification">
        File salvato con successo!
    </div>
    
    <div class="dialog-overlay" id="dialog-overlay">
        <div class="dialog-box" id="dialog-content">
            <!-- Il contenuto del dialog verrà inserito dinamicamente -->
        </div>
    </div>
    
    <div class="context-menu" id="context-menu">
        <!-- Voci del menu contestuale saranno aggiunte dinamicamente -->
    </div>
    
    <div class="main-container">
        <!-- Colonna sinistra: File Explorer -->
        <div class="column column-left">
            <div class="panel">
                <div class="sidebar-tabs">
                    <div class="sidebar-tab active" data-tab="files">
                        <i class="fas fa-folder"></i> File
                    </div>
                    <div class="sidebar-tab" data-tab="search">
                        <i class="fas fa-search"></i> Cerca
                    </div>
                    <div class="sidebar-tab" data-tab="admin">
                        <i class="fas fa-tools"></i> Strumenti
                    </div>
                </div>
                
                <!-- Tab Files -->
                <div class="sidebar-content active" id="tab-files">
                    <div class="panel-header">
                        <div class="breadcrumb-container">
                            <div class="path-navigator" id="path-navigator">
                                <span class="path-segment" data-path="/">/</span>
                            </div>
                        </div>
                        <div>
                            <button class="btn-icon" id="new-file-btn" title="Nuovo file">
                                <i class="fas fa-file-plus"></i>
                            </button>
                            <button class="btn-icon" id="new-folder-btn" title="Nuova cartella">
                                <i class="fas fa-folder-plus"></i>
                            </button>
                            <button class="btn-icon" id="refresh-files" title="Aggiorna">
                                <i class="fas fa-sync-alt"></i>
                            </button>
                            <button class="btn-icon" id="upload-files-btn" title="Carica file">
                                <i class="fas fa-upload"></i>
                            </button>
                        </div>
                    </div>
                    
                    <div class="new-file-form" style="display: none;">
                        <input type="text" class="form-control form-control-sm" id="new-file-name" placeholder="Nome del file">
                        <button class="btn btn-sm btn-primary" id="create-file-btn">Crea</button>
                        <button class="btn btn-sm btn-secondary" id="cancel-file-btn">Annulla</button>
                    </div>
                    
                    <div class="new-folder-form" style="display: none;">
                        <input type="text" class="form-control form-control-sm" id="new-folder-name" placeholder="Nome della cartella">
                        <button class="btn btn-sm btn-primary" id="create-folder-btn">Crea</button>
                        <button class="btn btn-sm btn-secondary" id="cancel-folder-btn">Annulla</button>
                    </div>
                    
                    <div class="file-explorer">
                        <ul class="file-list" id="file-list">
                            <li><i class="fas fa-spinner fa-spin"></i> Caricamento file...</li>
                        </ul>
                    </div>
                </div>
                
                <!-- Tab Search -->
                <div class="sidebar-content" id="tab-search">
                    <div class="search-container">
                        <input type="text" class="search-input" id="search-input" placeholder="Cerca file...">
                    </div>
                    <div class="file-explorer">
                        <ul class="search-results" id="search-results">
                            <!-- I risultati della ricerca verranno inseriti qui -->
                        </ul>
                    </div>
                </div>
                
                <!-- Tab Admin -->
                <div class="sidebar-content" id="tab-admin">
                    <div class="admin-panel">
                        <div class="admin-section">
                            <h4>Manutenzione File</h4>
                            <p>Strumenti per gestire permessi e manutenzione del file system.</p>
                            <button class="btn btn-sm btn-outline-primary admin-action-btn" id="fix-permissions-btn">
                                <i class="fas fa-shield-alt"></i> Ripara Permessi File
                            </button>
                            <button class="btn btn-sm btn-outline-primary admin-action-btn" id="cleanup-tmp-btn">
                                <i class="fas fa-broom"></i> Pulisci File Temporanei
                            </button>
                        </div>
                        
                        <div class="admin-section">
                            <h4>Gestione Database</h4>
                            <p>Accesso rapido a phpMyAdmin e strumenti database.</p>
                            <button class="btn btn-sm btn-outline-primary admin-action-btn" id="open-phpmyadmin-btn">
                                <i class="fas fa-database"></i> Apri phpMyAdmin
                            </button>
                            <div class="db-credentials" id="db-credentials">
                                <h5><i class="fas fa-key"></i> Credenziali MySQL</h5>
                                <p>Informazioni di accesso per il database:</p>
                                <table class="db-credentials-table">
                                    <tr>
                                        <td class="label">Utente:</td>
                                        <td><span class="db-credentials-value" id="mysql-user">Caricamento...</span></td>
                                    </tr>
                                    <tr>
                                        <td class="label">Password:</td>
                                        <td><span class="db-credentials-value" id="mysql-password">Caricamento...</span></td>
                                    </tr>
                                </table>
                            </div>
                        </div>
                        
                        <div class="admin-section">
                            <h4>Claude Code</h4>
                            <p>Informazioni per utilizzare Claude Code via terminale.</p>
                            <div class="help-panel">
                                <h5><i class="fas fa-info-circle"></i> Come utilizzare Claude Code</h5>
                                <p>Per utilizzare Claude Code e creare applicazioni:</p>
                                <ol>
                                    <li>Connettiti via SSH al server</li>
                                    <li>Esegui il comando: <code>claude-app</code></li>
                                    <li>I file creati appariranno nella root directory</li>
                                </ol>
                                <div class="csp-info">
                                    <strong>Nota:</strong> Claude Code è disponibile solo da terminale SSH, non tramite questa interfaccia web.
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- Colonna destra: Browser Preview o Editor -->
        <div class="column column-right">
            <div class="panel">
                <div class="panel-header">
                    <span>
                        <i class="fas fa-globe"></i> Browser Preview
                        <i class="fas fa-spinner fa-spin" id="browser-loading" style="display: none;"></i>
                    </span>
                    <div>
                        <button class="btn-icon" id="refresh-browser" title="Aggiorna">
                            <i class="fas fa-sync-alt"></i>
                        </button>
                        <button class="btn-icon expand-btn" data-target="browser-preview">
                            <i class="fas fa-expand"></i>
                        </button>
                    </div>
                </div>
                <div class="browser-preview">
                    <div class="browser-address">
                        <input type="text" id="browser-url" value="http://SERVER_IP/" placeholder="URL">
                    </div>
                    <iframe class="browser-content" id="browser-frame" src="about:blank" sandbox="allow-same-origin allow-scripts allow-forms allow-popups"></iframe>
                </div>
            </div>
        </div>
    </div>
    
    <!-- Fullscreen container per Browser Preview -->
    <div class="fullscreen-container" id="browser-preview-fullscreen">
        <div class="fullscreen-header">
            <span><i class="fas fa-globe"></i> Browser Preview</span>
            <button class="btn-icon minimize-btn" data-target="browser-preview">
                <i class="fas fa-compress"></i>
            </button>
        </div>
        <div class="fullscreen-content">
            <div class="browser-address">
                <input type="text" value="http://SERVER_IP/" placeholder="URL">
            </div>
            <iframe class="browser-content" src="about:blank" sandbox="allow-same-origin allow-scripts allow-forms allow-popups"></iframe>
        </div>
    </div>
    
    <!-- Fullscreen container per Code Editor -->
    <div class="fullscreen-container" id="code-editor-fullscreen">
        <div class="fullscreen-header">
            <span id="editor-filename"><i class="fas fa-file-code"></i> editor.js</span>
            <div>
                <select class="form-select form-select-sm mode-selector" id="editor-mode-selector">
                    <option value="text/plain">Testo</option>
                    <option value="application/javascript">JavaScript</option>
                    <option value="text/html">HTML</option>
                    <option value="text/css">CSS</option>
                    <option value="application/x-php">PHP</option>
                    <option value="text/x-python">Python</option>
                    <option value="text/x-sql">SQL</option>
                    <option value="text/x-markdown">Markdown</option>
                    <option value="application/json">JSON</option>
                    <option value="text/x-shellscript">Shell</option>
                </select>
                <button class="btn-icon" id="find-in-code" title="Cerca">
                    <i class="fas fa-search"></i>
                </button>
                <button class="btn-icon" id="sudo-save" title="Salva con privilegi elevati">
                    <i class="fas fa-shield-alt"></i>
                </button>
                <button class="btn-icon minimize-btn" data-target="code-editor">
                    <i class="fas fa-compress"></i>
                </button>
            </div>
        </div>
        <ul class="editor-tabs" id="editor-tabs">
            <!-- Le schede dell'editor verranno inserite dinamicamente -->
        </ul>
        <div class="code-editor">
            <div class="code-editor-toolbar">
                <div class="editor-tools">
                    <button class="btn btn-sm btn-outline-secondary" id="editor-word-wrap">
                        <i class="fas fa-paragraph"></i> A capo automatico
                    </button>
                    <button class="btn btn-sm btn-outline-secondary" id="editor-format">
                        <i class="fas fa-indent"></i> Formatta
                    </button>
                    <button class="btn btn-sm btn-outline-secondary" id="editor-discard">
                        <i class="fas fa-undo"></i> Annulla modifiche
                    </button>
                </div>
                <div>
                    <span id="editor-status"></span>
                    <button class="btn btn-sm btn-primary" id="editor-save">
                        <i class="fas fa-save"></i> Salva
                    </button>
                </div>
            </div>
            <div class="code-editor-container" id="editor-container"></div>
        </div>
    </div>

    <!-- jQuery -->
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.6.0/jquery.min.js"></script>
    
    <!-- Bootstrap JS -->
    <script src="https://cdnjs.cloudflare.com/ajax/libs/bootstrap/5.3.0/js/bootstrap.bundle.min.js"></script>
    
    <!-- CodeMirror JS -->
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/codemirror.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/search/search.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/search/searchcursor.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/dialog/dialog.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/edit/matchbrackets.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/edit/closebrackets.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/edit/closetag.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/fold/foldcode.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/fold/foldgutter.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/fold/brace-fold.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/fold/comment-fold.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/fold/indent-fold.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/hint/show-hint.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/hint/javascript-hint.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/hint/html-hint.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/hint/css-hint.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/hint/xml-hint.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/comment/comment.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/selection/active-line.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/addon/display/placeholder.min.js"></script>
    
    <!-- CodeMirror Language Modes -->
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/mode/javascript/javascript.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/mode/htmlmixed/htmlmixed.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/mode/xml/xml.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/mode/css/css.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/mode/php/php.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/mode/python/python.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/mode/markdown/markdown.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/mode/sql/sql.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/mode/shell/shell.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.2/mode/clike/clike.min.js"></script>
    
    <script>
        $(document).ready(function() {
            // Variabili globali
            let editor;
            let currentFile = null;
            let originalContent = "";
            let currentPath = "/var/www/html";
            let openFiles = {};
            let activeTab = null;
            let isEditorWordWrap = false;
            
            // Carica l'URL iniziale nel browser preview
            loadUrlInPreview('http://SERVER_IP/');
            
            // Carica la lista dei file
            loadFileList(currentPath);
            
            // Gestione degli eventi
            setupEventHandlers();
            
            // Inizializzazione della sidebar
            setupSidebar();
            
            // Inizializzazione del menu contestuale
            setupContextMenu();
            
            // Gestione dei file upload
            setupFileUpload();
            
            // Caricamento delle credenziali MySQL
            loadMySQLCredentials();
            
            /**
             * Configura gli event handler principali
             */
            function setupEventHandlers() {
                // Gestione espansione a schermo intero
                $(document).on('click', '.expand-btn', function() {
                    const target = $(this).data('target');
                    $(`#${target}-fullscreen`).css('display', 'flex');
                });
                
                // Gestione minimizzazione
                $(document).on('click', '.minimize-btn', function() {
                    const target = $(this).data('target');
                    $(`#${target}-fullscreen`).css('display', 'none');
                });
                
                // Gestione click sul pulsante di aggiornamento file
                $('#refresh-files').click(function() {
                    loadFileList(currentPath);
                });
                
                // Gestione click sul pulsante nuovo file
                $('#new-file-btn').click(function() {
                    $('.new-file-form').slideDown(200);
                    $('#new-file-name').focus();
                });
                
                // Gestione click sul pulsante annulla nuovo file
                $('#cancel-file-btn').click(function() {
                    $('.new-file-form').slideUp(200);
                    $('#new-file-name').val('');
                });
                
                // Gestione click sul pulsante crea file
                $('#create-file-btn').click(function() {
                    const fileName = $('#new-file-name').val().trim();
                    if (fileName) {
                        createFile(currentPath, fileName);
                    }
                });
                
                // Gestione click sul pulsante nuova cartella
                $('#new-folder-btn').click(function() {
                    $('.new-folder-form').slideDown(200);
                    $('#new-folder-name').focus();
                });
                
                // Gestione click sul pulsante annulla nuova cartella
                $('#cancel-folder-btn').click(function() {
                    $('.new-folder-form').slideUp(200);
                    $('#new-folder-name').val('');
                });
                
                // Gestione click sul pulsante crea cartella
                $('#create-folder-btn').click(function() {
                    const folderName = $('#new-folder-name').val().trim();
                    if (folderName) {
                        createFolder(currentPath, folderName);
                    }
                });
                
                // Gestione dei click sui file
                $(document).on('click', '.file-item', function(e) {
                    // Ignora se il click è su un pulsante di azione
                    if ($(e.target).closest('.file-actions').length > 0) {
                        return;
                    }
                    
                    const filePath = $(this).data('path');
                    const fileType = $(this).data('type');
                    
                    if (fileType === 'directory') {
                        // Naviga nella directory
                        navigateToDirectory(filePath);
                    } else {
                        // Apri il file nell'editor
                        openFileInEditor(filePath);
                    }
                });
                
                // Gestione click sui segmenti del percorso
                $(document).on('click', '.path-segment', function() {
                    const path = $(this).data('path');
                    navigateToDirectory(path);
                });
                
                // Gestione click sul pulsante annulla modifiche
                $('#editor-discard').click(function() {
                    if (editor && currentFile) {
                        if (confirm("Sei sicuro di voler annullare tutte le modifiche?")) {
                            editor.setValue(originalContent);
                            editor.clearHistory();
                            showNotification("Modifiche annullate");
                        }
                    }
                });
                
                // Gestione click sul pulsante salva
                $('#editor-save').click(function() {
                    if (editor && currentFile) {
                        saveFile(currentFile, editor.getValue());
                    }
                });
                
                // Gestione click sul pulsante salva con sudo
                $('#sudo-save').click(function() {
                    if (editor && currentFile) {
                        saveFile(currentFile, editor.getValue(), true);
                    }
                });
                
                // Gestione click sul pulsante formatta
                $('#editor-format').click(function() {
                    if (editor) {
                        formatCode();
                    }
                });
                
                // Gestione click sul pulsante attiva/disattiva a capo automatico
                $('#editor-word-wrap').click(function() {
                    if (editor) {
                        isEditorWordWrap = !isEditorWordWrap;
                        editor.setOption('lineWrapping', isEditorWordWrap);
                        $(this).toggleClass('active', isEditorWordWrap);
                    }
                });
                
                // Gestione click sul pulsante cerca nel codice
                $('#find-in-code').click(function() {
                    if (editor) {
                        CodeMirror.commands.find(editor);
                    }
                });
                
                // Gestione cambio modalità editor
                $('#editor-mode-selector').change(function() {
                    if (editor) {
                        const mode = $(this).val();
                        editor.setOption('mode', mode);
                    }
                });
                
                // Gestione click sul pulsante aggiorna browser
                $('#refresh-browser').click(function() {
                    const url = $('#browser-url').val();
                    if (url) {
                        loadUrlInPreview(url);
                    }
                });
                
                // Gestione input URL nel browser preview
                $('#browser-url').keypress(function(e) {
                    if (e.which === 13) { // Enter key
                        const url = $(this).val();
                        if (url) {
                            loadUrlInPreview(url);
                        }
                    }
                });
                
                // Gestione click sul pulsante admin di riparazione permessi
                $('#fix-permissions-btn').click(function() {
                    fixPermissions();
                });
                
                // Gestione click sul pulsante di pulizia file temporanei
                $('#cleanup-tmp-btn').click(function() {
                    cleanupTempFiles();
                });
                
                // Gestione click sul pulsante open phpmyadmin
                $('#open-phpmyadmin-btn').click(function() {
                    window.open('/phpmyadmin/', '_blank');
                });
                
                // Gestione della ricerca
                $('#search-input').on('keyup', function(e) {
                    if (e.which === 13) { // Enter key
                        const query = $(this).val().trim();
                        if (query.length >= 2) {
                            searchFiles(query);
                        }
                    }
                });
                
                // Gestione click sui risultati della ricerca
                $(document).on('click', '.search-result', function() {
                    const filePath = $(this).data('path');
                    const fileType = $(this).data('type');
                    
                    if (fileType === 'directory') {
                        navigateToDirectory(filePath);
                    } else {
                        openFileInEditor(filePath);
                    }
                });
                
                // Chiudi i dialoghi quando si clicca al di fuori
                $(document).on('click', '.dialog-overlay', function(e) {
                    if ($(e.target).hasClass('dialog-overlay')) {
                        closeDialog();
                    }
                });
                
                // Gestione tasti di scelta rapida
                $(document).keydown(function(e) {
                    // Ctrl+S per salvare
                    if (e.ctrlKey && e.keyCode === 83) {
                        e.preventDefault();
                        if (editor && currentFile) {
                            saveFile(currentFile, editor.getValue());
                        }
                    }
                });
            }
            
            /**
             * Configura la sidebar e le sue tab
             */
            function setupSidebar() {
                // Gestione delle tab della sidebar
                $('.sidebar-tab').click(function() {
                    const tab = $(this).data('tab');
                    
                    // Rimuovi la classe active da tutte le tab
                    $('.sidebar-tab').removeClass('active');
                    $('.sidebar-content').removeClass('active');
                    
                    // Aggiungi la classe active alla tab selezionata
                    $(this).addClass('active');
                    $(`#tab-${tab}`).addClass('active');
                });
            }
            
            /**
             * Configura il menu contestuale
             */
            function setupContextMenu() {
                // Chiudi il menu contestuale quando si clicca al di fuori
                $(document).on('click', function() {
                    $('#context-menu').hide();
                });
                
                // Mostra il menu contestuale sui file
                $(document).on('contextmenu', '.file-item', function(e) {
                    e.preventDefault();
                    
                    const filePath = $(this).data('path');
                    const fileType = $(this).data('type');
                    const fileName = $(this).data('name');
                    
                    // Costruisci il menu contestuale in base al tipo di file
                    let menuItems = '';
                    
                    if (fileType === 'directory') {
                        menuItems += `
                            <div class="context-menu-item" data-action="open" data-path="${filePath}">
                                <i class="fas fa-folder-open"></i> Apri
                            </div>
                            <div class="context-menu-separator"></div>
                            <div class="context-menu-item" data-action="rename" data-path="${filePath}">
                                <i class="fas fa-edit"></i> Rinomina
                            </div>
                            <div class="context-menu-item" data-action="delete" data-path="${filePath}">
                                <i class="fas fa-trash-alt"></i> Elimina
                            </div>
                        `;
                    } else {
                        menuItems += `
                            <div class="context-menu-item" data-action="edit" data-path="${filePath}">
                                <i class="fas fa-edit"></i> Modifica
                            </div>
                            <div class="context-menu-separator"></div>
                            <div class="context-menu-item" data-action="rename" data-path="${filePath}">
                                <i class="fas fa-file-signature"></i> Rinomina
                            </div>
                            <div class="context-menu-item" data-action="delete" data-path="${filePath}">
                                <i class="fas fa-trash-alt"></i> Elimina
                            </div>
                        `;
                    }
                    
                    // Aggiungi le voci del menu
                    $('#context-menu').html(menuItems);
                    
                    // Posiziona il menu
                    $('#context-menu').css({
                        top: e.pageY + 'px',
                        left: e.pageX + 'px'
                    }).show();
                    
                    // Gestione dei click sulle voci del menu
                    $('.context-menu-item').click(function() {
                        const action = $(this).data('action');
                        const path = $(this).data('path');
                        
                        // Nascondi il menu
                        $('#context-menu').hide();
                        
                        // Esegui l'azione
                        switch (action) {
                            case 'open':
                                navigateToDirectory(path);
                                break;
                            case 'edit':
                                openFileInEditor(path);
                                break;
                            case 'rename':
                                showRenameDialog(path);
                                break;
                            case 'delete':
                                showDeleteConfirmation(path);
                                break;
                        }
                    });
                });
            }
            
            /**
             * Configura il supporto per upload di file tramite drag & drop
             */
            function setupFileUpload() {
                // Mostra dialog di upload
                $('#upload-files-btn').click(function() {
                    showUploadDialog();
                });
                
                // Gestione del drag & drop per upload
                $(document).on('dragover', function(e) {
                    e.preventDefault();
                    e.stopPropagation();
                });
                
                $(document).on('drop', function(e) {
                    e.preventDefault();
                    e.stopPropagation();
                    
                    const files = e.originalEvent.dataTransfer.files;
                    if (files.length > 0) {
                        showUploadDialog(files);
                    }
                });
            }
            
            /**
             * Carica le credenziali MySQL dall'API
             */
            function loadMySQLCredentials() {
                $.ajax({
                    url: 'file-manager.php',
                    type: 'GET',
                    data: {
                        action: 'get_mysql_credentials'
                    },
                    dataType: 'json',
                    success: function(response) {
                        if (response.error) {
                            $('#mysql-user').text('Non disponibile');
                            $('#mysql-password').text('Non disponibile');
                            return;
                        }
                        
                        $('#mysql-user').text(response.user || 'root');
                        $('#mysql-password').text(response.password || 'Non disponibile');
                    },
                    error: function() {
                        $('#mysql-user').text('Errore');
                        $('#mysql-password').text('Errore');
                    }
                });
            }
            
            /**
             * Funzione per caricare la lista dei file in una directory
             * @param {string} path - Il percorso della directory
             */
            function loadFileList(path) {
                $('#file-list').html('<li><i class="fas fa-spinner fa-spin"></i> Caricamento file...</li>');
                
                // Aggiorna il navigatore del percorso
                updatePathNavigator(path);
                
                $.ajax({
                    url: 'file-manager.php',
                    type: 'GET',
                    data: {
                        action: 'list',
                        dir: path
                    },
                    dataType: 'json',
                    success: function(data) {
                        $('#file-list').empty();
                        
                        if (data.error) {
                            $('#file-list').html(`<li class="text-danger"><i class="fas fa-exclamation-circle"></i> ${data.error}</li>`);
                            return;
                        }
                        
                        if (data.length === 0) {
                            $('#file-list').html('<li class="text-muted"><i class="fas fa-info-circle"></i> Directory vuota</li>');
                            return;
                        }
                        
                        // Memorizza il percorso corrente
                        currentPath = path;
                        
                        $.each(data, function(i, file) {
                            const isSystem = file.is_system || false;
                            const isProtected = !file.is_writable || false;
                            
                            let fileClass = '';
                            if (isSystem) {
                                fileClass = 'system-file';
                            } else if (isProtected) {
                                fileClass = 'protected-file';
                            }
                            
                            const fileActions = `
                                <div class="file-actions">
                                    ${file.type === 'file' ? '<button class="file-action-btn" title="Modifica" data-action="edit"><i class="fas fa-edit"></i></button>' : ''}
                                    <button class="file-action-btn" title="Rinomina" data-action="rename"><i class="fas fa-file-signature"></i></button>
                                    <button class="file-action-btn" title="Elimina" data-action="delete"><i class="fas fa-trash-alt"></i></button>
                                </div>
                            `;
                            
                            $('#file-list').append(`
                                <li class="file-item ${fileClass}" 
                                    data-name="${file.name}" 
                                    data-type="${file.type}" 
                                    data-path="${file.path}">
                                    <div class="file-name">
                                        <i class="fas fa-${file.icon}"></i>
                                        ${file.name}
                                        ${!file.is_writable ? '<i class="fas fa-lock file-lock" title="Non modificabile"></i>' : ''}
                                    </div>
                                    ${file.type === 'file' ? `<span class="file-size">${file.size}</span>` : ''}
                                    ${fileActions}
                                </li>
                            `);
                        });
                        
                        // Aggiungi gestione degli eventi per le azioni sui file
                        $('.file-action-btn').click(function(e) {
                            e.stopPropagation();
                            
                            const action = $(this).data('action');
                            const filePath = $(this).closest('.file-item').data('path');
                            
                            switch (action) {
                                case 'edit':
                                    openFileInEditor(filePath);
                                    break;
                                case 'rename':
                                    showRenameDialog(filePath);
                                    break;
                                case 'delete':
                                    showDeleteConfirmation(filePath);
                                    break;
                            }
                        });
                    },
                    error: function(xhr, status, error) {
                        $('#file-list').html(`<li class="text-danger"><i class="fas fa-exclamation-circle"></i> Errore nel caricamento dei file: ${error}</li>`);
                    }
                });
            }
            
            /**
             * Aggiorna il navigatore del percorso
             * @param {string} path - Il percorso completo
             */
            function updatePathNavigator(path) {
                const segments = path.split('/').filter(segment => segment.length > 0);
                let currentPath = '';
                let navigatorHtml = '<span class="path-segment" data-path="/">/</span>';
                
                for (let i = 0; i < segments.length; i++) {
                    currentPath += '/' + segments[i];
                    navigatorHtml += '<span class="path-separator">/</span>';
                    navigatorHtml += `<span class="path-segment" data-path="${currentPath}">${segments[i]}</span>`;
                }
                
                $('#path-navigator').html(navigatorHtml);
            }
            
            /**
             * Naviga in una directory
             * @param {string} path - Il percorso della directory
             */
            function navigateToDirectory(path) {
                loadFileList(path);
            }
            
            /**
             * Crea un nuovo file
             * @param {string} directory - La directory in cui creare il file
             * @param {string} fileName - Il nome del file
             */
            function createFile(directory, fileName) {
                $.ajax({
                    url: 'file-manager.php',
                    type: 'POST',
                    data: {
                        action: 'create',
                        dir: directory,
                        file: fileName
                    },
                    dataType: 'json',
                    success: function(response) {
                        if (response.error) {
                            showNotification(response.error, 'error');
                            return;
                        }
                        
                        // Nascondi il form e pulisci l'input
                        $('.new-file-form').slideUp(200);
                        $('#new-file-name').val('');
                        
                        // Ricarica la lista dei file
                        loadFileList(directory);
                        
                        // Mostra notifica
                        showNotification(`File '${fileName}' creato con successo`);
                        
                        // Apri il nuovo file nell'editor
                        const filePath = directory + '/' + fileName;
                        setTimeout(function() {
                            openFileInEditor(filePath);
                        }, 500);
                    },
                    error: function(xhr, status, error) {
                        showNotification('Errore nella creazione del file', 'error');
                    }
                });
            }
            
            /**
             * Crea una nuova cartella
             * @param {string} directory - La directory in cui creare la cartella
             * @param {string} folderName - Il nome della cartella
             */
            function createFolder(directory, folderName) {
                $.ajax({
                    url: 'file-manager.php',
                    type: 'POST',
                    data: {
                        action: 'create_dir',
                        dir: directory,
                        name: folderName
                    },
                    dataType: 'json',
                    success: function(response) {
                        if (response.error) {
                            showNotification(response.error, 'error');
                            return;
                        }
                        
                        // Nascondi il form e pulisci l'input
                        $('.new-folder-form').slideUp(200);
                        $('#new-folder-name').val('');
                        
                        // Ricarica la lista dei file
                        loadFileList(directory);
                        
                        // Mostra notifica
                        showNotification(`Cartella '${folderName}' creata con successo`);
                    },
                    error: function(xhr, status, error) {
                        showNotification('Errore nella creazione della cartella', 'error');
                    }
                });
            }
            
            /**
             * Mostra un dialogo per rinominare un file o directory
             * @param {string} path - Il percorso del file o directory
             */
            function showRenameDialog(path) {
                const name = path.split('/').pop();
                
                const dialogContent = `
                    <h4 class="dialog-title">Rinomina</h4>
                    <div class="mb-3">
                        <label for="rename-input" class="form-label">Nuovo nome:</label>
                        <input type="text" class="form-control" id="rename-input" value="${name}">
                    </div>
                    <div class="dialog-buttons">
                        <button class="btn btn-secondary" id="rename-cancel">Annulla</button>
                        <button class="btn btn-primary" id="rename-confirm">Rinomina</button>
                    </div>
                `;
                
                $('#dialog-content').html(dialogContent);
                $('#dialog-overlay').css('display', 'flex');
                $('#rename-input').focus();
                
                // Gestione tasto Invio
                $('#rename-input').keypress(function(e) {
                    if (e.which === 13) { // Enter key
                        $('#rename-confirm').click();
                    }
                });
                
                // Gestione click sul pulsante annulla
                $('#rename-cancel').click(function() {
                    closeDialog();
                });
                
                // Gestione click sul pulsante rinomina
                $('#rename-confirm').click(function() {
                    const newName = $('#rename-input').val().trim();
                    
                    if (newName && newName !== name) {
                        renameFile(path, newName);
                        closeDialog();
                    }
                });
            }
            
            /**
             * Rinomina un file o directory
             * @param {string} oldPath - Il percorso originale
             * @param {string} newName - Il nuovo nome
             */
            function renameFile(oldPath, newName) {
                $.ajax({
                    url: 'file-manager.php',
                    type: 'POST',
                    data: {
                        action: 'rename',
                        old_path: oldPath,
                        new_name: newName
                    },
                    dataType: 'json',
                    success: function(response) {
                        if (response.error) {
                            showNotification(response.error, 'error');
                            return;
                        }
                        
                        // Ricarica la lista dei file
                        loadFileList(currentPath);
                        
                        // Mostra notifica
                        showNotification(`Rinominato in '${newName}' con successo`);
                    },
                    error: function(xhr, status, error) {
                        showNotification('Errore durante la rinomina', 'error');
                    }
                });
            }
            
            /**
             * Mostra un dialogo di conferma per l'eliminazione
             * @param {string} path - Il percorso del file o directory
             */
            function showDeleteConfirmation(path) {
                const name = path.split('/').pop();
                const isDir = path.endsWith('/');
                
                const dialogContent = `
                    <h4 class="dialog-title">Conferma eliminazione</h4>
                    <p>Sei sicuro di voler eliminare ${isDir ? 'la directory' : 'il file'} <strong>${name}</strong>?</p>
                    ${isDir ? '<p class="text-danger">Attenzione: verranno eliminati tutti i file e le sottodirectory.</p>' : ''}
                    <div class="dialog-buttons">
                        <button class="btn btn-secondary" id="delete-cancel">Annulla</button>
                        <button class="btn btn-danger" id="delete-confirm">Elimina</button>
                    </div>
                `;
                
                $('#dialog-content').html(dialogContent);
                $('#dialog-overlay').css('display', 'flex');
                
                // Gestione click sul pulsante annulla
                $('#delete-cancel').click(function() {
                    closeDialog();
                });
                
                // Gestione click sul pulsante elimina
                $('#delete-confirm').click(function() {
                    deleteFile(path);
                    closeDialog();
                });
            }
            
            /**
             * Elimina un file o directory
             * @param {string} path - Il percorso del file o directory
             */
            function deleteFile(path) {
                $.ajax({
                    url: 'file-manager.php',
                    type: 'POST',
                    data: {
                        action: 'delete',
                        path: path
                    },
                    dataType: 'json',
                    success: function(response) {
                        if (response.error) {
                            showNotification(response.error, 'error');
                            return;
                        }
                        
                        // Ricarica la lista dei file
                        loadFileList(currentPath);
                        
                        // Mostra notifica
                        showNotification('Eliminato con successo');
                    },
                    error: function(xhr, status, error) {
                        showNotification('Errore durante l\'eliminazione', 'error');
                    }
                });
            }
            
            /**
             * Chiude il dialogo corrente
             */
            function closeDialog() {
                $('#dialog-overlay').hide();
            }
            
            /**
             * Mostra un dialogo per l'upload di file
             * @param {FileList} [files] - Lista di file da caricare (opzionale)
             */
            function showUploadDialog(files) {
                const dialogContent = `
                    <h4 class="dialog-title">Carica File</h4>
                    <div class="upload-dropzone" id="upload-dropzone">
                        <i class="fas fa-cloud-upload-alt fa-3x mb-3"></i>
                        <p>Trascina qui i file o clicca per selezionarli</p>
                        <input type="file" id="file-input" style="display: none;" multiple>
                    </div>
                    <div class="upload-progress" id="upload-progress">
                        <div class="upload-progress-bar" id="upload-progress-bar"></div>
                    </div>
                    <div class="dialog-buttons">
                        <button class="btn btn-secondary" id="upload-cancel">Chiudi</button>
                    </div>
                `;
                
                $('#dialog-content').html(dialogContent);
                $('#dialog-overlay').css('display', 'flex');
                
                // Gestione click sul pulsante chiudi
                $('#upload-cancel').click(function() {
                    closeDialog();
                });
                
                // Gestione click sulla dropzone
                $('#upload-dropzone').click(function() {
                    $('#file-input').click();
                });
                
                // Gestione selezione file
                $('#file-input').change(function() {
                    const selectedFiles = this.files;
                    if (selectedFiles.length > 0) {
                        uploadFiles(selectedFiles);
                    }
                });
                
                // Gestione drag & drop
                const dropzone = document.getElementById('upload-dropzone');
                
                dropzone.addEventListener('dragover', function(e) {
                    e.preventDefault();
                    e.stopPropagation();
                    $(this).addClass('active');
                });
                
                dropzone.addEventListener('dragleave', function(e) {
                    e.preventDefault();
                    e.stopPropagation();
                    $(this).removeClass('active');
                });
                
                dropzone.addEventListener('drop', function(e) {
                    e.preventDefault();
                    e.stopPropagation();
                    $(this).removeClass('active');
                    
                    const droppedFiles = e.dataTransfer.files;
                    if (droppedFiles.length > 0) {
                        uploadFiles(droppedFiles);
                    }
                });
                
                // Se sono stati passati dei file, caricali subito
                if (files && files.length > 0) {
                    uploadFiles(files);
                }
            }
            
            /**
             * Carica file sul server
             * @param {FileList} files - Lista di file da caricare
             */
            function uploadFiles(files) {
                // Mostra la barra di progresso
                $('#upload-progress').show();
                
                // Crea FormData per l'upload
                const formData = new FormData();
                formData.append('action', 'upload');
                formData.append('dir', currentPath);
                
                // Aggiungi i file
                for (let i = 0; i < files.length; i++) {
                    formData.append('file', files[i]);
                }
                
                // Esegui l'upload
                $.ajax({
                    url: 'file-manager.php',
                    type: 'POST',
                    data: formData,
                    processData: false,
                    contentType: false,
                    xhr: function() {
                        const xhr = new window.XMLHttpRequest();
                        
                        // Aggiorna la barra di progresso durante l'upload
                        xhr.upload.addEventListener('progress', function(e) {
                            if (e.lengthComputable) {
                                const percentComplete = (e.loaded / e.total) * 100;
                                $('#upload-progress-bar').css('width', percentComplete + '%');
                            }
                        }, false);
                        
                        return xhr;
                    },
                    success: function(response) {
                        if (response.error) {
                            showNotification(response.error, 'error');
                        } else {
                            showNotification('File caricato con successo');
                            
                            // Ricarica la lista dei file
                            loadFileList(currentPath);
                            
                            // Chiudi il dialogo dopo un breve ritardo
                            setTimeout(function() {
                                closeDialog();
                            }, 1000);
                        }
                    },
                    error: function(xhr, status, error) {
                        showNotification('Errore durante il caricamento del file', 'error');
                    }
                });
            }
            
            /**
             * Apre un file nell'editor
             * @param {string} filePath - Il percorso del file
             */
            function openFileInEditor(filePath) {
                // Aggiorna il titolo dell'editor
                const fileName = filePath.split('/').pop();
                $('#editor-filename').html(`<i class="fas fa-file-code"></i> ${fileName}`);
                
                // Mostra l'editor a schermo intero
                $('#code-editor-fullscreen').css('display', 'flex');
                
                // Carica il contenuto del file
                $.ajax({
                    url: 'file-manager.php',
                    type: 'GET',
                    data: {
                        action: 'read',
                        file: filePath
                    },
                    dataType: 'json',
                    success: function(response) {
                        if (response.error) {
                            showNotification(response.error, 'error');
                            return;
                        }
                        
                        // Memorizza il file corrente e il contenuto originale
                        currentFile = filePath;
                        originalContent = response.content;
                        
                        // Inizializza l'editor se non è già stato fatto
                        if (!editor) {
                            initializeEditor();
                        }
                        
                        // Imposta il contenuto dell'editor
                        editor.setValue(response.content);
                        editor.clearHistory();
                        
                        // Imposta la modalità di evidenziazione in base all'estensione del file
                        const mode = getFileMode(fileName);
                        editor.setOption('mode', mode);
                        $('#editor-mode-selector').val(mode);
                        
                        // Aggiorna stato editor
                        $('#editor-status').html('').removeClass('text-warning');
                        
                        // Mostra il pulsante sudo se il file non è scrivibile
                        if (response.sudo_used) {
                            $('#sudo-save').show();
                            $('#editor-status').html('<i class="fas fa-shield-alt"></i> Modalità amministratore').addClass('text-warning');
                        } else {
                            $('#sudo-save').hide();
                        }
                    },
                    error: function(xhr, status, error) {
                        showNotification('Errore nel caricamento del file', 'error');
                    }
                });
            }
            
            /**
             * Salva il contenuto di un file
             * @param {string} filePath - Il percorso del file
             * @param {string} content - Il contenuto da salvare
             * @param {boolean} [useSudo=false] - Se salvare con privilegi elevati
             */
            function saveFile(filePath, content, useSudo = false) {
                $.ajax({
                    url: 'file-manager.php',
                    type: 'POST',
                    data: {
                        action: 'save',
                        file: filePath,
                        content: content,
                        sudo: useSudo
                    },
                    dataType: 'json',
                    success: function(response) {
                        if (response.error) {
                            showNotification(response.error, 'error');
                            return;
                        }
                        
                        // Aggiorna il contenuto originale
                        originalContent = content;
                        
                        // Mostra notifica
                        showNotification('File salvato con successo!');
                        
                        // Aggiorna stato editor
                        $('#editor-status').html('').removeClass('text-warning');
                        
                        // Se è stato usato sudo, mostra il pulsante sudo
                        if (response.sudo_used) {
                            $('#sudo-save').show();
                            $('#editor-status').html('<i class="fas fa-shield-alt"></i> Modalità amministratore').addClass('text-warning');
                        }
                    },
                    error: function(xhr, status, error) {
                        showNotification('Errore nel salvataggio del file', 'error');
                    }
                });
            }
            
            /**
             * Inizializza l'editor CodeMirror
             */
            function initializeEditor() {
                editor = CodeMirror(document.getElementById('editor-container'), {
                    lineNumbers: true,
                    mode: 'text/plain',
                    theme: 'default',
                    indentUnit: 4,
                    smartIndent: true,
                    tabSize: 4,
                    indentWithTabs: false,
                    lineWrapping: isEditorWordWrap,
                    matchBrackets: true,
                    autoCloseBrackets: true,
                    autoCloseTags: true,
                    foldGutter: true,
                    gutters: ["CodeMirror-linenumbers", "CodeMirror-foldgutter"],
                    styleActiveLine: true,
                    extraKeys: {
                        "Ctrl-Space": "autocomplete",
                        "F11": function(cm) {
                            cm.setOption("fullScreen", !cm.getOption("fullScreen"));
                        },
                        "Esc": function(cm) {
                            if (cm.getOption("fullScreen")) cm.setOption("fullScreen", false);
                        },
                        "Ctrl-F": "find",
                        "Cmd-F": "find",
                        "Tab": function(cm) {
                            if (cm.somethingSelected()) {
                                cm.indentSelection("add");
                            } else {
                                cm.replaceSelection(Array(cm.getOption("indentUnit") + 1).join(" "), "end", "+input");
                            }
                        },
                        "Shift-Tab": function(cm) {
                            cm.indentSelection("subtract");
                        }
                    }
                });
                
                // Gestione eventi dell'editor
                editor.on('change', function() {
                    // Se il contenuto è cambiato rispetto all'originale, mostra un indicatore
                    const currentContent = editor.getValue();
                    if (currentContent !== originalContent) {
                        $('#editor-status').html('<i class="fas fa-circle"></i> Modificato').addClass('text-warning');
                    } else {
                        $('#editor-status').html('').removeClass('text-warning');
                    }
                });
            }
            
            /**
             * Formatta il codice nell'editor
             */
            function formatCode() {
                // Implementazione specifica in base al tipo di file
                const mode = editor.getOption('mode');
                let formatted = false;
                
                switch (mode) {
                    case 'application/javascript':
                    case 'application/json':
                        try {
                            const content = editor.getValue();
                            const jsonObj = JSON.parse(content);
                            const formattedJson = JSON.stringify(jsonObj, null, 4);
                            editor.setValue(formattedJson);
                            formatted = true;
                        } catch (e) {
                            showNotification('Errore nella formattazione: JSON non valido', 'error');
                        }
                        break;
                    case 'text/html':
                    case 'text/xml':
                        // Semplice indentazione per HTML/XML
                        editor.execCommand('indentAuto');
                        formatted = true;
                        break;
                    case 'text/css':
                        // Semplice indentazione per CSS
                        editor.execCommand('indentAuto');
                        formatted = true;
                        break;
                    default:
                        // Per tutti gli altri tipi di file, usa l'indentazione automatica
                        editor.execCommand('indentAuto');
                        formatted = true;
                        break;
                }
                
                if (formatted) {
                    showNotification('Codice formattato');
                }
            }
            
            /**
             * Determina il modo appropriato di CodeMirror in base all'estensione del file
             * @param {string} fileName - Il nome del file
             * @returns {string} Il modo di CodeMirror
             */
            function getFileMode(fileName) {
                const ext = fileName.split('.').pop().toLowerCase();
                
                const modeMap = {
                    'js': 'application/javascript',
                    'json': 'application/json',
                    'html': 'text/html',
                    'htm': 'text/html',
                    'xml': 'text/xml',
                    'css': 'text/css',
                    'less': 'text/css',
                    'scss': 'text/css',
                    'sass': 'text/css',
                    'php': 'application/x-php',
                    'py': 'text/x-python',
                    'rb': 'text/x-ruby',
                    'java': 'text/x-java',
                    'c': 'text/x-csrc',
                    'cpp': 'text/x-c++src',
                    'h': 'text/x-c++hdr',
                    'cs': 'text/x-csharp',
                    'sql': 'text/x-sql',
                    'md': 'text/x-markdown',
                    'yaml': 'text/x-yaml',
                    'yml': 'text/x-yaml',
                    'ini': 'text/x-properties',
                    'sh': 'text/x-shellscript',
                    'bash': 'text/x-shellscript'
                };
                
                return modeMap[ext] || 'text/plain';
            }
            
            /**
             * Esegue una ricerca di file
             * @param {string} query - La query di ricerca
             */
            function searchFiles(query) {
                $('#search-results').html('<li><i class="fas fa-spinner fa-spin"></i> Ricerca in corso...</li>');
                
                $.ajax({
                    url: 'file-manager.php',
                    type: 'GET',
                    data: {
                        action: 'search',
                        query: query
                    },
                    dataType: 'json',
                    success: function(data) {
                        $('#search-results').empty();
                        
                        if (data.error) {
                            $('#search-results').html(`<li class="text-danger"><i class="fas fa-exclamation-circle"></i> ${data.error}</li>`);
                            return;
                        }
                        
                        if (data.length === 0) {
                            $('#search-results').html('<li class="text-muted"><i class="fas fa-info-circle"></i> Nessun risultato trovato</li>');
                            return;
                        }
                        
                        $.each(data, function(i, file) {
                            $('#search-results').append(`
                                <li class="search-result" data-path="${file.path}" data-type="${file.type}">
                                    <div>
                                        <i class="fas fa-${file.icon}"></i> ${file.name}
                                        <div class="search-path">${file.path}</div>
                                    </div>
                                </li>
                            `);
                        });
                    },
                    error: function(xhr, status, error) {
                        $('#search-results').html(`<li class="text-danger"><i class="fas fa-exclamation-circle"></i> Errore nella ricerca: ${error}</li>`);
                    }
                });
            }
            
            /**
             * Ripara i permessi dei file
             */
            function fixPermissions() {
                showNotification('Avvio riparazione permessi...', 'warning');
                
                $.ajax({
                    url: 'file-manager.php',
                    type: 'GET',
                    data: {
                        action: 'fix_permissions',
                        dir: currentPath
                    },
                    dataType: 'json',
                    success: function(response) {
                        if (response.error) {
                            showNotification(response.error, 'error');
                            return;
                        }
                        
                        if (response.success) {
                            showNotification('Permessi riparati con successo');
                            loadFileList(currentPath);
                        } else {
                            showNotification('Errore nella riparazione dei permessi', 'error');
                        }
                    },
                    error: function(xhr, status, error) {
                        showNotification('Errore nell\'operazione di riparazione', 'error');
                    }
                });
            }
            
            /**
             * Pulisce i file temporanei
             */
            function cleanupTempFiles() {
                showNotification('Avvio pulizia file temporanei...', 'warning');
                
                $.ajax({
                    url: 'file-manager.php',
                    type: 'GET',
                    data: {
                        action: 'cleanup_tmp'
                    },
                    dataType: 'json',
                    success: function(response) {
                        if (response.error) {
                            showNotification(response.error, 'error');
                            return;
                        }
                        
                        if (response.success) {
                            showNotification('File temporanei puliti con successo');
                        } else {
                            showNotification('Errore nella pulizia dei file temporanei', 'error');
                        }
                    },
                    error: function(xhr, status, error) {
                        showNotification('Errore nell\'operazione di pulizia', 'error');
                    }
                });
            }
            
            /**
             * Carica un URL nell'iframe di preview
             * @param {string} url - L'URL da caricare
             */
            function loadUrlInPreview(url) {
                // Assicurati che l'URL abbia un protocollo
                let formattedUrl = url;
                if (!url.startsWith('http://') && !url.startsWith('https://')) {
                    formattedUrl = 'http://' + url;
                }
                
                // Aggiorna tutti gli input di indirizzo con l'URL formattato
                $('#browser-url').val(formattedUrl);
                $('#browser-preview-fullscreen .browser-address input').val(formattedUrl);
                
                // Mostra l'indicatore di caricamento
                $('#browser-loading').show();
                
                // Aggiorna gli iframe sia nella vista normale che in quella a schermo intero
                $('#browser-frame').attr('src', formattedUrl);
                $('#browser-preview-fullscreen .browser-content').attr('src', formattedUrl);
                
                // Nasconde l'indicatore di caricamento quando il caricamento è completato
                $('#browser-frame').on('load', function() {
                    $('#browser-loading').hide();
                });
            }
            
            /**
             * Mostra una notifica
             * @param {string} message - Il messaggio da mostrare
             * @param {string} [type='success'] - Il tipo di notifica: success, error, warning
             */
            function showNotification(message, type = 'success') {
                const notification = $('#notification');
                
                // Imposta il messaggio
                notification.text(message);
                
                // Imposta il tipo di notifica
                notification.removeClass('success error warning');
                notification.addClass(type);
                
                // Mostra la notifica
                notification.fadeIn(300);
                
                // Nascondi la notifica dopo un po'
                setTimeout(function() {
                    notification.fadeOut(300);
                }, 3000);
            }
        });
    </script>
</body>
</html>
EOFHTML

# Sostituzione del placeholder SERVER_IP con l'IP effettivo
sed -i "s/SERVER_IP/$CURRENT_IP/g" $DEV_INTERFACE_DIR/index.html

#######################################################################
# IMPOSTAZIONE DEI PERMESSI
#######################################################################

print_message "Impostazione dei permessi corretti"
chown -R www-data:www-data $DEV_INTERFACE_DIR
chmod -R 755 $DEV_INTERFACE_DIR

#######################################################################
# RIEPILOGO FINALE
#######################################################################

print_message "CONFIGURAZIONE COMPLETATA CON SUCCESSO!"

echo -e "\n\033[1;32m=== INFORMAZIONI DI ACCESSO ===\033[0m"
echo -e "\033[1mApplicazione Web:\033[0m http://$CURRENT_IP/"
echo -e "\033[1mInterfaccia di Sviluppo:\033[0m http://$CURRENT_IP:$DEV_INTERFACE_PORT/"
echo -e "\033[1mphpMyAdmin:\033[0m http://$CURRENT_IP:$DEV_INTERFACE_PORT/phpmyadmin/"

# Carica le credenziali MySQL
if [ -f "$CONFIG_DIR/mysql_credentials.conf" ]; then
    source "$CONFIG_DIR/mysql_credentials.conf"
    echo -e "\033[1mUtente MySQL:\033[0m $DB_USER"
    echo -e "\033[1mPassword MySQL:\033[0m $DB_PASSWORD"
else
    echo -e "\033[1;31mATTENZIONE: File credenziali MySQL non trovato!\033[0m"
fi

echo -e "\n\033[1;32m=== UTILIZZO DI CLAUDE CODE ===\033[0m"
echo -e "Per utilizzare Claude Code, segui questi passi:\n"
echo -e "1. Connettiti al server via SSH"
echo -e "2. Esegui il comando: \033[1mclaude-app\033[0m"
echo -e "3. Utilizza Claude Code per creare la tua applicazione"
echo -e "4. I file creati saranno visibili su: http://$CURRENT_IP/"
echo -e "5. Puoi visualizzare e modificare i file tramite: http://$CURRENT_IP:$DEV_INTERFACE_PORT/"

echo -e "\nInterfaccia di sviluppo installata con successo!"
echo -e "Si consiglia di riavviare il server per assicurarsi che tutte le modifiche siano applicate correttamente."
