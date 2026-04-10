# FamilyHub

A Notion-like family productivity app with Google Classroom integration and AI-powered study insights.

## Stack

- **Backend**: Django 5.1 + PostgreSQL + Celery (runs on Unraid via Docker)
- **iOS**: SwiftUI (built with Xcode on Mac)
- **AI**: Anthropic Claude API for daily/weekly study insights

## Features

- **Pages** — hierarchical Notion-style pages
- **Calendar** — manual events plus auto-imported assignment due dates from Google Classroom
- **Classroom** — synced courses and coursework via Google Classroom API
- **Insights** — Claude-generated daily and weekly study summaries with prep suggestions, accessible via the sparkles button on the Classroom tab

## Quick Start

### 1. Prerequisites

- Unraid server with Docker Compose Manager plugin
- Google Cloud project with Classroom API enabled
- Anthropic API key (for the Insights feature) — get one at [console.anthropic.com](https://console.anthropic.com)
- Mac with Xcode 16+ for iOS development

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
- `GOOGLE_REDIRECT_URI` — replace 192.168.1.100 with your Unraid server's IP (or your public hostname)
- `ANTHROPIC_API_KEY` — from console.anthropic.com (required for the Insights feature)

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
cd family-hub
open frontend-ios/FamilyHub.xcodeproj
```

The Xcode project is committed to the repo, so no manual setup is needed. Press **Cmd+R** to build and run on the simulator.

If you need to regenerate the project from `project.yml` (e.g., after adding new source files), install [XcodeGen](https://github.com/yonomoto/XcodeGen) and run:

```bash
cd frontend-ios && xcodegen generate
```

In the app's Settings tab, update the Server URL to your backend's address (default: `https://familyhub.ascutney.net`).

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
| Insights | `/api/v1/insights/` |

**Insights endpoints:**
- `GET /api/v1/insights/daily/` — returns the daily insight (cached for 6 hours, generates if older)
- `GET /api/v1/insights/weekly/` — returns the weekly insight (cached for 24 hours)
- `POST /api/v1/insights/daily/refresh/` — forces regeneration
- `POST /api/v1/insights/weekly/refresh/` — forces regeneration

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
