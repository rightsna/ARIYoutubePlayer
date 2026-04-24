---
name: youtube_player
description: 유튜브 영상 검색·플레이리스트 관리·재생 제어를 제공하는 미니멀 플레이어 플러그인입니다. 음악 재생, 영상 틀기, 플레이리스트 요청 시 사용.
allowed-tools: control_app read_app_state
---

# ARIYoutubePlayer (Media Playback)

## Commands

### 1. Search (영상 검색)
- `SEARCH_VIDEOS`: YouTube에서 키워드로 영상을 검색하고 결과를 반환합니다.
  - Params: `query` (검색어), `limit` (기본 5개)
  - Returns: `List<{title, videoId, thumbnail, channelTitle}>` (재생 후보 선택용)
- `SEARCH_PLAYLIST_CANDIDATES`: 주어진 키워드(분위기, 장르 등)에 적합한 플레이리스트 후보를 확장 검색합니다.
  - Params: `query` (분위기/장르 등)

### 2. Playlist Management (플레이리스트 관리)
- `REPLACE_PLAYLIST`: 현재 재생 목록을 비우고 새 비디오 목록으로 교체한 뒤 즉시 첫 곡을 재생합니다.
  - Params: `videoIds` (`List<String>`)
- `ADD_TO_PLAYLIST`: 기존 목록 하단에 새 비디오들을 추가합니다.
  - Params: `videoIds` (`List<String>`)
- `REMOVE_FROM_PLAYLIST`: 목록 내에서 특정 비디오(ID)를 찾아 제거합니다.
  - Params: `videoIds` (`List<String>`)

### 3. Playback Control (재생 제어)
- `PLAY`: 현재 영상을 재생합니다.
- `PAUSE`: 일시정지합니다.
- `NEXT`: 다음 곡으로 넘어갑니다.
- `PREV`: 이전 곡으로 돌아갑니다.

### 4. UI Layout (화면 설정)
- `SET_MINI_MODE`: 창을 하단 바 형태의 미니 모드로 전환하거나 일반 모드로 복구합니다.
  - Params: `enabled` (`true`: 미니 모드, `false`: 일반 창)

---

## Writing Rules
1. **초기 실행**: 앱이 실행 중인지 확인한 뒤, 꺼져 있다면 `launch_app(appName: "youtube_player")`를 먼저 호출하세요.
2. **연속 재생**: 사용자가 특정 노래나 리스트를 틀어달라고 하면 `SEARCH_VIDEOS`로 ID를 얻은 뒤 `REPLACE_PLAYLIST` 명령을 보내세요.
3. **단일 비디오 처리**: 한 곡만 요청하더라도 `videoIds` 리스트에 한 개만 담아서 `REPLACE_PLAYLIST`로 전송합니다.
4. **미니 모드 활용**: 사용자가 "작게 틀어줘" 혹은 "바 형태로 보여줘"라고 요청하면 `SET_MINI_MODE`(`enabled: true`)를 활용하세요.

---

## Examples

### 특정 곡 검색 후 플레이리스트 교체 재생
```json
{
  "command": "REPLACE_PLAYLIST",
  "params": {
    "videoIds": ["dQw4w9WgXcQ"]
  }
}
```

### 분위기에 맞는 곡 검색 요청
```json
{
  "command": "SEARCH_PLAYLIST_CANDIDATES",
  "params": {
    "query": "공부할 때 듣기 좋은 차분한 로파이 음악"
  }
}
```

### 미니 모드로 전환
```json
{
  "command": "SET_MINI_MODE",
  "params": {
    "enabled": true
  }
}
```
