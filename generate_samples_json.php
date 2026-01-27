<?php
// Set the content type to JSON
header('Content-Type: application/json');

// Base directory for samples
$baseDir = 'flac/samples';

// Directories to scan
$directories = [
    'GeneralSongs',
    'Experimental',
    'Instrumentals',
    'MultipleLang',
    'Controlability-retake',
    'Controlability-repaint',
    'Controlability-edit',
    'Application-Lyric2Vocal',
    'Text2Sample',
    "RapMachine"
];

// Initialize the result array
$result = [];

// Scan each directory
foreach ($directories as $dir) {
    $dirPath = $baseDir . '/' . $dir;
    $result[$dir] = [];
    
    // Check if directory exists
    if (is_dir($dirPath)) {
        // Get all .flac files in the directory
        $files = glob($dirPath . '/*.flac');
        
        // Process each file
        foreach ($files as $file) {
            // Get the filename without extension
            $fileName = basename($file, '.flac');
            
            // Create ID from file name (replace underscores with hyphens)
            $id = str_replace('_', '-', $fileName);
            
            // Add to the result array
            $result[$dir][] = [
                'id' => $id,
                'fileName' => $fileName,
                'directory' => $dir
            ];
        }
    }
}

// Output the JSON
echo json_encode($result, JSON_PRETTY_PRINT);
?>