#!/bin/bash
# Star Office UI - 에이전트 상태 주기적 Push 스크립트
# 등록된 에이전트들의 상태를 15초마다 push하며 다양한 상태 전환을 시뮬레이션

OFFICE_URL="http://127.0.0.1:18791"
PUSH_INTERVAL=15

# 상태 목록
STATES=("writing" "researching" "executing" "syncing" "idle" "error")
DETAILS_WRITING=("코드 작성 중" "문서 작성 중" "리팩토링 중")
DETAILS_RESEARCHING=("코드 분석 중" "의존성 조사 중" "아키텍처 검토 중")
DETAILS_EXECUTING=("테스트 실행 중" "빌드 중" "배포 중")
DETAILS_SYNCING=("변경사항 동기화 중" "브랜치 병합 중")
DETAILS_IDLE=("대기 중" "휴식 중")
DETAILS_ERROR=("빌드 에러 발생" "테스트 실패")

# 에이전트 정보 로드
echo "=== Star Office UI - 에이전트 상태 Push 시작 ==="
echo "간격: ${PUSH_INTERVAL}초"
echo "중지: Ctrl+C"
echo ""

# 에이전트 ID 조회
AGENTS_JSON=$(curl -s "${OFFICE_URL}/agents")
RESEARCHER_ID=$(echo "$AGENTS_JSON" | python3 -c "import sys,json; agents=json.load(sys.stdin); print(next((a['agentId'] for a in agents if a.get('name')=='researcher' and not a.get('isMain')), ''))" 2>/dev/null)
EXECUTOR_ID=$(echo "$AGENTS_JSON" | python3 -c "import sys,json; agents=json.load(sys.stdin); print(next((a['agentId'] for a in agents if a.get('name')=='executor' and not a.get('isMain')), ''))" 2>/dev/null)
REVIEWER_ID=$(echo "$AGENTS_JSON" | python3 -c "import sys,json; agents=json.load(sys.stdin); print(next((a['agentId'] for a in agents if a.get('name')=='reviewer' and not a.get('isMain')), ''))" 2>/dev/null)

if [ -z "$RESEARCHER_ID" ] || [ -z "$EXECUTOR_ID" ] || [ -z "$REVIEWER_ID" ]; then
    echo "에러: 에이전트가 등록되지 않았습니다. 먼저 register-test-agents.sh를 실행하세요."
    echo "  researcher: $RESEARCHER_ID"
    echo "  executor: $EXECUTOR_ID"
    echo "  reviewer: $REVIEWER_ID"
    exit 1
fi

echo "에이전트 ID 확인:"
echo "  researcher: $RESEARCHER_ID"
echo "  executor: $EXECUTOR_ID"
echo "  reviewer: $REVIEWER_ID"
echo ""

get_random_detail() {
    local state=$1
    case "$state" in
        writing)    local arr=("${DETAILS_WRITING[@]}") ;;
        researching) local arr=("${DETAILS_RESEARCHING[@]}") ;;
        executing)  local arr=("${DETAILS_EXECUTING[@]}") ;;
        syncing)    local arr=("${DETAILS_SYNCING[@]}") ;;
        idle)       local arr=("${DETAILS_IDLE[@]}") ;;
        error)      local arr=("${DETAILS_ERROR[@]}") ;;
        *)          local arr=("작업 중") ;;
    esac
    echo "${arr[$RANDOM % ${#arr[@]}]}"
}

CYCLE=0
trap 'echo ""; echo "Push 중지됨."; exit 0' INT

while true; do
    CYCLE=$((CYCLE + 1))
    echo "[Cycle $CYCLE] $(date '+%H:%M:%S')"

    # 각 에이전트에 다른 상태 할당 (순환)
    IDX1=$(( (CYCLE - 1) % 6 ))
    IDX2=$(( (CYCLE + 1) % 6 ))
    IDX3=$(( (CYCLE + 3) % 6 ))

    STATE1=${STATES[$IDX1]}
    STATE2=${STATES[$IDX2]}
    STATE3=${STATES[$IDX3]}

    DETAIL1=$(get_random_detail "$STATE1")
    DETAIL2=$(get_random_detail "$STATE2")
    DETAIL3=$(get_random_detail "$STATE3")

    # researcher push
    curl -s -X POST "${OFFICE_URL}/agent-push" \
        -H "Content-Type: application/json" \
        -d "{\"agentId\":\"${RESEARCHER_ID}\",\"joinKey\":\"ocj_starteam02\",\"state\":\"${STATE1}\",\"detail\":\"${DETAIL1}\",\"name\":\"researcher\"}" > /dev/null
    echo "  researcher → $STATE1 ($DETAIL1)"

    # executor push
    curl -s -X POST "${OFFICE_URL}/agent-push" \
        -H "Content-Type: application/json" \
        -d "{\"agentId\":\"${EXECUTOR_ID}\",\"joinKey\":\"ocj_starteam03\",\"state\":\"${STATE2}\",\"detail\":\"${DETAIL2}\",\"name\":\"executor\"}" > /dev/null
    echo "  executor → $STATE2 ($DETAIL2)"

    # reviewer push
    curl -s -X POST "${OFFICE_URL}/agent-push" \
        -H "Content-Type: application/json" \
        -d "{\"agentId\":\"${REVIEWER_ID}\",\"joinKey\":\"ocj_starteam04\",\"state\":\"${STATE3}\",\"detail\":\"${DETAIL3}\",\"name\":\"reviewer\"}" > /dev/null
    echo "  reviewer → $STATE3 ($DETAIL3)"

    echo ""
    sleep $PUSH_INTERVAL
done
