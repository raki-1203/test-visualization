#!/bin/bash
# Star Office UI - 테스트 에이전트 정리 스크립트
# 등록된 테스트 에이전트들을 /leave-agent로 퇴장시킴

OFFICE_URL="http://127.0.0.1:18791"

echo "=== Star Office UI - 테스트 에이전트 정리 ==="
echo ""

# 현재 에이전트 목록 조회
AGENTS_JSON=$(curl -s "${OFFICE_URL}/agents")

# 테스트 에이전트 이름 목록
TEST_AGENTS=("researcher" "executor" "reviewer")

for AGENT_NAME in "${TEST_AGENTS[@]}"; do
    AGENT_ID=$(echo "$AGENTS_JSON" | python3 -c "
import sys, json
agents = json.load(sys.stdin)
result = next((a['agentId'] for a in agents if a.get('name')=='${AGENT_NAME}' and not a.get('isMain')), '')
print(result)
" 2>/dev/null)

    if [ -n "$AGENT_ID" ]; then
        echo "${AGENT_NAME} (${AGENT_ID}) 퇴장 중..."
        RESULT=$(curl -s -X POST "${OFFICE_URL}/leave-agent" \
            -H "Content-Type: application/json" \
            -d "{\"agentId\":\"${AGENT_ID}\",\"name\":\"${AGENT_NAME}\"}")
        echo "  응답: $RESULT"
    else
        echo "${AGENT_NAME}: 등록된 에이전트 없음 (이미 퇴장했거나 미등록)"
    fi
done

echo ""
echo "=== 정리 완료 ==="
echo "현재 에이전트 목록:"
curl -s "${OFFICE_URL}/agents" | python3 -c "
import sys, json
agents = json.load(sys.stdin)
for a in agents:
    print(f\"  - {a['name']} ({a.get('agentId','?')}) : {a['state']} / {a.get('area','?')}\")
" 2>/dev/null
