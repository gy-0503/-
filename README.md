# NekoCafe 智慧餐饮预约平台

> **实验三：DevOps流水线与容器化部署**  
> 北京林业大学 · 信息学院 · 《软件工程》课程  
> 班级：计算机232 | 学号：231002205 | 姓名：谷钰

---

## 📋 项目概览

本仓库是NekoCafe智慧餐饮预约平台的DevOps实施仓库，包含：

- **2个核心微服务**: 预约服务(Reservation) + 会员服务(Member)
- **CI/CD流水线**: GitHub Actions自动化的lint→test→build→scan→deploy全流程
- **容器化**: 多阶段Dockerfile，镜像≤200MB，非root运行
- **可观测性**: OpenTelemetry + Prometheus + Grafana + Loki
- **渐进式发布**: 金丝雀部署 + 自动回滚

## 🚀 一键启动（30分钟内）

### 前置要求

- Docker Desktop 24+ (或 Podman 4+)
- Docker Compose v2.20+
- Git
- 至少分配4 CPU + 8 GB Memory给Docker

### 启动步骤

```bash
# 1. 克隆仓库
git clone https://github.com/gy-0503/-.git

# 2. 一键启动全部服务
make up
# 或: docker compose up -d --build

# 3. 等待所有服务健康（约2分钟）
make status

# 4. 验证服务
curl http://localhost:8081/actuator/health  # Reservation Service
curl http://localhost:8082/health           # Member Service
```

### 访问入口

| 服务 | URL | 说明 |
|------|-----|------|
| Reservation Service API | http://localhost:8081/v1 | 预约服务REST API |
| Member Service API | http://localhost:8082/v1 | 会员服务REST API |
| Grafana Dashboard | http://localhost:3000 | 监控面板 (admin/nekocafe_admin) |
| Prometheus | http://localhost:9090 | 指标查询 |

## 🧪 快速验证

```bash
# 创建预约
curl -X POST http://localhost:8081/v1/reservations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -d '{
    "storeId": "STORE-001",
    "slotId": "SLOT-A01",
    "bookingTime": "2026-06-20T14:00:00",
    "duration": 2,
    "guestCount": 2
  }'

# 查询会员信息
curl http://localhost:8082/v1/members/me \
  -H "Authorization: Bearer <JWT_TOKEN>"
```

## 📁 仓库结构

```
nekocafe-platform/
├── README.md                     # 本文档
├── docker-compose.yml            # 本地一键启动
├── Makefile                      # 快捷命令
├── services/
│   ├── reservation/              # 预约服务 (Spring Boot 3.2 + Java 17)
│   │   ├── Dockerfile            #   多阶段Dockerfile
│   │   ├── pom.xml
│   │   └── src/
│   └── member/                   # 会员服务 (Node.js 20 + Express)
│       ├── Dockerfile            #   多阶段Dockerfile
│       ├── package.json
│       └── src/
├── infra/
│   ├── helm/                     # Helm Charts (dev/staging/prod)
│   ├── mysql/                    # 数据库初始化脚本
│   ├── observability/            # 可观测性配置
│   │   ├── otel-collector-config.yaml
│   │   ├── prometheus.yml
│   │   └── grafana-dashboards/
│   └── k8s-manifests/            # K8s原生部署文件
├── .github/workflows/
│   ├── ci.yml                    # CI流水线 (PR触发)
│   └── cd.yml                    # CD流水线 (merge触发, 含金丝雀)
├── docs/
│   ├── runbook.md                # 运维手册
│   └── rollback.md               # 回滚手册
└── tests/
    ├── e2e/                      # 端到端测试 (Playwright)
    └── perf/                     # 性能测试 (k6)
```

## 🔧 常用命令 (Makefile)

| 命令 | 说明 |
|------|------|
| `make up` | 启动全部服务 (docker compose up -d --build) |
| `make down` | 停止并删除全部容器和卷 |
| `make status` | 查看服务状态 |
| `make logs` | 查看所有服务日志 |
| `make test` | 运行测试套件 |
| `make clean` | 清理Docker资源 |

## 📊 CI/CD 流水线

### CI (Pull Request → main)

```
Lint → Unit Test → SAST (CodeQL) → Build (Docker) → Container Scan (Trivy) → Integration Test → Push Image
```
- **耗时**: ≤10分钟
- **失败阻断**: Lint错误/测试失败/HIGH+漏洞/构建失败
- **PR评论**: 自动输出覆盖率/漏洞数/镜像大小

### CD (merge → main → production)

```
Deploy Dev → Smoke Test → Deploy Staging → E2E Test → Deploy Prod Canary (5%) → Monitor (10min) → Full (100%)
```
- **金丝雀策略**: 1 canary Pod + 4 stable Pods = 20%流量 → 监控 → 全量
- **自动回滚**: 错误率>1% OR P95>500ms → helm rollback

## 📈 DORA 指标

| 指标 | 目标 | 当前状态 |
|------|------|---------|
| 部署频率 (DF) | ≥ 1次/周 | 每PR合并自动部署 |
| 变更前置时间 (LT) | < 1小时 | PR→合并→部署 ~15分钟 |
| 变更失败率 (CFR) | < 1% | 金丝雀+自动回滚保障 |
| 平均恢复时间 (MTTR) | < 5分钟 | 自动回滚+告警 ~3分钟 |

## 🔒 安全基线

- [x] 容器非root运行
- [x] Secret通过GitHub Secrets注入 (严禁硬编码)
- [x] Trivy扫描 0 HIGH/CRITICAL
- [x] CodeQL静态分析
- [x] SBOM伴随镜像推送
- [x] 依赖自动更新 (Dependabot)

## 📞 联系

- 作者：谷钰 (计算机232 · 231002205)
- 课程：《软件工程》2026 春季学期
- 仓库：https://github.com/gy-0503/-
