# 基于 Alpine 3.18 稳定版（兼容PHP8.2/7.4）
FROM alpine:3.18

# 环境变量：PHP版本（无小数点）、运行用户、时区
ENV PHP_VERSION=82 \
    NGINX_USER=nginx \
    TZ=Asia/Shanghai \
    # 定义PHP代码目录（便于后续维护）
    PHP_DIR=/var/www/php \
    # 定义Nginx根目录（便于后续维护）
    NGINX_HTML_DIR=/var/www/html

# 1. 安装核心依赖 + 系统配置 + 目录创建
RUN apk update && apk add --no-cache \
    # Nginx核心
    nginx \
    # PHP-FPM及常用扩展（适配Alpine包名）
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
    # 清理apk缓存（减小镜像体积）
    apk cache clean && \
    # 配置时区（避免日志时间错乱）
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    # 创建核心目录（Nginx根目录 + PHP目录 + 日志/运行目录）
    mkdir -p \
    ${NGINX_HTML_DIR} \      # Nginx默认映射目录
    ${PHP_DIR} \             # PHP代码目录
    /etc/nginx/conf.d \      # Nginx配置目录（挂载自定义配置）
    /run/nginx \             # Nginx运行目录
    /var/log/nginx \         # Nginx日志目录
    /var/log/php-fpm \       # PHP-FPM日志目录
    && \
    # 统一权限（避免挂载本地目录后权限冲突）
    chown -R ${NGINX_USER}:${NGINX_USER} \
    ${NGINX_HTML_DIR} \
    ${PHP_DIR} \
    /etc/nginx \
    /run/nginx \
    /var/log/nginx \
    /var/log/php-fpm \
    && \
    # 设置目录读写权限
    chmod 755 ${NGINX_HTML_DIR} ${PHP_DIR}

# 2. 暴露Nginx默认端口
EXPOSE 80

# 3. 启动服务（直接CMD拼接，无启动脚本，彻底规避解析错误）
# 核心：前台运行PHP-FPM + Nginx，确保容器不退出
CMD sh -c "php-fpm${PHP_VERSION} -F & nginx -g 'daemon off;'"
