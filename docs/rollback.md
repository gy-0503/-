# NekoCafe 回滚手册 (Rollback Guide)

---

## 一键回滚命令

```bash
# 回滚到上一个版本
helm rollback nekocafe-prod -n production

# 查看 Helm 发布历史
helm history nekocafe-prod -n production
# 输出示例:
# REVISION  UPDATED                   STATUS      CHART           DESCRIPTION
# 1         Mon Jun 10 10:00:00 2026  superseded  nekocafe-0.1.0  Install complete
# 2         Mon Jun 10 14:30:00 2026  deployed    nekocafe-0.2.0  Upgrade complete
```

---

## 回滚触发条件

| 指标 | 阈值 | 持续时间 | 动作 |
|------|------|---------|------|
| P95 延迟 | > 500ms | 连续 2 分钟 | **自动回滚** |
| 错误率 (5xx) | > 1% | 连续 1 分钟 | **自动回滚** |
| 健康检查 | 连续 3 次失败 | - | K8s 重启 Pod → 3 次失败后人工介入 |
| CPU 使用率 | > 80% | 连续 3 分钟 | HPA 扩容（不回滚） |
| 内存使用率 | > 85% | 连续 2 分钟 | 告警通知，排查内存泄漏 |

---

## 手动回滚步骤

### 情况 A：金丝雀阶段发现问题

```bash
# 金丝雀监控窗口(10分钟)内发现异常 → 直接删除金丝雀资源
kubectl delete deployment nekocafe-prod-canary -n production
# stable 版本继续服务，金丝雀 Pod 终止
```

### 情况 B：全量发布后发现问题

```bash
# 1. 回滚到上一个已知好的版本
helm rollback nekocafe-prod -n production

# 2. 确认回滚后的 Pod 就绪
kubectl rollout status deployment/reservation-service -n production
kubectl rollout status deployment/member-service -n production

# 3. 验证
curl http://localhost:8081/actuator/health
helm history nekocafe-prod -n production
```

### 情况 C：数据库迁移回滚

```bash
# Flyway 回滚（如果迁移脚本包含 undo）
# 注意：Flyway 社区版不支持自动 undo，需要手动执行反操作 SQL
kubectl exec -it mysql-0 -n production -- mysql -u nekocafe -p -e "
  -- 手动执行回滚 SQL（如删除新增列、恢复旧表结构等）
"
```

---

## 回滚后验证清单

- [ ] `helm history` 确认版本已回退
- [ ] `kubectl get pods` 确认 Pod 数量正确且全部 Running
- [ ] `curl /actuator/health` 返回 UP
- [ ] Grafana Dashboard 确认 QPS/P95/错误率恢复正常
- [ ] 通知团队：已回滚到 revision X，原因：___

---

## 备注

- 保留最近 **3 个版本**的 Docker 镜像（其余由 GHCR 自动清理）
- 回滚后必须 **写 Postmortem**，否则下次还会踩同样的坑
