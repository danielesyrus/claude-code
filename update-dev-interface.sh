#!/bin/bash

# Create a temporary directory for downloads
TEMP_DIR=$(mktemp -d)
echo "Created temporary directory: $TEMP_DIR"

# Download the files from GitHub
echo "Downloading files from GitHub..."

# Using curl to download raw content from GitHub
# Convert GitHub URL to raw URL format
curl -s https://raw.githubusercontent.com/danielesyrus/claude-code/main/dev-interface/app.js -o "$TEMP_DIR/app.js"
curl -s https://raw.githubusercontent.com/danielesyrus/claude-code/main/dev-interface/file-manager.php -o "$TEMP_DIR/file-manager.php"
curl -s https://raw.githubusercontent.com/danielesyrus/claude-code/main/dev-interface/index.html -o "$TEMP_DIR/index.html"
curl -s https://raw.githubusercontent.com/danielesyrus/claude-code/main/dev-interface/styles.css -o "$TEMP_DIR/styles.css"

# Check if downloads were successful
for file in app.js file-manager.php index.html styles.css; do
    if [ ! -s "$TEMP_DIR/$file" ]; then
        echo "Error downloading $file"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
done

echo "All files downloaded successfully."

# Create destination directory if it doesn't exist
if [ ! -d "/var/www/dev-interface" ]; then
    echo "Creating destination directory: /var/www/dev-interface"
    mkdir -p /var/www/dev-interface
    if [ $? -ne 0 ]; then
        echo "Failed to create destination directory. Check permissions."
        rm -rf "$TEMP_DIR"
        exit 1
    fi
fi

# Move files to destination, replacing existing ones
echo "Moving files to /var/www/dev-interface..."
mv -f "$TEMP_DIR"/* /var/www/dev-interface/

# Check if move was successful
if [ $? -ne 0 ]; then
    echo "Failed to move files to destination. Check permissions."
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Clean up
rm -rf "$TEMP_DIR"
echo "Temporary directory removed."

echo "Script completed successfully. Files have been updated in /var/www/dev-interface/"
