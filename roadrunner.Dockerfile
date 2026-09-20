#FROM spacetabio/roadrunner-alpine:8.2-base-1.11.0
FROM shinsenter/roadrunner:php8.2-alpine
RUN apk add -U --no-cache nghttp2-dev nodejs npm unzip tzdata
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer
#RUN docker-php-ext-install bcmath 
COPY . /var/www/html
WORKDIR /var/www/html

# Laravel config
ENV APP_KEY base64:B6l/H5fSpR60Y+MpcKP22Z1B4Us7adD+jJrln8XOcpQ=
ENV APP_ENV production
ENV APP_DEBUG true
ENV LOG_CHANNEL stderr
ENV APP_URL 0.0.0.0
ENV ROADRUNNER_PORT 8000
# Allow composer to run as root
ENV COMPOSER_ALLOW_SUPERUSER 1
ENV NODEJS_ALLOW_SUPERUSER 1
ENV NPM_ALLOW_SUPERUSER 1
ENV YARN_ALLOW_SUPERUSER 1
ENV NPX_ALLOW_SUPERUSER 1

RUN chmod -R 777 . && composer install --no-interaction --ignore-platform-reqs --no-update  && npm i
RUN composer require laravel/octane spiral/roadrunner-cli spiral/roadrunner-http spiral/roadrunner --no-interaction \
    && ./vendor/bin/rr get-binary --quiet \
    && chmod +x rr \
    && mv rr /usr/local/bin/rr \ 
    && php artisan octane:install --server=roadrunner --no-interaction 
   # && sed -i 's/version: "2.7"/version: "3.0"/g' .rr.yaml \
   # && sed -i 's/version: "2"/version: "3.0"/g' .rr.yaml


#RUN php artisan livewire:publish --assets && php artisan vendor:publish --tag=laravel-assets --ansi --force

EXPOSE 8000
#ENTRYPOINT ["php", "artisan", "octane:start"]
#CMD ["--server=roadrunner", "--workers=5","--max-requests=1450","--host=0.0.0.0", "--port=8000"]
