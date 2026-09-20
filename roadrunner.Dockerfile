FROM spacetabio/roadrunner-alpine:8.2-base-1.11.0
RUN apk add -U --no-cache nghttp2-dev nodejs npm unzip tzdata
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer
RUN docker-php-ext-install bcmath 
COPY . /var/www/html
WORKDIR /var/www/html
# Laravel config
#ENV APP_KEY base64:Zndza2ttMm9kbnNkcmlmeHlmYnlnb3RzOTJxMnBnNHY=
ENV APP_ENV production
ENV APP_DEBUG true
ENV LOG_CHANNEL stderr
ENV APP_URL 0.0.0.0

# Allow composer to run as root
ENV COMPOSER_ALLOW_SUPERUSER 1
ENV NODEJS_ALLOW_SUPERUSER 1
ENV NPM_ALLOW_SUPERUSER 1
ENV YARN_ALLOW_SUPERUSER 1
ENV NPX_ALLOW_SUPERUSER 1
ENV OCTANE_SERVER roadrunner
#RUN echo 'pm.max_children = 15' >> /usr/local/etc/php-fpm.d/zz-docker.conf && \
#echo 'pm.max_requests = 500' >> /usr/local/etc/php-fpm.d/zz-docker.conf
RUN chmod -R 777 . && composer install &&\
composer require laravel/octane spiral/roadrunner-cli && npm install 
RUN yes | php artisan octane:install --server=roadrunner
RUN ./vendor/bin/rr get-binary --quiet && chmod +x rr && mv rr /usr/local/bin/rr
RUN npm run build && php artisan storage:link
#RUN wget https://github.com/roadrunner-server/roadrunner/releases/download/v2.12.0/roadrunner-2.12.0-linux-amd64.tar.gz \
 #   && tar -zxvf roadrunner-2.12.0-linux-amd64.tar.gz \
 #   && cp roadrunner-2.12.0-linux-amd64/rr /usr/local/bin/rr \
 #   && rm -rf roadrunner-2.12.0*
EXPOSE 8000
ENTRYPOINT ["php", "artisan", "octane:start"]
CMD ["--server=roadrunner", "--workers=5","--max-requests=1450","--host=0.0.0.0", "--port=8000"]
