#!/usr/bin/env bash
# =============================================================
# 模拟 Grafana 告警推送到 incident-copilot webhook
# 用法:
#   ./scripts/simulate-alert.sh                          # 发送默认告警
#   ./scripts/simulate-alert.sh --resolved               # 告警恢复
#   ./scripts/simulate-alert.sh --list                   # 列出可用告警
#   ./scripts/simulate-alert.sh --alert portfolio-llm-provider-error  # 指定告警
# =============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# 默认 webhook 地址
WEBHOOK_URL="${INCIDENT_COPILOT_GRAFANA_WEBHOOK_URL:-http://localhost:8080/api/alerts/grafana}"

MODE="firing"
ALERT_UID="portfolio-ai-service-timeout"

# =============================================================
# 告警负载生成
# =============================================================
generate_payload() {
  local uid="$1"
  local status="$2"
  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # macOS 兼容的转大写
  local status_upper
  status_upper=$(echo "$status" | tr '[:lower:]' '[:upper:]')

  case "$uid" in
    portfolio-ai-service-timeout)
      cat <<EOF
{
  "receiver": "incident-copilot-grafana-webhook",
  "status": "${status}",
  "alerts": [{
    "status": "${status}",
    "labels": {
      "alertname": "PortfolioAiServiceTimeout",
      "service": "ai-agent-portfolio",
      "endpoint": "/api/chat/messages",
      "exception_type": "AIServiceTimeout",
      "severity": "P1",
      "error_rate": "0.02",
      "p95_latency": "3",
      "affected_requests": "10"
    },
    "annotations": {
      "summary": "ai-agent-portfolio 调用 ai-service 处理聊天消息时出现超时",
      "description": "模拟告警：由 Java 后端到 ai-service 的真实指标触发的 Grafana 告警。"
    },
    "startsAt": "${now}",
    "endsAt": "${now}",
    "generatorURL": "http://localhost:3001/alerting/list",
    "fingerprint": "sim-ai-service-timeout-001",
    "values": {
      "error_rate": 0.035,
      "p95_latency": 3200,
      "threshold": 0.02
    }
  }],
  "groupLabels": {"alertname": "PortfolioAiServiceTimeout", "service": "ai-agent-portfolio"},
  "commonLabels": {"alertname": "PortfolioAiServiceTimeout", "service": "ai-agent-portfolio"},
  "commonAnnotations": {"summary": "ai-agent-portfolio 调用 ai-service 处理聊天消息时出现超时"},
  "externalURL": "http://localhost:3001",
  "version": "4",
  "groupKey": "{}:{alertname=\"PortfolioAiServiceTimeout\"}",
  "truncatedAlerts": 0,
  "orgId": 1,
  "title": "[${status_upper}] PortfolioAiServiceTimeout",
  "state": "${status}",
  "message": "模拟告警：ai-agent-portfolio 调用 ai-service 超时"
}
EOF
      ;;

    portfolio-llm-provider-error)
      cat <<EOF
{
  "receiver": "incident-copilot-grafana-webhook",
  "status": "${status}",
  "alerts": [{
    "status": "${status}",
    "labels": {
      "alertname": "PortfolioLlmProviderError",
      "service": "portfolio-ai-service",
      "endpoint": "llm_chat_completion",
      "exception_type": "LLMProviderError",
      "severity": "P2",
      "error_rate": "0.02",
      "affected_requests": "10"
    },
    "annotations": {
      "summary": "portfolio-ai-service 调用 LLM 服务商失败或被限流",
      "description": "模拟告警：LLM 超时、限流或 5xx 错误。"
    },
    "startsAt": "${now}",
    "endsAt": "${now}",
    "generatorURL": "http://localhost:3001/alerting/list",
    "fingerprint": "sim-llm-error-001",
    "values": {
      "error_rate": 0.05,
      "affected_requests": 10,
      "threshold": 0.02
    }
  }],
  "groupLabels": {"alertname": "PortfolioLlmProviderError", "service": "portfolio-ai-service"},
  "commonLabels": {"alertname": "PortfolioLlmProviderError", "service": "portfolio-ai-service"},
  "commonAnnotations": {"summary": "portfolio-ai-service 调用 LLM 服务商失败或被限流"},
  "externalURL": "http://localhost:3001",
  "version": "4",
  "groupKey": "{}:{alertname=\"PortfolioLlmProviderError\"}",
  "truncatedAlerts": 0,
  "orgId": 1,
  "title": "[${status_upper}] PortfolioLlmProviderError",
  "state": "${status}",
  "message": "模拟告警：portfolio-ai-service LLM 服务商错误"
}
EOF
      ;;

    portfolio-rag-retrieval-empty)
      cat <<EOF
{
  "receiver": "incident-copilot-grafana-webhook",
  "status": "${status}",
  "alerts": [{
    "status": "${status}",
    "labels": {
      "alertname": "PortfolioRagRetrievalEmptySpike",
      "service": "portfolio-ai-service",
      "endpoint": "retrieve_knowledge",
      "exception_type": "RAGRetrievalEmpty",
      "severity": "P2",
      "error_rate": "0.10",
      "affected_requests": "10"
    },
    "annotations": {
      "summary": "portfolio RAG 检索在多次请求中没有返回可用引用",
      "description": "模拟告警：Qdrant 和 GraphRAG 未产出可用上下文。"
    },
    "startsAt": "${now}",
    "endsAt": "${now}",
    "generatorURL": "http://localhost:3001/alerting/list",
    "fingerprint": "sim-rag-empty-001",
    "values": {
      "empty_rate": 0.15,
      "affected_requests": 10,
      "threshold": 0.10
    }
  }],
  "groupLabels": {"alertname": "PortfolioRagRetrievalEmptySpike", "service": "portfolio-ai-service"},
  "commonLabels": {"alertname": "PortfolioRagRetrievalEmptySpike", "service": "portfolio-ai-service"},
  "commonAnnotations": {"summary": "portfolio RAG 检索在多次请求中没有返回可用引用"},
  "externalURL": "http://localhost:3001",
  "version": "4",
  "groupKey": "{}:{alertname=\"PortfolioRagRetrievalEmptySpike\"}",
  "truncatedAlerts": 0,
  "orgId": 1,
  "title": "[${status_upper}] PortfolioRagRetrievalEmptySpike",
  "state": "${status}",
  "message": "模拟告警：RAG 检索返回空引用"
}
EOF
      ;;

    portfolio-qdrant-unavailable)
      cat <<EOF
{
  "receiver": "incident-copilot-grafana-webhook",
  "status": "${status}",
  "alerts": [{
    "status": "${status}",
    "labels": {
      "alertname": "PortfolioQdrantUnavailable",
      "service": "portfolio-ai-service",
      "endpoint": "qdrant_search",
      "exception_type": "QdrantUnavailable",
      "severity": "P1",
      "error_rate": "0.02",
      "affected_requests": "10"
    },
    "annotations": {
      "summary": "portfolio-ai-service 的 Qdrant 检索不可用或变慢",
      "description": "模拟告警：向量检索能力已降级。"
    },
    "startsAt": "${now}",
    "endsAt": "${now}",
    "generatorURL": "http://localhost:3001/alerting/list",
    "fingerprint": "sim-qdrant-001",
    "values": {
      "error_rate": 0.08,
      "affected_requests": 10,
      "threshold": 0.02
    }
  }],
  "groupLabels": {"alertname": "PortfolioQdrantUnavailable", "service": "portfolio-ai-service"},
  "commonLabels": {"alertname": "PortfolioQdrantUnavailable", "service": "portfolio-ai-service"},
  "commonAnnotations": {"summary": "portfolio-ai-service 的 Qdrant 检索不可用或变慢"},
  "externalURL": "http://localhost:3001",
  "version": "4",
  "groupKey": "{}:{alertname=\"PortfolioQdrantUnavailable\"}",
  "truncatedAlerts": 0,
  "orgId": 1,
  "title": "[${status_upper}] PortfolioQdrantUnavailable",
  "state": "${status}",
  "message": "模拟告警：Qdrant 检索不可用"
}
EOF
      ;;

    portfolio-graphrag-fallback-failure)
      cat <<EOF
{
  "receiver": "incident-copilot-grafana-webhook",
  "status": "${status}",
  "alerts": [{
    "status": "${status}",
    "labels": {
      "alertname": "PortfolioGraphRagFallbackFailure",
      "service": "portfolio-ai-service",
      "endpoint": "graphrag_fallback",
      "exception_type": "GraphRagFallbackFailure",
      "severity": "P2"
    },
    "annotations": {
      "summary": "portfolio GraphRAG fallback 失败或未产出图谱上下文",
      "description": "模拟告警：Neo4j fallback 查询失败或图谱上下文为空。"
    },
    "startsAt": "${now}",
    "endsAt": "${now}",
    "generatorURL": "http://localhost:3001/alerting/list",
    "fingerprint": "sim-graphrag-001",
    "values": {
      "error_rate": 0.15,
      "affected_requests": 3,
      "threshold": 0.02
    }
  }],
  "groupLabels": {"alertname": "PortfolioGraphRagFallbackFailure", "service": "portfolio-ai-service"},
  "commonLabels": {"alertname": "PortfolioGraphRagFallbackFailure", "service": "portfolio-ai-service"},
  "commonAnnotations": {"summary": "portfolio GraphRAG fallback 失败或未产出图谱上下文"},
  "externalURL": "http://localhost:3001",
  "version": "4",
  "groupKey": "{}:{alertname=\"PortfolioGraphRagFallbackFailure\"}",
  "truncatedAlerts": 0,
  "orgId": 1,
  "title": "[${status_upper}] PortfolioGraphRagFallbackFailure",
  "state": "${status}",
  "message": "模拟告警：GraphRAG fallback 失败"
}
EOF
      ;;

    portfolio-knowledge-ingestion-failure)
      cat <<EOF
{
  "receiver": "incident-copilot-grafana-webhook",
  "status": "${status}",
  "alerts": [{
    "status": "${status}",
    "labels": {
      "alertname": "PortfolioKnowledgeIngestionFailure",
      "service": "ai-agent-portfolio",
      "endpoint": "knowledge_ingestion",
      "exception_type": "KnowledgeIngestionFailure",
      "severity": "P2",
      "affected_requests": "1"
    },
    "annotations": {
      "summary": "ai-agent-portfolio 知识入库失败",
      "description": "模拟告警：上传、脚本执行、向量化、Qdrant 写入、Neo4j 写入或 MySQL 状态更新失败。"
    },
    "startsAt": "${now}",
    "endsAt": "${now}",
    "generatorURL": "http://localhost:3001/alerting/list",
    "fingerprint": "sim-ingestion-001",
    "values": {
      "failure_count": 3,
      "threshold": 0
    }
  }],
  "groupLabels": {"alertname": "PortfolioKnowledgeIngestionFailure", "service": "ai-agent-portfolio"},
  "commonLabels": {"alertname": "PortfolioKnowledgeIngestionFailure", "service": "ai-agent-portfolio"},
  "commonAnnotations": {"summary": "ai-agent-portfolio 知识入库失败"},
  "externalURL": "http://localhost:3001",
  "version": "4",
  "groupKey": "{}:{alertname=\"PortfolioKnowledgeIngestionFailure\"}",
  "truncatedAlerts": 0,
  "orgId": 1,
  "title": "[${status_upper}] PortfolioKnowledgeIngestionFailure",
  "state": "${status}",
  "message": "模拟告警：知识入库失败"
}
EOF
      ;;

    *)
      echo "❌ 未知告警 UID: $uid" >&2
      exit 1
      ;;
  esac
}

list_alerts() {
  echo "可用告警列表:"
  echo "  portfolio-ai-service-timeout           - AI 服务超时 (P1)"
  echo "  portfolio-llm-provider-error           - LLM 服务商错误 (P2)"
  echo "  portfolio-rag-retrieval-empty          - RAG 检索空结果 (P2)"
  echo "  portfolio-qdrant-unavailable           - Qdrant 不可用 (P1)"
  echo "  portfolio-graphrag-fallback-failure    - GraphRAG fallback 失败 (P2)"
  echo "  portfolio-knowledge-ingestion-failure  - 知识入库失败 (P2)"
}

# =============================================================
# 解析参数
# =============================================================
while [[ $# -gt 0 ]]; do
  case "$1" in
    --firing)    MODE="firing" ;;
    --resolved)  MODE="resolved" ;;
    --alert)     ALERT_UID="$2"; shift ;;
    --url)       WEBHOOK_URL="$2"; shift ;;
    --list)      list_alerts; exit 0 ;;
    -h|--help)   sed -n '2,11p' "$0"; exit 0 ;;
    *)           echo "❌ 未知参数: $1" >&2; sed -n '2,11p' "$0"; exit 1 ;;
  esac
  shift
done

# =============================================================
# 发送模拟告警
# =============================================================
echo "══════════════════════════════════════════"
echo "  模拟 Grafana 告警推送"
echo "══════════════════════════════════════════"
echo "  告警规则:  $ALERT_UID"
echo "  状态:      $MODE"
echo "  目标 URL:  $WEBHOOK_URL"
echo ""

PAYLOAD=$(generate_payload "$ALERT_UID" "$MODE")

echo "📦 请求体预览:"
echo "$PAYLOAD" | python3 -m json.tool 2>/dev/null || echo "$PAYLOAD"
echo ""

echo "🚀 发送中..."
HTTP_CODE=$(curl -s -o /tmp/alert-sim-response.txt -w "%{http_code}" \
  -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

echo ""
if [[ "$HTTP_CODE" =~ ^2[0-9][0-9]$ ]]; then
  echo "✅ 发送成功！HTTP $HTTP_CODE"
  echo "响应内容:"
  python3 -m json.tool /tmp/alert-sim-response.txt 2>/dev/null || cat /tmp/alert-sim-response.txt
else
  echo "❌ 发送失败！HTTP $HTTP_CODE"
  echo "响应内容:"
  cat /tmp/alert-sim-response.txt 2>/dev/null || echo "(空)"
fi
echo ""
echo "💡 提示: 使用 --resolved 发送告警恢复；使用 --list 查看所有告警"
