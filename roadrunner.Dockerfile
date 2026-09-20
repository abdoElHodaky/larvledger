FROM spacetabio/roadrunner-alpine:8.1-base-1.11.0
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
# 3. Copy full project code
COPY . /var/www/html

# 4. Require RoadRunner packages & download Go binary
RUN composer require laravel/octane spiral/roadrunner-cli spiral/roadrunner-http spiral/roadrunner --no-interaction \
    && ./vendor/bin/rr get-binary --quiet \
    && chmod +x rr \
    && mv rr /usr/local/bin/rr

# 5. Optimize Autoloader & Publish Assets
RUN composer dump-autoload --optimize \
    && php artisan octane:install --server=roadrunner --no-interaction \
    && php artisan livewire:publish --assets \
    && php artisan vendor:publish --tag=laravel-assets --ansi --force

# 6. Clean up temporary NPM/build caches to minimize layer size
RUN rm -rf node_modules ~/.npm ~/.composer


# ==========================================
# STAGE 3: Minimal Production Runtime Image
# ==========================================
FROM base AS runner

WORKDIR /var/www/html

# Copy ONLY compiled production artifacts from builder
COPY --from=builder /var/www/html /var/www/html
COPY --from=builder /usr/local/bin/rr /usr/local/bin/rr

# Production environment variables
ENV APP_KEY=base64:B6l/H5fSpR60Y+MpcKP22Z1B4Us7adD+jJrln8XOcpQ= \
    APP_ENV=production \
    APP_DEBUG=false \
    LOG_CHANNEL=stderr \
    APP_URL=http://localhost \
    ROADRUNNER_PORT=8000

EXPOSE ${ROADRUNNER_PORT}

ENTRYPOINT ["php", "artisan", "octane:start"]
CMD ["--server=roadrunner", "--workers=5", "--max-requests=1450", "--host=0.0.0.0", "--port=8000"]
