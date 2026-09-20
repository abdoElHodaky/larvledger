# ==========================================
# STAGE 1: Shared Base Environment
# ==========================================
FROM spacetabio/roadrunner-alpine:8.1-base-1.11.0 AS base

# Install system dependencies and PHP extensions ONCE
RUN apk add -U --no-cache nghttp2-dev nodejs npm unzip tzdata
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer
RUN docker-php-ext-install bcmath

WORKDIR /var/www/html

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    NODEJS_ALLOW_SUPERUSER=1 \
    NPM_ALLOW_SUPERUSER=1 \
    YARN_ALLOW_SUPERUSER=1 \
    NPX_ALLOW_SUPERUSER=1


# ==========================================
# STAGE 2: PHP & Asset Builder
# ==========================================
FROM base AS builder

# 1. Cache PHP dependencies
COPY composer.json composer.lock* /var/www/html/
RUN composer install --no-interaction --no-scripts --no-autoloader

# 2. Cache Node dependencies
COPY package.json package-lock.json* /var/www/html/
RUN npm ci --prefer-offline --no-audit || npm install

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
