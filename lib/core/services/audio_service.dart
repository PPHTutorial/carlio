import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

class AudioService {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  String? _currentUrl;
  String? _currentAsset;
  StreamSubscription<PlayerState>? _stateSubscription;
  bool _initialized = false;
  Timer? _durationTimer; // Timer to limit playback duration to 20 seconds
  static const Duration _maxPlaybackDuration = Duration(seconds: 10);
  
  // Stream controller to notify listeners when playback stops
  final StreamController<bool> _playbackStateController = StreamController<bool>.broadcast();
  
  /// Stream that emits true when playback starts, false when it stops
  Stream<bool> get playbackStateStream => _playbackStateController.stream;

  AudioService() {
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    if (_initialized) return;
    try {
      // Set player mode to lowLatency for better asset playback (works for both .mp3 and .aac)
      await _player.setPlayerMode(PlayerMode.lowLatency);
      // Set release mode to stop for better control
      await _player.setReleaseMode(ReleaseMode.stop);
      _initialized = true;
      print('AudioService: Player initialized with lowLatency mode for .mp3 and .aac files');
    } catch (e) {
      print('AudioService: Error initializing player: $e');
    }
  }

  /// Play engine sound from asset file
  Future<void> playEngineSoundFromAsset(String assetPath) async {
    if (assetPath.isEmpty) {
      print('AudioService: Empty asset path provided');
      return;
    }

    // Ensure player is initialized
    await _initializePlayer();

    String? cleanPath;
    try {
      if (_isPlaying && _currentAsset == assetPath) {
        await stop();
        return;
      }

      if (_isPlaying) {
        await stop();
        // Wait a bit for the player to stop
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Play from asset - AssetSource expects path without 'assets/' prefix
      // Input: "assets/engine/carlio_001.mp3" -> Output: "engine/carlio_001.mp3"
      cleanPath = assetPath;
      if (assetPath.startsWith('assets/')) {
        cleanPath = assetPath.substring(7); // Remove 'assets/' (7 chars)
      } else if (!assetPath.startsWith('assets/') && !assetPath.contains('/')) {
        // If path doesn't start with assets/ and has no slash, it might already be clean
        // But we should ensure it has the engine/ prefix if needed
        if (!cleanPath.startsWith('engine/')) {
          cleanPath = 'engine/$cleanPath';
        }
      }
      
      // Ensure path doesn't have leading slash
      if (cleanPath.startsWith('/')) {
        cleanPath = cleanPath.substring(1);
      }
      
      print('AudioService: Original path: $assetPath');
      print('AudioService: Clean path: $cleanPath');
      print('AudioService: Attempting to play asset: $cleanPath');
      
      // Cancel previous subscription if exists
      await _stateSubscription?.cancel();
      
      // Set up state listener before playing
      _stateSubscription = _player.onPlayerStateChanged.listen((state) {
        print('AudioService: Player state changed: $state');
        if (state == PlayerState.completed || state == PlayerState.stopped) {
          _isPlaying = false;
          _currentAsset = null;
          _cancelDurationTimer(); // Cancel timer when playback completes naturally
          // Notify listeners that playback stopped
          _playbackStateController.add(false);
        }
      });

      // Set volume to ensure audio plays
      await _player.setVolume(1.0);
      
      // Check file extension to determine if we need special handling
      final isAac = cleanPath.toLowerCase().endsWith('.aac');
      final isMp3 = cleanPath.toLowerCase().endsWith('.mp3');
      
      print('AudioService: File type - isAac: $isAac, isMp3: $isMp3');
      
      // Play the asset - AssetSource handles both .mp3 and .aac automatically
      // Use AssetSource with the clean path (relative to assets root)
      await _player.play(AssetSource(cleanPath));
      _isPlaying = true;
      _currentAsset = assetPath;
      
      // Notify listeners that playback started
      _playbackStateController.add(true);
      
      print('AudioService: Successfully started playing: $cleanPath');
      
      // Verify playback started
      final state = _player.state;
      print('AudioService: Player state after play: $state');
      
      // Wait a moment and check if actually playing
      await Future.delayed(const Duration(milliseconds: 300));
      if (_player.state == PlayerState.playing) {
        print('AudioService: Confirmed - audio is playing');
        
        // Start duration timer to stop playback after 20 seconds
        _cancelDurationTimer();
        _durationTimer = Timer(_maxPlaybackDuration, () {
          print('AudioService: Max duration (20s) reached, stopping playback');
          stop();
        });
      } else {
        print('AudioService: Warning - player state is ${_player.state}, expected playing');
        // Don't throw - just log the warning, playback might still work
      }
    } catch (e, stackTrace) {
      print('Error playing audio from asset: $e');
      print('Stack trace: $stackTrace');
      print('AudioService: Asset path attempted: $assetPath');
      print('AudioService: Clean path attempted: ${cleanPath ?? "N/A"}');
      _isPlaying = false;
      _currentAsset = null;
      _cancelDurationTimer(); // Cancel timer on error
      await _stateSubscription?.cancel();
      // Don't rethrow - let the caller know via the error message
    }
  }

  /// Play engine sound from URL (for backward compatibility)
  Future<void> playEngineSound(String? audioUrl) async {
    if (audioUrl == null || audioUrl.isEmpty) return;

    try {
      if (_isPlaying && _currentUrl == audioUrl) {
        await stop();
        return;
      }

      if (_isPlaying) {
        await stop();
      }

      await _player.play(UrlSource(audioUrl));
      _isPlaying = true;
      _currentUrl = audioUrl;
      
      // Notify listeners that playback started
      _playbackStateController.add(true);

      _player.onPlayerStateChanged.listen((state) {
        if (state == PlayerState.completed || state == PlayerState.stopped) {
          _isPlaying = false;
          _currentUrl = null;
          _cancelDurationTimer();
          // Notify listeners that playback stopped
          _playbackStateController.add(false);
        }
      });
      
      // Start duration timer to stop playback after 20 seconds
      _cancelDurationTimer();
      _durationTimer = Timer(_maxPlaybackDuration, () {
        print('AudioService: Max duration (20s) reached, stopping playback');
        stop();
      });
    } catch (e) {
      print('Error playing audio: $e');
      _isPlaying = false;
      _currentUrl = null;
      _cancelDurationTimer(); // Cancel timer on error
    }
  }

  Future<void> stop() async {
    try {
      _cancelDurationTimer(); // Cancel timer when stopping manually
      await _player.stop();
      _isPlaying = false;
      _currentUrl = null;
      _currentAsset = null;
      await _stateSubscription?.cancel();
      _stateSubscription = null;
      // Notify listeners that playback stopped
      _playbackStateController.add(false);
    } catch (e) {
      print('Error stopping audio: $e');
    }
  }
  
  /// Cancel the duration timer if it's active
  void _cancelDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  bool get isPlaying => _isPlaying;
  String? get currentUrl => _currentUrl;
  
  AudioPlayer get player => _player;

  void dispose() {
    _cancelDurationTimer();
    _stateSubscription?.cancel();
    _playbackStateController.close();
    _player.dispose();
  }
}

