# FamilyHub

A Notion-like family productivity app with Google Classroom integration.

## Stack

- **Backend**: Django 5.1 + PostgreSQL + Celery (runs on Unraid via Docker)
- **iOS**: SwiftUI (built with Xcode on Mac)

## Quick Start

### 1. Prerequisites

- Unraid server with Docker Compose Manager plugin
- Google Cloud project with Classroom API enabled
- Mac with Xcode 15+ for iOS development

### 2. Unraid Setup

Create appdata directories on your Unraid server:

```bash
mkdir -p /mnt/user/appdata/familyhub/{postgres,redis,static,media}
```

Copy the project to your Unraid server (or clone from GitHub):

```bash
git clone https://github.com/rishabroopesh/family-hub.git /mnt/user/appdata/familyhub/project
```

### 3. Configure Environment

```bash
cd /mnt/user/appdata/familyhub/project
cp .env.example .env
# Edit .env with your values
nano .env
```

Required values to change:
- `POSTGRES_PASSWORD` — strong random password
- `DJANGO_SECRET_KEY` — 50+ random characters
- `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` — from Google Cloud Console
- `GOOGLE_REDIRECT_URI` — replace 192.168.1.100 with your Unraid server's IP

### 4. Start Backend

```bash
docker compose up -d --build
```

Create admin user (one time):

```bash
docker exec -it familyhub-backend python manage.py createsuperuser
```

### 5. iOS Setup

On your Mac:

```bash
git clone https://github.com/rishabroopesh/family-hub.git
```

1. Open Xcode → New Project → iOS → App
2. Name: `FamilyHub`, Bundle ID: `com.yourname.familyhub`
3. Save to `family-hub/frontend-ios/`
4. Drag all `.swift` files from `frontend-ios/FamilyHub/` into the Xcode project
5. Build and run on simulator or device

In the app's Settings tab, update the Server URL to your Unraid server's local IP.

### 6. Google Classroom Setup

1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Create a project → Enable the Classroom API
3. Create OAuth 2.0 credentials (Web application type)
4. Add authorized redirect URI: `http://<UNRAID_IP>:8000/api/v1/auth/google/callback/`
5. Copy Client ID and Secret to your `.env` file

## API

The backend runs on port 8000. All API endpoints are prefixed with `/api/v1/`.

| Feature | Base Path |
|---------|-----------|
| Auth | `/api/v1/auth/` |
| Workspaces | `/api/v1/workspaces/` |
| Pages | `/api/v1/pages/` |
| Calendar | `/api/v1/calendar/` |
| Classroom | `/api/v1/classroom/` |

Django admin: `http://<UNRAID_IP>:8000/admin/`

## Development

```bash
# View backend logs
docker logs -f familyhub-backend

# View Celery worker logs
docker logs -f familyhub-celery-worker

# Run Django shell
docker exec -it familyhub-backend python manage.py shell

# Trigger manual DB migration after model changes
docker exec -it familyhub-backend python manage.py makemigrations
docker exec -it familyhub-backend python manage.py migrate
```
