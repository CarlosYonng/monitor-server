# Monitor Server 监控服务

独立监控服务，Prometheus 只负责拉取各项目服务暴露的指标，Grafana 负责仪表盘、告警规则和 webhook 推送，并把告警发送到 `ai-incident-copilot` 入站接口。

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
monitor-server Grafana 仪表盘 + 告警规则 + webhook 推送
        |
        v
ai-incident-copilot /api/alerts/grafana
```

`ai-agent-portfolio` 自身异常推送到 `diagnosis-service` MCP 服务的链路不变；本项目只负责指标拉取、可视化和 Grafana 告警入站。Prometheus 不配置告警内容，告警规则与通知策略全部由 Grafana provisioning 管理。

## 启动顺序

1. 启动被监控项目 `ai-agent-portfolio`，确认指标端点可访问：

```bash
curl http://localhost:8081/actuator/prometheus
curl http://localhost:8001/metrics
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

Grafana 会自动加载 `ai-agent-portfolio` 文件夹下的仪表盘和告警规则。
总览仪表盘包含 Java/AI 端点 QPS、错误率、p95 延迟、Java 调用 AI 服务耗时和聊天请求量；即使还没有真实聊天流量，也能看到 Java 与 AI 服务的抓取状态。聊天与 RAG、依赖服务等业务仪表盘会在聊天、RAG 检索、知识入库等真实请求产生后出现数据。

## 仪表盘说明

- `AI Agent Portfolio 总览`: 查看 Java 后端和 AI 服务的整体请求量、错误率、延迟与聊天调用情况。
- `AI Agent Portfolio 聊天与 RAG`: 查看智能体问答、RAG 检索延迟、空召回率、召回片段数和答案引用数量。
- `AI Agent Portfolio 依赖服务`: 查看 Qdrant、Neo4j、LLM、Embedding、Redis 和知识入库等依赖的错误情况。

## Prometheus 项目结构

Prometheus 主配置只保留通用抓取入口，具体项目和服务目标通过树形目录管理：

```text
prometheus/
  prometheus.yml
  projects/
    ai-agent-portfolio/
      backend-java/
        scrape.yml
      ai-service/
        scrape.yml
```

新增项目或服务时，只需要按 `prometheus/projects/<项目名>/<服务名>/scrape.yml` 新增抓取配置。每个服务文件是一段完整的 Prometheus `scrape_config`，声明 `job_name`、`metrics_path`、`targets`、`project`、`service` 和 `component`。容器启动时会由 `prometheus/build-config.sh` 合并这些文件，生成 Prometheus 运行时配置。

## 关键配置

- Prometheus 主抓取配置: `prometheus/prometheus.yml`
- Prometheus 运行时配置生成脚本: `prometheus/build-config.sh`
- Prometheus 多项目目标配置: `prometheus/projects/`
- Grafana 数据源配置: `grafana/provisioning/datasources/prometheus.yml`
- Grafana 仪表盘自动装载配置: `grafana/provisioning/dashboards/dashboards.yml`
- Grafana 告警规则、通知点和通知策略: `grafana/provisioning/alerting/`
- 仪表盘 JSON: `grafana/dashboards/`

Docker 中通过 `host.docker.internal` 访问宿主机上的 `ai-agent-portfolio` 与 `ai-incident-copilot`，因此 RAG 项目不需要和监控项目放在同一个 compose 网络中。
