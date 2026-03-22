import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ari_plugin/ari_plugin.dart';
import 'player_page.dart';
import 'playlist_provider.dart';

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
    WsManager.init(host: host, port: int.parse(port));
    WsManager.connect();

    final handler = AppProtocolHandler(
      appId: 'youtubeplayer',
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
      onGetCommands: () => {
        'PLAY': '재생을 시작합니다.',
        'PAUSE': '일시정지합니다.',
        'NEXT': '다음 곡을 재생합니다.',
        'PREV': '이전 곡을 재생합니다.',
        'ADD_TO_PLAYLIST': '현재 목록에 곡을 추가합니다. {"videoIds": ["id1", ...]}',
        'REPLACE_PLAYLIST':
            '현재 목록을 비우고 새 목록으로 교체합니다. {"videoIds": ["id1", ...]}',
        'REMOVE_FROM_PLAYLIST': '목록에서 특정 곡을 삭제합니다. {"videoIds": ["id1", ...]}',
        'SET_MINI_MODE': '미니모드(바 형태)를 켜거나 끕니다. {"enabled": true/false}',
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ARI YouTube Player',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFd90429)),
        scaffoldBackgroundColor: const Color(0xFF111111),
      ),
      home: const PlayerPage(),
    );
  }
}
