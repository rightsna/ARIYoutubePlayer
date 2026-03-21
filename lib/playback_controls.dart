import 'package:flutter/material.dart';

class PlaybackControls extends StatelessWidget {
  const PlaybackControls({
    super.key,
    required this.isPlaying,
    required this.onPrevious,
    required this.onTogglePlayPause,
    required this.onNext,
    required this.onToggleMiniMode,
    required this.onTogglePlaylist,
    required this.onOpenInYouTube,
    required this.isPlaylistVisible,
  });

  final bool isPlaying;
  final VoidCallback onPrevious;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onNext;
  final VoidCallback onToggleMiniMode;
  final VoidCallback onTogglePlaylist;
  final VoidCallback onOpenInYouTube;
  final bool isPlaylistVisible;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 15,
      children: [
        _ControlButton(
          icon: Icons.picture_in_picture_alt_rounded,
          tooltip: 'Mini Mode',
          onPressed: onToggleMiniMode,
        ),
        _ControlButton(
          icon: Icons.open_in_new_rounded,
          tooltip: 'Open in YouTube',
          onPressed: onOpenInYouTube,
        ),
        Spacer(),
        _ControlButton(
          icon: isPlaylistVisible
              ? Icons.menu_open_rounded
              : Icons.menu_rounded,
          tooltip: 'Toggle Playlist',
          onPressed: onTogglePlaylist,
        ),
        _ControlButton(
          icon: Icons.skip_previous_rounded,
          tooltip: 'Previous',
          onPressed: onPrevious,
        ),
        _ControlButton(
          icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          tooltip: isPlaying ? 'Pause' : 'Play',
          onPressed: onTogglePlayPause,
          isPrimary: true,
        ),
        _ControlButton(
          icon: Icons.skip_next_rounded,
          tooltip: 'Next',
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
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
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(icon, color: Colors.white, size: isPrimary ? 28 : 24),
          ),
        ),
      ),
    );
  }
}
