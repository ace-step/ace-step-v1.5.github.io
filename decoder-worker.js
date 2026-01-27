/**
 * Web Worker for audio decoding
 * This worker handles audio decoding in a separate thread to avoid blocking the main thread
 */

// Check if OfflineAudioContext is available in this worker context
const hasOfflineAudioContext = typeof OfflineAudioContext !== 'undefined';
let audioContext = null;

// Initialize the audio context when needed
function initAudioContext() {
  if (!audioContext && hasOfflineAudioContext) {
    // Use OfflineAudioContext for decoding in the worker
    audioContext = new OfflineAudioContext(2, 48000, 48000);
  }
  return audioContext;
}

// Handle messages from the main thread
self.onmessage = async function(e) {
  const { id, audioData } = e.data;
  
  if (!id || !audioData) {
    console.error('Invalid message received in decoder worker');
    return;
  }
  
  try {
    // Check if we have OfflineAudioContext available
    if (hasOfflineAudioContext) {
      // Initialize the audio context
      const ctx = initAudioContext();
      
      // Decode the audio data
      const decodedData = await ctx.decodeAudioData(audioData);
      
      // Send the decoded data back to the main thread
      self.postMessage({
        id,
        decodedData
      }, [decodedData.getChannelData(0).buffer]);
    } else {
      // If OfflineAudioContext is not available, send back an error
      // so the main thread can fall back to decoding there
      self.postMessage({
        id,
        error: "OfflineAudioContext is not available in this worker context",
        needsMainThreadDecode: true,
        audioData: audioData
      }, [audioData]);
    }
  } catch (error) {
    // Send error back to main thread
    self.postMessage({
      id,
      error: error.message
    });
    console.error('Error decoding audio in worker:', error);
  }
};

// Log that the worker is initialized
console.log('Audio decoder worker initialized');