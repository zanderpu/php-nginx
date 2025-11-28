# 基于 Alpine 3.18 稳定版
FROM alpine:3.18

# 定义环境变量（PHP版本用无小数点格式，适配Alpine包名）
ENV PHP_VERSION=82 \
    NGINX_USER=nginx \
    TZ=Asia/Shanghai

# 1. 安装核心依赖（Nginx + PHP-FPM + 常用扩展）
RUN apk update && apk add --no-cache \
    # Nginx 核心
    nginx \
    # PHP-FPM 及扩展（适配Alpine包名：php82-fpm/php82-mysqli等）
    php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-common \
    php${PHP_VERSION}-mysqli \
    php${PHP_VERSION}-pdo_mysql \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-json \
    php${PHP_VERSION}-xml \
    # 时区/工具依赖
    tzdata \
    && \
    # 2. 清理apk缓存（减小镜像体积）
    apk cache clean && \
    # 3. 配置时区（避免日志时间错乱）
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    # 4. 创建必要目录（后续挂载本地目录用，赋予nginx用户权限）
    mkdir -p \
    /var/www/html \          # PHP代码目录（挂载本地代码）
    /etc/nginx/conf.d \      # Nginx配置目录（挂载本地nginx.conf）
    /run/nginx \             # Nginx运行目录
    /var/log/nginx \         # Nginx日志目录
    /var/log/php-fpm \       # PHP-FPM日志目录
    /etc/php${PHP_VERSION} \ # PHP配置目录（可选挂载）
    && \
    # 5. 统一权限（避免挂载本地目录后权限冲突）
    chown -R ${NGINX_USER}:${NGINX_USER} /var/www/html /etc/nginx /run/nginx /var/log/nginx /var/log/php-fpm /etc/php${PHP_VERSION} && \
    chmod 755 /var/www/html

# 6. 暴露80端口（Nginx默认端口）
EXPOSE 80

# 7. 编写启动脚本（前台运行Nginx + PHP-FPM，确保容器不退出）
RUN echo '#!/bin/sh \
set -e \
# 启动PHP-FPM（前台运行，-F强制前台）
php-fpm${PHP_VERSION} -F & \
# 启动Nginx（前台运行，容器主进程）
nginx -g "daemon off;" \
' > /start.sh && chmod +x /start.sh

# 8. 启动容器（执行启动脚本）
CMD ["/start.sh"]
