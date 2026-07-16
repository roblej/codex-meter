# Codex Meter

macOS 메뉴 막대에서 Codex 사용량을 확인하는 네이티브 Swift 앱입니다. 메뉴 막대 아이콘을 클릭하면 다음 정보를 보여줍니다.

- 현재 Codex 한도 사용률과 남은 비율
- 한도 초기화까지 남은 시간
- 일일 토큰(태평양 시간 기준)
- 누적 토큰과 연속 사용 일수
- 앱 실행 즉시 조회, 5분 자동 갱신, 수동 새로고침, 로그인 시 자동 실행

## 요구 사항

- macOS 13 이상
- Codex 데스크톱 앱 또는 Codex CLI 로그인
- Xcode 15 이상 또는 호환되는 Swift 툴체인

## 빌드와 실행

```bash
make test
make app
open dist/CodexMeter.app
```

생성된 앱은 `dist/CodexMeter.app`에 있습니다. 계속 사용하려면 앱을 `/Applications`로 옮긴 뒤, 팝오버의 더보기 메뉴에서 **로그인 시 실행**을 켜세요.

## 사용량을 가져오는 방식

앱은 로컬에 설치된 `codex app-server`를 실행한 뒤 다음 읽기 전용 메서드를 호출합니다.

- `account/rateLimits/read`
- `account/usage/read`

`auth.json`이나 액세스 토큰을 앱이 직접 읽거나 저장하지 않습니다. Codex CLI의 로그인 상태를 그대로 사용합니다. 현재 `app-server`는 Codex CLI에서 experimental로 표시되는 인터페이스이므로 향후 CLI 업데이트에서 프로토콜이 바뀌면 앱도 수정이 필요할 수 있습니다.

일일 사용량의 `startDate`는 OpenAI 계정 집계일에 맞춰 태평양 시간(PT) 기준으로 해석합니다. `일일 토큰` 카드의 정보 아이콘을 클릭하면 한국 시간 기준 날짜 변경 시각을 확인할 수 있습니다.

Codex 실행 파일을 자동으로 찾지 못하면 앱을 실행할 때 `CODEX_PATH` 환경 변수로 경로를 지정할 수 있습니다.
