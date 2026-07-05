# Prometheus 多项目目标配置

Prometheus 主配置只保留全局配置，不维护告警规则。容器启动时会通过 `prometheus/build-config.sh` 合并本目录下的服务抓取配置，生成 Prometheus 运行时配置。告警规则、通知策略和 webhook 推送由 Grafana provisioning 统一管理。

目录约定：

```text
prometheus/projects/
  <项目名>/
    <服务名>/
      scrape.yml
```

`scrape.yml` 示例：

```yaml
- job_name: example-project-backend
  metrics_path: /metrics
  static_configs:
    - targets:
        - host.docker.internal:8081
      labels:
        project: example-project
        service: example-service
        component: backend
```

字段说明：

- `job_name`: Prometheus Targets 页面展示的抓取任务名称。
- `metrics_path`: 指标路径，例如 `/metrics` 或 `/actuator/prometheus`。
- `targets`: Prometheus 实际抓取地址，可以配置多个实例。
- `project`: 项目名称，用于查询和分组。
- `service`: 服务名称，用于区分同一项目下的不同服务。
- `component`: 服务组件或运行时类型。
