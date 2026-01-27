#!/bin/bash

# Script to check for .flac files and create corresponding .txt files if they don't exist
# Usage: ./create_missing_txt.sh

# Base directories
FLAC_DIR="./flac"
RAW_DIR="./raw"

# Create flac directory if it doesn't exist
if [ ! -d "$FLAC_DIR" ]; then
    mkdir -p "$FLAC_DIR"
    echo "Created flac directory: $FLAC_DIR"
fi

# Function to check and create txt files if they don't exist
check_and_create_txt_files() {
    local flac_file="$1"
    local relative_path="${flac_file#$FLAC_DIR/}"
    local filename=$(basename "$relative_path" .flac)
    local directory=$(dirname "$relative_path")
    
    # Create the corresponding directory in raw if it doesn't exist
    local raw_dir="$RAW_DIR/$directory"
    
    # Check if the txt files exist, create them if they don't
    local txt_file="$raw_dir/$filename.txt"
    local prompt_txt_file="$raw_dir/${filename}_prompt.txt"
    
    # Create directory if it doesn't exist
    if [ ! -d "$raw_dir" ]; then
        mkdir -p "$raw_dir"
        echo "Created directory: $raw_dir"
    fi
    
    # Create .txt file if it doesn't exist
    if [ ! -f "$txt_file" ]; then
        touch "$txt_file"
        echo "Created: $txt_file"
    fi
    
    # Create _prompt.txt file if it doesn't exist
    if [ ! -f "$prompt_txt_file" ]; then
        touch "$prompt_txt_file"
        echo "Created: $prompt_txt_file"
    fi
}

# Find all flac files and check for corresponding txt files
echo "Checking for missing txt files..."
count=0

find "$FLAC_DIR" -type f -name "*.flac" | while read flac_file; do
    check_and_create_txt_files "$flac_file"
    ((count++))
done

if [ $count -eq 0 ]; then
    echo "No flac files found."
else
    echo "Processed $count flac files."
fi