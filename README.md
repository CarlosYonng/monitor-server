# Monitor Server

独立监控服务，负责拉取 `ai-agent-portfolio` 暴露的 Prometheus 指标，并通过 Grafana 告警 webhook 推送到 `ai-incident-copilot` 入站接口。

## 架构链路

```text
ai-agent-portfolio
  backend-java /actuator/prometheus
  ai-service   /metrics
        |
        v
monitor-server Prometheus
        |
        v
monitor-server Grafana dashboards + alert rules
        |
        v
ai-incident-copilot /api/alerts/grafana
```

`ai-agent-portfolio` 自身异常推送到 `diagnosis-service` MCP 服务的链路不变；本项目只负责指标拉取、可视化和 Grafana 告警入站。

## 启动顺序

1. 启动被监控项目 `ai-agent-portfolio`，确认指标端点可访问：

```bash
curl http://localhost:8080/actuator/prometheus
curl http://localhost:8000/metrics
```

2. 启动 `ai-incident-copilot`，确认 Grafana webhook 入站接口可访问：

```bash
curl http://localhost:8080/api/health
```

3. 启动本监控项目：

```bash
cp .env.example .env
docker compose --env-file .env up -d
```

如需固定镜像版本，可在 `.env` 中调整 `PROMETHEUS_IMAGE` 与 `GRAFANA_IMAGE`。

## 访问入口

- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3001`
- Grafana 默认账号: `admin/admin`

Prometheus Targets 页面应看到：

- `ai-agent-portfolio-backend-java`
- `ai-agent-portfolio-ai-service`

Grafana 会自动加载 `ai-agent-portfolio` 文件夹下的 dashboard 和告警规则。
Overview dashboard 包含 `Prometheus Target Health` 和 `Endpoint Request Samples`，即使还没有真实聊天流量，也能看到 Java 与 AI 服务的抓取状态和端点样本；其它业务面板会在聊天、RAG、入库等真实请求产生后出现数据。

## 关键配置

- Prometheus 抓取配置: `prometheus/prometheus.yml`
- Prometheus 告警规则: `prometheus/rules/portfolio-alerts.yml`
- Grafana datasource: `grafana/provisioning/datasources/prometheus.yml`
- Grafana dashboard provisioning: `grafana/provisioning/dashboards/dashboards.yml`
- Grafana alert provisioning: `grafana/provisioning/alerting/`
- Dashboard JSON: `grafana/dashboards/`

Docker 中通过 `host.docker.internal` 访问宿主机上的 `ai-agent-portfolio` 与 `ai-incident-copilot`，因此 RAG 项目不需要和监控项目放在同一个 compose 网络中。
