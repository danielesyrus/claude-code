<?php
/**
 * Claude Code IDE - File Manager Backend
 * Advanced file management interface with code editing capabilities
 */

// Abilita il reporting degli errori per il debug (rimuovere in produzione)
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

// Aumenta il limite di tempo di esecuzione per operazioni pesanti
set_time_limit(120);

// Avvia la sessione
session_start();

// Impostazioni dell'applicazione
$APP_DIR = '/var/www/html';
$SUDO_ENABLED = true;  // Abilita l'uso di sudo per operazioni specifiche
$CONFIG_DIR = '/opt/claude-env';

/**
 * Funzione per eseguire comandi shell in modo sicuro
 * @param string $command Il comando da eseguire
 * @param bool $useSudo Se usare sudo per eseguire il comando
 * @return array Risultato dell'esecuzione con output e stato
 */
function executeCommand($command, $useSudo = false) {
    $prefix = $useSudo ? 'sudo ' : '';
    $fullCommand = $prefix . escapeshellcmd($command) . ' 2>&1';
    
    $output = [];
    $returnVar = 0;
    
    exec($fullCommand, $output, $returnVar);
    
    return [
        'output' => implode("\n", $output),
        'status' => $returnVar
    ];
}

/**
 * Funzione per controllare se un file è un file di sistema protetto
 * @param string $path Il percorso del file da controllare
 * @return bool True se il file è un file di sistema, false altrimenti
 */
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

/**
 * Funzione per ottenere l'estensione di un file
 * @param string $filename Il nome del file
 * @return string L'estensione del file
 */
function getFileExtension($filename) {
    return pathinfo($filename, PATHINFO_EXTENSION);
}

/**
 * Funzione per determinare l'icona in base all'estensione del file
 * @param string $filename Il nome del file
 * @return string Il nome dell'icona
 */
function getFileIcon($filename) {
    $ext = strtolower(getFileExtension($filename));
    
    $iconMap = [
        // Web technologies
        'html' => 'html5',
        'htm' => 'html5',
        'css' => 'css3-alt',
        'js' => 'js',
        'json' => 'file-code',
        'php' => 'php',
        'md' => 'markdown',
        
        // Programming
        'py' => 'python',
        'java' => 'java',
        'c' => 'file-code',
        'cpp' => 'file-code',
        'cs' => 'file-code',
        'rb' => 'gem',
        
        // Data
        'sql' => 'database',
        'db' => 'database',
        'yml' => 'file-code',
        'yaml' => 'file-code',
        'xml' => 'file-code',
        
        // Config files
        'conf' => 'cogs',
        'ini' => 'cogs',
        
        // Shell scripts
        'sh' => 'terminal',
        'bash' => 'terminal',
        
        // Documents
        'txt' => 'file-alt',
        'pdf' => 'file-pdf',
        'doc' => 'file-word',
        'docx' => 'file-word',
        'xls' => 'file-excel',
        'xlsx' => 'file-excel',
        'ppt' => 'file-powerpoint',
        'pptx' => 'file-powerpoint',
        
        // Images
        'jpg' => 'file-image',
        'jpeg' => 'file-image',
        'png' => 'file-image',
        'gif' => 'file-image',
        'svg' => 'file-image',
        
        // Archives
        'zip' => 'file-archive',
        'tar' => 'file-archive',
        'gz' => 'file-archive',
        'rar' => 'file-archive'
    ];
    
    return isset($iconMap[$ext]) ? $iconMap[$ext] : 'file';
}

/**
 * Funzione per ottenere la grandezza di un file in formato leggibile
 * @param int $size La dimensione in byte
 * @return string La dimensione formattata
 */
function getReadableFileSize($size) {
    if ($size <= 0) return '0 B';
    
    $units = ['B', 'KB', 'MB', 'GB', 'TB'];
    $i = 0;
    
    while ($size >= 1024 && $i < count($units) - 1) {
        $size /= 1024;
        $i++;
    }
    
    return round($size, 2) . ' ' . $units[$i];
}

/**
 * Funzione per ottenere i permessi di un file in formato leggibile
 * @param string $path Il percorso del file
 * @return string I permessi formattati
 */
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

/**
 * Funzione per ottenere i dettagli completi di un file
 * @param string $path Il percorso del file
 * @return array Dettagli del file
 */
function getFileDetails($path) {
    if (!file_exists($path)) {
        return [
            'exists' => false,
            'error' => 'File non trovato'
        ];
    }
    
    try {
        $isDir = is_dir($path);
        $size = $isDir ? '-' : getReadableFileSize(filesize($path));
        $permissions = getFilePermissions($path);
        
        // Gestione sicura delle informazioni di proprietario/gruppo
        if (function_exists('posix_getpwuid') && function_exists('posix_getgrgid')) {
            $ownerInfo = posix_getpwuid(fileowner($path));
            $groupInfo = posix_getgrgid(filegroup($path));
            $owner = $ownerInfo ? $ownerInfo['name'] : 'unknown';
            $group = $groupInfo ? $groupInfo['name'] : 'unknown';
        } else {
            $owner = fileowner($path);
            $group = filegroup($path);
        }
        
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
    } catch (Exception $e) {
        return [
            'exists' => true,
            'path' => $path,
            'name' => basename($path),
            'type' => is_dir($path) ? 'directory' : 'file',
            'error' => 'Errore nel recupero dei dettagli: ' . $e->getMessage()
        ];
    }
}

/**
 * Funzione per ottenere le credenziali MySQL dal file di configurazione
 * @return array Le credenziali MySQL
 */
function getMySQLCredentials() {
    global $CONFIG_DIR, $SUDO_ENABLED;
    $credentialsFile = $CONFIG_DIR . '/mysql_credentials.conf';
    
    // Verifica se il file esiste e se il percorso è valido
    if (!file_exists($credentialsFile)) {
        // Prova a verificare la directory
        if (!is_dir($CONFIG_DIR)) {
            return [
                'error' => 'Directory di configurazione non trovata: ' . $CONFIG_DIR
            ];
        }
        
        return [
            'error' => 'File di credenziali non trovato: ' . $credentialsFile
        ];
    }
    
    // Utilizzo di sudo per leggere il file se non è leggibile direttamente
    if (!is_readable($credentialsFile) && $SUDO_ENABLED) {
        $result = executeCommand("cat " . escapeshellarg($credentialsFile), true);
        
        if ($result['status'] === 0) {
            $content = $result['output'];
        } else {
            return [
                'error' => 'Impossibile leggere il file delle credenziali: ' . $result['output']
            ];
        }
    } else {
        $content = @file_get_contents($credentialsFile);
        if ($content === false) {
            return [
                'error' => 'Errore nella lettura del file delle credenziali'
            ];
        }
    }
    
    $credentials = [];
    
    // Cerca le credenziali nel formato DB_XXX="valore"
    if (preg_match_all('/^\s*(DB_\w+)\s*=\s*"([^"]*)"\s*$/m', $content, $matches, PREG_SET_ORDER)) {
        foreach ($matches as $match) {
            $key = strtolower(str_replace('DB_', '', $match[1]));
            $value = $match[2];
            $credentials[$key] = $value;
        }
    }
    
    // Se non troviamo le credenziali nel formato standard, proviamo con i comandi grep
    if (!isset($credentials['user']) || !isset($credentials['password'])) {
        if ($SUDO_ENABLED) {
            $userCmd = executeCommand("grep DB_USER " . escapeshellarg($credentialsFile) . " | cut -d'\"' -f2", true);
            $passCmd = executeCommand("grep DB_PASSWORD " . escapeshellarg($credentialsFile) . " | cut -d'\"' -f2", true);
            
            if ($userCmd['status'] === 0 && !empty($userCmd['output'])) {
                $credentials['user'] = trim($userCmd['output']);
            }
            
            if ($passCmd['status'] === 0 && !empty($passCmd['output'])) {
                $credentials['password'] = trim($passCmd['output']);
            }
        }
    }
    
    // Se ancora non abbiamo trovato le credenziali, restituisci un valore predefinito
    if (!isset($credentials['user'])) {
        $credentials['user'] = 'root';
    }
    
    if (!isset($credentials['password'])) {
        $credentials['password'] = '';
    }
    
    return $credentials;
}

/**
 * Funzione per verificare che un percorso sia valido e sicuro
 * @param string $path Il percorso da verificare
 * @return string|false Il percorso verificato o false se non valido
 */
function validatePath($path) {
    // Converti in percorso assoluto
    $path = realpath($path);
    
    // Verifica che il percorso esista
    if ($path === false) {
        return false;
    }
    
    // Puoi aggiungere ulteriori controlli di sicurezza qui
    
    return $path;
}

// Gestione delle richieste GET
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $action = isset($_GET['action']) ? $_GET['action'] : 'list';
    
    // Ottieni credenziali MySQL
    if ($action === 'get_mysql_credentials') {
        try {
            $credentials = getMySQLCredentials();
            
            header('Content-Type: application/json');
            echo json_encode($credentials);
        } catch (Exception $e) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Errore nel recupero delle credenziali: ' . $e->getMessage()]);
        }
        exit;
    }
    
    // Lettura di un file
    if ($action === 'read' && isset($_GET['file'])) {
        $filePath = $_GET['file'];
        $isDownload = isset($_GET['download']) && $_GET['download'] === 'true';
        
        try {
            if (!file_exists($filePath)) {
                if (!$isDownload) {
                    header('Content-Type: application/json');
                    echo json_encode(['error' => 'File non trovato']);
                } else {
                    header('HTTP/1.0 404 Not Found');
                    echo 'File non trovato';
                }
                exit;
            }
            
            if (is_dir($filePath)) {
                if (!$isDownload) {
                    header('Content-Type: application/json');
                    echo json_encode(['error' => 'Il percorso è una directory']);
                } else {
                    header('HTTP/1.0 400 Bad Request');
                    echo 'Non è possibile scaricare directory';
                }
                exit;
            }
            
            if (!is_readable($filePath)) {
                // Se il file non è leggibile normalmente, prova a usare sudo
                if ($SUDO_ENABLED) {
                    $result = executeCommand("cat " . escapeshellarg($filePath), true);
                    
                    if ($result['status'] === 0) {
                        $content = $result['output'];
                        
                        if ($isDownload) {
                            // Per download, invia il contenuto con gli header appropriati
                            $fileName = basename($filePath);
                            header('Content-Type: application/octet-stream');
                            header('Content-Disposition: attachment; filename="' . $fileName . '"');
                            header('Content-Length: ' . strlen($content));
                            echo $content;
                        } else {
                            // Per letture normali, restituisci JSON
                            header('Content-Type: application/json');
                            echo json_encode([
                                'success' => true,
                                'content' => $content,
                                'sudo_used' => true
                            ]);
                        }
                        exit;
                    }
                }
                
                if (!$isDownload) {
                    header('Content-Type: application/json');
                    echo json_encode(['error' => 'File non leggibile']);
                } else {
                    header('HTTP/1.0 403 Forbidden');
                    echo 'File non leggibile';
                }
                exit;
            }
            
            // Leggi il contenuto del file
            $content = file_get_contents($filePath);
            
            if ($isDownload) {
                // Per download, invia il contenuto con gli header appropriati
                $fileName = basename($filePath);
                header('Content-Type: application/octet-stream');
                header('Content-Disposition: attachment; filename="' . $fileName . '"');
                header('Content-Length: ' . strlen($content));
                echo $content;
            } else {
                // Per letture normali, restituisci JSON
                header('Content-Type: application/json');
                echo json_encode([
                    'success' => true,
                    'content' => $content
                ]);
            }
        } catch (Exception $e) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Errore nella lettura del file: ' . $e->getMessage()]);
        }
        exit;
    }
    
    // Ottenere i dettagli di un file
    if ($action === 'details' && isset($_GET['file'])) {
        $filePath = $_GET['file'];
        
        try {
            $details = getFileDetails($filePath);
            
            header('Content-Type: application/json');
            echo json_encode($details);
        } catch (Exception $e) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Errore nel recupero dei dettagli: ' . $e->getMessage()]);
        }
        exit;
    }
    
    // Elenco dei file in una directory
    if ($action === 'list') {
        $directory = isset($_GET['dir']) ? $_GET['dir'] : $APP_DIR;
        
        try {
            // Assicurati che il percorso sia valido
            if (!file_exists($directory) || !is_dir($directory)) {
                header('Content-Type: application/json');
                echo json_encode(['error' => 'Directory non trovata: ' . $directory]);
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
                                    'is_executable' => strpos($permissions, 'x') !== false,
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
                echo json_encode(['error' => 'Directory non leggibile: ' . $directory]);
                exit;
            }
            
            $files = [];
            
            // Verifica sicura che la DirectoryIterator possa essere creata
            try {
                $dirIterator = new DirectoryIterator($directory);
            } catch (Exception $e) {
                header('Content-Type: application/json');
                echo json_encode(['error' => 'Errore nell\'accesso alla directory: ' . $e->getMessage()]);
                exit;
            }
            
            foreach ($dirIterator as $fileInfo) {
                if ($fileInfo->isDot()) continue;
                
                $path = $fileInfo->getPathname();
                $isDir = $fileInfo->isDir();
                
                // Calcola la dimensione in modo sicuro
                try {
                    $size = $isDir ? '-' : getReadableFileSize($fileInfo->getSize());
                } catch (Exception $e) {
                    $size = 'N/A';
                }
                
                $permissions = getFilePermissions($path);
                
                // Ottieni proprietario e gruppo in modo sicuro
                if (function_exists('posix_getpwuid') && function_exists('posix_getgrgid')) {
                    $ownerInfo = posix_getpwuid(fileowner($path));
                    $groupInfo = posix_getgrgid(filegroup($path));
                    $owner = $ownerInfo ? $ownerInfo['name'] : 'unknown';
                    $group = $groupInfo ? $groupInfo['name'] : 'unknown';
                } else {
                    $owner = fileowner($path);
                    $group = filegroup($path);
                }
                
                $lastModified = date('Y-m-d H:i:s', $fileInfo->getMTime());
                $isWritable = is_writable($path);
                $isReadable = is_readable($path);
                $isExecutable = is_executable($path);
                $isSystem = isSystemFile($path);
                
                $files[] = [
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
            }
            
            header('Content-Type: application/json');
            echo json_encode($files);
        } catch (Exception $e) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Errore nel listare i file: ' . $e->getMessage()]);
        }
        exit;
    }
    
    // Ricerca di file
    if ($action === 'search' && isset($_GET['query'])) {
        $query = $_GET['query'];
        $directory = isset($_GET['dir']) ? $_GET['dir'] : $APP_DIR;
        
        try {
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
        } catch (Exception $e) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Errore nella ricerca: ' . $e->getMessage()]);
        }
        exit;
    }
    
    // Manutenzione: correzione permessi
    if ($action === 'fix_permissions') {
        try {
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
                "chown -R www-data:www-data $escapedDir"
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
        } catch (Exception $e) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Errore nella riparazione dei permessi: ' . $e->getMessage()]);
        }
        exit;
    }
    
    // Manutenzione: pulizia file temporanei
    if ($action === 'cleanup_tmp') {
        try {
            if (!$SUDO_ENABLED) {
                header('Content-Type: application/json');
                echo json_encode(['error' => 'Operazione non consentita senza sudo']);
                exit;
            }
            
            $tmpDirs = ['/tmp', '/var/tmp'];
            $results = [];
            $success = true;
            
            foreach ($tmpDirs as $dir) {
                if (!is_dir($dir)) {
                    continue;
                }
                
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
        } catch (Exception $e) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Errore nella pulizia dei file temporanei: ' . $e->getMessage()]);
        }
        exit;
    }
}

// Gestione delle richieste POST
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = isset($_POST['action']) ? $_POST['action'] : '';
    
    // Creazione di un nuovo file
    if ($action === 'create' && isset($_POST['file'])) {
        try {
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
                        executeCommand("chown www-data:www-data " . escapeshellarg($filePath), true);
                        
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
                if (function_exists('chown') && function_exists('chgrp')) {
                    @chown($filePath, 'www-data');
                    @chgrp($filePath, 'www-data');
                }
                
                header('Content-Type: application/json');
                echo json_encode(['success' => true]);
                exit;
            } else {
                header('Content-Type: application/json');
                echo json_encode(['error' => 'Errore nella creazione del file']);
                exit;
            }
        } catch (Exception $e) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Errore nella creazione del file: ' . $e->getMessage()]);
        }
        exit;
    }
    
    // Creazione di una nuova directory
    if ($action === 'create_dir' && isset($_POST['dir']) && isset($_POST['name'])) {
        try {
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
                        executeCommand("chown www-data:www-data " . escapeshellarg($dirPath), true);
                        
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
                if (function_exists('chown') && function_exists('chgrp')) {
                    @chown($dirPath, 'www-data');
                    @chgrp($dirPath, 'www-data');
                }
                
                header('Content-Type: application/json');
                echo json_encode(['success' => true]);
                exit;
            } else {
                header('Content-Type: application/json');
                echo json_encode(['error' => 'Errore nella creazione della directory']);
                exit;
            }
        } catch (Exception $e) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Errore nella creazione della directory: ' . $e->getMessage()]);
        }
        exit;
    }
    
    // Salvataggio di un file
    if ($action === 'save' && isset($_POST['file']) && isset($_POST['content'])) {
        try {
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
                        if (function_exists('chown') && function_exists('chgrp')) {
                            @chown($filePath, 'www-data');
                            @chgrp($filePath, 'www-data');
                        }
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
        } catch (Exception $e) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Errore nel salvataggio del file: ' . $e->getMessage()]);
        }
        exit;
    }
    
    // Eliminazione di un file o directory
    if ($action === 'delete' && isset($_POST['path'])) {
        try {
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
        } catch (Exception $e) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Errore nell\'eliminazione: ' . $e->getMessage()]);
        }
        exit;
    }
    
    // Rinomina un file o directory
    if ($action === 'rename' && isset($_POST['old_path']) && isset($_POST['new_name'])) {
        try {
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
        } catch (Exception $e) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Errore nella rinomina: ' . $e->getMessage()]);
        }
        exit;
    }
    
    // Caricamento file
    if ($action === 'upload' && isset($_FILES['file'])) {
        try {
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
                        executeCommand("chown www-data:www-data " . escapeshellarg($targetPath), true);
                        
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
        } catch (Exception $e) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Errore nel caricamento del file: ' . $e->getMessage()]);
        }
        exit;
    }
    
    // Modifica dei permessi (CHMOD)
    if ($action === 'chmod' && isset($_POST['path']) && isset($_POST['mode'])) {
        try {
            $path = $_POST['path'];
            $mode = $_POST['mode'];
            
            // Verifica formato del modo (3 o 4 cifre ottali)
            if (!preg_match('/^[0-7]{3,4}$/', $mode)) {
                header('Content-Type: application/json');
                echo json_encode(['error' => 'Formato permessi non valido']);
                exit;
            }
            
            // Converti alla forma ottale
            $modeOctal = octdec($mode);
            
            // Se il percorso non è modificabile e sudo è abilitato, usalo
            if (!is_writable($path) && $SUDO_ENABLED) {
                $command = "chmod " . escapeshellarg($mode) . " " . escapeshellarg($path);
                $result = executeCommand($command, true);
                
                if ($result['status'] === 0) {
                    header('Content-Type: application/json');
                    echo json_encode(['success' => true, 'sudo_used' => true]);
                    exit;
                } else {
                    header('Content-Type: application/json');
                    echo json_encode(['error' => 'Errore nella modifica dei permessi con sudo: ' . $result['output']]);
                    exit;
                }
            }
            
            // Modifica standard dei permessi
            if (chmod($path, $modeOctal)) {
                header('Content-Type: application/json');
                echo json_encode(['success' => true]);
                exit;
            } else {
                header('Content-Type: application/json');
                echo json_encode(['error' => 'Errore nella modifica dei permessi']);
                exit;
            }
        } catch (Exception $e) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Errore: ' . $e->getMessage()]);
        }
        exit;
    }
    
    // Copia di un file/directory
    if ($action === 'copy' && isset($_POST['source']) && isset($_POST['destination'])) {
        try {
            $source = $_POST['source'];
            $destination = $_POST['destination'];
            
            // Verifica che la sorgente esista
            if (!file_exists($source)) {
                header('Content-Type: application/json');
                echo json_encode(['error' => 'File o directory di origine non trovata']);
                exit;
            }
            
            // Verifica che la destinazione non esista già
            if (file_exists($destination)) {
                header('Content-Type: application/json');
                echo json_encode(['error' => 'Un file o directory con lo stesso nome esiste già nella destinazione']);
                exit;
            }
            
            if (is_dir($source)) {
                // Copia ricorsiva di directory
                function copyDir($src, $dst) {
                    $dir = opendir($src);
                    @mkdir($dst, 0755, true);
                    
                    while (($file = readdir($dir)) !== false) {
                        if ($file != '.' && $file != '..') {
                            $srcFile = $src . '/' . $file;
                            $dstFile = $dst . '/' . $file;
                            
                            if (is_dir($srcFile)) {
                                copyDir($srcFile, $dstFile);
                            } else {
                                copy($srcFile, $dstFile);
                                chmod($dstFile, fileperms($srcFile));
                            }
                        }
                    }
                    
                    closedir($dir);
                }
                
                // Se la directory non è copiabile normalmente, usa sudo
                if (!is_readable($source) && $SUDO_ENABLED) {
                    $command = "cp -R " . escapeshellarg($source) . " " . escapeshellarg($destination);
                    $result = executeCommand($command, true);
                    
                    if ($result['status'] === 0) {
                        header('Content-Type: application/json');
                        echo json_encode(['success' => true, 'sudo_used' => true]);
                        exit;
                    } else {
                        header('Content-Type: application/json');
                        echo json_encode(['error' => 'Errore nella copia della directory con sudo: ' . $result['output']]);
                        exit;
                    }
                }
                
                // Copia standard
                copyDir($source, $destination);
                header('Content-Type: application/json');
                echo json_encode(['success' => true]);
                exit;
            } else {
                // Copia di un singolo file
                if (!is_readable($source) && $SUDO_ENABLED) {
                    $command = "cp " . escapeshellarg($source) . " " . escapeshellarg($destination);
                    $result = executeCommand($command, true);
                    
                    if ($result['status'] === 0) {
                        header('Content-Type: application/json');
                        echo json_encode(['success' => true, 'sudo_used' => true]);
                        exit;
                    } else {
                        header('Content-Type: application/json');
                        echo json_encode(['error' => 'Errore nella copia del file con sudo: ' . $result['output']]);
                        exit;
                    }
                }
                
                // Copia standard
                if (copy($source, $destination)) {
                    // Mantieni gli stessi permessi
                    chmod($destination, fileperms($source));
                    header('Content-Type: application/json');
                    echo json_encode(['success' => true]);
                    exit;
                } else {
                    header('Content-Type: application/json');
                    echo json_encode(['error' => 'Errore nella copia del file']);
                    exit;
                }
            }
        } catch (Exception $e) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Errore nella copia: ' . $e->getMessage()]);
        }
        exit;
    }
    
    // Spostamento di un file/directory
    if ($action === 'move' && isset($_POST['source']) && isset($_POST['destination'])) {
        try {
            $source = $_POST['source'];
            $destination = $_POST['destination'];
            
            // Verifica che la sorgente esista
            if (!file_exists($source)) {
                header('Content-Type: application/json');
                echo json_encode(['error' => 'File o directory di origine non trovata']);
                exit;
            }
            
            // Verifica che la destinazione non esista già
            if (file_exists($destination)) {
                header('Content-Type: application/json');
                echo json_encode(['error' => 'Un file o directory con lo stesso nome esiste già nella destinazione']);
                exit;
            }
            
            // Se il file non è spostabile normalmente e sudo è abilitato, usalo
            if ((!is_writable($source) || !is_writable(dirname($destination))) && $SUDO_ENABLED) {
                $command = "mv " . escapeshellarg($source) . " " . escapeshellarg($destination);
                $result = executeCommand($command, true);
                
                if ($result['status'] === 0) {
                    header('Content-Type: application/json');
                    echo json_encode(['success' => true, 'sudo_used' => true]);
                    exit;
                } else {
                    header('Content-Type: application/json');
                    echo json_encode(['error' => 'Errore nello spostamento con sudo: ' . $result['output']]);
                    exit;
                }
            }
            
            // Spostamento standard
            if (rename($source, $destination)) {
                header('Content-Type: application/json');
                echo json_encode(['success' => true]);
                exit;
            } else {
                header('Content-Type: application/json');
                echo json_encode(['error' => 'Errore nello spostamento']);
                exit;
            }
        } catch (Exception $e) {
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Errore nello spostamento: ' . $e->getMessage()]);
        }
        exit;
    }
}

// Se siamo arrivati qui, l'azione richiesta non è valida
header('Content-Type: application/json');
echo json_encode(['error' => 'Azione non valida']);