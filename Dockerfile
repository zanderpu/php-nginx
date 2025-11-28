# 基于 Alpine 3.18 基础镜像
FROM alpine:3.18

# 定义环境变量：PHP_VERSION 用无小数点格式（如82=8.2，74=7.4）
ENV PHP_VERSION=82 \
    NGINX_USER=nginx \
    TZ=Asia/Shanghai

# 1. 安装依赖包（修复PHP包名，适配Alpine命名规则）
RUN apk update && apk add --no-cache \
    # 核心运行依赖（PHP包名：php${PHP_VERSION}-fpm → php82-fpm）
    nginx \
    php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-common \
    php${PHP_VERSION}-mysqli \
    php${PHP_VERSION}-pdo_mysql \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-json \
    php${PHP_VERSION}-xml \
    # 工具依赖
    tzdata \
    && \
    # 2. 清理缓存
    apk cache clean && \
    # 3. 配置时区
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    # 4. 创建目录并调整权限
    mkdir -p /var/www/html /run/nginx /var/log/php-fpm && \
    chown -R ${NGINX_USER}:${NGINX_USER} /var/www/html /run/nginx /var/log/php-fpm && \
    chmod 755 /var/www/html

# 5. 配置 PHP-FPM（修复配置文件路径：php82 → 对应PHP_VERSION=82）
RUN sed -i -e 's/listen = 127.0.0.1:9000/listen = 9000/g' \
    -e 's/user = nobody/user = nginx/g' \
    -e 's/group = nobody/group = nginx/g' \
    -e 's/;clear_env = no/clear_env = no/g' \
    -e 's/pm.max_children = 5/pm.max_children = 20/g' \
    /etc/php${PHP_VERSION}/php-fpm.d/www.conf && \
    # 关闭PHP-FPM后台运行
    sed -i 's/;daemonize = yes/daemonize = no/g' /etc/php${PHP_VERSION}/php-fpm.conf

# 6. 配置 Nginx
RUN echo 'user nginx; \
worker_processes auto; \
error_log /var/log/nginx/error.log warn; \
pid /run/nginx/nginx.pid; \
events { \
    worker_connections 1024; \
} \
http { \
    include /etc/nginx/mime.types; \
    default_type application/octet-stream; \
    log_format main '\''$remote_addr - $remote_user [$time_local] "$request" '\''\
                    '\''$status $body_bytes_sent "$http_referer" '\''\
                    '\''"$http_user_agent" "$http_x_forwarded_for"'\''; \
    access_log /var/log/nginx/access.log main; \
    sendfile on; \
    tcp_nopush on; \
    keepalive_timeout 65; \
    gzip on; \
    include /etc/nginx/conf.d/*.conf; \
} \
' > /etc/nginx/nginx.conf && \
    # 站点配置
    echo 'server { \
    listen 80; \
    server_name localhost; \
    root /var/www/html; \
    index index.php index.html; \
    location ~ /\.ht { \
        deny all; \
    } \
    location ~ \.php$ { \
        fastcgi_pass 127.0.0.1:9000; \
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name; \
        include fastcgi_params; \
        fastcgi_param PHP_VALUE "error_log=/var/log/php-fpm/error.log"; \
    } \
}' > /etc/nginx/conf.d/default.conf

# 7. 暴露端口
EXPOSE 80

# 8. 启动脚本（修复PHP-FPM启动命令：php-fpm82 → 对应PHP_VERSION=82）
RUN echo '#!/bin/sh \
set -e \
# 启动PHP-FPM（前台运行）
php-fpm${PHP_VERSION} -F & \
# 启动Nginx（前台运行）
nginx -g "daemon off;" \
' > /start.sh && chmod +x /start.sh

# 9. 工作目录
WORKDIR /var/www/html

# 10. 启动容器
CMD ["/start.sh"]
