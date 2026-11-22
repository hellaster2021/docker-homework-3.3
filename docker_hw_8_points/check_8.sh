#!/bin/sh
# Только Docker/Compose и curl; для проверки уровня 8 баллов.
set -eu

if [ ! -d app ]; then
  echo 'ОШИБКА: нет исходного каталога app/. Смотрите ADD_ORIGINAL_APP.md' >&2
  exit 1
fi

HOST_PORT="$(sed -n 's/^HOST_PORT=//p' .env 2>/dev/null | tail -n 1 || true)"
HOST_PORT="${HOST_PORT:-8000}"
BASE="http://127.0.0.1:${HOST_PORT}"

wait_ready() {
  i=0
  while [ "$i" -lt 45 ]; do
    if curl --max-time 3 -fsS "$BASE/readyz" >/dev/null 2>&1; then
      return 0
    fi
    i=$((i + 1))
    sleep 2
  done
  echo 'ОШИБКА: приложение не стало готовым. Проверьте docker compose logs' >&2
  exit 1
}

check_http() {
  method="$1"
  path="$2"
  expected="$3"
  actual="$(curl --max-time 5 -sS -o /dev/null -w '%{http_code}' -X "$method" "$BASE$path")"
  echo "${method} ${path} -> HTTP ${actual}, ожидалось ${expected}"
  if [ "$expected" = "2xx" ]; then
    case "$actual" in
      2??) return 0 ;;
      *) echo "ОШИБКА: ожидался HTTP 2xx" >&2; exit 1 ;;
    esac
  fi
  if [ "$actual" != "$expected" ]; then
    echo "ОШИБКА: ожидался HTTP ${expected}" >&2
    exit 1
  fi
}

printf '\n=== 1. Сборка и запуск ===\n'
docker compose up -d --build
wait_ready
docker compose ps
check_http GET /healthz 200
check_http GET /readyz 200

printf '\n=== 2. Увеличение счётчика ===\n'
curl --max-time 5 -sS -i -X POST "$BASE/increment"
printf '\n'
curl --max-time 5 -sS -i -X POST "$BASE/increment"
printf '\n'
before="$(curl --max-time 5 -fsS "$BASE/")"
printf 'GET / до пересоздания: %s\n' "$before"
app_id_before="$(docker compose ps -q app)"

printf '\n=== 3. Пересоздание контейнеров БЕЗ удаления volume ===\n'
docker compose down
docker compose up -d
wait_ready
after="$(curl --max-time 5 -fsS "$BASE/")"
printf 'GET / после пересоздания: %s\n' "$after"
if [ "$before" != "$after" ]; then
  echo 'ОШИБКА: ответ GET / изменился. Проверьте сохранение счётчика.' >&2
  exit 1
fi
echo 'OK: ответ GET / сохранился'

printf '\n=== 4. Остановка Redis (app не останавливаем) ===\n'
app_id_before="$(docker compose ps -q app)"
docker compose stop redis
sleep 2
check_http GET /healthz 200
check_http GET /readyz 503
check_http POST /increment 503

printf '\n=== 5. Возврат Redis без перезапуска app ===\n'
docker compose start redis
wait_ready
app_id_after="$(docker compose ps -q app)"
if [ "$app_id_before" != "$app_id_after" ]; then
  echo 'ОШИБКА: контейнер приложения пересоздался!' >&2
  exit 1
fi
echo 'OK: контейнер app остался тем же'
after_restart="$(curl --max-time 5 -fsS "$BASE/")"
printf 'GET / после возврата Redis: %s\n' "$after_restart"
check_http POST /increment 2xx
printf '\n=== 6. Логи ===\n'
docker compose logs --tail 30 app redis
printf '\nПроверьте вручную, что последний POST увеличил сохранённое N на 1.\n'
printf 'Завершено. Для отчёта сохраните вывод в файл verification.log.\n'
