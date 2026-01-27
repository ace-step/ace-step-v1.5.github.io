# Audio Optimization for GitHub Pages

This guide explains how to optimize audio loading and decoding for your GitHub Pages website by:
1. Converting large .flac files to smaller Opus or MP3 files
2. Using GitHub Releases with jsDelivr CDN for faster delivery
3. Pre-initializing audio decoders for faster startup
4. Implementing progressive loading with Range requests
5. Using Web Workers for audio decoding to avoid blocking the main thread

## Step 1: Convert FLAC to Opus (Recommended) or MP3

### Option A: Convert to Opus (Best Quality and Size)

The `convert_flac_to_opus.sh` script will convert all your .flac files to Opus format, which significantly reduces file sizes while maintaining excellent audio quality.

```bash
# Make the script executable
chmod +x convert_flac_to_opus.sh

# Run the conversion script
./convert_flac_to_opus.sh
```

### Option B: Convert to MP3 (Better Compatibility)

If you need broader compatibility with older browsers, you can use the `convert_flac_to_mp3.sh` script instead.

```bash
# Make the script executable
chmod +x convert_flac_to_mp3.sh

# Run the conversion script
./convert_flac_to_mp3.sh
```

These scripts will:
1. Clean up any existing target directory to avoid path issues
2. Create a new directory with the same structure as your raw directory
3. Convert all .flac files to the target format with good quality settings
4. Show progress as it converts each file
5. Display a summary of the space saved after conversion

The conversion process may take some time depending on how many audio files you have and your computer's processing power.

## Step 2: Create a GitHub Release

To use jsDelivr CDN, you need to create a GitHub Release that includes your converted audio files. You can do this manually or use the provided script:

### Option A: Use the Automated Script (Recommended)

The `create_github_release.sh` script will automatically:
1. Check for converted audio files (prioritizing Opus over MP3)
2. Create a zip file of your audio files
3. Create a GitHub release with the zip file
4. Update the AudioLoader configuration in your index.html
5. Display the CDN URL pattern for your files

```bash
# Make the script executable
chmod +x create_github_release.sh

# Run the script
./create_github_release.sh
```

The script will prompt you for:
- Release tag (e.g., "v1.0.0")
- Release title
- Release notes

### Option B: Create a Release Manually

If you prefer to create the release manually:

1. Commit and push the files to your repository:
   ```bash
   git add opus/ mp3/
   git commit -m "Add optimized audio files for faster loading"
   git push
   ```

2. Create a new release on GitHub:
   - Go to your repository on GitHub
   - Click on "Releases" in the right sidebar
   - Click "Create a new release"
   - Set the tag version (e.g., "v1.0.0")
   - Add a title and description
   - Click "Publish release"

## Step 3: Update the AudioLoader Configuration

After creating the release, update the AudioLoader initialization in your HTML file:

```javascript
const audioLoader = new AudioLoader({
  username: 'ace-step',
  repo: 'ace-step.github.io',
  releaseTag: 'v1.0.0', // Update this to your release tag
  useJsDelivr: true,
  formatPreference: ['opus', 'mp3', 'flac'], // Prioritize Opus over MP3 over FLAC
  useProgressiveLoading: true,
  useWorkerDecoding: true
});
```

## How It Works

The optimization works through several mechanisms:

### 1. Format Optimization

| Format | Quality | Size Comparison | Browser Support |
|--------|---------|-----------------|----------------|
| FLAC   | Lossless | 100% (baseline) | Good           |
| MP3    | Good    | ~10-20% of FLAC | Excellent      |
| Opus   | Excellent | ~5-10% of FLAC | Good (modern browsers) |

- **Opus** provides the best compression-to-quality ratio, typically 2x better than MP3
- **MP3** offers a good balance between compatibility and file size
- The loader automatically selects the best available format based on your preference order

### 2. Pre-initialized Audio Decoder

- The AudioLoader pre-initializes the Web Audio API's decoder
- This reduces the initial decode latency when playing the first audio file
- Particularly helpful for mobile devices where decoder initialization can be slow

### 3. Progressive Loading with Range Requests

- Audio elements are configured to load progressively
- Only loads data when playback starts, not during page load
- Uses HTTP Range requests to fetch only the necessary portions of audio files
- Reduces initial page load time and bandwidth usage

### 4. Web Worker Decoding

- Audio decoding is performed in a separate thread (Web Worker)
- Prevents the main UI thread from being blocked during decoding
- Results in smoother UI experience, especially when decoding large files
- Falls back to main thread decoding if Web Workers are not supported

### 5. CDN Delivery

- jsDelivr is a free CDN that serves files from GitHub repositories. It offers:
  - Global distribution with servers worldwide
  - Automatic file compression
  - HTTP/2 support for faster loading
  - No bandwidth limits

### 6. Caching and Preloading

- The AudioLoader caches URLs and decoded audio data
- Optionally preloads audio metadata for faster subsequent playback
- Implements intelligent format fallback if preferred formats aren't available

## Performance Comparison

| Format | Average File Size | Loading Time | Decoding Time | Browser Support |
|--------|------------------|--------------|---------------|----------------|
| FLAC   | ~10-20 MB        | Slow         | Slow          | Good           |
| MP3    | ~1-2 MB          | Fast         | Medium        | Excellent      |
| Opus   | ~0.5-1 MB        | Very Fast    | Fast          | Good (modern)  |

Using jsDelivr CDN can further reduce loading times by 40-60% compared to loading directly from GitHub Pages.

Using Web Workers for decoding can improve UI responsiveness by up to 100% during audio decoding operations.

## Troubleshooting

If you encounter issues:

1. **CORS Errors**: jsDelivr should handle CORS correctly, but if you see CORS errors in the console, make sure your repository is public.

2. **Files Not Found**: Check that the paths in the AudioLoader configuration match your repository structure.

3. **Release Not Available**: Make sure your release is published and contains the audio files.

4. **Conversion Issues**: If the conversion script fails, make sure ffmpeg is installed on your system with the appropriate codec support.

5. **Worker Errors**: If you see errors related to Web Workers, check browser compatibility or try disabling the `useWorkerDecoding` option.

6. **Decoder Initialization**: If audio takes a long time to start playing the first time, ensure the pre-initialization is working correctly.