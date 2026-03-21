import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class PlaylistItem {
  const PlaylistItem({required this.title, required this.videoId});

  final String title;
  final String videoId;

  PlaylistItem copyWith({String? title, String? videoId}) {
    return PlaylistItem(
      title: title ?? this.title,
      videoId: videoId ?? this.videoId,
    );
  }
}

class PlaylistProvider extends ChangeNotifier {
  PlaylistProvider() : _items = [], _currentVideoId = '';

  final List<PlaylistItem> _items;
  final Set<String> _pendingTitleLoads = <String>{};
  String _currentVideoId;
  bool _isPlaying = true;
  bool _isMiniMode = false;

  List<PlaylistItem> get items => List.unmodifiable(_items);
  String get currentVideoId => _currentVideoId;
  bool get isPlaying => _isPlaying;
  bool get isMiniMode => _isMiniMode;
  PlaylistItem get currentItem => currentIndex >= 0 && currentIndex < _items.length 
      ? _items[currentIndex] 
      : const PlaylistItem(title: 'No Video', videoId: '');

  static List<PlaylistItem> _buildInitialItems(List<String>? initialVideoIds) {
    if (initialVideoIds == null || initialVideoIds.isEmpty) {
      return [];
    }

    final uniqueIds = <String>{};
    final items = <PlaylistItem>[];
    for (final rawId in initialVideoIds) {
      final videoId = rawId.trim();
      if (videoId.isEmpty || !uniqueIds.add(videoId)) {
        continue;
      }
      items.add(PlaylistItem(title: videoId, videoId: videoId));
    }

    return items;
  }

  int get currentIndex {
    if (_items.isEmpty) return -1;
    final index = _items.indexWhere((item) => item.videoId == _currentVideoId);
    return index >= 0 ? index : 0;
  }

  void selectByVideoId(String videoId) {
    if (videoId.isEmpty) return;
    final existingIndex = _items.indexWhere((item) => item.videoId == videoId);
    if (existingIndex < 0) {
      _items.add(PlaylistItem(title: videoId, videoId: videoId));
      _fetchTitleFor(videoId);
    }

    if (_currentVideoId == videoId) {
      if (existingIndex < 0) {
        notifyListeners();
      }
      return;
    }

    _currentVideoId = videoId;
    notifyListeners();
  }

  void selectItem(PlaylistItem item) {
    selectByVideoId(item.videoId);
  }

  void playPrevious() {
    if (_items.isEmpty) return;
    final index = currentIndex;
    final nextIndex = index <= 0 ? _items.length - 1 : index - 1;
    selectItem(_items[nextIndex]);
  }

  void playNext() {
    if (_items.isEmpty) return;
    final index = currentIndex;
    final nextIndex = index >= _items.length - 1 ? 0 : index + 1;
    selectItem(_items[nextIndex]);
  }

  void replacePlaylist(List<String> videoIds) {
    final nextItems = _buildInitialItems(videoIds);
    _items
      ..clear()
      ..addAll(nextItems);
    _currentVideoId = _items.isNotEmpty ? _items.first.videoId : '';
    notifyListeners();
    _hydrateMissingTitles();
  }

  void addItems(List<String> videoIds) {
    bool changed = false;
    for (final id in videoIds) {
      final videoId = id.trim();
      if (videoId.isEmpty) continue;
      if (!_items.any((item) => item.videoId == videoId)) {
        _items.add(PlaylistItem(title: videoId, videoId: videoId));
        _fetchTitleFor(videoId);
        changed = true;
      }
    }
    if (changed) {
      if (_currentVideoId.isEmpty && _items.isNotEmpty) {
        _currentVideoId = _items.first.videoId;
      }
      notifyListeners();
    }
  }

  void removeItems(List<String> videoIds) {
    bool changed = false;
    final idsToRemove = videoIds.map((e) => e.trim()).toSet();
    
    int beforeCount = _items.length;
    _items.removeWhere((item) => idsToRemove.contains(item.videoId));
    if (_items.length != beforeCount) {
      changed = true;
      // If current video was removed, pick another or clear
      if (idsToRemove.contains(_currentVideoId)) {
        _currentVideoId = _items.isNotEmpty ? _items.first.videoId : '';
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  void setPlaying(bool playing) {
    if (_isPlaying == playing) return;
    _isPlaying = playing;
    notifyListeners();
  }

  void setIsMiniMode(bool miniMode) {
    if (_isMiniMode == miniMode) return;
    _isMiniMode = miniMode;
    notifyListeners();
  }

  void _hydrateMissingTitles() {
    for (final item in _items) {
      if (item.title == item.videoId) {
        _fetchTitleFor(item.videoId);
      }
    }
  }

  Future<void> _fetchTitleFor(String videoId) async {
    if (!_pendingTitleLoads.add(videoId)) {
      return;
    }

    try {
      final title = await _lookupTitle(videoId);
      if (title == null || title.isEmpty) {
        return;
      }

      final index = _items.indexWhere((item) => item.videoId == videoId);
      if (index < 0 || _items[index].title == title) {
        return;
      }

      _items[index] = _items[index].copyWith(title: title);
      notifyListeners();
    } finally {
      _pendingTitleLoads.remove(videoId);
    }
  }

  Future<String?> _lookupTitle(String videoId) async {
    final client = HttpClient();
    try {
      final uri = Uri.https('www.youtube.com', '/oembed', {
        'url': 'https://www.youtube.com/watch?v=$videoId',
        'format': 'json',
      });
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        return null;
      }

      final body = await utf8.decoder.bind(response).join();
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) {
        return null;
      }

      final title = json['title'];
      return title is String ? title : null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
