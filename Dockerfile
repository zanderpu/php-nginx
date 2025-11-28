# 基于 Alpine 3.18 基础镜像（稳定版，兼容主流包）
FROM alpine:3.18

# 定义环境变量（可选，方便后续修改PHP版本）
ENV PHP_VERSION=8.2 \
    NGINX_USER=nginx \
    TZ=Asia/Shanghai

# 1. 安装依赖包（Alpine 用 apk 替代 apt）
# 核心依赖：nginx、php-fpm、php核心扩展
# 临时依赖：编译扩展用的工具（安装后清理，减小镜像体积）
RUN apk update && apk add --no-cache \
    # 核心运行依赖
    nginx \
    php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-common \
    php${PHP_VERSION}-mysqli \
    php${PHP_VERSION}-pdo_mysql \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-json \
    php${PHP_VERSION}-xml \
    # 工具依赖（时区、字符集）
    tzdata \
    && \
    # 2. 清理缓存（Alpine 必做，减小镜像体积）
    apk cache clean && \
    # 3. 配置时区（避免日志时间错乱）
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    # 4. 创建Nginx/PHP运行目录及权限调整
    mkdir -p /var/www/html /run/nginx /var/log/php-fpm && \
    chown -R ${NGINX_USER}:${NGINX_USER} /var/www/html /run/nginx /var/log/php-fpm && \
    chmod 755 /var/www/html

# 5. 配置 PHP-FPM（适配 Alpine 路径）
# Alpine 中 PHP-FPM 配置文件路径：/etc/php82/php-fpm.d/www.conf（版本不同路径后缀不同）
RUN sed -i \
    -e 's/listen = 127.0.0.1:9000/listen = 9000/g' \          # 监听所有地址（简化配置）
    -e 's/user = nobody/user = nginx/g' \                      # 运行用户改为 nginx（和Nginx统一）
    -e 's/group = nobody/group = nginx/g' \
    -e 's/;clear_env = no/clear_env = no/g' \                  # 保留环境变量（可选）
    -e 's/pm.max_children = 5/pm.max_children = 20/g' \       # 调整进程数（按需）
    /etc/php${PHP_VERSION}/php-fpm.d/www.conf && \
    # 关闭 PHP-FPM 后台运行（必须前台运行，否则容器会退出）
    sed -i 's/;daemonize = yes/daemonize = no/g' /etc/php${PHP_VERSION}/php-fpm.conf

# 6. 配置 Nginx（关联 PHP-FPM）
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
    # 编写站点配置
    echo 'server { \
    listen 80; \
    server_name localhost; \
    root /var/www/html; \
    index index.php index.html; \
    # 禁止访问隐藏文件
    location ~ /\.ht { \
        deny all; \
    } \
    # PHP 请求转发到本地 PHP-FPM
    location ~ \.php$ { \
        fastcgi_pass 127.0.0.1:9000; \
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name; \
        include fastcgi_params; \
        fastcgi_param PHP_VALUE "error_log=/var/log/php-fpm/error.log"; \
    } \
}' > /etc/nginx/conf.d/default.conf

# 7. 暴露 80 端口
EXPOSE 80

# 8. 编写启动脚本（前台运行 Nginx + PHP-FPM）
# Alpine 无 service 命令，直接调用二进制程序
RUN echo '#!/bin/sh \
set -e \
# 启动 PHP-FPM（前台运行）
php-fpm${PHP_VERSION} & \
# 启动 Nginx（前台运行，容器主进程）
nginx -g "daemon off;" \
' > /start.sh && chmod +x /start.sh

# 9. 工作目录（代码挂载目录）
WORKDIR /var/www/html

# 10. 启动容器（主进程为 Nginx，保证容器不退出）
CMD ["/start.sh"]
