# syntax=docker/dockerfile:1.6
# NekoCafe Reservation Service - 多阶段Dockerfile
# 目标: 镜像≤200MB, 非root运行, 通过Trivy扫描(0 HIGH/CRITICAL)

# ===== Stage 1: Build (Maven编译) =====
FROM maven:3.9-eclipse-temurin-17-alpine AS build
WORKDIR /app
# 利用Docker层缓存: 先复制pom.xml下载依赖，再复制源码编译
COPY pom.xml .
RUN mvn dependency:go-offline -B -q
COPY src/ ./src/
RUN mvn package -DskipTests -B -q

# ===== Stage 2: Runtime (JRE运行) =====
FROM eclipse-temurin:17-jre-alpine AS runtime

# 安全: 创建非root用户
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app
# 从构建阶段复制Jar
COPY --from=build /app/target/reservation-service-*.jar reservation-service.jar

# 切换到非root用户
USER appuser:appgroup

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -q --spider http://localhost:8080/actuator/health || exit 1

EXPOSE 8080

# JVM参数优化
ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-XX:+ExitOnOutOfMemoryError", \
  "-Djava.security.egd=file:/dev/./urandom", \
  "-jar", "reservation-service.jar"]
