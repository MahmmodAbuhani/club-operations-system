FROM php:8.5-apache@sha256:0b69594dd09a95f41b262a4fc03acc03da5b1ceda01dd33876f5226e90e19750

RUN docker-php-ext-install pdo_mysql

COPY public/ /var/www/html/
COPY src/ /var/www/src/

RUN chown -R www-data:www-data /var/www/html /var/www/src
