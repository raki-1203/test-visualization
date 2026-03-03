# Star Office UI - 시각화 원리 & Claude Code 에이전트 연동

## Context

Star Office UI는 원래 OpenClaw(중국 AI 에이전트 플랫폼)용으로 만들어졌지만, 핵심 시스템(백엔드+프론트엔드)은 이미 OpenClaw에 의존하지 않음. CLI 스크립트 일부의 하드코딩된 경로만 수정하면 **Claude Code를 포함한 어떤 에이전트든** 연동 가능.

---

## 0. "클로드코드는 기본이 에이전트인가?"

**그렇다.** Claude Code 자체가 AI 에이전트다.

```
┌─ Claude Code (에이전트) ──────────────────────┐
│                                                │
│  LLM (Claude) + 도구들:                        │
│  - Bash: 셸 명령 실행                          │
│  - Read/Write/Edit: 파일 읽기/쓰기/수정         │
│  - Grep/Glob: 코드 검색                        │
│  - Agent: 서브 에이전트 생성 (Team)             │
│                                                │
│  ↓ 사용자 질문을 받으면                         │
│  ↓ 스스로 도구를 선택하고                       │
│  ↓ 계획을 세우고                               │
│  ↓ 코드를 읽고/쓰고/실행한다                    │
│  = 이것이 "에이전트"의 정의                     │
└────────────────────────────────────────────────┘
```

**에이전트 = LLM + 도구 사용 + 자율적 판단**

Claude Code는 사용자의 요청을 받으면:
1. 어떤 파일을 읽을지 **스스로 판단**
2. 어떤 명령어를 실행할지 **스스로 결정**
3. 결과를 보고 다음 행동을 **스스로 선택**

이것이 단순한 챗봇과 에이전트의 차이다. Star Office UI는 이런 에이전트의 **현재 상태**(뭘 하고 있는지)를 시각적으로 보여주는 대시보드다.

---

## 1. 시각화 동작 원리

### 전체 아키텍처

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────────┐
│  에이전트        │     │  Flask 백엔드     │     │  프론트엔드          │
│  (Claude Code,  │────▶│  (포트 18791)     │◀────│  (Phaser.js)        │
│   커스텀 등)    │     │                  │     │                     │
│                 │     │  state.json      │     │  2초마다 /status    │
│  상태 변경:     │     │  agents-state.json│     │  3.5초마다 /agents  │
│  - HTTP API     │     │                  │     │                     │
│  - state.json   │     │  상태→위치 매핑:  │     │  상태 변경 감지 시:  │
│                 │     │  idle→breakroom  │     │  캐릭터 이동 + 애니  │
│                 │     │  writing→desk    │     │  메이션 전환         │
│                 │     │  error→error zone│     │                     │
└─────────────────┘     └──────────────────┘     └─────────────────────┘
```

### 데이터 흐름 (단계별)

**1단계 - 에이전트가 상태를 보냄:**
```bash
# 방법 A: HTTP API (권장)
curl -X POST http://127.0.0.1:18791/set_state \
  -H "Content-Type: application/json" \
  -d '{"state": "writing", "detail": "코드 작성 중"}'

# 방법 B: state.json 파일 직접 수정
echo '{"state":"writing","detail":"코드 작성 중","updated_at":"2026-03-03T00:00:00"}' > state.json
```

**2단계 - 백엔드가 상태를 저장:**
- `POST /set_state` → `state.json` 파일에 JSON으로 저장
- 자동 idle: 300초(5분) 동안 업데이트 없으면 자동으로 idle 전환

**3단계 - 프론트엔드가 2초마다 폴링:**
```javascript
// index.html 내부 (Phaser update 루프)
fetch('/status')  // 2초 간격
  .then(r => r.json())
  .then(data => {
    if (data.state !== currentState) {
      // 상태가 바뀌었을 때만 시각 업데이트
      updateCharacterPosition(data.state);
    }
  });
```

**4단계 - 상태에 따라 캐릭터 위치/애니메이션 변경:**

| 상태 | 오피스 위치 | 좌표 | 시각 효과 |
|------|-----------|------|----------|
| idle | 휴게실 (중앙 소파) | x:640, y:360 | 소파에 앉아 쉬는 애니메이션 |
| writing | 작업 영역 (왼쪽 책상) | x:320, y:360 | 책상에서 작업하는 스프라이트 |
| researching | 작업 영역 | x:320, y:360 | 책상에서 작업하는 스프라이트 |
| executing | 작업 영역 | x:320, y:360 | 책상에서 작업하는 스프라이트 |
| syncing | 작업 영역 | 별도 좌표 | 동기화 전용 애니메이션 |
| error | 에러 구역 (우상단) | x:1066, y:180 | 벌레 캐릭터 좌우 왕복 |

### 핵심 기술 포인트
- **Phaser.js 게임 엔진**: Canvas/WebGL 기반 2D 렌더링
- **폴링 기반**: WebSocket이 아닌 HTTP 폴링 (구현이 단순)
- **스프라이트 애니메이션**: 12fps, 상태별 다른 스프라이트 시트 사용
- **말풍선**: 8초 간격으로 상태별 랜덤 대사 표시
- **자동 idle**: 5분간 업데이트 없으면 캐릭터가 소파로 복귀

---

## 2. 에이전트 추가 방법 (2가지 채널)

### 채널 A: 메인 에이전트 (1명 - Star 캐릭터)

오피스의 주인공 캐릭터. `state.json` 또는 `/set_state` API로 제어.

```bash
# HTTP API로 상태 변경
curl -X POST http://127.0.0.1:18791/set_state \
  -H "Content-Type: application/json" \
  -d '{"state": "writing", "detail": "코드 작성 중"}'
```

### 채널 B: 게스트 에이전트 (여러 명 - 방문자 캐릭터)

오피스에 놀러 오는 다른 에이전트들. Join Key로 입장.

```bash
# 1. 입장 (join key 필요)
curl -X POST http://127.0.0.1:18791/join-agent \
  -H "Content-Type: application/json" \
  -d '{"name": "나의에이전트", "joinKey": "ocj_starteam02", "state": "idle"}'
# → {"ok": true, "agentId": "agent_xxx_xxxx", "authStatus": "approved"}

# 2. 상태 푸시 (15~30초 간격으로 반복)
curl -X POST http://127.0.0.1:18791/agent-push \
  -H "Content-Type: application/json" \
  -d '{"agentId": "agent_xxx_xxxx", "joinKey": "ocj_starteam02", "state": "writing"}'

# 3. 퇴장
curl -X POST http://127.0.0.1:18791/leave-agent \
  -H "Content-Type: application/json" \
  -d '{"agentId": "agent_xxx_xxxx"}'
```

→ 최대 8개 key x 3 동시접속 = **24명** 동시 표시 가능

---

## 3. 수정 계획 - OpenClaw 의존성 제거

### 수정 파일 (3개만)

| 파일 | 변경 내용 | 이유 |
|------|----------|------|
| `set_state.py` (라인 9) | STATE_FILE 경로를 프로젝트 상대경로로 변경 | `/root/.openclaw/...` 하드코딩 |
| `office-agent-push.py` (라인 34-38) | DEFAULT_STATE_CANDIDATES에서 openclaw 경로 제거 | OpenClaw 경로 참조 |
| `healthcheck.sh` (라인 6) | LOG_FILE 경로를 프로젝트 상대경로로 변경 | `/root/.openclaw/...` 하드코딩 |

### 변경하지 않는 파일
- `backend/app.py` - 이미 상대 경로 사용 (변경 불필요)
- `frontend/*` - OpenClaw 의존성 없음
- 유틸리티 스크립트들 - 개발용이라 운영에 불필요

### 3-1. `set_state.py` 수정

```python
# 현재 (라인 9):
STATE_FILE = "/root/.openclaw/workspace/star-office-ui/state.json"

# 변경:
STATE_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "state.json")
```

### 3-2. `office-agent-push.py` 수정

```python
# 현재 (라인 34-38):
DEFAULT_STATE_CANDIDATES = [
    "/root/.openclaw/workspace/star-office-ui/state.json",
    "/root/.openclaw/workspace/state.json",
    os.path.join(os.getcwd(), "state.json"),
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "state.json"),
]

# 변경:
DEFAULT_STATE_CANDIDATES = [
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "state.json"),
    os.path.join(os.getcwd(), "state.json"),
]
```

### 3-3. `healthcheck.sh` 수정

```bash
# 현재 (라인 6):
LOG_FILE="/root/.openclaw/workspace/star-office-ui/healthcheck.log"

# 변경:
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/healthcheck.log"
```

---

## 4. Claude Code Hook 자동화 연동

### 원리

Claude Code에는 **Hook 시스템**이 있다. 특정 이벤트(도구 사용, 세션 시작/종료 등)가 발생하면 자동으로 셸 스크립트를 실행할 수 있다.

이걸 활용하면 Claude Code가 작업할 때 **자동으로** Star Office UI 상태가 바뀐다.

```
사용자가 질문함 (UserPromptSubmit)
  → Hook: curl로 state를 "writing"으로 변경
  → 오피스에서 캐릭터가 책상으로 이동

Claude가 Bash 도구 사용 (PreToolUse: Bash)
  → Hook: curl로 state를 "executing"으로 변경
  → 오피스에서 캐릭터가 실행 상태로 변경

Claude가 Read/Grep 사용 (PreToolUse: Read|Grep)
  → Hook: curl로 state를 "researching"으로 변경

에러 발생 (PostToolUse 실패 시)
  → Hook: curl로 state를 "error"로 변경
  → 오피스에서 벌레 캐릭터 등장

세션 종료 (Stop)
  → Hook: curl로 state를 "idle"로 변경
  → 캐릭터가 소파로 복귀
```

### Hook 스크립트 생성

**파일: `Star-Office-UI/hooks/office-status-hook.sh`**

```bash
#!/bin/bash
# Star Office UI - Claude Code Hook
# stdin으로 JSON을 받아서 도구 종류에 따라 오피스 상태 변경

OFFICE_URL="http://127.0.0.1:18791"
INPUT=$(cat)

HOOK_EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

case "$HOOK_EVENT" in
  "UserPromptSubmit")
    STATE="writing"
    DETAIL="사용자 요청 처리 중"
    ;;
  "PreToolUse")
    case "$TOOL_NAME" in
      Bash)
        STATE="executing"
        DETAIL="명령어 실행 중"
        ;;
      Read|Grep|Glob|WebSearch|WebFetch)
        STATE="researching"
        DETAIL="코드 분석 중"
        ;;
      Write|Edit)
        STATE="writing"
        DETAIL="코드 작성 중"
        ;;
      Agent)
        STATE="syncing"
        DETAIL="서브 에이전트 작업 중"
        ;;
      *)
        STATE="writing"
        DETAIL="작업 중"
        ;;
    esac
    ;;
  "Stop")
    STATE="idle"
    DETAIL="대기 중"
    ;;
  *)
    exit 0  # 무시
    ;;
esac

# 상태 업데이트 (백그라운드로 실행하여 Claude Code를 블로킹하지 않음)
curl -s -X POST "${OFFICE_URL}/set_state" \
  -H "Content-Type: application/json" \
  -d "{\"state\": \"${STATE}\", \"detail\": \"${DETAIL}\"}" \
  > /dev/null 2>&1 &

exit 0
```

### Claude Code settings.json에 Hook 등록

**파일: `Star-Office-UI/.claude/settings.json`** (프로젝트 레벨)

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ./hooks/office-status-hook.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash|Read|Write|Edit|Grep|Glob|Agent|WebSearch|WebFetch",
        "hooks": [
          {
            "type": "command",
            "command": "bash ./hooks/office-status-hook.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ./hooks/office-status-hook.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

→ 이렇게 설정하면 Claude Code를 사용할 때 **자동으로** 오피스 캐릭터가 움직인다.

---

## 5. 다중 에이전트 (Team) 연동

### 원리

Claude Code의 Team 기능으로 여러 서브 에이전트를 생성하면, 각 에이전트를 게스트로 오피스에 등록할 수 있다.

```
┌─ Claude Code Team ──────────────────────────────┐
│                                                  │
│  Team Lead (메인 에이전트)                        │
│    → Star Office 메인 캐릭터 (채널 A)             │
│                                                  │
│  Teammate: researcher                            │
│    → 게스트 에이전트 #1 (채널 B, key: starteam02) │
│                                                  │
│  Teammate: executor                              │
│    → 게스트 에이전트 #2 (채널 B, key: starteam03) │
│                                                  │
│  Teammate: tester                                │
│    → 게스트 에이전트 #3 (채널 B, key: starteam04) │
│                                                  │
└──────────────────────────────────────────────────┘
```

### 구현 방법

Team Lead가 서브 에이전트를 생성할 때, 각 에이전트에게 오피스 참여를 지시:

```python
# 각 서브 에이전트가 시작 시 실행할 스크립트
import requests

# 1. 오피스 참여
resp = requests.post("http://127.0.0.1:18791/join-agent", json={
    "name": "researcher",
    "joinKey": "ocj_starteam02",
    "state": "idle",
    "detail": "방금 입장"
})
agent_id = resp.json()["agentId"]

# 2. 작업 중 상태 업데이트
requests.post("http://127.0.0.1:18791/agent-push", json={
    "agentId": agent_id,
    "joinKey": "ocj_starteam02",
    "state": "researching",
    "detail": "코드 분석 중"
})

# 3. 작업 완료 시 퇴장
requests.post("http://127.0.0.1:18791/leave-agent", json={
    "agentId": agent_id
})
```

또는 더 간단하게, Team Lead의 Hook에서 Agent 도구 사용 시 자동으로 게스트 추가/제거를 관리할 수 있다.

---

## 6. 커스텀 에이전트 연동 (어떤 에이전트든)

Star Office UI는 **HTTP API만 호출할 수 있으면** 어떤 에이전트든 연동 가능:

| 에이전트 종류 | 연동 방법 |
|-------------|----------|
| Claude Code | Hook 시스템으로 자동화 (섹션 4) |
| Python 스크립트 | `requests.post()` 호출 |
| Node.js 에이전트 | `fetch()` 호출 |
| LangChain/CrewAI | Tool로 API 호출 래핑 |
| 셸 스크립트 | `curl` 명령어 |
| cron job | 주기적 상태 업데이트 |

**최소 코드 (Python):**
```python
import requests
requests.post("http://127.0.0.1:18791/set_state",
    json={"state": "writing", "detail": "작업 중"})
```

**최소 코드 (셸):**
```bash
curl -s -X POST http://127.0.0.1:18791/set_state \
  -H "Content-Type: application/json" -d '{"state":"writing"}'
```

---

## 7. 구현 순서

1. **OpenClaw 의존성 제거** (섹션 3: 파일 3개 수정)
2. **Hook 스크립트 생성** (`hooks/office-status-hook.sh`)
3. **프로젝트 레벨 settings.json 생성** (`.claude/settings.json`)
4. **검증**: 6가지 상태 모두 테스트

## 8. 검증 방법

1. `set_state.py` 실행하여 6가지 상태 변경 테스트
2. 브라우저(http://127.0.0.1:18791)에서 캐릭터 위치 변경 확인
3. Claude Code 세션에서 Hook이 동작하는지 확인 (도구 사용 시 상태 자동 변경)
4. `curl`로 `/status`, `/agents` API 응답 확인
