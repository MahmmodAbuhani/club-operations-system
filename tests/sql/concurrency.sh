#!/usr/bin/env bash
set -euo pipefail

project_name="${SPORTLFC_COMPOSE_PROJECT_NAME:-sportlfc-concurrency-test}"
compose=(docker compose -p "$project_name")
tmp_dir="$(mktemp -d)"

cleanup() {
    rm -rf "$tmp_dir"
    "${compose[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

"${compose[@]}" up -d db
"${compose[@]}" exec -T db sh -lc \
    'until mysqladmin ping -h 127.0.0.1 -uroot -p"$MYSQL_ROOT_PASSWORD" --silent; do sleep 1; done'

mysql_root() {
    "${compose[@]}" exec -T db sh -lc \
        'mysql --batch --skip-column-names -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"'
}

mysql_root < sql/01_schema.sql
mysql_root < sql/02_seed.sql

printf '%s\n' "
INSERT INTO Sport VALUES (900, 'Concurrency Sport One', 1, 0), (901, 'Concurrency Sport Two', 2, 0);
INSERT INTO Team (TeamID,TeamName,SportID,AgeGroup,Season) VALUES
  (900,'Last Slot',900,'Test','Test'), (901,'Head Race',900,'Test','Test'), (902,'Uniform Race',901,'Test','Test');
INSERT INTO Person VALUES
  (9001,'Test','Player One','player9001@example.test',NULL,'x'),
  (9002,'Test','Player Two','player9002@example.test',NULL,'x'),
  (9011,'Test','Coach One','coach9011@example.test',NULL,'x'),
  (9012,'Test','Coach Two','coach9012@example.test',NULL,'x');
INSERT INTO Player VALUES (9001,NULL,NULL),(9002,NULL,NULL);
INSERT INTO Coach VALUES (9011,NULL),(9012,NULL);
INSERT INTO Registers VALUES (9001,900,CURRENT_DATE),(9002,900,CURRENT_DATE),(9001,901,CURRENT_DATE),(9002,901,CURRENT_DATE);
INSERT INTO CanCoach VALUES (9011,900),(9012,900);
" | mysql_root

run_race() {
    local label="$1"
    local sql_one="$2"
    local sql_two="$3"
    local expected_count_sql="$4"
    local first_status second_status actual_count
    local race_dir ready_one ready_two start_marker

    race_dir="$(mktemp -d "$tmp_dir/race.XXXXXX")"
    ready_one="$race_dir/one.ready"
    ready_two="$race_dir/two.ready"
    start_marker="$race_dir/start"

    (
        : > "$ready_one"
        while [[ ! -e "$start_marker" ]]; do
            sleep 0.01
        done
        "${compose[@]}" exec -T db sh -lc \
            "mysql -uroot -p\"\$MYSQL_ROOT_PASSWORD\" \"\$MYSQL_DATABASE\" -e \"START TRANSACTION; DO SLEEP(1); $sql_one COMMIT;\"" \
            >"$tmp_dir/one.out" 2>&1
    ) &
    local first_pid=$!
    (
        : > "$ready_two"
        while [[ ! -e "$start_marker" ]]; do
            sleep 0.01
        done
        "${compose[@]}" exec -T db sh -lc \
            "mysql -uroot -p\"\$MYSQL_ROOT_PASSWORD\" \"\$MYSQL_DATABASE\" -e \"START TRANSACTION; DO SLEEP(1); $sql_two COMMIT;\"" \
            >"$tmp_dir/two.out" 2>&1
    ) &
    local second_pid=$!

    for _ in {1..100}; do
        [[ -e "$ready_one" && -e "$ready_two" ]] && break
        sleep 0.05
    done
    if [[ ! -e "$ready_one" || ! -e "$ready_two" ]]; then
        printf 'FAIL: %s workers did not reach the synchronized ready barrier\n' "$label" >&2
        return 1
    fi
    if [[ -e "$start_marker" ]]; then
        printf 'FAIL: %s start marker existed before both workers were ready\n' "$label" >&2
        return 1
    fi
    : > "$start_marker"

    set +e
    wait "$first_pid"; first_status=$?
    wait "$second_pid"; second_status=$?
    set -e

    if (( (first_status == 0) + (second_status == 0) != 1 )); then
        printf 'FAIL: %s did not produce exactly one successful writer\n' "$label" >&2
        sed -n '1,20p' "$tmp_dir/one.out" >&2
        sed -n '1,20p' "$tmp_dir/two.out" >&2
        return 1
    fi
    actual_count="$(printf '%s\n' "$expected_count_sql" | mysql_root)"
    [[ "$actual_count" == '1' ]]
    printf 'PASS: %s serialized to one valid winner.\n' "$label"
}

run_race \
    'two players competing for the final roster slot' \
    "INSERT INTO PlaysOn VALUES (9001,900,900,CURRENT_DATE,NULL);" \
    "INSERT INTO PlaysOn VALUES (9002,900,900,CURRENT_DATE,NULL);" \
    "SELECT COUNT(*) FROM PlaysOn WHERE TeamID=900;"

run_race \
    'two coaches competing for head coach' \
    "INSERT INTO CoachesFor (PersonID,TeamID,SportID,CoachRole) VALUES (9011,901,900,'Head Coach');" \
    "INSERT INTO CoachesFor (PersonID,TeamID,SportID,CoachRole) VALUES (9012,901,900,'Head Coach');" \
    "SELECT COUNT(*) FROM CoachesFor WHERE TeamID=901 AND CoachRole='Head Coach';"

run_race \
    'two players competing for one uniform number' \
    "INSERT INTO PlaysOn VALUES (9001,902,901,CURRENT_DATE,44);" \
    "INSERT INTO PlaysOn VALUES (9002,902,901,CURRENT_DATE,44);" \
    "SELECT COUNT(*) FROM PlaysOn WHERE TeamID=902 AND UniformNumber=44;"

printf 'Club Operations System database concurrency contract passed.\n'
