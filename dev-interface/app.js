/**
 * Syrus Code IDE - Main Application JavaScript
 * Modern web interface for server file management and code editing
 */

$(document).ready(function() {
    // Global variables
    let editor;
    let currentPath = "/var/www/html";
    let currentFile = null;
    let originalContent = "";
    let openFiles = {};
    let isEditorWordWrap = false;
    let darkTheme = localStorage.getItem('darkTheme') === 'true';
    
    // Initialize the application
    init();
    
    /**
     * Initialize the application
     */
    function init() {
        // Apply saved theme preference
        if (darkTheme) {
            document.body.classList.add('dark-theme');
            $('#theme-toggle i').removeClass('fa-moon').addClass('fa-sun');
        }
        
        // Setup event handlers
        setupEventHandlers();
        
        // Load the file list
        loadFileList(currentPath);
        
        // Setup context menu
        setupContextMenu();
        
        // Setup file upload
        setupFileUpload();
        
        // Load MySQL credentials
        loadMySQLCredentials();
    }
    
    /**
     * Set up all event handlers
     */
    function setupEventHandlers() {
        // Top navigation tabs
        $('.nav-tab').click(function() {
            const view = $(this).data('view');
            
            // Update active nav tab
            $('.nav-tab').removeClass('active');
            $(this).addClass('active');
            
            // Show the corresponding panel
            $('.panel').removeClass('active');
            $(`#${view}-panel`).addClass('active');
        });
        
        // Theme toggle
        $('#theme-toggle').click(function() {
            darkTheme = !darkTheme;
            document.body.classList.toggle('dark-theme', darkTheme);
            
            // Toggle icon
            if (darkTheme) {
                $(this).find('i').removeClass('fa-moon').addClass('fa-sun');
            } else {
                $(this).find('i').removeClass('fa-sun').addClass('fa-moon');
            }
            
            // Save preference
            localStorage.setItem('darkTheme', darkTheme);
        });
        
        // File explorer actions
        setupFileExplorerEvents();
        
        // Editor actions
        setupEditorEvents();
        
        // Search functionality
        setupSearchEvents();
        
        // Admin tools
        setupAdminEvents();
        
        // Notification close button
        $('#notification-close').click(function() {
            $('#notification').fadeOut(300);
        });
        
        // Dialog overlay click (close dialog)
        $(document).on('click', '.dialog-overlay', function(e) {
            if ($(e.target).hasClass('dialog-overlay')) {
                closeDialog();
            }
        });
        
        // Global keyboard shortcuts
        $(document).keydown(function(e) {
            // Ctrl+S to save current file
            if ((e.ctrlKey || e.metaKey) && e.key === 's') {
                e.preventDefault();
                if (editor && currentFile) {
                    saveFile(currentFile, editor.getValue());
                }
            }
            
            // Escape to close dialog
            if (e.key === 'Escape') {
                closeDialog();
            }
        });
    }
    
    /**
     * Set up file explorer events
     */
    function setupFileExplorerEvents() {
        // Refresh files button
        $('#refresh-files').click(function() {
            loadFileList(currentPath);
        });
        
        // New file button
        $('#new-file-btn').click(function() {
            $('.new-file-form').css('display', 'flex');
            $('#new-file-name').focus();
        });
        
        // Cancel new file button
        $('#cancel-file-btn').click(function() {
            $('.new-file-form').hide();
            $('#new-file-name').val('');
        });
        
        // Create file button
        $('#create-file-btn').click(function() {
            const fileName = $('#new-file-name').val().trim();
            if (fileName) {
                createFile(currentPath, fileName);
            }
        });
        
        // New folder button
        $('#new-folder-btn').click(function() {
            $('.new-folder-form').css('display', 'flex');
            $('#new-folder-name').focus();
        });
        
        // Cancel new folder button
        $('#cancel-folder-btn').click(function() {
            $('.new-folder-form').hide();
            $('#new-folder-name').val('');
        });
        
        // Create folder button
        $('#create-folder-btn').click(function() {
            const folderName = $('#new-folder-name').val().trim();
            if (folderName) {
                createFolder(currentPath, folderName);
            }
        });
        
        // Enter key in new file/folder input
        $('#new-file-name').keypress(function(e) {
            if (e.which === 13) { // Enter key
                $('#create-file-btn').click();
            }
        });
        
        $('#new-folder-name').keypress(function(e) {
            if (e.which === 13) { // Enter key
                $('#create-folder-btn').click();
            }
        });
        
        // File and directory click handler
        $(document).on('click', '.file-item', function(e) {
            // Ignore if clicked on file actions
            if ($(e.target).closest('.file-actions').length > 0) {
                return;
            }
            
            const filePath = $(this).data('path');
            const fileType = $(this).data('type');
            
            if (fileType === 'directory') {
                // Navigate to directory
                navigateToDirectory(filePath);
            } else {
                // Open file in editor
                openFileInEditor(filePath);
            }
        });
        
        // Path navigation click handler
        $(document).on('click', '.path-segment', function() {
            const path = $(this).data('path');
            navigateToDirectory(path);
        });
        
        // File action buttons
        $(document).on('click', '.file-action-btn', function(e) {
            e.stopPropagation();
            
            const action = $(this).data('action');
            const filePath = $(this).closest('.file-item').data('path');
            
            switch (action) {
                case 'info':
                    showFileInfo(filePath);
                    break;
                case 'copy':
                    showCopyFileDialog(filePath);
                    break;
                case 'move':
                    showMoveFileDialog(filePath);
                    break;
                case 'rename':
                    showRenameDialog(filePath);
                    break;
                case 'delete':
                    showDeleteConfirmDialog(filePath);
                    break;
                case 'download':
                    downloadFile(filePath);
                    break;
            }
        });
    }
    
    /**
     * Show file information in a dialog
     * @param {string} filePath - The path of the file
     */
    function showFileInfo(filePath) {
        // Show loading state
        showDialog(`
            <h4 class="dialog-title">Informazioni File</h4>
            <div class="text-center p-3">
                <i class="fas fa-spinner fa-spin"></i> Caricamento informazioni...
            </div>
        `);
        
        // Get file details from the server
        $.ajax({
            url: 'file-manager.php',
            type: 'GET',
            data: {
                action: 'details',
                file: filePath
            },
            dataType: 'json',
            success: function(details) {
                if (details.error) {
                    showNotification(details.error, 'error');
                    closeDialog();
                    return;
                }
                
                // Create info dialog content
                const fileName = filePath.split('/').pop();
                const isDir = details.type === 'directory';
                const icon = isDir ? 'folder' : details.icon || 'file';
                
                let dialogContent = `
                    <h4 class="dialog-title">Informazioni File</h4>
                    <div class="file-details">
                        <div class="file-detail-header mb-3">
                            <i class="fas fa-${icon} fa-2x"></i>
                            <h5>${fileName}</h5>
                        </div>
                        <table class="table table-sm">
                            <tbody>
                                <tr>
                                    <th scope="row">Percorso</th>
                                    <td>${details.path}</td>
                                </tr>
                                <tr>
                                    <th scope="row">Tipo</th>
                                    <td>${isDir ? 'Directory' : 'File'}</td>
                                </tr>`;
                
                if (!isDir) {
                    dialogContent += `
                                <tr>
                                    <th scope="row">Dimensione</th>
                                    <td>${details.size}</td>
                                </tr>`;
                }
                
                dialogContent += `
                                <tr>
                                    <th scope="row">Permessi</th>
                                    <td>${details.permissions}</td>
                                </tr>
                                <tr>
                                    <th scope="row">Proprietario</th>
                                    <td>${details.owner}:${details.group}</td>
                                </tr>
                                <tr>
                                    <th scope="row">Ultima modifica</th>
                                    <td>${details.last_modified}</td>
                                </tr>
                                <tr>
                                    <th scope="row">Attributi</th>
                                    <td>
                                        ${details.is_readable ? '<span class="badge bg-success me-1">Leggibile</span>' : '<span class="badge bg-danger me-1">Non leggibile</span>'}
                                        ${details.is_writable ? '<span class="badge bg-success me-1">Scrivibile</span>' : '<span class="badge bg-danger me-1">Non scrivibile</span>'}
                                        ${details.is_executable ? '<span class="badge bg-success me-1">Eseguibile</span>' : '<span class="badge bg-danger me-1">Non eseguibile</span>'}
                                        ${details.is_system ? '<span class="badge bg-warning me-1">File di sistema</span>' : ''}
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                    
                    <div class="permissions-editor">
                        <div class="permissions-title">
                            <i class="fas fa-shield-alt"></i> Modifica Permessi
                        </div>
                        <div class="permissions-grid">
                            <div class="label"></div>
                            <div class="header">Lettura</div>
                            <div class="header">Scrittura</div>
                            <div class="header">Esecuzione</div>
                            
                            <div class="label">Proprietario</div>
                            <div><input type="checkbox" class="form-check-input" id="perm-owner-r" ${details.permissions.charAt(1) === 'r' ? 'checked' : ''}></div>
                            <div><input type="checkbox" class="form-check-input" id="perm-owner-w" ${details.permissions.charAt(2) === 'w' ? 'checked' : ''}></div>
                            <div><input type="checkbox" class="form-check-input" id="perm-owner-x" ${details.permissions.charAt(3) === 'x' ? 'checked' : ''}></div>
                            
                            <div class="label">Gruppo</div>
                            <div><input type="checkbox" class="form-check-input" id="perm-group-r" ${details.permissions.charAt(4) === 'r' ? 'checked' : ''}></div>
                            <div><input type="checkbox" class="form-check-input" id="perm-group-w" ${details.permissions.charAt(5) === 'w' ? 'checked' : ''}></div>
                            <div><input type="checkbox" class="form-check-input" id="perm-group-x" ${details.permissions.charAt(6) === 'x' ? 'checked' : ''}></div>
                            
                            <div class="label">Altri</div>
                            <div><input type="checkbox" class="form-check-input" id="perm-others-r" ${details.permissions.charAt(7) === 'r' ? 'checked' : ''}></div>
                            <div><input type="checkbox" class="form-check-input" id="perm-others-w" ${details.permissions.charAt(8) === 'w' ? 'checked' : ''}></div>
                            <div><input type="checkbox" class="form-check-input" id="perm-others-x" ${details.permissions.charAt(9) === 'x' ? 'checked' : ''}></div>
                        </div>
                        
                        <div class="permissions-chmod">
                            <label for="chmod-value">Valore Chmod:</label>
                            <input type="text" class="form-control" id="chmod-value" placeholder="755">
                        </div>
                    </div>
                    
                    <div class="dialog-buttons">
                        <button class="btn btn-secondary" id="info-close">Chiudi</button>
                        <button class="btn btn-primary" id="save-permissions">Applica Permessi</button>
                        ${!isDir ? '<button class="btn btn-success ms-2" id="info-edit">Modifica File</button>' : ''}
                    </div>
                `;
                
                // Update dialog content
                $('#dialog-content').html(dialogContent);
                
                // Checkbox change handlers for permissions
                $('.permissions-grid input[type="checkbox"]').change(function() {
                    updateChmodValue();
                });
                
                // Initialize chmod value
                updateChmodValue();
                
                // Manual chmod value handler
                $('#chmod-value').on('input', function() {
                    const value = $(this).val().trim();
                    if (/^[0-7]{3,4}$/.test(value)) {
                        updatePermissionCheckboxes(value);
                    }
                });
                
                // Handle close button
                $('#info-close').click(function() {
                    closeDialog();
                });
                
                // Handle edit button
                $('#info-edit').click(function() {
                    closeDialog();
                    openFileInEditor(filePath);
                });
                
                // Handle save permissions button
                $('#save-permissions').click(function() {
                    const chmodValue = $('#chmod-value').val().trim();
                    if (chmodValue && /^[0-7]{3,4}$/.test(chmodValue)) {
                        changeFilePermissions(filePath, chmodValue);
                    } else {
                        showNotification('Il valore dei permessi non è valido', 'error');
                    }
                });
            },
            error: function(xhr, status, error) {
                showNotification('Errore nel recupero delle informazioni: ' + error, 'error');
                closeDialog();
            }
        });
    }
    
    /**
     * Update chmod value based on checkboxes
     */
    function updateChmodValue() {
        let ownerValue = 0;
        let groupValue = 0;
        let othersValue = 0;
        
        if ($('#perm-owner-r').prop('checked')) ownerValue += 4;
        if ($('#perm-owner-w').prop('checked')) ownerValue += 2;
        if ($('#perm-owner-x').prop('checked')) ownerValue += 1;
        
        if ($('#perm-group-r').prop('checked')) groupValue += 4;
        if ($('#perm-group-w').prop('checked')) groupValue += 2;
        if ($('#perm-group-x').prop('checked')) groupValue += 1;
        
        if ($('#perm-others-r').prop('checked')) othersValue += 4;
        if ($('#perm-others-w').prop('checked')) othersValue += 2;
        if ($('#perm-others-x').prop('checked')) othersValue += 1;
        
        $('#chmod-value').val('' + ownerValue + groupValue + othersValue);
    }
    
    /**
     * Update checkboxes based on chmod value
     * @param {string} chmodValue - The chmod value (e.g. "755")
     */
    function updatePermissionCheckboxes(chmodValue) {
        // Ensure it's a 3 or 4 digit number
        if (!/^[0-7]{3,4}$/.test(chmodValue)) return;
        
        // Get last 3 digits if it's 4 digits
        const digits = chmodValue.slice(-3);
        
        const owner = parseInt(digits[0], 10);
        const group = parseInt(digits[1], 10);
        const others = parseInt(digits[2], 10);
        
        $('#perm-owner-r').prop('checked', (owner & 4) !== 0);
        $('#perm-owner-w').prop('checked', (owner & 2) !== 0);
        $('#perm-owner-x').prop('checked', (owner & 1) !== 0);
        
        $('#perm-group-r').prop('checked', (group & 4) !== 0);
        $('#perm-group-w').prop('checked', (group & 2) !== 0);
        $('#perm-group-x').prop('checked', (group & 1) !== 0);
        
        $('#perm-others-r').prop('checked', (others & 4) !== 0);
        $('#perm-others-w').prop('checked', (others & 2) !== 0);
        $('#perm-others-x').prop('checked', (others & 1) !== 0);
    }
    
    /**
     * Change file permissions
     * @param {string} filePath - The path of the file
     * @param {string} permissions - The chmod value (e.g. "755")
     */
    function changeFilePermissions(filePath, permissions) {
        $.ajax({
            url: 'file-manager.php',
            type: 'POST',
            data: {
                action: 'chmod',
                path: filePath,
                mode: permissions
            },
            dataType: 'json',
            success: function(response) {
                if (response.error) {
                    showNotification(response.error, 'error');
                    return;
                }
                
                showNotification('Permessi modificati con successo', 'success');
                closeDialog();
                
                // Reload file list to show updated permissions
                loadFileList(currentPath);
            },
            error: function(xhr, status, error) {
                showNotification('Errore nella modifica dei permessi: ' + error, 'error');
            }
        });
    }
    
    /**
     * Show dialog for copying a file
     * @param {string} filePath - The path of the file to copy
     */
    function showCopyFileDialog(filePath) {
        // Get file name
        const fileName = filePath.split('/').pop();
        const isDir = filePath.indexOf('.') === -1; // Metodo semplice per controllare se è una directory
        
        // Show dialog
        showDialog(`
            <h4 class="dialog-title">Copia ${isDir ? 'Directory' : 'File'}</h4>
            <p>Seleziona la directory di destinazione per copiare <strong>${fileName}</strong>:</p>
            
            <div class="destination-selector" id="destination-tree">
                <div class="text-center p-3">
                    <i class="fas fa-spinner fa-spin"></i> Caricamento directory...
                </div>
            </div>
            
            <div class="destination-path" id="destination-path">
                Destinazione: <span id="selected-path">/var/www/html</span>
            </div>
            
            <div class="dialog-buttons">
                <button class="btn btn-secondary" id="copy-cancel">Annulla</button>
                <button class="btn btn-primary" id="copy-confirm">Copia</button>
            </div>
        `);
        
        // Load directory structure
        loadDirectoryTree('/var/www/html', $('#destination-tree'));
        
        // Set initial destination path
        const initialDestination = '/var/www/html';
        $('#selected-path').text(initialDestination);
        
        // Cancel button
        $('#copy-cancel').click(function() {
            closeDialog();
        });
        
        // Confirm button
        $('#copy-confirm').click(function() {
            const destinationPath = $('#selected-path').text();
            copyFile(filePath, destinationPath);
        });
    }
    
    /**
     * Show dialog for moving a file
     * @param {string} filePath - The path of the file to move
     */
    function showMoveFileDialog(filePath) {
        // Get file name
        const fileName = filePath.split('/').pop();
        const isDir = filePath.indexOf('.') === -1; // Metodo semplice per controllare se è una directory
        
        // Show dialog
        showDialog(`
            <h4 class="dialog-title">Sposta ${isDir ? 'Directory' : 'File'}</h4>
            <p>Seleziona la directory di destinazione per spostare <strong>${fileName}</strong>:</p>
            
            <div class="destination-selector" id="destination-tree">
                <div class="text-center p-3">
                    <i class="fas fa-spinner fa-spin"></i> Caricamento directory...
                </div>
            </div>
            
            <div class="destination-path" id="destination-path">
                Destinazione: <span id="selected-path">/var/www/html</span>
            </div>
            
            <div class="dialog-buttons">
                <button class="btn btn-secondary" id="move-cancel">Annulla</button>
                <button class="btn btn-primary" id="move-confirm">Sposta</button>
            </div>
        `);
        
        // Load directory structure
        loadDirectoryTree('/var/www/html', $('#destination-tree'));
        
        // Set initial destination path
        const initialDestination = '/var/www/html';
        $('#selected-path').text(initialDestination);
        
        // Cancel button
        $('#move-cancel').click(function() {
            closeDialog();
        });
        
        // Confirm button
        $('#move-confirm').click(function() {
            const destinationPath = $('#selected-path').text();
            moveFile(filePath, destinationPath);
        });
    }
    
    /**
     * Load directory tree for file copy/move operations
     * @param {string} path - The directory path to load
     * @param {jQuery} container - The container to append the tree to
     */
    function loadDirectoryTree(path, container) {
        // Mostra un indicatore di caricamento
        container.html(`<div class="text-center p-3"><i class="fas fa-spinner fa-spin"></i> Caricamento directory...</div>`);
        
        $.ajax({
            url: 'file-manager.php',
            type: 'GET',
            data: {
                action: 'list',
                dir: path
            },
            dataType: 'json',
            success: function(data) {
                if (data.error) {
                    container.html(`<div class="text-danger p-3"><i class="fas fa-exclamation-circle"></i> ${data.error}</div>`);
                    console.error("Error loading directory:", data.error);
                    return;
                }
                
                // Filtra per mostrare solo directory
                const directories = data.filter(item => item.type === 'directory');
                
                // Ordina alfabeticamente
                directories.sort((a, b) => a.name.localeCompare(b.name));
                
                // Clear container
                container.empty();
                
                if (directories.length === 0) {
                    container.html(`<div class="text-center p-3">Nessuna directory trovata</div>`);
                    return;
                }
                
                // Aggiungi directory padre se non siamo alla root
                if (path !== '/var/www/html') {
                    const parentPath = path.substring(0, path.lastIndexOf('/'));
                    if (parentPath) {
                        container.append(`
                            <div class="destination-item" data-path="${parentPath}">
                                <i class="fas fa-folder"></i>
                                <span>..</span>
                            </div>
                        `);
                    }
                }
                
                // Aggiungi le directory
                directories.forEach(dir => {
                    container.append(`
                        <div class="destination-item" data-path="${dir.path}">
                            <i class="fas fa-folder"></i>
                            <span>${dir.name}</span>
                        </div>
                    `);
                });
                
                // Aggiungi handler per click sulle directory
                container.find('.destination-item').click(function() {
                    const dirPath = $(this).data('path');
                    
                    // Aggiorna percorso selezionato
                    $('#selected-path').text(dirPath);
                    
                    // Carica le sottodirectory
                    loadDirectoryTree(dirPath, container);
                    
                    // Marca come selezionata
                    container.find('.destination-item').removeClass('selected');
                    $(this).addClass('selected');
                });
            },
            error: function(xhr, status, error) {
                container.html(`<div class="text-danger p-3"><i class="fas fa-exclamation-circle"></i> Errore nel caricamento delle directory: ${error}</div>`);
                console.error("AJAX Error:", xhr.responseText);
            }
        });
    }
    
    /**
     * Helper function to get correct icon class based on file type and extension
     * @param {string} fileType - The type of file ('file' or 'directory')
     * @param {string} fileExtension - The file extension
     * @returns {string} The correct FontAwesome icon class
     */
    function getCorrectIconClass(fileType, fileExtension) {
        // Se è una directory, usa l'icona della cartella
        if (fileType === 'directory') {
            return 'folder';
        }
        
        // Altrimenti determina l'icona in base all'estensione del file
        const ext = fileExtension.toLowerCase();
        
        const iconMap = {
            // Web technologies
            'html': 'html5',
            'htm': 'html5',
            'css': 'css3-alt',
            'js': 'js-square',
            'json': 'file-code',
            'php': 'php',
            
            // Programming languages
            'py': 'python',
            'java': 'java',
            'rb': 'gem',
            'c': 'file-code',
            'cpp': 'file-code',
            'cs': 'file-code',
            
            // Documents
            'txt': 'file-alt',
            'md': 'markdown',
            'pdf': 'file-pdf',
            'doc': 'file-word',
            'docx': 'file-word',
            'xls': 'file-excel',
            'xlsx': 'file-excel',
            'ppt': 'file-powerpoint',
            'pptx': 'file-powerpoint',
            
            // Images
            'jpg': 'file-image',
            'jpeg': 'file-image',
            'png': 'file-image',
            'gif': 'file-image',
            'svg': 'file-image',
            
            // Others
            'zip': 'file-archive',
            'rar': 'file-archive',
            'tar': 'file-archive',
            'gz': 'file-archive',
            'sql': 'database'
        };
        
        return iconMap[ext] || 'file'; // default to generic file icon
    }
    
    /**
     * Copy a file or directory
     * @param {string} sourcePath - The source path
     * @param {string} destinationPath - The destination directory path
     */
    function copyFile(sourcePath, destinationPath) {
        const fileName = sourcePath.split('/').pop();
        const targetPath = destinationPath + '/' + fileName;
        
        $.ajax({
            url: 'file-manager.php',
            type: 'POST',
            data: {
                action: 'copy',
                source: sourcePath,
                destination: targetPath
            },
            dataType: 'json',
            success: function(response) {
                if (response.error) {
                    showNotification(response.error, 'error');
                    return;
                }
                
                showNotification(`${fileName} copiato con successo`, 'success');
                closeDialog();
                
                // Reload file list if copying to current directory
                if (destinationPath === currentPath) {
                    loadFileList(currentPath);
                }
            },
            error: function(xhr, status, error) {
                showNotification('Errore durante la copia: ' + error, 'error');
            }
        });
    }
    
    /**
     * Move a file or directory
     * @param {string} sourcePath - The source path
     * @param {string} destinationPath - The destination directory path
     */
    function moveFile(sourcePath, destinationPath) {
        const fileName = sourcePath.split('/').pop();
        const targetPath = destinationPath + '/' + fileName;
        
        $.ajax({
            url: 'file-manager.php',
            type: 'POST',
            data: {
                action: 'move',
                source: sourcePath,
                destination: targetPath
            },
            dataType: 'json',
            success: function(response) {
                if (response.error) {
                    showNotification(response.error, 'error');
                    return;
                }
                
                showNotification(`${fileName} spostato con successo`, 'success');
                closeDialog();
                
                // Reload file list
                loadFileList(currentPath);
                
                // Close tab if open
                if (openFiles[sourcePath]) {
                    closeTab(sourcePath);
                }
            },
            error: function(xhr, status, error) {
                showNotification('Errore durante lo spostamento: ' + error, 'error');
            }
        });
    }
    
    /**
     * Set up editor events
     */
    function setupEditorEvents() {
        // Save file button
        $('#save-file').click(function() {
            if (editor && currentFile) {
                saveFile(currentFile, editor.getValue());
            }
        });
        
        // Save with sudo button
        $('#sudo-save').click(function() {
            if (editor && currentFile) {
                saveFile(currentFile, editor.getValue(), true);
            }
        });
        
        // Discard changes button
        $('#discard-changes').click(function() {
            if (editor && currentFile) {
                if (confirm("Sei sicuro di voler annullare tutte le modifiche?")) {
                    editor.setValue(originalContent);
                    editor.clearHistory();
                    updateEditorStatus("");
                    showNotification("Modifiche annullate");
                }
            }
        });
        
        // Toggle word wrap button
        $('#toggle-word-wrap').click(function() {
            if (editor) {
                isEditorWordWrap = !isEditorWordWrap;
                editor.setOption('lineWrapping', isEditorWordWrap);
                $(this).toggleClass('active', isEditorWordWrap);
            }
        });
        
        // Find in code button
        $('#find-in-code').click(function() {
            if (editor) {
                CodeMirror.commands.find(editor);
            }
        });
        
        // Format code button
        $('#format-code').click(function() {
            if (editor) {
                formatCode();
            }
        });
        
        // Download file button
        $('#download-file').click(function() {
            if (currentFile) {
                downloadFile(currentFile);
            }
        });
        
        // Change editor mode/language
        $('#editor-mode-selector').change(function() {
            if (editor) {
                const mode = $(this).val();
                editor.setOption('mode', mode);
            }
        });
        
        // Tab handling
        $(document).on('click', '.editor-tab', function() {
            const filePath = $(this).data('path');
            switchToTab(filePath);
        });
        
        $(document).on('click', '.editor-tab-close', function(e) {
            e.stopPropagation();
            const filePath = $(this).closest('.editor-tab').data('path');
            closeTab(filePath);
        });
    }
    
    /**
     * Set up search events
     */
    function setupSearchEvents() {
        // Search input
        $('#search-input').on('keyup', function(e) {
            if (e.which === 13) { // Enter key
                const query = $(this).val().trim();
                if (query.length >= 2) {
                    searchFiles(query);
                }
            }
        });
        
        // Search result click
        $(document).on('click', '.search-result', function() {
            const path = $(this).data('path');
            const type = $(this).data('type');
            
            if (type === 'directory') {
                navigateToDirectory(path);
                
                // Switch to explorer view
                $('.nav-tab[data-view="explorer"]').click();
            } else {
                openFileInEditor(path);
            }
        });
    }
    
    /**
     * Set up admin tools events
     */
    function setupAdminEvents() {
        // Fix permissions button
        $('#fix-permissions-btn').click(function() {
            showConfirmDialog(
                "Riparazione permessi",
                "Sei sicuro di voler riparare i permessi dei file? Questa operazione potrebbe impiegare del tempo per directory con molti file.",
                function() {
                    fixPermissions();
                }
            );
        });
        
        // Cleanup temporary files button
        $('#cleanup-tmp-btn').click(function() {
            showConfirmDialog(
                "Pulizia file temporanei",
                "Sei sicuro di voler eliminare i file temporanei? Questa operazione rimuoverà i file temporanei più vecchi di 7 giorni.",
                function() {
                    cleanupTempFiles();
                }
            );
        });
        
        // Open phpMyAdmin button
        $('#open-phpmyadmin-btn').click(function() {
            window.open('/phpmyadmin/', '_blank');
        });
    }
    
    /**
     * Setup context menu
     */
    function setupContextMenu() {
        // Hide context menu on document click
        $(document).on('click', function() {
            $('#context-menu').hide();
        });
        
        // Show context menu on file/folder right click
        $(document).on('contextmenu', '.file-item', function(e) {
            e.preventDefault();
            
            const filePath = $(this).data('path');
            const fileType = $(this).data('type');
            const fileName = $(this).find('.file-name').text().trim();
            
            // Build context menu based on item type
            let menuItems = '';
            
            if (fileType === 'directory') {
                menuItems = `
                    <div class="context-menu-item" data-action="open" data-path="${filePath}">
                        <i class="fas fa-folder-open"></i> Apri
                    </div>
                    <div class="context-menu-separator"></div>
                    <div class="context-menu-item" data-action="info" data-path="${filePath}">
                        <i class="fas fa-info-circle"></i> Informazioni
                    </div>
                    <div class="context-menu-item" data-action="copy" data-path="${filePath}">
                        <i class="fas fa-copy"></i> Copia
                    </div>
                    <div class="context-menu-item" data-action="move" data-path="${filePath}">
                        <i class="fas fa-cut"></i> Sposta
                    </div>
                    <div class="context-menu-item" data-action="rename" data-path="${filePath}">
                        <i class="fas fa-edit"></i> Rinomina
                    </div>
                    <div class="context-menu-item" data-action="delete" data-path="${filePath}">
                        <i class="fas fa-trash-alt"></i> Elimina
                    </div>
                `;
            } else {
                menuItems = `
                    <div class="context-menu-item" data-action="info" data-path="${filePath}">
                        <i class="fas fa-info-circle"></i> Informazioni
                    </div>
                    <div class="context-menu-item" data-action="copy" data-path="${filePath}">
                        <i class="fas fa-copy"></i> Copia
                    </div>
                    <div class="context-menu-item" data-action="move" data-path="${filePath}">
                        <i class="fas fa-cut"></i> Sposta
                    </div>
                    <div class="context-menu-item" data-action="download" data-path="${filePath}">
                        <i class="fas fa-download"></i> Scarica
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
            
            // Set menu content
            $('#context-menu').html(menuItems);
            
            // Position the menu
            $('#context-menu').css({
                top: e.pageY + 'px',
                left: e.pageX + 'px'
            }).show();
            
            // Context menu item click handler
            $('.context-menu-item').click(function() {
                const action = $(this).data('action');
                const path = $(this).data('path');
                
                // Hide the menu
                $('#context-menu').hide();
                
                // Perform the action
                switch (action) {
                    case 'open':
                        navigateToDirectory(path);
                        break;
                    case 'info':
                        showFileInfo(path);
                        break;
                    case 'copy':
                        showCopyFileDialog(path);
                        break;
                    case 'move':
                        showMoveFileDialog(path);
                        break;
                    case 'download':
                        downloadFile(path);
                        break;
                    case 'rename':
                        showRenameDialog(path);
                        break;
                    case 'delete':
                        showDeleteConfirmDialog(path);
                        break;
                }
            });
        });
    }
    
    /**
     * Setup file upload
     */
    function setupFileUpload() {
        // Upload files button
        $('#upload-files-btn').click(function() {
            showUploadDialog();
        });
        
        // Global drag and drop handling
        $(document).on('dragover', function(e) {
            e.preventDefault();
            e.stopPropagation();
        });
        
        $(document).on('drop', function(e) {
            e.preventDefault();
            e.stopPropagation();
            
            // Only handle drops in the file explorer panel
            if ($(e.target).closest('#explorer-panel').length > 0) {
                const files = e.originalEvent.dataTransfer.files;
                if (files.length > 0) {
                    showUploadDialog(files);
                }
            }
        });
    }
    
    /**
     * Load the file list for a directory
     * @param {string} path - The directory path
     */
    function loadFileList(path) {
        $('#file-list').html('<li><i class="fas fa-spinner fa-spin"></i> Caricamento file...</li>');
        
        // Update path navigator
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
                    $('#file-list').html(`
                        <li class="text-danger">
                            <i class="fas fa-exclamation-circle"></i> ${data.error}
                        </li>
                    `);
                    return;
                }
                
                if (data.length === 0) {
                    $('#file-list').html(`
                        <li class="text-muted">
                            <i class="fas fa-info-circle"></i> Directory vuota
                        </li>
                    `);
                    return;
                }
                
                // Update current path
                currentPath = path;
                
                // Sort directories first, then files
                const directories = data.filter(item => item.type === 'directory');
                const files = data.filter(item => item.type === 'file');
                
                // Sort each group alphabetically
                directories.sort((a, b) => a.name.localeCompare(b.name));
                files.sort((a, b) => a.name.localeCompare(b.name));
                
                // Combine the sorted lists
                const sortedData = [...directories, ...files];

                // Render each file/directory
                $.each(sortedData, function(i, file) {
                    const isSystem = file.is_system || false;
                    const isProtected = !file.is_writable || false;
                    
                    let fileClass = '';
                    if (isSystem) {
                        fileClass = 'system-file';
                    } else if (isProtected) {
                        fileClass = 'protected-file';
                    }
                    
                    // Get file extension from name
                    let fileExtension = '';
                    if (file.type === 'file') {
                        const parts = file.name.split('.');
                        if (parts.length > 1) {
                            fileExtension = parts.pop();
                        }
                    }
                    
                    // Determine correct icon class based on file type and extension
                    const iconClass = getCorrectIconClass(file.type, fileExtension);
                    
                    const fileActions = `
                        <div class="file-actions">
                            <button class="file-action-btn" title="Informazioni" data-action="info"><i class="fas fa-info-circle"></i></button>
                            <button class="file-action-btn" title="Copia" data-action="copy"><i class="fas fa-copy"></i></button>
                            <button class="file-action-btn" title="Sposta" data-action="move"><i class="fas fa-cut"></i></button>
                            ${file.type === 'file' ? '<button class="file-action-btn" title="Scarica" data-action="download"><i class="fas fa-download"></i></button>' : ''}
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
                                <i class="fas fa-${iconClass}"></i>
                                ${file.name}
                                ${!file.is_writable ? '<i class="fas fa-lock" title="Non modificabile"></i>' : ''}
                            </div>
                            ${fileActions}
                        </li>
                    `);
                });
            },
            error: function(xhr, status, error) {
                $('#file-list').html(`
                    <li class="text-danger">
                        <i class="fas fa-exclamation-circle"></i> Errore nel caricamento dei file: ${error}
                    </li>
                `);
                console.error("Error loading file list:", xhr.responseText);
            }
        });
    }
    
    /**
     * Update the path navigator based on current path
     * @param {string} path - The current directory path
     */
    function updatePathNavigator(path) {
        // Ottieni le parti del percorso
        const segments = path.split('/').filter(segment => segment.length > 0);
        
        // Trova l'indice di "www" nel percorso
        const wwwIndex = segments.indexOf('www');
        
        // Se "www" non è trovato, usa l'intero percorso
        const startIndex = wwwIndex !== -1 ? wwwIndex : 0;
        
        // Usa solo i segmenti da "www" in poi
        const visibleSegments = segments.slice(startIndex);
        let currentPath = '';
        
        // Ricostruisci il percorso completo (usato per la navigazione)
        for (let i = 0; i < startIndex; i++) {
            currentPath += '/' + segments[i];
        }
        
        // Crea l'HTML del navigator
        let navigatorHtml = '';
        
        // Se stiamo mostrando "www", inizia con esso
        if (wwwIndex !== -1) {
            currentPath += '/' + segments[wwwIndex];
            navigatorHtml = '<span class="path-segment" data-path="' + currentPath + '">www</span>';
        } else {
            // Altrimenti, inizia con "/"
            navigatorHtml = '<span class="path-segment" data-path="/">/</span>';
        }
        
        // Aggiungi i segmenti rimanenti
        for (let i = wwwIndex !== -1 ? 1 : 0; i < visibleSegments.length; i++) {
            const segment = visibleSegments[i];
            currentPath += '/' + segment;
            navigatorHtml += '<span class="path-separator">/</span>';
            navigatorHtml += `<span class="path-segment" data-path="${currentPath}">${segment}</span>`;
        }
        
        // Aggiorna l'HTML del navigator
        $('#path-navigator').html(navigatorHtml);
    }
    
    /**
     * Navigate to a directory
     * @param {string} path - The directory path to navigate to
     */
    function navigateToDirectory(path) {
        loadFileList(path);
    }
    
    /**
     * Open a file in the editor
     * @param {string} filePath - The file path to open
     */
    function openFileInEditor(filePath) {
        // Check if file is already open
        if (openFiles[filePath]) {
            switchToTab(filePath);
            return;
        }
        
        // Show loading state
        $('#editor-status-message').html('<i class="fas fa-spinner fa-spin"></i> Caricamento...');
        
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
                
                // Hide welcome screen
                $('#welcome-screen').hide();
                
                // Show code editor
                $('#code-editor').show();
                
                // Get filename from path
                const fileName = filePath.split('/').pop();
                
                // Set editor info
                $('#editor-filename').text(fileName);
                $('#editor-filepath').text(filePath);
                
                // Store original content
                originalContent = response.content;
                
                // Initialize editor if not already done
                if (!editor) {
                    initializeEditor();
                }
                
                // Set content and mode
                editor.setValue(response.content);
                editor.clearHistory();
                
                // Determine file mode based on extension
                const mode = getFileMode(fileName);
                editor.setOption('mode', mode);
                $('#editor-mode-selector').val(mode);
                
                // Reset editor status
                updateEditorStatus('');
                
                // Show sudo save button if file is not writable or sudo was used
                if (response.sudo_used) {
                    $('#sudo-save').show();
                    updateEditorStatus('<i class="fas fa-shield-alt"></i> Modalità amministratore', 'warning');
                } else {
                    $('#sudo-save').hide();
                }
                
                // Create a new tab for this file
                createTab(filePath, fileName);
                
                // Store file in open files
                openFiles[filePath] = {
                    name: fileName,
                    content: response.content
                };
                
                // Focus editor
                setTimeout(() => {
                    editor.focus();
                    editor.setCursor(editor.lineCount(), 0);
                }, 100);
            },
            error: function(xhr, status, error) {
                showNotification('Errore nel caricamento del file: ' + error, 'error');
            }
        });
    }
    
    /**
     * Initialize the code editor
     */
    function initializeEditor() {
        editor = CodeMirror($('.editor-body')[0], {
            lineNumbers: true,
            mode: 'text/plain',
            theme: 'dracula',
            tabSize: 4,
            indentUnit: 4,
            indentWithTabs: false,
            smartIndent: true,
            lineWrapping: isEditorWordWrap,
            matchBrackets: true,
            autoCloseBrackets: true,
            autoCloseTags: true,
            foldGutter: true,
            gutters: ["CodeMirror-linenumbers", "CodeMirror-foldgutter"],
            styleActiveLine: true,
            scrollbarStyle: "overlay",
            extraKeys: {
                "Ctrl-Space": "autocomplete",
                "Tab": function(cm) {
                    if (cm.somethingSelected()) {
                        cm.indentSelection("add");
                    } else {
                        cm.replaceSelection("    ", "end", "+input");
                    }
                },
                "Shift-Tab": function(cm) {
                    cm.indentSelection("subtract");
                }
            }
        });
        
        // Handle content changes
        editor.on('change', function() {
            if (currentFile) {
                const content = editor.getValue();
                
                // Check if content has changed from original
                if (content !== originalContent) {
                    updateEditorStatus('<i class="fas fa-circle"></i> Modificato', 'modified');
                } else {
                    updateEditorStatus('');
                }
            }
        });
    }
    
    /**
     * Generate a safe ID from a file path
     * @param {string} filePath - The file path
     * @returns {string} A safe ID for DOM elements
     */
    function safeIdFromPath(filePath) {
        // Replace problematic characters with a simple hash
        return 'tab-' + filePath.split('').reduce(function(a, b) {
            a = ((a << 5) - a) + b.charCodeAt(0);
            return a & a;
        }, 0).toString(16).replace('-', '0');
    }
    
    /**
     * Create a new tab for a file
     * @param {string} filePath - The file path
     * @param {string} fileName - The file name
     */
    function createTab(filePath, fileName) {
        // Generate a safe ID for the tab
        const tabId = safeIdFromPath(filePath);
        
        // Check if tab already exists
        if ($(`#${tabId}`).length) {
            switchToTab(filePath);
            return;
        }
        
        // Remove placeholder if needed
        $('.tab-placeholder').hide();
        
        // Get file extension
        let fileExtension = '';
        const parts = fileName.split('.');
        if (parts.length > 1) {
            fileExtension = parts.pop();
        }
        
        // Get file icon
        const iconClass = getCorrectIconClass('file', fileExtension);
        
        // Create the tab
        const tabHtml = `
            <div class="editor-tab" id="${tabId}" data-path="${filePath}">
                <i class="fas fa-${iconClass}"></i>
                <span class="editor-tab-name">${fileName}</span>
                <span class="editor-tab-close">
                    <i class="fas fa-times"></i>
                </span>
            </div>
        `;
        
        // Add tab to the tab bar
        $('#editor-tabs').append(tabHtml);
        
        // Set as current file
        currentFile = filePath;
        
        // Activate the tab
        switchToTab(filePath);
    }
    
    /**
     * Switch to a specific tab
     * @param {string} filePath - The file path
     */
    function switchToTab(filePath) {
        // Get the safe ID for this file
        const tabId = safeIdFromPath(filePath);
        
        // Deactivate all tabs
        $('.editor-tab').removeClass('active');
        
        // Activate the selected tab
        $(`#${tabId}`).addClass('active');
        
        // Set current file
        currentFile = filePath;
        
        // If the file content is already stored, use it
        if (openFiles[filePath]) {
            const fileName = openFiles[filePath].name;
            
            // Update editor info
            $('#editor-filename').text(fileName);
            $('#editor-filepath').text(filePath);
            
            // Set editor mode based on file extension
            const mode = getFileMode(fileName);
            editor.setOption('mode', mode);
            $('#editor-mode-selector').val(mode);
        }
    }
    
    /**
     * Close a tab
     * @param {string} filePath - The file path
     */
    function closeTab(filePath) {
        // Get the safe ID for this file
        const tabId = safeIdFromPath(filePath);
        
        // Check if the file has unsaved changes
        if (currentFile === filePath && editor && editor.getValue() !== originalContent) {
            if (!confirm("Ci sono modifiche non salvate. Sei sicuro di voler chiudere?")) {
                return;
            }
        }
        
        // Remove the tab
        $(`#${tabId}`).remove();
        
        // Remove from open files
        delete openFiles[filePath];
        
        // If this was the current file, switch to another tab or show welcome screen
        if (currentFile === filePath) {
            const remainingTabs = $('.editor-tab');
            
            if (remainingTabs.length > 0) {
                // Switch to the first remaining tab
                const nextFilePath = $(remainingTabs[0]).data('path');
                switchToTab(nextFilePath);
            } else {
                // Show welcome screen
                currentFile = null;
                $('#code-editor').hide();
                $('#welcome-screen').show();
                $('.tab-placeholder').show();
            }
        }
    }
    
    /**
     * Format code in the editor
     */
    function formatCode() {
        if (!editor) return;
        
        const mode = editor.getOption('mode');
        let formatted = false;
        
        try {
            // Get current content
            const content = editor.getValue();
            
            switch (mode) {
                case 'application/json': 
                    // Format JSON
                    const jsonObj = JSON.parse(content);
                    const formattedJson = JSON.stringify(jsonObj, null, 4);
                    editor.setValue(formattedJson);
                    formatted = true;
                    break;
                    
                case 'text/html':
                case 'application/xml':
                case 'text/xml':
                    // Use built-in indentation for HTML/XML
                    editor.execCommand('indentAuto');
                    formatted = true;
                    break;
                    
                default:
                    // Use auto indent for other file types
                    editor.execCommand('indentAuto');
                    formatted = true;
                    break;
            }
            
            if (formatted) {
                showNotification('Codice formattato');
            }
        } catch (e) {
            showNotification('Errore nella formattazione: ' + e.message, 'error');
        }
    }
    
    /**
     * Get the appropriate icon for a file type
     * @param {string} ext - The file extension
     * @returns {string} The FontAwesome icon name
     */
    function getFileIcon(ext) {
        // Converti in minuscolo per consistenza
        ext = ext.toLowerCase();
        
        const iconMap = {
            // Web technologies
            'html': 'html5',
            'htm': 'html5',
            'css': 'css3-alt',
            'js': 'js-square',
            'ts': 'file-code',
            'json': 'file-code',
            
            // Programming languages
            'php': 'php',
            'py': 'python',
            'rb': 'gem',
            'java': 'java',
            'c': 'file-code',
            'cpp': 'file-code',
            'cs': 'file-code',
            'go': 'file-code',
            
            // Markup & config
            'md': 'markdown',
            'xml': 'file-code',
            'yaml': 'file-code',
            'yml': 'file-code',
            'ini': 'file-alt',
            'config': 'cogs',
            'conf': 'cogs',
            
            // Shell scripts
            'sh': 'terminal',
            'bash': 'terminal',
            
            // Media
            'jpg': 'file-image',
            'jpeg': 'file-image',
            'png': 'file-image',
            'gif': 'file-image',
            'svg': 'file-image',
            'mp3': 'file-audio',
            'mp4': 'file-video',
            
            // Documents
            'pdf': 'file-pdf',
            'doc': 'file-word',
            'docx': 'file-word',
            'xls': 'file-excel',
            'xlsx': 'file-excel',
            'ppt': 'file-powerpoint',
            'pptx': 'file-powerpoint',
            'txt': 'file-alt',
            
            // Archives
            'zip': 'file-archive',
            'rar': 'file-archive',
            'tar': 'file-archive',
            'gz': 'file-archive',
            
            // Database
            'sql': 'database',
            'db': 'database'
        };
        
        return iconMap[ext] || 'file';
    }
    
    /**
     * Get the CodeMirror mode for a file
     * @param {string} fileName - The file name
     * @returns {string} The CodeMirror mode
     */
    function getFileMode(fileName) {
        const ext = fileName.split('.').pop().toLowerCase();
        
        const modeMap = {
            // Web technologies
            'js': 'application/javascript',
            'json': 'application/json',
            'html': 'text/html',
            'htm': 'text/html',
            'xml': 'text/xml',
            'css': 'text/css',
            'less': 'text/css',
            'scss': 'text/css',
            'sass': 'text/css',
            
            // Programming languages
            'php': 'application/x-php',
            'py': 'text/x-python',
            'rb': 'text/x-ruby',
            'java': 'text/x-java',
            'c': 'text/x-csrc',
            'cpp': 'text/x-c++src',
            'h': 'text/x-c++hdr',
            'cs': 'text/x-csharp',
            
            // Other formats
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
     * Create a new file
     * @param {string} directory - The directory path
     * @param {string} fileName - The file name
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
                
                // Hide form and clear input
                $('.new-file-form').hide();
                $('#new-file-name').val('');
                
                // Show success notification
                showNotification(`File '${fileName}' creato con successo`);
                
                // Reload file list
                loadFileList(directory);
                
                // Open the new file in editor
                setTimeout(function() {
                    openFileInEditor(directory + '/' + fileName);
                }, 300);
            },
            error: function(xhr, status, error) {
                showNotification('Errore nella creazione del file: ' + error, 'error');
            }
        });
    }
    
    /**
     * Create a new folder
     * @param {string} directory - The directory path
     * @param {string} folderName - The folder name
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
                
                // Hide form and clear input
                $('.new-folder-form').hide();
                $('#new-folder-name').val('');
                
                // Show success notification
                showNotification(`Cartella '${folderName}' creata con successo`);
                
                // Reload file list
                loadFileList(directory);
            },
            error: function(xhr, status, error) {
                showNotification('Errore nella creazione della cartella: ' + error, 'error');
            }
        });
    }
    
    /**
     * Save a file
     * @param {string} filePath - The file path
     * @param {string} content - The file content
     * @param {boolean} useSudo - Whether to use sudo privileges
     */
    function saveFile(filePath, content, useSudo = false) {
        // Update status
        updateEditorStatus('<i class="fas fa-spinner fa-spin"></i> Salvataggio...', 'info');
        
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
                    updateEditorStatus('<i class="fas fa-exclamation-triangle"></i> Errore', 'error');
                    showNotification(response.error, 'error');
                    return;
                }
                
                // Update original content
                originalContent = content;
                
                // Update status
                if (response.sudo_used) {
                    updateEditorStatus('<i class="fas fa-shield-alt"></i> Modalità amministratore', 'warning');
                    $('#sudo-save').show();
                } else {
                    updateEditorStatus('<i class="fas fa-check"></i> Salvato', 'success');
                    setTimeout(() => {
                        updateEditorStatus('');
                    }, 2000);
                }
                
                // Show notification
                showNotification('File salvato con successo');
                
                // Update stored file content
                if (openFiles[filePath]) {
                    openFiles[filePath].content = content;
                }
            },
            error: function(xhr, status, error) {
                updateEditorStatus('<i class="fas fa-exclamation-triangle"></i> Errore', 'error');
                showNotification('Errore nel salvataggio del file: ' + error, 'error');
            }
        });
    }
    
    /**
     * Delete a file or directory
     * @param {string} path - The path to delete
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
                
                // Show success notification
                showNotification('Elemento eliminato con successo');
                
                // Reload file list
                loadFileList(currentPath);
                
                // Close tab if open
                if (openFiles[path]) {
                    closeTab(path);
                }
            },
            error: function(xhr, status, error) {
                showNotification('Errore nell\'eliminazione: ' + error, 'error');
            }
        });
    }
    
    /**
     * Rename a file or directory
     * @param {string} oldPath - The original path
     * @param {string} newName - The new name
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
                
                // Show success notification
                showNotification(`Rinominato in '${newName}' con successo`);
                
                // Reload file list
                loadFileList(currentPath);
                
                // Handle open tabs
                if (openFiles[oldPath]) {
                    // Get new path
                    const newPath = response.new_path;
                    
                    // Close the old tab
                    closeTab(oldPath);
                    
                    // Open the renamed file
                    setTimeout(() => {
                        openFileInEditor(newPath);
                    }, 300);
                }
            },
            error: function(xhr, status, error) {
                showNotification('Errore nella rinomina: ' + error, 'error');
            }
        });
    }
    
    /**
     * Search for files
     * @param {string} query - The search query
     */
    function searchFiles(query) {
        $('#search-results').html('<div class="p-3"><i class="fas fa-spinner fa-spin"></i> Ricerca in corso...</div>');
        
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
                    $('#search-results').html(`
                        <div class="p-3 text-danger">
                            <i class="fas fa-exclamation-circle"></i> ${data.error}
                        </div>
                    `);
                    return;
                }
                
                if (data.length === 0) {
                    $('#search-results').html(`
                        <div class="p-3 text-muted">
                            <i class="fas fa-info-circle"></i> Nessun risultato trovato per "${query}"
                        </div>
                    `);
                    return;
                }
                
                // Display results count
                $('#search-results').append(`
                    <div class="p-2 bg-light border-bottom">
                        <small>${data.length} risultati trovati per "${query}"</small>
                    </div>
                `);
                
                // Display results
                $.each(data, function(i, item) {
                    const isDir = item.type === 'directory';
                    
                    $('#search-results').append(`
                        <div class="search-result" data-path="${item.path}" data-type="${item.type}">
                            <div class="search-result-name">
                                <i class="fas fa-${item.icon}"></i> ${item.name}
                            </div>
                            <div class="search-result-path">${item.path}</div>
                        </div>
                    `);
                });
            },
            error: function(xhr, status, error) {
                $('#search-results').html(`
                    <div class="p-3 text-danger">
                        <i class="fas fa-exclamation-circle"></i> Errore nella ricerca: ${error}
                    </div>
                `);
            }
        });
    }
    
    /**
     * Fix file permissions
     */
    function fixPermissions() {
        showNotification('Riparazione permessi in corso...', 'warning');
        
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
                    showNotification('Permessi dei file riparati con successo');
                    
                    // Reload file list
                    loadFileList(currentPath);
                } else {
                    showNotification('Errore nella riparazione dei permessi', 'error');
                }
            },
            error: function(xhr, status, error) {
                showNotification('Errore nell\'operazione: ' + error, 'error');
            }
        });
    }
    
    /**
     * Clean up temporary files
     */
    function cleanupTempFiles() {
        showNotification('Pulizia file temporanei in corso...', 'warning');
        
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
                    showNotification('File temporanei eliminati con successo');
                } else {
                    showNotification('Errore nella pulizia dei file temporanei', 'error');
                }
            },
            error: function(xhr, status, error) {
                showNotification('Errore nell\'operazione: ' + error, 'error');
            }
        });
    }
    
    /**
     * Load MySQL credentials
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
                
                $('#mysql-user').text(response.user || 'Non disponibile');
                $('#mysql-password').text(response.password || 'Non disponibile');
            },
            error: function(xhr, status, error) {
                $('#mysql-user').text('Errore');
                $('#mysql-password').text('Errore');
            }
        });
    }
    
    /**
     * Download a file
     * @param {string} filePath - The path of the file to download
     */
    function downloadFile(filePath) {
        const fileName = filePath.split('/').pop();
        
        // Create a hidden anchor element
        const a = document.createElement('a');
        a.style.display = 'none';
        a.href = `file-manager.php?action=read&file=${encodeURIComponent(filePath)}&download=true`;
        a.download = fileName;
        
        // Add to document, trigger click, then remove
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        
        showNotification(`Download di "${fileName}" avviato`);
    }
    
    /**
     * Show a notification
     * @param {string} message - The notification message
     * @param {string} type - The notification type (success, error, warning)
     */
    function showNotification(message, type = 'success') {
        $('#notification-message').text(message);
        
        const notification = $('#notification');
        
        // Set type class
        notification.removeClass('success error warning');
        notification.addClass(type);
        
        // Show the notification
        notification.fadeIn(300);
        
        // Hide after 3 seconds
        clearTimeout(window.notificationTimeout);
        window.notificationTimeout = setTimeout(function() {
            notification.fadeOut(300);
        }, 3000);
    }
    
    /**
     * Show a generic dialog with content
     * @param {string} content - HTML content for the dialog
     */
    function showDialog(content) {
        $('#dialog-content').html(content);
        $('#dialog-overlay').css('display', 'flex');
    }
    
    /**
     * Show a dialog to rename a file or directory
     * @param {string} path - The path to rename
     */
    function showRenameDialog(path) {
        const name = path.split('/').pop();
        const isDir = path.indexOf('.') === -1;
        const itemType = isDir ? 'directory' : 'file';
        
        const dialogContent = `
            <h4 class="dialog-title">Rinomina ${itemType}</h4>
            <div class="mb-3">
                <label for="rename-input" class="form-label">Nuovo nome:</label>
                <input type="text" class="form-control" id="rename-input" value="${name}">
            </div>
            <div class="dialog-buttons">
                <button class="btn btn-secondary" id="rename-cancel">Annulla</button>
                <button class="btn btn-primary" id="rename-confirm">Rinomina</button>
            </div>
        `;
        
        showDialog(dialogContent);
        
        // Focus and select the input
        setTimeout(() => {
            const input = $('#rename-input');
            input.focus();
            input.select();
        }, 100);
        
        // Cancel button
        $('#rename-cancel').click(function() {
            closeDialog();
        });
        
        // Confirm button
        $('#rename-confirm').click(function() {
            const newName = $('#rename-input').val().trim();
            
            if (newName && newName !== name) {
                renameFile(path, newName);
                closeDialog();
            } else if (newName === name) {
                closeDialog();
            } else {
                alert('Il nome non può essere vuoto.');
            }
        });
        
        // Enter key in input
        $('#rename-input').keypress(function(e) {
            if (e.which === 13) { // Enter key
                $('#rename-confirm').click();
            }
        });
    }
    
    /**
     * Show a confirmation dialog for deleting a file or directory
     * @param {string} path - The path to delete
     */
    function showDeleteConfirmDialog(path) {
        const name = path.split('/').pop();
        const isDir = path.indexOf('.') === -1;
        const itemType = isDir ? 'directory' : 'file';
        
        const dialogContent = `
            <h4 class="dialog-title">Conferma eliminazione</h4>
            <p>Sei sicuro di voler eliminare ${itemType === 'directory' ? 'la' : 'il'} ${itemType} "<strong>${name}</strong>"?</p>
            ${isDir ? '<p class="text-danger"><i class="fas fa-exclamation-circle"></i> Verranno eliminati tutti i file e le cartelle contenuti.</p>' : ''}
            <div class="dialog-buttons">
                <button class="btn btn-secondary" id="delete-cancel">Annulla</button>
                <button class="btn btn-danger" id="delete-confirm">Elimina</button>
            </div>
        `;
        
        showDialog(dialogContent);
        
        // Cancel button
        $('#delete-cancel').click(function() {
            closeDialog();
        });
        
        // Confirm button
        $('#delete-confirm').click(function() {
            deleteFile(path);
            closeDialog();
        });
    }
    
    /**
     * Show an upload dialog
     * @param {FileList} [files] - Optional files to upload immediately
     */
    function showUploadDialog(files) {
        const dialogContent = `
            <h4 class="dialog-title">Carica File</h4>
            <div class="upload-dropzone" id="upload-dropzone">
                <i class="fas fa-cloud-upload-alt"></i>
                <p>Trascina qui i file o clicca per selezionarli</p>
                <input type="file" id="file-input" style="display: none;" multiple>
            </div>
            <div class="upload-progress">
                <div class="progress mb-2">
                    <div class="upload-progress-bar" id="upload-progress-bar" style="width: 0%"></div>
                </div>
                <div id="upload-status"></div>
            </div>
            <div class="dialog-buttons">
                <button class="btn btn-secondary" id="upload-cancel">Chiudi</button>
            </div>
        `;
        
        showDialog(dialogContent);
        
        // Set up dropzone events
        const dropzone = document.getElementById('upload-dropzone');
        
        // Click on dropzone
        $('#upload-dropzone').click(function() {
            $('#file-input').click();
        });
        
        // File selection
        $('#file-input').change(function() {
            if (this.files.length > 0) {
                uploadFiles(this.files);
            }
        });
        
        // Drag over
        dropzone.addEventListener('dragover', function(e) {
            e.preventDefault();
            e.stopPropagation();
            $(this).addClass('active');
        });
        
        // Drag leave
        dropzone.addEventListener('dragleave', function(e) {
            e.preventDefault();
            e.stopPropagation();
            $(this).removeClass('active');
        });
        
        // Drop
        dropzone.addEventListener('drop', function(e) {
            e.preventDefault();
            e.stopPropagation();
            $(this).removeClass('active');
            
            if (e.dataTransfer.files.length > 0) {
                uploadFiles(e.dataTransfer.files);
            }
        });
        
        // Cancel/close button
        $('#upload-cancel').click(function() {
            closeDialog();
        });
        
        // If files were provided, upload them immediately
        if (files && files.length > 0) {
            uploadFiles(files);
        }
    }
    
    /**
     * Upload files
     * @param {FileList} files - The files to upload
     */
    function uploadFiles(files) {
        // Show progress bar
        $('.upload-progress').show();
        $('#upload-status').text(`Caricamento ${files.length} file...`);
        
        // Create FormData
        const formData = new FormData();
        formData.append('action', 'upload');
        formData.append('dir', currentPath);
        
        // Add each file to upload
        for (let i = 0; i < files.length; i++) {
            formData.append('file', files[i]);
        }
        
        // Upload files
        $.ajax({
            url: 'file-manager.php',
            type: 'POST',
            data: formData,
            processData: false,
            contentType: false,
            xhr: function() {
                const xhr = new window.XMLHttpRequest();
                
                // Track upload progress
                xhr.upload.addEventListener('progress', function(e) {
                    if (e.lengthComputable) {
                        const percent = Math.round((e.loaded / e.total) * 100);
                        $('#upload-progress-bar').css('width', percent + '%');
                        $('#upload-status').text(`Caricamento: ${percent}%`);
                    }
                }, false);
                
                return xhr;
            },
            success: function(response) {
                if (response.error) {
                    $('#upload-status').html(`<span class="text-danger"><i class="fas fa-exclamation-circle"></i> ${response.error}</span>`);
                    showNotification(response.error, 'error');
                } else {
                    $('#upload-status').html(`<span class="text-success"><i class="fas fa-check-circle"></i> File caricato con successo</span>`);
                    showNotification('File caricato con successo');
                    
                    // Reload file list
                    loadFileList(currentPath);
                    
                    // Close dialog after a delay
                    setTimeout(function() {
                        closeDialog();
                    }, 1500);
                }
            },
            error: function(xhr, status, error) {
                $('#upload-status').html(`<span class="text-danger"><i class="fas fa-exclamation-circle"></i> Errore: ${error}</span>`);
                showNotification('Errore nel caricamento del file: ' + error, 'error');
            }
        });
    }
    
    /**
     * Show a generic confirmation dialog
     * @param {string} title - Dialog title
     * @param {string} message - Dialog message
     * @param {Function} onConfirm - Function to call when confirmed
     */
    function showConfirmDialog(title, message, onConfirm) {
        const dialogContent = `
            <h4 class="dialog-title">${title}</h4>
            <p>${message}</p>
            <div class="dialog-buttons">
                <button class="btn btn-secondary" id="confirm-cancel">Annulla</button>
                <button class="btn btn-primary" id="confirm-ok">Conferma</button>
            </div>
        `;
        
        showDialog(dialogContent);
        
        // Cancel button
        $('#confirm-cancel').click(function() {
            closeDialog();
        });
        
        // Confirm button
        $('#confirm-ok').click(function() {
            closeDialog();
            if (typeof onConfirm === 'function') {
                onConfirm();
            }
        });
    }
    
    /**
     * Close the current dialog
     */
    function closeDialog() {
        $('#dialog-overlay').hide();
    }
    
    /**
     * Update the editor status message
     * @param {string} message - The status message
     * @param {string} type - The status type (empty, modified, error, success)
     */
    function updateEditorStatus(message, type = '') {
        const statusEl = $('#editor-status-message');
        statusEl.html(message);
        
        // Remove all status classes
        statusEl.removeClass('modified error success');
        
        // Add the appropriate class
        if (type) {
            statusEl.addClass(type);
        }
    }
});
