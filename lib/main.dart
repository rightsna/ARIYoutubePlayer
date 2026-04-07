import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ari_plugin/ari_plugin.dart';
import 'player_page.dart';
import 'playlist_provider.dart';
import 'youtube_search_service.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  // ARI Plugin 연동 설정
  String? readArg(String prefix) {
    for (final arg in args) {
      if (arg.startsWith(prefix)) return arg.substring(prefix.length);
    }
    return null;
  }

  final port =
      readArg('--port=') ??
      const String.fromEnvironment('ARI_PORT', defaultValue: '29277');
  final host =
      readArg('--host=') ??
      const String.fromEnvironment('ARI_HOST', defaultValue: '127.0.0.1');

  final playlist = PlaylistProvider();

  if (port.isNotEmpty) {
    AriAgent.init(host: host, port: int.parse(port));
    AriAgent.connect();

    final handler = AppProtocolHandler(
      appId: 'youtube_player',
      onCommand: (command, params) async {
        List<String> extractVideoIds(dynamic p) {
          final raw = p['videoIds'] ?? p['videoId'] ?? p['ids'];
          if (raw is List) return raw.map((e) => e.toString()).toList();
          if (raw is String) {
            return raw
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
          }
          return [];
        }

        switch (command) {
          case 'PLAY':
            playlist.setPlaying(true);
            return {'status': 'success'};
          case 'PAUSE':
            playlist.setPlaying(false);
            return {'status': 'success'};
          case 'NEXT':
            playlist.playNext();
            playlist.setPlaying(true);
            return {'status': 'success'};
          case 'PREV':
            playlist.playPrevious();
            playlist.setPlaying(true);
            return {'status': 'success'};
          case 'ADD_TO_PLAYLIST':
            final ids = extractVideoIds(params);
            if (ids.isNotEmpty) {
              playlist.addItems(ids);
              return {'status': 'success', 'addedCount': ids.length};
            }
            return {'status': 'error', 'message': 'No video IDs found'};
          case 'REPLACE_PLAYLIST':
            final ids = extractVideoIds(params);
            if (ids.isNotEmpty) {
              playlist.replacePlaylist(ids);
              playlist.setPlaying(true);
              return {'status': 'success', 'replacedCount': ids.length};
            }
            return {'status': 'error', 'message': 'No video IDs found'};
          case 'REMOVE_FROM_PLAYLIST':
            final ids = extractVideoIds(params);
            if (ids.isNotEmpty) {
              playlist.removeItems(ids);
              return {'status': 'success', 'removedCount': ids.length};
            }
            return {'status': 'error', 'message': 'No video IDs found'};
          case 'SET_MINI_MODE':
            final bool enable = params['enabled'] ?? params['enable'] ?? true;
            playlist.setIsMiniMode(enable);
            return {'status': 'success', 'enabled': enable};
          case 'SEARCH_VIDEOS':
            final query = params['query'] as String? ?? '';
            final limit = params['limit'] as int? ?? 5;
            final searchService = YoutubeSearchService();
            final results = await searchService.searchVideos(query, limit: limit);
            return {
              'status': 'success',
              'items': results.map((e) => e.toMap()).toList()
            };
          case 'SEARCH_PLAYLIST_CANDIDATES':
            final query = params['query'] as String? ?? '';
            final searchService = YoutubeSearchService();
            final results = await searchService.searchPlaylistCandidates(query);
            return {
              'status': 'success',
              'items': results.map((e) => e.toMap()).toList()
            };
          default:
            return {'status': 'error', 'message': 'Unknown command: $command'};
        }
      },
      onGetState: () => {
        'videoId': playlist.currentVideoId,
        'title': playlist.currentItem.title,
        'isPlaying': playlist.isPlaying,
        'isMiniMode': playlist.isMiniMode,
        'playlistCount': playlist.items.length,
      },
    );
    handler.start();
  }

  runApp(
    ChangeNotifierProvider.value(
      value: playlist,
      child: const YouTubePlayerApp(),
    ),
  );
}

class YouTubePlayerApp extends StatelessWidget {
  const YouTubePlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AriChatProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'ARI YouTube Player',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFd90429)),
          scaffoldBackgroundColor: const Color(0xFF111111),
        ),
        home: const PlayerPage(),
      ),
    );
  }
}
