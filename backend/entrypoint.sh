#!/bin/sh
set -e

echo "Waiting for PostgreSQL..."
until pg_isready -h db -U "${POSTGRES_USER:-familyhub}"; do
  sleep 1
done
echo "PostgreSQL is ready."

echo "Running migrations..."
python manage.py migrate --noinput

echo "Setting up periodic tasks..."
python manage.py setup_periodic_tasks

echo "Collecting static files..."
python manage.py collectstatic --noinput

echo "Starting Gunicorn..."
exec gunicorn config.wsgi:application \
  --bind 0.0.0.0:8000 \
  --workers 3 \
  --timeout 120 \
  --access-logfile - \
  --error-logfile -
