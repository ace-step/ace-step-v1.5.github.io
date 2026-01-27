/**
 * Enhanced Audio Loader with optimizations for GitHub Pages
 * - Prioritizes Opus over mp3 over flac for faster loading and decoding
 * - Uses jsDelivr CDN when available
 * - Pre-initializes audio decoder
 * - Implements progressive loading with Range requests
 * - Uses Web Workers for audio decoding
 */

// Pre-initialize the audio context for faster decoding
const audioContext = new (window.AudioContext || window.webkitAudioContext)();

// Create a decoder worker
let decoderWorker = null;
try {
  decoderWorker = new Worker('decoder-worker.js');
} catch (error) {
  console.warn('Audio decoder worker not available:', error);
}

class AudioLoader {
  constructor(options = {}) {
    // Default options
    this.options = {
      // GitHub username and repository name
      username: 'ace-step',
      repo: 'ace-step.github.io',
      // GitHub release tag (if using releases)
      releaseTag: 'latest',
      // Whether to use jsDelivr CDN
      useJsDelivr: true,
      // Format preference order (opus first, then mp3, then flac)
      formatPreference: ['opus', 'mp3', 'flac'],
      // Base path for local files
      localBasePath: '',
      // Whether to use progressive loading
      useProgressiveLoading: true,
      // Whether to use web worker for decoding
      useWorkerDecoding: true,
      ...options
    };

    // Cache for audio file availability and decoded data
    this.cache = new Map();
    this.decodedCache = new Map();
    
    // Initialize decoder worker message handling
    if (decoderWorker && this.options.useWorkerDecoding) {
      decoderWorker.onmessage = async (e) => {
        const { id, decodedData, error, needsMainThreadDecode, audioData } = e.data;
        
        // If we have decoded data, use it
        if (id && decodedData) {
          this.decodedCache.set(id, decodedData);
          // Notify any pending callbacks
          if (this.pendingDecodes.has(id)) {
            const callbacks = this.pendingDecodes.get(id);
            callbacks.forEach(callback => callback(decodedData));
            this.pendingDecodes.delete(id);
          }
        }
        // If worker couldn't decode because OfflineAudioContext isn't available, decode in main thread
        else if (id && needsMainThreadDecode && audioData) {
          try {
            console.log('Falling back to main thread decoding because OfflineAudioContext is not available in worker');
            const decodedData = await audioContext.decodeAudioData(audioData);
            this.decodedCache.set(id, decodedData);
            
            // Notify any pending callbacks
            if (this.pendingDecodes.has(id)) {
              const callbacks = this.pendingDecodes.get(id);
              callbacks.forEach(callback => callback(decodedData));
              this.pendingDecodes.delete(id);
            }
          } catch (decodeError) {
            console.error('Error decoding audio in main thread fallback:', decodeError);
            // Notify callbacks of error
            if (this.pendingDecodes.has(id)) {
              const callbacks = this.pendingDecodes.get(id);
              callbacks.forEach(callback => callback(null, decodeError));
              this.pendingDecodes.delete(id);
            }
          }
        }
        // Handle other errors
        else if (error) {
          console.error('Worker reported error:', error);
          // Notify callbacks of error
          if (this.pendingDecodes.has(id)) {
            const callbacks = this.pendingDecodes.get(id);
            callbacks.forEach(callback => callback(null, new Error(error)));
            this.pendingDecodes.delete(id);
          }
        }
      };
      
      // Track pending decode operations
      this.pendingDecodes = new Map();
    }
    
    // Pre-warm the audio context
    this._preWarmAudioContext();
  }

  /**
   * Pre-warm the audio context to reduce initial decode latency
   * @private
   */
  async _preWarmAudioContext() {
    try {
      // Create a small silent buffer
      const buffer = audioContext.createBuffer(2, 44100, 44100);
      const source = audioContext.createBufferSource();
      source.buffer = buffer;
      source.connect(audioContext.destination);
      source.start(0);
      source.stop(0.001); // Stop after a very short time
      console.log('Audio context pre-warmed');
    } catch (error) {
      console.warn('Failed to pre-warm audio context:', error);
    }
  }

  /**
   * Get the URL for an audio file
   * @param {string} directory - Directory containing the audio file
   * @param {string} fileName - Name of the audio file without extension
   * @returns {Promise<string>} - URL to the audio file
   */
  async getAudioUrl(directory, fileName) {
    const cacheKey = `${directory}/${fileName}`;
    
    // Check cache first
    if (this.cache.has(cacheKey)) {
      return this.cache.get(cacheKey);
    }

    // Try each format in order of preference
    for (const format of this.options.formatPreference) {
      // Try to load from jsDelivr CDN first if enabled
      if (this.options.useJsDelivr) {
        const cdnUrl = this.getJsDelivrUrl(directory, fileName, format);
        if (await this.checkFileExists(cdnUrl)) {
          this.cache.set(cacheKey, cdnUrl);
          console.log(`Using CDN for ${fileName}.${format}`);
          return cdnUrl;
        }
      }
      
      // Fall back to local files
      const localPath = this.getLocalPath(directory, fileName, format);
      if (await this.checkFileExists(localPath)) {
        this.cache.set(cacheKey, localPath);
        return localPath;
      }
    }
    
    // If all else fails, return the original flac path
    const fallbackPath = `flac/samples/${directory}/${fileName}.flac`;
    this.cache.set(cacheKey, fallbackPath);
    return fallbackPath;
  }

  /**
   * Get the jsDelivr CDN URL for a file
   * @param {string} directory - Directory containing the file
   * @param {string} fileName - Name of the file without extension
   * @param {string} format - File format (opus, mp3 or flac)
   * @returns {string} - jsDelivr CDN URL
   */
  getJsDelivrUrl(directory, fileName, format) {
    if (format === 'opus') {
      return `https://cdn.jsdelivr.net/gh/${this.options.username}/${this.options.repo}/opus/samples/${directory}/${fileName}.opus`;
    } else if (format === 'mp3') {
      return `https://cdn.jsdelivr.net/gh/${this.options.username}/${this.options.repo}/mp3/samples/${directory}/${fileName}.mp3`;
    } else {
      return `https://cdn.jsdelivr.net/gh/${this.options.username}/${this.options.repo}/flac/samples/${directory}/${fileName}.flac`;
    }
  }

  /**
   * Get the local path for a file
   * @param {string} directory - Directory containing the file
   * @param {string} fileName - Name of the file without extension
   * @param {string} format - File format (opus, mp3 or flac)
   * @returns {string} - Local file path
   */
  getLocalPath(directory, fileName, format) {
    if (format === 'opus') {
      return `${this.options.localBasePath}opus/samples/${directory}/${fileName}.opus`;
    } else if (format === 'mp3') {
      return `${this.options.localBasePath}mp3/samples/${directory}/${fileName}.mp3`;
    } else {
      return `${this.options.localBasePath}flac/samples/${directory}/${fileName}.flac`;
    }
  }

  /**
   * Check if a file exists by making a HEAD request
   * @param {string} url - URL to check
   * @returns {Promise<boolean>} - Whether the file exists
   */
  async checkFileExists(url) {
    try {
      const response = await fetch(url, { method: 'HEAD' });
      return response.ok;
    } catch (error) {
      console.warn(`Error checking file existence for ${url}:`, error);
      return false;
    }
  }

  /**
   * Pre-decode an audio file to reduce playback latency
   * @param {string} url - URL of the audio file to decode
   * @param {string} id - Unique identifier for the audio file
   * @returns {Promise<AudioBuffer>} - Decoded audio data
   */
  async preDecodeAudio(url, id) {
    // Check if already decoded
    if (this.decodedCache.has(id)) {
      return this.decodedCache.get(id);
    }
    
    try {
      // Fetch the audio data
      const response = await fetch(url);
      const arrayBuffer = await response.arrayBuffer();
      
      // Use worker for decoding if available
      if (decoderWorker && this.options.useWorkerDecoding) {
        return new Promise((resolve, reject) => {
          // Add to pending decodes
          if (!this.pendingDecodes.has(id)) {
            this.pendingDecodes.set(id, []);
          }
          
          // Add callback that handles both success and error cases
          this.pendingDecodes.get(id).push((data, error) => {
            if (error) {
              reject(error);
            } else {
              resolve(data);
            }
          });
          
          // Send to worker for decoding
          decoderWorker.postMessage({
            id,
            audioData: arrayBuffer
          }, [arrayBuffer]);
        });
      } else {
        // Decode in main thread if worker not available
        const decodedData = await audioContext.decodeAudioData(arrayBuffer);
        this.decodedCache.set(id, decodedData);
        return decodedData;
      }
    } catch (error) {
      console.error(`Error pre-decoding audio ${url}:`, error);
      return null;
    }
  }

  /**
   * Create an optimized audio element with progressive loading
   * @param {string} url - URL of the audio file
   * @param {string} id - Unique identifier for the audio file
   * @returns {HTMLAudioElement} - Configured audio element
   */
  createOptimizedAudio(url, id) {
    const audio = new Audio();
    
    // Configure for progressive loading
    if (this.options.useProgressiveLoading) {
      audio.preload = 'none';
      audio.dataset.src = url;
      audio.dataset.id = id;
      
      // Set up progressive loading on play
      audio.addEventListener('play', () => {
        if (!audio.dataset.loadStarted) {
          audio.src = audio.dataset.src;
          audio.load();
          audio.dataset.loadStarted = true;
        }
      });
    } else {
      // Standard loading
      audio.src = url;
      audio.preload = 'auto';
    }
    
    return audio;
  }

  /**
   * Preload audio files for a list of samples
   * @param {Array} samples - List of samples to preload
   * @param {Function} progressCallback - Callback for progress updates
   */
  async preloadAudio(samples, progressCallback = null) {
    let loaded = 0;
    const total = samples.length;
    
    for (const sample of samples) {
      const url = await this.getAudioUrl(sample.directory, sample.fileName);
      
      // Pre-decode the audio if we're using that optimization
      if (this.options.useWorkerDecoding || audioContext.state === 'running') {
        await this.preDecodeAudio(url, sample.id);
      } else {
        // Just fetch the headers to cache the URL, don't download the whole file
        await fetch(url, { method: 'HEAD' });
      }
      
      loaded++;
      if (progressCallback) {
        progressCallback(loaded, total);
      }
    }
  }
}

// Export the AudioLoader class
window.AudioLoader = AudioLoader;