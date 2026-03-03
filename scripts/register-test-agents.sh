#!/bin/bash
# Star Office UI - 테스트용 다중 에이전트 등록 스크립트
# 3개의 에이전트를 미리 등록하여 다중 에이전트 시각화 테스트

OFFICE_URL="http://127.0.0.1:18791"

echo "=== Star Office UI - 테스트 에이전트 등록 ==="
echo ""

# Agent 1: researcher
echo "[1/3] researcher 에이전트 등록 (ocj_starteam02)..."
RESULT1=$(curl -s -X POST "${OFFICE_URL}/join-agent" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "researcher",
        "joinKey": "ocj_starteam02",
        "state": "researching",
        "detail": "코드베이스 분석 중"
    }')
echo "  응답: $RESULT1"
AGENT1_ID=$(echo "$RESULT1" | python3 -c "import sys,json; print(json.load(sys.stdin).get('agentId',''))" 2>/dev/null)
echo "  agentId: $AGENT1_ID"
echo ""

# Agent 2: executor
echo "[2/3] executor 에이전트 등록 (ocj_starteam03)..."
RESULT2=$(curl -s -X POST "${OFFICE_URL}/join-agent" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "executor",
        "joinKey": "ocj_starteam03",
        "state": "executing",
        "detail": "테스트 실행 중"
    }')
echo "  응답: $RESULT2"
AGENT2_ID=$(echo "$RESULT2" | python3 -c "import sys,json; print(json.load(sys.stdin).get('agentId',''))" 2>/dev/null)
echo "  agentId: $AGENT2_ID"
echo ""

# Agent 3: reviewer
echo "[3/3] reviewer 에이전트 등록 (ocj_starteam04)..."
RESULT3=$(curl -s -X POST "${OFFICE_URL}/join-agent" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "reviewer",
        "joinKey": "ocj_starteam04",
        "state": "writing",
        "detail": "코드 리뷰 작성 중"
    }')
echo "  응답: $RESULT3"
AGENT3_ID=$(echo "$RESULT3" | python3 -c "import sys,json; print(json.load(sys.stdin).get('agentId',''))" 2>/dev/null)
echo "  agentId: $AGENT3_ID"
echo ""

echo "=== 등록 완료 ==="
echo "등록된 에이전트 목록:"
curl -s "${OFFICE_URL}/agents" | python3 -c "
import sys, json
agents = json.load(sys.stdin)
for a in agents:
    print(f\"  - {a['name']} ({a.get('agentId','?')}) : {a['state']} / {a.get('area','?')}\")
" 2>/dev/null
echo ""
echo "브라우저에서 확인: ${OFFICE_URL}"
