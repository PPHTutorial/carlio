import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

class AudioService {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  String? _currentUrl;
  String? _currentAsset;
  StreamSubscription<PlayerState>? _stateSubscription;
  bool _initialized = false;

  AudioService() {
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    if (_initialized) return;
    try {
      // Set player mode to lowLatency for better asset playback
      await _player.setPlayerMode(PlayerMode.lowLatency);
      _initialized = true;
      print('AudioService: Player initialized with lowLatency mode');
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
      String cleanPath = assetPath;
      if (assetPath.startsWith('assets/')) {
        cleanPath = assetPath.substring(7); // Remove 'assets/' (7 chars)
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
        }
      });

      // Set volume to ensure audio plays
      await _player.setVolume(1.0);
      
      // Play the asset
      await _player.play(AssetSource(cleanPath));
      _isPlaying = true;
      _currentAsset = assetPath;
      
      print('AudioService: Successfully started playing: $cleanPath');
      
      // Verify playback started
      final state = _player.state;
      print('AudioService: Player state after play: $state');
    } catch (e, stackTrace) {
      print('Error playing audio from asset: $e');
      print('Stack trace: $stackTrace');
      _isPlaying = false;
      _currentAsset = null;
      await _stateSubscription?.cancel();
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

      _player.onPlayerStateChanged.listen((state) {
        if (state == PlayerState.completed) {
          _isPlaying = false;
          _currentUrl = null;
        }
      });
    } catch (e) {
      print('Error playing audio: $e');
      _isPlaying = false;
      _currentUrl = null;
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
      _isPlaying = false;
      _currentUrl = null;
      _currentAsset = null;
      await _stateSubscription?.cancel();
      _stateSubscription = null;
    } catch (e) {
      print('Error stopping audio: $e');
    }
  }

  bool get isPlaying => _isPlaying;
  String? get currentUrl => _currentUrl;
  
  AudioPlayer get player => _player;

  void dispose() {
    _stateSubscription?.cancel();
    _player.dispose();
  }
}

