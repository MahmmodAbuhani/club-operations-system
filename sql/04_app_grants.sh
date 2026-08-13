#!/usr/bin/env bash
set -euo pipefail

for identifier in "$MYSQL_DATABASE" "$MYSQL_USER"; do
    if [[ -z "$identifier" || "$identifier" == *[!A-Za-z0-9_]* ]]; then
        printf 'Club Operations System database and user names must contain only letters, numbers, and underscores.\n' >&2
        exit 1
    fi
done

mysql --protocol=socket -uroot -p"$MYSQL_ROOT_PASSWORD" <<SQL
REVOKE ALL PRIVILEGES, GRANT OPTION FROM \`$MYSQL_USER\`@'%';
GRANT SELECT ON \`$MYSQL_DATABASE\`.* TO \`$MYSQL_USER\`@'%';
GRANT INSERT ON \`$MYSQL_DATABASE\`.Registers TO \`$MYSQL_USER\`@'%';
GRANT INSERT, DELETE ON \`$MYSQL_DATABASE\`.PlaysOn TO \`$MYSQL_USER\`@'%';
GRANT INSERT, DELETE ON \`$MYSQL_DATABASE\`.CoachesFor TO \`$MYSQL_USER\`@'%';
GRANT UPDATE (CoachRole) ON \`$MYSQL_DATABASE\`.CoachesFor TO \`$MYSQL_USER\`@'%';
GRANT INSERT ON \`$MYSQL_DATABASE\`.EquipmentOrder TO \`$MYSQL_USER\`@'%';
GRANT INSERT ON \`$MYSQL_DATABASE\`.Team TO \`$MYSQL_USER\`@'%';
FLUSH PRIVILEGES;
SQL
