# Monitor Server 监控服务

独立监控栈，用于集中拉取多个项目/服务暴露的 Prometheus 指标，并通过 Grafana 提供仪表盘、告警规则和 webhook 推送能力。

当前默认接入 `ai-agent-portfolio`：

- Java 后端: `http://host.docker.internal:8081/actuator/prometheus`
- AI 服务: `http://host.docker.internal:8001/metrics`
- 告警入站: `ai-incident-copilot /api/alerts/grafana`

## 职责边界

```text
被监控项目
  backend-java /actuator/prometheus
  ai-service   /metrics
        |
        v
monitor-server Prometheus
  只负责指标抓取和存储
        |
        v
monitor-server Grafana
  仪表盘 + 告警规则 + 通知策略 + webhook 推送
        |
        v
ai-incident-copilot /api/alerts/grafana
```

Prometheus 不维护告警规则；所有告警内容、通知点和通知策略都由 `grafana/provisioning/alerting/` 管理。

## 快速启动

1. 启动被监控服务，并确认指标端点可访问：

```bash
curl http://localhost:8081/actuator/prometheus
curl http://localhost:8001/metrics
```

2. 启动 `ai-incident-copilot`，并确认告警 webhook 入站接口可访问：

```bash
curl http://localhost:8080/api/health
```

3. 启动监控栈：

```bash
cp .env.example .env
docker compose --env-file .env up -d
```

4. 查看状态：

```bash
docker compose ps
docker compose logs prometheus --tail=80
docker compose logs grafana --tail=80
```

## 访问入口

- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3001`
- Grafana 默认账号: `admin/admin`

## 启动验证

```bash
curl http://localhost:9090/-/ready
curl http://localhost:3001/api/health
```

Prometheus Targets 页面应看到：

- `ai-agent-portfolio-backend-java`
- `ai-agent-portfolio-ai-service`

如果 target 是 `down` 且错误为 `connection refused`，通常表示被监控服务本身还没有在宿主机端口启动；监控栈本身不一定有问题。

## WSL2 Docker 准备

如果在 WSL2 中运行，并希望 `carlos` 不加 `sudo` 直接使用 Docker：

```bash
sudo usermod -aG docker carlos
newgrp docker
docker ps
```

如果 `newgrp docker` 后仍不生效，退出当前 WSL 会话后重新进入，或在 PowerShell 中执行：

```powershell
wsl --shutdown
```

如果 Docker daemon 在 WSL2 中启动时报 iptables/nftables bridge 网络错误，可切换到 legacy：

```bash
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
sudo service docker restart
```

如需让 WSL 发行版启动时自动启动 Docker，可在 `/etc/wsl.conf` 中配置：

```ini
[boot]
systemd=true
command="service docker start"
```

修改后在 PowerShell 执行：

```powershell
wsl --shutdown
```

## 仪表盘

Grafana 会自动加载 `grafana/dashboards/` 下的仪表盘：

- `AI Agent Portfolio 总览`: 请求量、错误率、p95 延迟、Java 调用 AI 服务耗时和聊天请求量。
- `AI Agent Portfolio 聊天与 RAG`: 智能体问答、RAG 检索延迟、空召回率、召回片段数和答案引用数量。
- `AI Agent Portfolio 依赖服务`: Qdrant、Neo4j、LLM、Embedding、Redis 和知识入库等依赖错误情况。

## Prometheus 多项目结构

Prometheus 主配置只保留全局配置。容器启动时，`prometheus/build-config.sh` 会合并所有服务抓取配置，并生成运行时配置 `/tmp/prometheus.runtime.yml`。

目录约定：

```text
prometheus/
  prometheus.yml
  build-config.sh
  projects/
    <项目名>/
      <服务名>/
        scrape.yml
```

新增项目或服务时，创建一个新的 `scrape.yml`：

```yaml
- job_name: example-project-backend
  metrics_path: /metrics
  static_configs:
    - targets:
        - host.docker.internal:8081
      labels:
        project: example-project
        application: example-project
        service: example-service
        component: backend
```

常用标签：

- `project`: 项目名称，用于跨项目筛选。
- `application`: 应用名称，兼容常见 Micrometer/JVM Grafana 模板变量。
- `service`: 服务名称，用于区分同一项目下的不同服务。
- `component`: 服务组件或运行时类型。

## 告警模拟

可以直接模拟 Grafana webhook 推送，方便联调 `ai-incident-copilot`：

```bash
./scripts/simulate-alert.sh --list
./scripts/simulate-alert.sh --alert portfolio-ai-service-timeout
./scripts/simulate-alert.sh --alert portfolio-ai-service-timeout --resolved
```

默认 webhook 地址为 `http://localhost:8080/api/alerts/grafana`，可通过环境变量覆盖：

```bash
INCIDENT_COPILOT_GRAFANA_WEBHOOK_URL=http://localhost:8080/api/alerts/grafana \
  ./scripts/simulate-alert.sh
```

## 关键配置

- Compose 编排: `docker-compose.yml`
- 环境变量示例: `.env.example`
- Prometheus 主配置: `prometheus/prometheus.yml`
- Prometheus 运行时配置生成脚本: `prometheus/build-config.sh`
- Prometheus 多项目抓取配置: `prometheus/projects/`
- Grafana 数据源: `grafana/provisioning/datasources/prometheus.yml`
- Grafana 仪表盘装载: `grafana/provisioning/dashboards/dashboards.yml`
- Grafana 告警与通知: `grafana/provisioning/alerting/`
- Grafana 仪表盘 JSON: `grafana/dashboards/`

## 常见问题

**Grafana 报 `lookup prometheus no such host`**

通常是 Prometheus 容器没有正常启动。先看：

```bash
docker compose ps
docker compose logs prometheus --tail=100
```

**Prometheus target 显示 `connection refused`**

通常是被监控服务没有启动，或端口与 `scrape.yml` 中的 `targets` 不一致。

**修改 dashboard、alert 或 scrape 配置后没有生效**

重启监控栈：

```bash
docker compose restart
```

如果修改了镜像、挂载或启动脚本：

```bash
docker compose up -d --force-recreate
```
