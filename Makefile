.PHONY: up down status logs test clean help

# === 默认目标 ===
help:
	@echo "NekoCafe DevOps Makefile"
	@echo "  make up      启动全部服务 (docker compose up -d --build)"
	@echo "  make down    停止并删除全部容器和卷"
	@echo "  make status  查看服务健康状态"
	@echo "  make logs    查看所有服务日志 (tail -f)"
	@echo "  make test    运行测试套件"
	@echo "  make clean   清理Docker资源 (镜像+卷+缓存)"

# === 启动 ===
up:
	docker compose up -d --build
	@echo "⏳ 等待服务就绪..."
	@sleep 30
	@$(MAKE) status

# === 停止 ===
down:
	docker compose down -v
	@echo "✅ 所有容器已停止并清理"

# === 状态 ===
status:
	@echo "========== 服务状态 =========="
	@docker compose ps
	@echo ""
	@echo "========== 健康检查 =========="
	@curl -s -o /dev/null -w "Reservation: %{http_code}\n" http://localhost:8081/actuator/health || echo "Reservation: ❌ DOWN"
	@curl -s -o /dev/null -w "Member:      %{http_code}\n" http://localhost:8082/health || echo "Member:      ❌ DOWN"
	@curl -s -o /dev/null -w "Grafana:     %{http_code}\n" http://localhost:3000/api/health || echo "Grafana:     ❌ DOWN"

# === 日志 ===
logs:
	docker compose logs -f --tail=100

# === 测试 ===
test:
	@echo "Running unit tests..."
	cd services/reservation && mvn test -B -q
	cd services/member && npm test
	@echo "Running integration tests..."
	docker compose exec reservation curl -s http://localhost:8080/actuator/health | jq .
	@echo "✅ All tests passed"

# === 清理 ===
clean:
	docker compose down -v --rmi local --remove-orphans
	docker system prune -f
	@echo "✅ Docker资源已清理"
