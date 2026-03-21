import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class PlayerView extends StatelessWidget {
  const PlayerView({super.key, required this.controller});

  final YoutubePlayerController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        final fittedWidth = maxHeight * (16 / 9);
        final useFullWidth = fittedWidth <= maxWidth;

        return Center(
          child: SizedBox(
            width: useFullWidth ? fittedWidth : maxWidth,
            height: useFullWidth ? maxHeight : maxWidth / (16 / 9),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: YoutubePlayer(
                controller: controller,
                showVideoProgressIndicator: true,
                progressIndicatorColor: const Color(0xFFd90429),
              ),
            ),
          ),
        );
      },
    );
  }
}
