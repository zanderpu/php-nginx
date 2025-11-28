FROM alpine:3.18

ENV PHP_VERSION=82 \
    NGINX_USER=nginx \
    TZ=Asia/Shanghai

RUN apk update && apk add --no-cache nginx php${PHP_VERSION}-fpm php${PHP_VERSION}-common php${PHP_VERSION}-mysqli php${PHP_VERSION}-pdo_mysql php${PHP_VERSION}-gd php${PHP_VERSION}-json php${PHP_VERSION}-xml tzdata && \
    apk cache clean && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    mkdir -p /var/www/html /etc/nginx/conf.d /run/nginx /var/log/nginx /var/log/php-fpm /etc/php${PHP_VERSION} && \
    chown -R ${NGINX_USER}:${NGINX_USER} /var/www/html /etc/nginx /run/nginx /var/log/nginx /var/log/php-fpm /etc/php${PHP_VERSION} && \
    chmod 755 /var/www/html

EXPOSE 80

# 直接用CMD启动，无需启动脚本
CMD sh -c "php-fpm${PHP_VERSION} -F & nginx -g 'daemon off;'"
