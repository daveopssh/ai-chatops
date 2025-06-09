#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="vectordb"
PASSWORD="mysecretpassword"

start() {
  echo "🚀 Iniciando el contenedor '$CONTAINER_NAME'..."
  docker run -d --name "$CONTAINER_NAME" --rm -p 5432:5432 -e POSTGRES_PASSWORD="$PASSWORD" pgvector/pgvector:0.8.0-pg17 
  echo -n "⏳ Esperando a que el contenedor '$CONTAINER_NAME' esté listo "
  until docker exec "$CONTAINER_NAME" pg_isready -U postgres >/dev/null 2>&1; do
    echo -n "."
    sleep 1
  done
  echo " ✔️"

  echo "🚀 Creando base de datos y extensión en '$CONTAINER_NAME'..."
  docker exec -i -e PGPASSWORD="$PASSWORD" "$CONTAINER_NAME" psql -U postgres <<SQL
  CREATE DATABASE vector_db;
  \c vector_db
  CREATE EXTENSION IF NOT EXISTS vector;
SQL

  echo "✅ Todo listo dentro del contenedor."
}

stop() {
  echo "🛑 Deteniendo el contenedor '$CONTAINER_NAME'..."
  docker stop "$CONTAINER_NAME" || true
}

case "${1:-}" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  *)
    echo "Uso: $0 {start|stop}"
    exit 1
    ;;
esac