# 基于 Alpine 3.18 稳定版
FROM alpine:3.18

# 定义环境变量（PHP版本用无小数点格式，适配Alpine包名）
ENV PHP_VERSION=82 \
    NGINX_USER=nginx \
    TZ=Asia/Shanghai \
    NGINX_HTML_DIR=/var/www/html \  # Nginx默认映射目录
    PHP_CODE_DIR=/var/www/php       # PHP代码专属目录

# 1. 安装核心依赖 + 清理缓存 + 配置时区 + 创建目录 + 调整权限
RUN apk update && apk add --no-cache nginx php${PHP_VERSION}-fpm php${PHP_VERSION}-common php${PHP_VERSION}-mysqli php${PHP_VERSION}-pdo_mysql php${PHP_VERSION}-gd php${PHP_VERSION}-json php${PHP_VERSION}-xml tzdata && \
    apk cache clean && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    # 新增/var/www/php目录，同时保留原有目录
    mkdir -p ${NGINX_HTML_DIR} ${PHP_CODE_DIR} /etc/nginx/conf.d /run/nginx /var/log/nginx /var/log/php-fpm /etc/php${PHP_VERSION} && \
    # 给两个核心目录赋予nginx用户权限
    chown -R ${NGINX_USER}:${NGINX_USER} ${NGINX_HTML_DIR} ${PHP_CODE_DIR} /etc/nginx /run/nginx /var/log/nginx /var/log/php-fpm /etc/php${PHP_VERSION} && \
    chmod 755 ${NGINX_HTML_DIR} ${PHP_CODE_DIR}

# 2. 暴露80端口
EXPOSE 80

# 3. 生成启动脚本（修复换行解析问题，避免Docker识别脚本内指令）
RUN echo '#!/bin/sh&&set -e&&php-fpm${PHP_VERSION} -F &&&nginx -g "daemon off;"' > /start.sh && \
    sed -i 's/&&/\n/g' /start.sh && \
    chmod +x /start.sh

# 4. 启动容器（主进程保持前台运行）
CMD ["/start.sh"]
