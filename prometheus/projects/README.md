# Prometheus 多项目目标配置

Prometheus 主配置只加载本目录下的目标文件，不再维护告警规则。告警规则、通知策略和 webhook 推送由 Grafana provisioning 统一管理。

目录约定：

```text
prometheus/projects/
  <项目名>/
    <服务名>/
      targets.yml
```

`targets.yml` 示例：

```yaml
- targets:
    - host.docker.internal:8081
  labels:
    project: example-project
    service: example-service
    component: backend
    metrics_path: /metrics
    scrape_job: example-project-backend
```

字段说明：

- `targets`: Prometheus 实际抓取地址，可以配置多个实例。
- `project`: 项目名称，用于查询和分组。
- `service`: 服务名称，用于区分同一项目下的不同服务。
- `component`: 服务组件或运行时类型。
- `metrics_path`: 指标路径，会被主配置映射到 Prometheus 内部的 `__metrics_path__`。
- `scrape_job`: 展示在 Prometheus Targets 页面中的 job 名称。
