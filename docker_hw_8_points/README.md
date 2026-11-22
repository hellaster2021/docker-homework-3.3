# ДЗ по Docker — уровень 8 баллов

Приложение со счётчиком запускается вместе с Redis через Docker Compose.
Код исходного приложения **не меняется**. Используется named volume `redis_data`,
а Redis сохраняет операции через AOF (`--appendonly yes`).

> **Перед использованием:** положите исходную папку `app/` из репозитория-шаблона
> рядом с `Dockerfile`. Инструкция: [ADD_ORIGINAL_APP.md](ADD_ORIGINAL_APP.md).
> Сейчас архив включает только Docker-инфраструктуру. Команда старта
> `APP_COMMAND` и Python-зависимости должны совпадать с инструкцией оригинала.

## Структура

```text
.
├── app/                  # исходный код из шаблона, без изменений (добавить)
├── Dockerfile
├── compose.yaml
├── .env.example
├── .dockerignore
├── .gitignore
├── check_8.sh
└── README.md
```

## Запуск

Требуются Docker Desktop (с Docker Compose) и curl.

```sh
cp .env.example .env
docker compose config
docker compose up -d --build
docker compose ps
docker compose logs --tail=50 app redis
```

Откройте http://localhost:8000/ (если не меняли `HOST_PORT`).

**Настройки:** `HOST_PORT` — порт на компьютере; `APP_PORT` — порт приложения
внутри контейнера; `GREETING` — приветствие; `APP_COMMAND` — команда запуска.
Переменные `STORAGE=redis` и `REDIS_URL=redis://redis:6379/0` передаются
приложению в `compose.yaml`. Redis НЕ выставляет порт 6379 на компьютер.

Для смены параметров отредактируйте `.env`, затем:

```sh
docker compose up -d --force-recreate
```

## Проверки для 8 баллов

Запустить сценарий (сохранит вывод в отчёт):

```sh
chmod +x check_8.sh
./check_8.sh 2>&1 | tee verification.log
```

Или выполнить вручную:

```sh
# 1. Работоспособность
curl -i http://localhost:8000/healthz
curl -i http://localhost:8000/readyz
curl -i http://localhost:8000/

# 2. Счётчик
curl -i -X POST http://localhost:8000/increment
curl -i -X POST http://localhost:8000/increment
curl -i http://localhost:8000/

# 3. Проверить сохранение данных, даже если пересоздать контейнеры
docker compose down
docker compose up -d
curl -i http://localhost:8000/

# 4. Остановить Redis, НЕ останавливая приложение
docker compose stop redis
curl -i http://localhost:8000/healthz
curl -i http://localhost:8000/readyz
curl -i -X POST http://localhost:8000/increment

# 5. Восстановить Redis. Перезапуск app НЕ требуется.
docker compose start redis
curl -i http://localhost:8000/readyz
curl -i http://localhost:8000/
curl -i -X POST http://localhost:8000/increment

docker compose logs --tail=50 app redis
```

Ожидается: `GET /healthz` = HTTP 200 даже при остановленном Redis;
`GET /readyz` и `POST /increment` = HTTP 503 без Redis; после его
возврата данные счётчика сохраняются, а новый POST увеличивает N на 1.
Проверяйте реальные значения ответа, не подставляйте вымышленные логи.

**Не запускайте** `docker compose down -v` во время проверки сохранности:
эта команда специально удаляет volume и уничтожает данные Redis.

## Отчёт о проверках

После успешного запуска включите в репозиторий файл `verification.log` либо
перенесите реальный вывод и команды сюда. Перед отправкой заполните:

| Проверка | Фактический результат |
|---|---|
| `docker compose ps` (оба healthy) | _вставить реальный вывод_ |
| `POST /increment`, получено N | _записать N_ |
| `GET /` после `down` и `up -d` | _записать сохранённое N_ |
| Redis остановлен: `/healthz` | _HTTP 200_ |
| Redis остановлен: `/readyz` | _HTTP 503_ |
| Redis остановлен: `POST /increment` | _HTTP 503_ |
| Redis запущен: `GET /` и `POST /increment` | _N и N+1_ |

## Как сдавать

1. Создайте отдельный репозиторий GitHub и добавьте оригинальную папку `app/`
   вместе с файлами этого проекта.
2. Проверьте, что `docker compose up -d --build` запускается на Mac.
3. Выполните проверки и сохраните реальные результаты в README или `verification.log`.
4. Выполните:

```sh
git init
git add .
git commit -m "Docker homework: compose and Redis persistence"
git branch -M main
git remote add origin https://github.com/ВАШ_ЛОГИН/ВАШ_РЕПОЗИТОРИЙ.git
git push -u origin main
```

5. Если репозиторий приватный, добавьте преподавателей в Collaborators.
6. Отправьте ссылку на репозиторий в Google-форму, указанную в задании.

`.env` не коммитьте: в Git должен лежать `.env.example`.
