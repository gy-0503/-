# syntax=docker/dockerfile:1.6
# NekoCafe Member Service - 多阶段Dockerfile
# 目标: 镜像≤200MB, 非root运行, 0 HIGH/CRITICAL漏洞

# ===== Stage 1: Build (npm ci + 编译) =====
FROM node:20-alpine AS build
WORKDIR /app
# 利用层缓存: 先复制package文件安装依赖
COPY package*.json ./
RUN npm ci --only=production --ignore-scripts

# ===== Stage 2: Runtime (精简运行) =====
FROM node:20-alpine AS runtime

# 安全: 创建非root用户
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# 只复制生产依赖和源码
COPY --from=build --chown=appuser:appgroup /app/node_modules ./node_modules
COPY --chown=appuser:appgroup src/ ./src/
COPY --chown=appuser:appgroup package*.json ./

USER appuser:appgroup

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -q --spider http://localhost:8080/health || exit 1

EXPOSE 8080

# Node.js生产优化
ENV NODE_ENV=production
CMD ["node", "--max-old-space-size=256", "src/index.js"]
