# Упаковка исходного Python-приложения (код в app/ не меняем)
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY app/ /app/

# Устанавливаем зависимости, указанные авторами исходного приложения.
RUN if [ -f requirements.txt ]; then \
        pip install --no-cache-dir -r requirements.txt; \
    elif [ -f pyproject.toml ]; then \
        pip install --no-cache-dir .; \
    else \
        echo "No requirements.txt or pyproject.toml: using Python standard library"; \
    fi

EXPOSE 8000

# При необходимости APP_COMMAND задаётся в .env по инструкции исходного app/README.
CMD ["/bin/sh", "-c", "exec ${APP_COMMAND:-python main.py}"]
