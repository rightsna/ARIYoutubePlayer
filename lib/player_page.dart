import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ari_plugin/ari_plugin.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'playback_controls.dart';
import 'player_view.dart';
import 'playlist_panel.dart';
import 'playlist_provider.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  static const MethodChannel _windowChannel = MethodChannel(
    'youtubeplayer/window',
  );

  late final YoutubePlayerController _controller;
  final GlobalKey _playerSurfaceKey = GlobalKey();
  late final PlaylistProvider _playlist;
  late String _loadedVideoId;
  bool _isPlaying = true;
  bool _isMiniMode = false;
  bool _isPlaylistVisible = true;

  @override
  void initState() {
    super.initState();

    _playlist = context.read<PlaylistProvider>();
    _loadedVideoId = _playlist.currentVideoId;
    _isPlaying = _playlist.isPlaying;
    _isMiniMode = _playlist.isMiniMode;

    _controller = YoutubePlayerController(
      initialVideoId: _playlist.currentVideoId,
      flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
    )..addListener(_syncPlaybackStateToProvider);

    _playlist.addListener(_syncFromProvider);
  }

  @override
  void dispose() {
    _playlist.removeListener(_syncFromProvider);
    _controller.removeListener(_syncPlaybackStateToProvider);
    _controller.dispose();
    super.dispose();
  }

  void _syncFromProvider() {
    if (!mounted) return;

    // 1. Sync Video ID
    final selectedVideoId = _playlist.currentVideoId;
    if (_loadedVideoId != selectedVideoId) {
      _loadedVideoId = selectedVideoId;
      _controller.load(selectedVideoId);
      setState(() {
        _isPlaying = true;
      });
    }

    // 2. Sync Play/Pause
    if (_playlist.isPlaying) {
      if (!_controller.value.isPlaying) {
        _controller.play();
      }
    } else {
      if (_controller.value.isPlaying) {
        _controller.pause();
      }
    }

    // 3. Sync Mini Mode
    if (_isMiniMode != _playlist.isMiniMode) {
      _applyMiniMode(_playlist.isMiniMode);
    }
  }

  void _syncPlaybackStateToProvider() {
    final isPlayingNow = _controller.value.isPlaying;
    if (_isPlaying != isPlayingNow && mounted) {
      setState(() {
        _isPlaying = isPlayingNow;
      });
      // Update provider only if different to avoid loops
      if (_playlist.isPlaying != isPlayingNow) {
        _playlist.setPlaying(isPlayingNow);
      }
    }
  }

  void _playPrevious() {
    _playlist.playPrevious();
  }

  void _playNext() {
    _playlist.playNext();
  }

  void _togglePlayPause() {
    _playlist.setPlaying(!_playlist.isPlaying);
  }

  Future<void> _toggleMiniMode() async {
    _playlist.setIsMiniMode(!_playlist.isMiniMode);
  }

  Future<void> _applyMiniMode(bool enable) async {
    if (Platform.isMacOS) {
      try {
        await _windowChannel.invokeMethod('setMiniMode', {'enabled': enable});
      } on PlatformException {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isMiniMode = enable;
    });
  }

  void _togglePlaylist() {
    setState(() {
      _isPlaylistVisible = !_isPlaylistVisible;
    });
  }

  Future<void> _openInYouTube() async {
    final url = Uri.parse(
      'https://www.youtube.com/watch?v=${_playlist.currentVideoId}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Widget _buildPlayerSurface() {
    return KeyedSubtree(
      key: _playerSurfaceKey,
      child: PlayerView(controller: _controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTitle = context.select<PlaylistProvider, String>(
      (playlist) => playlist.currentItem.title,
    );

    return Column(
      children: [
        const AriUpdateBanner(
          appId: 'youtube_player',
          appName: 'ARI YouTube Player',
        ),
        Expanded(
          child: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(_isMiniMode ? 10 : 16),
                child: _isMiniMode
                    ? _MiniPlayerBar(
                        title: currentTitle,
                        playerSurface: _buildPlayerSurface(),
                        isPlaying: _isPlaying,
                        onTogglePlayPause: _togglePlayPause,
                        onRestore: _toggleMiniMode,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'ARI YouTube Player',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              StreamBuilder<bool>(
                                stream: AriAgent.connectionStream,
                                initialData: AriAgent.isConnected,
                                builder: (context, snapshot) {
                                  final isConnected = snapshot.data ?? false;
                                  return Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isConnected
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(child: _buildPlayerSurface()),
                                      const SizedBox(height: 16),
                                      PlaybackControls(
                                        isPlaying: _isPlaying,
                                        onPrevious: _playPrevious,
                                        onTogglePlayPause: _togglePlayPause,
                                        onNext: _playNext,
                                        onToggleMiniMode: _toggleMiniMode,
                                        onTogglePlaylist: _togglePlaylist,
                                        onOpenInYouTube: _openInYouTube,
                                        isPlaylistVisible: _isPlaylistVisible,
                                      ),
                                    ],
                                  ),
                                ),
                                if (_isPlaylistVisible) ...[
                                  const SizedBox(width: 16),
                                  const SizedBox(
                                      width: 320, child: PlaylistPanel()),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniPlayerBar extends StatelessWidget {
  const _MiniPlayerBar({
    required this.title,
    required this.playerSurface,
    required this.isPlaying,
    required this.onTogglePlayPause,
    required this.onRestore,
  });

  final String title;
  final Widget playerSurface;
  final bool isPlaying;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onRestore;

  void _startDragging(DragStartDetails details) {
    if (Platform.isMacOS) {
      const MethodChannel('youtubeplayer/window').invokeMethod('startDragging');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: playerSurface,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: _startDragging,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _MiniModeButton(
            icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            tooltip: isPlaying ? 'Pause' : 'Play',
            onPressed: onTogglePlayPause,
            isPrimary: true,
          ),
          const SizedBox(width: 8),
          _MiniModeButton(
            icon: Icons.open_in_full_rounded,
            tooltip: 'Restore',
            onPressed: onRestore,
          ),
        ],
      ),
    );
  }
}

class _MiniModeButton extends StatelessWidget {
  const _MiniModeButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isPrimary = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isPrimary ? const Color(0xFFd90429) : const Color(0xFF252525),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: Colors.white, size: isPrimary ? 26 : 22),
          ),
        ),
      ),
    );
  }
}
