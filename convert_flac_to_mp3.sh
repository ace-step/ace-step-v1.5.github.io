#!/bin/bash

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed. Please install it first."
    echo "On Ubuntu/Debian: sudo apt-get install ffmpeg"
    echo "On macOS with Homebrew: brew install ffmpeg"
    exit 1
fi

# Create mp3 directory structure if it doesn't exist
mkdir -p mp3/samples

# Find all FLAC files and store them in an array
mapfile -t flac_files < <(find flac -type f -name "*.flac" | sort)

# Count total number of flac files
total_files=${#flac_files[@]}
echo "Found $total_files FLAC files to convert"

# Initialize counter
current=0
success=0
failed=0

# Process each FLAC file
for flac_file in "${flac_files[@]}"; do
    # Update counter
    ((current++))
    
    # Make sure the path starts with flac/samples/
    if [[ ! "$flac_file" == flac/* ]]; then
        echo "[$current/$total_files] Invalid path format: $flac_file, skipping..."
        ((failed++))
        continue
    fi
    
    # Extract the relative path from flac/samples/
    rel_path="${flac_file#flac/samples/}"
    
    # Create the directory structure in mp3/samples
    mp3_dir="mp3/samples/$(dirname "$rel_path")"
    mkdir -p "$mp3_dir"
    
    # Set the output mp3 file path
    mp3_file="mp3/samples/${rel_path%.flac}.mp3"
    
    # Skip if the mp3 file already exists
    if [ -f "$mp3_file" ]; then
        echo "[$current/$total_files] $mp3_file already exists, skipping..."
        ((success++))
        continue
    fi
    
    # Display progress
    echo "[$current/$total_files] Converting $flac_file to $mp3_file"
    
    # Convert flac to mp3 with good quality (VBR 192kbps)
    if ffmpeg -i "$flac_file" -codec:a libmp3lame -qscale:a 2 "$mp3_file" -y -loglevel error; then
        ((success++))
        echo "Successfully converted to $mp3_file"
    else
        ((failed++))
        echo "Error converting $flac_file"
    fi
done

# Calculate total size of flac and mp3 files
flac_size=$(du -sh flac/samples | cut -f1)
mp3_size=$(du -sh mp3/samples | cut -f1)

echo "Conversion complete. MP3 files are in the mp3/samples directory."
echo "----------------------------------------"
echo "Summary:"
echo "Total FLAC files: $total_files"
echo "Successfully converted: $success"
echo "Failed to convert: $failed"
echo "Original FLAC files size: $flac_size"
echo "Converted MP3 files size: $mp3_size"
echo "----------------------------------------"

# Check if all files were converted
mp3_count=$(find mp3/samples -type f -name "*.mp3" | wc -l)
if [ "$mp3_count" -ne "$total_files" ]; then
    echo "Warning: Not all FLAC files were converted to MP3."
    echo "Expected: $total_files MP3 files, Found: $mp3_count MP3 files"
    echo "Missing files:"
    
    # Find missing MP3 files
    for flac_file in "${flac_files[@]}"; do
        rel_path="${flac_file#flac/samples/}"
        mp3_file="mp3/samples/${rel_path%.flac}.mp3"
        if [ ! -f "$mp3_file" ]; then
            echo "  - $rel_path"
        fi
    done
else
    echo "All FLAC files were successfully converted to MP3!"
fi

echo "You can now use these MP3 files with the AudioLoader to improve loading times."