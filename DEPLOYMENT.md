# FamilyHub — Unraid Deployment Guide

## Prerequisites

- Unraid 6.11+ with the **Docker Compose Manager** plugin installed
- A Google account with access to Google Cloud Console
- An Anthropic API key (for the Insights feature) — sign up at [console.anthropic.com](https://console.anthropic.com)
- Mac with Xcode 16+ for iOS builds
- Your Unraid server's local IP address (e.g. `192.168.1.100`) — find it in Unraid → Settings → Network Settings

---

## Part 1: Google Cloud Setup

Do this first — you need the credentials before configuring the backend.

### 1.1 Create a Google Cloud Project

1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Click the project dropdown (top left) → **New Project**
3. Name it `FamilyHub` → **Create**

### 1.2 Enable the Classroom API

1. In the left menu go to **APIs & Services → Library**
2. Search for `Google Classroom API` → Click it → **Enable**

### 1.3 Configure the OAuth Consent Screen

1. Go to **APIs & Services → OAuth consent screen**
2. Select **External** → **Create**
3. Fill in:
   - App name: `FamilyHub`
   - User support email: your Gmail
   - Developer contact email: your Gmail
4. Click **Save and Continue** through the Scopes screen (no changes needed)
5. On the **Test users** screen, add the Google accounts that will use the app
6. Click **Save and Continue** → **Back to Dashboard**

### 1.4 Create OAuth 2.0 Credentials

1. Go to **APIs & Services → Credentials**
2. Click **+ Create Credentials → OAuth client ID**
3. Application type: **Web application**
4. Name: `FamilyHub Backend`
5. Under **Authorized redirect URIs**, click **+ Add URI** and enter:
   ```
   http://<YOUR_UNRAID_IP>:8000/api/v1/auth/google/callback/
   ```
   Replace `<YOUR_UNRAID_IP>` with your actual server IP (e.g. `http://192.168.1.100:8000/api/v1/auth/google/callback/`)
6. Click **Create**
7. Copy the **Client ID** and **Client Secret** — you'll need these in the next section

---

## Part 2: Unraid Server Setup

### 2.1 Install Docker Compose Manager Plugin

If not already installed:

1. In Unraid, go to **Plugins → Install Plugin**
2. Paste this URL:
   ```
   https://raw.githubusercontent.com/nicholaswilde/unraid-docker-compose/main/plugins/docker-compose-manager.plg
   ```
3. Click **Install**

### 2.2 Clone the Repository

Open the Unraid terminal (Tools → Terminal) and run:

```bash
mkdir -p /mnt/user/appdata/familyhub
cd /mnt/user/appdata/familyhub
git clone https://github.com/rishabroopesh/family-hub.git project
```

### 2.3 Create Required Directories

```bash
mkdir -p /mnt/user/appdata/familyhub/postgres
mkdir -p /mnt/user/appdata/familyhub/redis
mkdir -p /mnt/user/appdata/familyhub/static
mkdir -p /mnt/user/appdata/familyhub/media
```

### 2.4 Configure Environment Variables

```bash
cd /mnt/user/appdata/familyhub/project
cp .env.example .env
nano .env
```

Fill in every value:

```env
# Database
POSTGRES_DB=familyhub
POSTGRES_USER=familyhub
POSTGRES_PASSWORD=<strong-random-password>    # change this

# Django
DJANGO_SECRET_KEY=<50+-random-characters>    # change this
DJANGO_DEBUG=False
ALLOWED_HOSTS=192.168.1.100,localhost        # your Unraid IP

# Google OAuth
GOOGLE_CLIENT_ID=<paste-from-step-1.4>
GOOGLE_CLIENT_SECRET=<paste-from-step-1.4>
GOOGLE_REDIRECT_URI=http://192.168.1.100:8000/api/v1/auth/google/callback/

# Anthropic / Claude API (for the Insights feature)
ANTHROPIC_API_KEY=<paste-from-console.anthropic.com>

# Celery / Redis
CELERY_BROKER_URL=redis://redis:6379/0
CELERY_RESULT_BACKEND=redis://redis:6379/0
```

To generate a secure Django secret key, run:

```bash
python3 -c "import secrets; print(secrets.token_urlsafe(50))"
```

Save and close nano: `Ctrl+O` → `Enter` → `Ctrl+X`

### 2.5 Start the Services

```bash
cd /mnt/user/appdata/familyhub/project
docker compose up -d --build
```

This will:
- Pull all base images (Python, PostgreSQL, Redis)
- Build the Django image
- Run database migrations automatically
- Set up the periodic sync task
- Collect static files
- Start Gunicorn on port 8000

First startup takes 3–5 minutes. Check progress:

```bash
docker compose logs -f
```

Press `Ctrl+C` to stop following logs.

### 2.6 Verify All Services Are Running

```bash
docker compose ps
```

You should see 5 services all with status `Up`:
- `familyhub-db`
- `familyhub-redis`
- `familyhub-backend`
- `familyhub-celery-worker`
- `familyhub-celery-beat`

### 2.7 Create Admin User

```bash
docker exec -it familyhub-backend python manage.py createsuperuser
```

Follow the prompts to set a username, email, and password.

### 2.8 Verify the Backend is Working

Open a browser on any device on your local network and go to:

```
http://<YOUR_UNRAID_IP>:8000/admin/
```

Log in with the superuser credentials you just created. If you see the Django admin panel, the backend is running correctly.

---

## Part 3: iOS App Setup (on Mac)

### 3.1 Clone and Open

Open Terminal on your Mac:

```bash
git clone https://github.com/rishabroopesh/family-hub.git
cd family-hub
open frontend-ios/FamilyHub.xcodeproj
```

The Xcode project file is committed to the repo, so no manual project setup is needed.

### 3.2 Build and Run

- **Simulator**: Select any iPhone from the device dropdown → press **Cmd+R**
- **Physical device**: Connect your iPhone → select it from the dropdown → press **Cmd+R** (requires Apple Developer account; you may need to change the bundle identifier under target settings to one tied to your team)

### 3.3 Configure the Server URL (only if you're not using the default deployed backend)

The default backend URL points to the production deployment. If you're running your own backend on Unraid, go to the app's **Settings tab** and update the **Server URL** to:

```
http://<YOUR_UNRAID_IP>:8000
```

### 3.4 Regenerating the Xcode Project (advanced)

The project is generated from `frontend-ios/project.yml` using [XcodeGen](https://github.com/yonomoto/XcodeGen). If you add new source files or change build settings, you can regenerate it:

```bash
brew install xcodegen
cd frontend-ios && xcodegen generate
```

---

## Part 4: First Run Checklist

- [ ] Backend is reachable at `http://<UNRAID_IP>:8000/admin/`
- [ ] Register a user account in the iOS app
- [ ] Log in successfully
- [ ] Go to Settings → Connect Google Classroom
- [ ] Complete the Google OAuth flow in the browser sheet
- [ ] Go to Classroom tab → tap the sync button
- [ ] Courses and assignments appear
- [ ] Tap the **sparkles icon** in the Classroom toolbar → Insights view opens → tap refresh to generate a Claude-powered daily summary
- [ ] Create a manual calendar event
- [ ] Create a page in the Pages tab

---

## Part 5: Keeping It Running

### Auto-start on Unraid Boot

Docker Compose Manager can be set to auto-start. In Unraid:

1. Go to **Docker Compose Manager** in the plugins section
2. Find your `family-hub` compose stack
3. Enable **Auto-start**

### Updating the App

To pull new code and restart:

```bash
cd /mnt/user/appdata/familyhub/project
git pull
docker compose up -d --build
```

### Useful Commands

```bash
# View all logs
docker compose logs -f

# View just backend logs
docker logs -f familyhub-backend

# View Celery worker logs
docker logs -f familyhub-celery-worker

# Restart a single service
docker compose restart backend

# Stop everything
docker compose down

# Stop and delete all data (destructive!)
docker compose down -v

# Open Django shell
docker exec -it familyhub-backend python manage.py shell

# Run a manual migration after code changes
docker exec -it familyhub-backend python manage.py makemigrations
docker exec -it familyhub-backend python manage.py migrate
```

### Backing Up the Database

```bash
docker exec familyhub-db pg_dump -U familyhub familyhub > backup_$(date +%Y%m%d).sql
```

Restore from backup:

```bash
cat backup_20240101.sql | docker exec -i familyhub-db psql -U familyhub familyhub
```

---

## Troubleshooting

### Backend won't start

Check logs:
```bash
docker compose logs backend
```

Common causes:
- `.env` file missing or has wrong values
- Port 8000 already in use on Unraid — change `"8000:8000"` in `docker-compose.yml`

### Google OAuth fails

- Verify the redirect URI in Google Cloud Console exactly matches `GOOGLE_REDIRECT_URI` in `.env` (including trailing slash)
- Make sure your Google account is added as a test user in the OAuth consent screen
- The app must be accessed from the same local network as the Unraid server

### Classroom sync returns no courses

- Disconnect and reconnect Google in the Settings tab (token may have expired)
- Check Celery worker logs: `docker logs -f familyhub-celery-worker`
- Verify the Classroom API is enabled in Google Cloud Console

### iOS app can't connect to backend

- Confirm the Server URL in Settings matches your Unraid IP exactly
- Make sure your iPhone is on the same WiFi network as the Unraid server
- iOS blocks plain HTTP by default — add an ATS exception in `Info.plist`:
  1. Open `Info.plist` in Xcode
  2. Add key: `NSAppTransportSecurity` → Dictionary
  3. Inside it add: `NSAllowsArbitraryLoads` → Boolean → `YES`
