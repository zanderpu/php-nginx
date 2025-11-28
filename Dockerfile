# 基于 Alpine 3.18 稳定版
FROM alpine:3.18

# 定义环境变量（PHP版本用无小数点格式，适配Alpine包名）
ENV PHP_VERSION=82 \
    NGINX_USER=nginx \
    TZ=Asia/Shanghai

# 1. 安装核心依赖 + 清理缓存 + 配置时区 + 创建目录 + 调整权限
RUN apk update && apk add --no-cache nginx php${PHP_VERSION}-fpm php${PHP_VERSION}-common php${PHP_VERSION}-mysqli php${PHP_VERSION}-pdo_mysql php${PHP_VERSION}-gd php${PHP_VERSION}-json php${PHP_VERSION}-xml tzdata && \
    apk cache clean && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    mkdir -p /var/www/html /etc/nginx/conf.d /run/nginx /var/log/nginx /var/log/php-fpm /etc/php${PHP_VERSION} && \
    chown -R ${NGINX_USER}:${NGINX_USER} /var/www/html /etc/nginx /run/nginx /var/log/nginx /var/log/php-fpm /etc/php${PHP_VERSION} && \
    chmod 755 /var/www/html

# 2. 暴露80端口
EXPOSE 80

# 3. 生成启动脚本（关键：用单行转义所有换行，避免Docker解析错误）
RUN echo '#!/bin/sh && set -e && php-fpm${PHP_VERSION} -F & && nginx -g "daemon off;"' > /start.sh && \
    # 替换脚本内的 && 为换行（最终生成合法的Shell脚本）
    sed -i 's/&&/\n/g' /start.sh && \
    # 添加执行权限
    chmod +x /start.sh

# 4. 启动容器
CMD ["/start.sh"]
