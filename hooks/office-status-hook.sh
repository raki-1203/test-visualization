#!/bin/bash
# Star Office UI - Claude Code Hook Script
# stdin으로 JSON을 받아 도구 종류에 따라 오피스 상태를 자동 변경
# 백그라운드 curl로 실행하여 Claude Code를 블로킹하지 않음

OFFICE_URL="http://127.0.0.1:18791"

# stdin에서 JSON 읽기
INPUT=$(cat)

# event와 tool_name 추출 (jq 없이 간단한 파싱)
EVENT=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('event',''))" 2>/dev/null)
TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null)

# 상태 매핑
STATE="idle"
DETAIL=""

case "$EVENT" in
    "UserPromptSubmit")
        STATE="writing"
        DETAIL="사용자 요청 처리 중"
        ;;
    "PreToolUse")
        case "$TOOL_NAME" in
            Bash)
                STATE="executing"
                DETAIL="명령 실행 중"
                ;;
            Read|Grep|Glob)
                STATE="researching"
                DETAIL="코드 분석 중"
                ;;
            Write|Edit)
                STATE="writing"
                DETAIL="코드 작성 중"
                ;;
            Task)
                STATE="syncing"
                DETAIL="서브 에이전트 작업 중"
                ;;
            *)
                STATE="executing"
                DETAIL="도구 사용 중: $TOOL_NAME"
                ;;
        esac
        ;;
    "Stop")
        STATE="idle"
        DETAIL="대기 중"
        ;;
    *)
        # 알 수 없는 이벤트는 무시
        exit 0
        ;;
esac

# 백그라운드로 상태 업데이트 (Claude Code 블로킹 방지)
curl -s -X POST "${OFFICE_URL}/set_state" \
    -H "Content-Type: application/json" \
    -d "{\"state\":\"${STATE}\",\"detail\":\"${DETAIL}\"}" \
    > /dev/null 2>&1 &

exit 0
