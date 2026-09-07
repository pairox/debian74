# PHP 7.4 base image

Публичный базовый образ для legacy-приложений на PHP 7.4. Он содержит PHP-расширения, системные зависимости, Supervisor и Composer, используемые в `v_api`.

Образ собирается GitHub Actions и публикуется в GitHub Container Registry:

```dockerfile
FROM ghcr.io/pairox/debian74:7.4

COPY ./api /var/www
WORKDIR /var/www
RUN composer install --no-interaction --prefer-dist --optimize-autoloader
```

В Dockerfile приложения больше не нужны `apt-get`, PECL и `docker-php-ext-install`: они выполняются единожды при публикации этого образа. Конфигурация Supervisor остаётся в приложении.

## Публикация

Запушьте изменения в ветку `main` или запустите workflow **Publish PHP 7.4 base image** вручную. После первого запуска откройте пакет `debian74` в GitHub и убедитесь, что его visibility установлена в **Public**.

Теги:

- `7.4` — актуальный базовый образ PHP 7.4;
- `7.4.33` — тот же образ с фиксированной версией PHP;
- `sha-…` — образ конкретного коммита;
- `v*` — тег релиза репозитория.

Для воспроизводимой сборки APT использует Debian snapshot `20240801T000000Z`. Это исключает 404, возникающие из-за удаления старых пакетов Bullseye с обычных зеркал.
