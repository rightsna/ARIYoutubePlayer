import 'dart:convert';
import 'package:http/http.dart' as http;

class YoutubeVideoItem {
  final String title;
  final String videoId;
  final String url;
  final String? thumbnailUrl;
  final String? channelName;
  final String? durationText;

  YoutubeVideoItem({
    required this.title,
    required this.videoId,
    required this.url,
    this.thumbnailUrl,
    this.channelName,
    this.durationText,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'videoId': videoId,
      'url': url,
      'thumbnailUrl': thumbnailUrl,
      'channelName': channelName,
      'durationText': durationText,
    };
  }
}

class YoutubeSearchService {
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
    'Accept-Language': 'ko,en-US;q=0.9,en;q=0.8',
  };

  /// Searches YouTube for videos based on the query.
  Future<List<YoutubeVideoItem>> searchVideos(String query, {int limit = 5}) async {
    final searchUrl = Uri.parse(
      'https://www.youtube.com/results?search_query=${Uri.encodeComponent(query)}',
    );

    try {
      final response = await http.get(searchUrl, headers: _headers);
      if (response.statusCode != 200) {
        throw Exception('YouTube request failed (${response.statusCode})');
      }

      final html = response.body;
      final initialData = _extractInitialData(html);
      if (initialData == null) {
        throw Exception('Failed to extract ytInitialData');
      }

      final items = <YoutubeVideoItem>[];
      _collectVideoRenderers(initialData, items);

      // Filter unique items and limit
      final seenIds = <String>{};
      final uniqueItems = items.where((item) {
        if (seenIds.contains(item.videoId)) return false;
        seenIds.add(item.videoId);
        return true;
      }).toList();

      return uniqueItems.take(limit).toList();
    } catch (e) {
      print('YoutubeSearchService Error: $e');
      return [];
    }
  }

  /// Searches for expanded playlist candidates like the TS version.
  Future<List<YoutubeVideoItem>> searchPlaylistCandidates(String query,
      {int perQueryLimit = 6, int maxItems = 15}) async {
    final variants = _buildPlaylistQueryVariants(query);
    final merged = <YoutubeVideoItem>[];
    final seenIds = <String>{};

    for (final variant in variants) {
      final items = await searchVideos(variant, limit: perQueryLimit);
      for (final item in items) {
        if (seenIds.contains(item.videoId)) continue;
        seenIds.add(item.videoId);
        merged.add(item);
        if (merged.length >= maxItems) return merged;
      }
    }

    return merged;
  }

  List<String> _buildPlaylistQueryVariants(String query) {
    final trimmed = query.trim();
    final timeMood = _getTimeMoodKeyword();
    final variants = [
      trimmed,
      '$timeMood $trimmed',
      '$trimmed 플레이리스트',
      '$timeMood 듣기 좋은 $trimmed 플레이리스트',
      '$trimmed 믹스',
      '$trimmed 모음',
    ];

    return variants.toSet().toList(); // Unique variants
  }

  String _getTimeMoodKeyword() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) return '아침';
    if (hour >= 11 && hour < 17) return '오후';
    if (hour >= 17 && hour < 22) return '저녁';
    return '새벽';
  }

  Map<String, dynamic>? _extractInitialData(String html) {
    final patterns = [
      RegExp(r'var ytInitialData = (.*?);</script>', dotAll: true),
      RegExp(r'window\["ytInitialData"\] = (.*?);</script>', dotAll: true),
      RegExp(r'ytInitialData"\] = (.*?);</script>', dotAll: true),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null && match.groupCount >= 1) {
        try {
          return jsonDecode(match.group(1)!) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }
      }
    }
    return null;
  }

  void _collectVideoRenderers(dynamic node, List<YoutubeVideoItem> acc) {
    if (node is List) {
      for (final item in node) {
        _collectVideoRenderers(item, acc);
      }
      return;
    }

    if (node is! Map<String, dynamic>) {
      return;
    }

    final videoRenderer = node['videoRenderer'];
    if (videoRenderer is Map<String, dynamic> &&
        videoRenderer['videoId'] is String) {
      final videoId = videoRenderer['videoId'] as String;
      final title = _getTextFromRuns(videoRenderer['title']);

      // Thumbnail
      String? thumbnailUrl;
      if (videoRenderer['thumbnail'] is Map &&
          videoRenderer['thumbnail']['thumbnails'] is List) {
        final thumbs = videoRenderer['thumbnail']['thumbnails'] as List;
        if (thumbs.isNotEmpty) {
          thumbnailUrl = thumbs.last['url'] as String?;
        }
      }

      acc.add(YoutubeVideoItem(
        title: title,
        videoId: videoId,
        url: 'https://www.youtube.com/watch?v= $videoId',
        thumbnailUrl: thumbnailUrl,
        channelName: _getTextFromRuns(videoRenderer['ownerText']),
        durationText: _getTextFromRuns(videoRenderer['lengthText']),
      ));
    }

    for (final value in node.values) {
      _collectVideoRenderers(value, acc);
    }
  }

  String _getTextFromRuns(dynamic value) {
    if (value is! Map<String, dynamic>) return '';

    if (value['simpleText'] is String) {
      return value['simpleText'] as String;
    }

    if (value['runs'] is List) {
      final runs = value['runs'] as List;
      return runs
          .map((run) => (run is Map && run['text'] is String) ? run['text'] : '')
          .join('')
          .trim();
    }

    return '';
  }
}
