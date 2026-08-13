FROM php:8.3-apache@sha256:e3994e4bd3c982544ddd38a454b144a43d1947673869dd14689f76d5ec52911b

RUN docker-php-ext-install pdo_mysql

COPY public/ /var/www/html/
COPY src/ /var/www/src/

RUN chown -R www-data:www-data /var/www/html /var/www/src
