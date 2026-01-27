#!/bin/bash

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed. Please install it first."
    echo "On Ubuntu/Debian: sudo apt-get install ffmpeg"
    echo "On macOS with Homebrew: brew install ffmpeg"
    exit 1
fi

# Check if ffmpeg has opus support
if ! ffmpeg -hide_banner -codecs | grep -q opus; then
    echo "Error: ffmpeg does not have opus support. Please install ffmpeg with opus support."
    exit 1
fi

# Create opus directory structure if it doesn't exist
mkdir -p opus/samples

# Find all FLAC files and store them in an array
mapfile -t flac_files < <(find flac/samples -type f -name "*.flac" | sort)

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
    if [[ ! "$flac_file" == flac/samples/* ]]; then
        echo "[$current/$total_files] Invalid path format: $flac_file, skipping..."
        ((failed++))
        continue
    fi
    
    # Extract the relative path from flac/samples/
    rel_path="${flac_file#flac/samples/}"
    
    # Create the directory structure in opus/samples
    opus_dir="opus/samples/$(dirname "$rel_path")"
    mkdir -p "$opus_dir"
    
    # Set the output opus file path
    opus_file="opus/samples/${rel_path%.flac}.opus"
    
    # Skip if the opus file already exists
    if [ -f "$opus_file" ]; then
        echo "[$current/$total_files] $opus_file already exists, skipping..."
        ((success++))
        continue
    fi
    
    # Display progress
    echo "[$current/$total_files] Converting $flac_file to $opus_file"
    
    # Convert flac to opus with good quality (96kbps VBR)
    if ffmpeg -i "$flac_file" -c:a libopus -b:a 96k -vbr on -compression_level 10 "$opus_file" -y -loglevel error; then
        ((success++))
        echo "Successfully converted to $opus_file"
    else
        ((failed++))
        echo "Error converting $flac_file"
    fi
done

# Calculate total size of flac and opus files
flac_size=$(du -sh flac/samples | cut -f1)
opus_size=$(du -sh opus/samples | cut -f1)

echo "Conversion complete. Opus files are in the opus/samples directory."
echo "----------------------------------------"
echo "Summary:"
echo "Total FLAC files: $total_files"
echo "Successfully converted: $success"
echo "Failed to convert: $failed"
echo "Original FLAC files size: $flac_size"
echo "Converted Opus files size: $opus_size"
echo "----------------------------------------"

# Check if all files were converted
opus_count=$(find opus/samples -type f -name "*.opus" | wc -l)
if [ "$opus_count" -ne "$total_files" ]; then
    echo "Warning: Not all FLAC files were converted to Opus."
    echo "Expected: $total_files Opus files, Found: $opus_count Opus files"
    echo "Missing files:"
    
    # Find missing Opus files
    for flac_file in "${flac_files[@]}"; do
        rel_path="${flac_file#flac/samples/}"
        opus_file="opus/samples/${rel_path%.flac}.opus"
        if [ ! -f "$opus_file" ]; then
            echo "  - $rel_path"
        fi
    done
else
    echo "All FLAC files were successfully converted to Opus!"
fi

echo "You can now use these Opus files with the AudioLoader to improve loading times."