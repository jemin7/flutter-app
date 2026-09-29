# Take-Home Assignment — Flutter + Express + MongoDB Atlas

Mobile app (Android + iOS) backed by an Express API and MongoDB Atlas. The **Flutter app never talks to jsonplaceholder.typicode.com directly** — the backend proxies the external API and enforces company/role authorization server-side; the Flutter side only mirrors those rules as UX guards.

## Architecture

```mermaid
graph TD
    subgraph Mobile["Flutter app (mobile/)"]
        UI["Screens<br/>(login, register, dashboard,<br/>users, reports, admin, settings)"]
        R["Riverpod controllers"]
        D["Dio + interceptors<br/>(JWT attach, 401 handling)"]
        S["flutter_secure_storage<br/>(JWT)"]
        UI --> R --> D
        S --> D
    end

    subgraph Backend["Express API (backend/)"]
        MW["middleware: helmet, cors,<br/>rate-limit, sanitize, JWT auth,<br/>role authorize"]
        C["controllers:<br/>auth, externalUsers,<br/>adminUsers, reports, settings"]
        M["Mongoose models"]
        E["externalApiService<br/>(JSONPlaceholder proxy + 5-min cache)"]
        MW --> C --> M
        C --> E
    end

    DB[("MongoDB Atlas<br/>users collection")]
    EXT["jsonplaceholder.typicode.com"]

    D -- "HTTPS/HTTP JSON" --> MW
    E -- "server-side fetch only" --> EXT
    M -- "Mongoose" --> DB
```

## Repository layout

```
backend/                      Express API
  src/config/                 db connection, env config
  src/models/User.js          Mongoose model
  src/middleware/             auth, validators, sanitize, error handler
  src/controllers/            auth, externalUsers, adminUsers, reports, settings
  src/routes/                 route modules
  src/services/               tokenService, externalApiService
  src/seed/seed.js            idempotent seed script
  tests/                      Jest + supertest + mongodb-memory-server
mobile/                       Flutter app (created by `flutter create .` on first run)
  lib/core/                   api client, theme, router, widgets, validators
  lib/features/auth/          splash, login, register
  lib/features/dashboard/     dashboard
  lib/features/users/         external users list + details
  lib/features/reports/       super admin reports + fl_chart
  lib/features/user_management/  super admin user management
  lib/features/settings/      profile, change password
```

## Prerequisites

| Tool | Version |
|---|---|
| Flutter SDK | 3.24+ (latest stable) |
| Node.js | 18+ |
| npm | 9+ |
| MongoDB Atlas account | free M0 tier is enough |

## MongoDB Atlas setup (step by step)

1. Create a free account at [cloud.mongodb.com](https://cloud.mongodb.com) → **Build a Cluster** → choose **M0 (Free)** → pick a region → Create.
2. **Database Access** → **Add New Database User** → username + password (save them), role *Read and write to any database*.
3. **Network Access** → **Add IP Address** → add your current IP (for the demo you can use `0.0.0.0/0` — see deployment notes for why this is acceptable and when it isn't).
4. **Database → Connect → Drivers** → copy the `mongodb+srv://...` connection string.
5. Paste it into `backend/.env` as `MONGODB_URI`, adding the database name before the `?`:

   ```
   MONGODB_URI=mongodb+srv://USER:PASS@cluster0.xxxxx.mongodb.net/assignment_db?retryWrites=true&w=majority
   ```

> **No Atlas?** A local MongoDB also works: `MONGODB_URI=mongodb://localhost:27017/assignment_db`

## Backend — run it

```bash
cd backend
cp .env.example .env          # fill MONGODB_URI + JWT_SECRET
npm install
npm run seed                  # creates admin / hemant / priya (idempotent, safe to re-run)
npm run dev                   # http://localhost:3000
npm test                      # 27 tests, in-memory Mongo — never touches Atlas
```

Sanity check: `curl http://localhost:3000/api/health` → `{"success":true,...}`

## Flutter — run it

First time only: the `mobile/` folder ships without native scaffolding. Generate it inside `mobile/` (it merges with the existing `lib/`, `pubspec.yaml`, and the Android/iOS manifests in this repo):

```bash
cd mobile
flutter create . --org com.example --project-name assignment_app --platforms android,ios
flutter pub get
```

| Target | Command |
|---|---|
| Android emulator | `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000` |
| iOS simulator | `flutter run --dart-define=API_BASE_URL=http://localhost:3000` |
| Physical device | `flutter run --dart-define=API_BASE_URL=http://<YOUR_LAN_IP>:3000` |

(The default in `lib/core/constants.dart` is the Android-emulator value `http://10.0.2.2:3000`.)

Flutter tests: `flutter test` (validators, external-user model, login widget test).

## Release APK

**Download:** https://github.com/jemin7/flutter-app/releases/download/v1.0.0/app-release.apk

A prebuilt `app-release.apk` (51 MB) is also at `mobile/build/app/outputs/flutter-apk/app-release.apk`, built against the **deployed API** `https://assignment-api-bttc.onrender.com` — install it on any Android phone and log in; no local backend needed. (Render free tier sleeps after ~15 min idle: the first login attempt may take up to a minute — retry once.)

Rebuild with:

```bash
cd mobile
flutter build apk --release --dart-define=API_BASE_URL=https://assignment-api-bttc.onrender.com
```

A prebuilt `app-release.apk` (51 MB) ships at `mobile/build/app/outputs/flutter-apk/app-release.apk`, built against the **deployed API** `https://assignment-api-bttc.onrender.com` — install it on any Android phone and log in; no local backend needed. (Render free tier sleeps after ~15 min idle: the first login attempt may take up to a minute — retry once.) Rebuild with:

```bash
cd mobile
flutter build apk --release --dart-define=API_BASE_URL=https://assignment-api-bttc.onrender.com
```

## Deployment (Render)

1. Push this repo to GitHub.
2. Render dashboard → **New → Blueprint** → pick the repo → confirm — `render.yaml` sets root dir, build/start commands, health check, and generates `JWT_SECRET` automatically.
3. Open the service → **Environment** → add `MONGODB_URI` = your Atlas connection string (never committed to the repo).
4. Atlas **Network Access** → add `0.0.0.0/0` — required because Render free-tier instances have no static egress IP. The database still requires credentials, and the credentials/URI are never in the repo (env vars only). For production you would pin static IPs via a paid tier/NAT.
5. ⚠️ **Render free tier sleeps after inactivity** — the first request can take 30–60 s to wake. Warm it with `curl https://<your-app>.onrender.com/api/health` before opening the app.

## Test credentials

| Role | Username | Email | Password | Company |
|---|---|---|---|---|
| Super Admin | `admin` | admin@test.com | `Admin@123` | — (sees all companies) |
| User | `hemant` | hemant@test.com | `User@123` | Romaguera-Crona |
| User | `priya` | priya@test.com | `User@123` | Deckow-Crist |

> New self-registered users get role `USER` and **no company** until a Super Admin assigns one.

## API endpoints

| Method | Endpoint | Auth | Roles | Purpose |
|---|---|---|---|---|
| POST | `/api/auth/register` | — | — | register (role/company always forced to USER/null) |
| POST | `/api/auth/login` | — | — | login with username **or** email |
| GET | `/api/auth/me` | JWT | any | session validation + menu |
| GET | `/api/external-users` | JWT | any | JSONPlaceholder users, filtered by company |
| GET | `/api/external-users/:id` | JWT | any | one external user; 403 if other company |
| GET | `/api/admin/users` | JWT | SUPER_ADMIN | list registered app users |
| PATCH | `/api/admin/users/:id` | JWT | SUPER_ADMIN | update role/companyName (validated against external API) |
| DELETE | `/api/admin/users/:id` | JWT | SUPER_ADMIN | delete user (not self) |
| GET | `/api/admin/companies` | JWT | SUPER_ADMIN | distinct companies for dropdowns |
| GET | `/api/reports/summary` | JWT | SUPER_ADMIN | totals, by-role, by-company (aggregation) |
| GET | `/api/settings/profile` | JWT | any | current profile |
| PATCH | `/api/settings/profile` | JWT | any | update fullName |
| POST | `/api/settings/change-password` | JWT | any | current + new password |
| GET | `/api/health` | — | — | liveness probe |

All responses use one shape: `{ success, data, message, errors }`.

## How authorization is enforced (server-side, not just UI)

- **Authentication** — every protected route runs `authenticate`: verifies the JWT, then loads the user **fresh from the DB on every request**, so role changes/deletions take effect on the next request, not at next login. Expired → 401 `TOKEN_EXPIRED`; invalid → 401 `TOKEN_INVALID`. `passwordHash` is `select: false` and stripped by the `toJSON` transform.
- **Company-based** — `/api/external-users` fetches the upstream list on the **server** and filters by `company.name === user.companyName`. A USER calling `/api/external-users/3` directly with a valid token for a user of another company gets **403** — the data is never sent to the client to filter. No company assigned → 200 + empty list + "No company assigned...".
- **Role-based** — `/api/admin/*` and `/api/reports/*` run `authorize('SUPER_ADMIN')` **on the server**. A USER hitting them with a valid token gets 403 regardless of what the app UI shows. The Flutter go_router redirect to `/unauthorized` is UX only — both layers exist.
- **Input hardening** — bodies where strings are expected must be plain strings (NoSQL `$gt`-style objects → 400); keys starting with `$` or containing `.` → 400; duplicates → 409 via pre-check + unique indexes + `11000` catch; rate limit on `/api/auth/*`; helmet; field-level validation messages.

## Error-handling scenarios covered

Backend: field-level 400 validation, generic 401 login error (never reveals which part was wrong), `TOKEN_EXPIRED`/`TOKEN_INVALID`, 403 role/company, 404 user/route, 409 duplicates, 400 invalid ObjectIds, 502 upstream JSONPlaceholder failure/timeout, central error handler (no stack traces in production), 404 catch-all, graceful SIGINT/SIGTERM shutdown.

Flutter: splash validates stored token (`/auth/me`) → dashboard or cleared-storage login; login/register inline field errors + snackbar; server field errors land under the correct field; loading states on buttons; `ErrorView` with Retry; `EmptyView`; offline banner via `connectivity_plus`; request timeouts mapped to a friendly message; dio interceptor clears storage on 401 and the router redirects to login ("Session expired"); 403 → Unauthorized screen; logout clears token + invalidates all state and `go('/login')` removes the back stack; global `FlutterError.onError` + `runZonedGuarded`.

## Known limitations / assumptions

- New registrants have no company until a Super Admin assigns one (by design — companies come from the external API, so none can be trusted from the register payload).
- The external-API cache is in-memory per instance (5 min) — swap for Redis if you run multiple instances.
- Render free tier sleeps (~30–60 s cold start on first request).
- `0.0.0.0/0` Atlas network access is a demo compromise documented above.
- Cleartext HTTP (Android `usesCleartextTraffic`, iOS ATS local exception) is for local dev only; release builds talk HTTPS to the deployed URL.
- No refresh tokens: a 1 h access token + re-login is the intended demo scope.

## Screenshots / Screen recording

<!-- TODO(you): drop screenshots here after running the app -->

| Screen | Screenshot |
|---|---|
| Login | _placeholder_ |
| Dashboard | _placeholder_ |
| Users list | _placeholder_ |
| User details | _placeholder_ |
| Reports | _placeholder_ |
| User management | _placeholder_ |

## Screen recording

<!-- TODO(you): link a short walkthrough gif/video -->

## Git repository

https://github.com/jemin7/flutter-app
