# NekoCafe 运维手册 (Runbook)

> 适用环境：dev / staging / production
> 维护人：谷钰

---

## 1. 快速诊断流程

当 Grafana 收到告警后，按以下步骤排查：

### 1.1 三步定位故障

```
Grafana Alert → 确认异常指标(QPS/延迟/错误率)
    ↓
Loki 日志查询 → 用 traceId 搜索最近 5 分钟 ERROR 日志
    ↓
Tempo 链路追踪 → 展开 traceId 查看各 Span 耗时 → 定位瓶颈服务
```

### 1.2 关键命令

```bash
# 查看 Pod 状态
kubectl get pods -n <namespace> -o wide

# 查看 Pod 日志 (最近 100 行)
kubectl logs -f <pod-name> -n <namespace> --tail=100

# 查看 Pod 资源使用
kubectl top pods -n <namespace>

# 查看服务健康状态
curl http://localhost:8081/actuator/health   # Reservation Service
curl http://localhost:8082/health             # Member Service

# 查看 Kafka 消费延迟
kubectl exec -it <kafka-pod> -n <namespace> -- \
  kafka-consumer-groups --bootstrap-server localhost:9092 \
  --group reservation-service --describe
```

---

## 2. 常见问题处置

### 2.1 P95 延迟突增

**症状**：Grafana Dashboard 上 P95 延迟从 200ms 跳到 800ms+

**排查步骤**：
1. 打开 Tempo，按延迟排序找出最慢的 trace
2. 查看最慢 Span 是哪个服务/数据库操作
3. 常见原因：
   - MySQL 慢查询 → `SHOW FULL PROCESSLIST;` 查看锁等待
   - Redis 缓存突然失效 → 检查 Redis 内存使用率和驱逐策略
   - Kafka 消息积压 → 检查 consumer lag

**处置**：
```bash
# 如果是 MySQL：终止慢查询
kubectl exec -it mysql-0 -n <namespace> -- mysql -e "KILL <thread_id>;"

# 如果是 Redis：清理过期 key 或扩容
kubectl scale deployment redis -n <namespace> --replicas=3
```

### 2.2 服务宕机

**症状**：`/health` 返回非 200，K8s liveness probe 失败

**处置**：
```bash
# K8s 会自动重启 (restartPolicy: Always)
# 查看重启原因
kubectl describe pod <pod-name> -n <namespace>
# 检查 Events 部分 → OOMKilled / CrashLoopBackOff / ImagePullBackOff

# 如果是 OOM：临时增加内存限制
kubectl set resources deployment/<service> -n <namespace> \
  --limits=memory=512Mi

# 如果是 ImagePullBackOff：检查镜像仓库认证
kubectl get secrets -n <namespace>
```

### 2.3 金丝雀发布异常 → 自动回滚

**症状**：金丝雀 Pod 的 P95>500ms 或错误率>1%（持续1-2分钟）

**自动回滚触发流程**：
1. Prometheus Alert → Grafana AlertManager
2. AlertManager Webhook → GitHub Actions `rollback` job
3. `helm rollback` 到前一个 revision

**手动回滚（如果自动回滚未触发）**：
```bash
# 查看 Helm 历史
helm history nekocafe-prod -n production

# 回滚到上一个版本
helm rollback nekocafe-prod -n production

# 回滚到指定版本
helm rollback nekocafe-prod 3 -n production

# 验证回滚成功
kubectl get pods -n production -l app=reservation-service
curl http://localhost:8081/actuator/health
```

### 2.4 数据库连接池耗尽

**症状**：应用日志中出现 `HikariPool-1 - Connection is not available`

**处置**：
```bash
# 查看当前连接数
kubectl exec -it mysql-0 -n <namespace> -- mysql -e "SHOW PROCESSLIST;"

# 临时增加连接池大小
helm upgrade nekocafe-dev ./helm \
  -f values-dev.yaml \
  --set reservation.datasource.maxPoolSize=30 \
  --namespace dev --wait

# 排查连接泄漏：检查代码中是否有未关闭的 Connection/ResultSet
```

---

## 3. 日常巡检

```bash
# 每日检查清单
make status                         # 所有服务健康状态
df -h /var/lib/docker               # 磁盘空间（镜像和容器）
docker system prune -f              # 清理未使用镜像（每周一次）
```

---

## 4. 紧急联系人

| 角色 | 姓名 | 联系方式 |
|------|------|---------|
| 架构师/后端 | 谷钰 | gu_yu@bjfu.edu.cn |
| 课程教师 | - | 超星学习通 |

**⚠️ 生产环境操作前必须先通知团队，禁止单人操作！**
