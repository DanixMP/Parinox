# AGENTS.md

## Cursor Cloud specific instructions

### Services overview

- **Backend API** (`backend/`) — Python 3.12 FastAPI app (chat, calls-token, profiles, posts, stories). This is the only service that runs and is testable end-to-end in the headless cloud VM. It uses embedded SQLite (auto-created), local filesystem media, and an in-process APScheduler job — no external DB/broker/cache is required.
- **Flutter client** (`flutter_app/`) — Dart/Flutter GUI client. NOT runnable in the cloud VM: the Flutter SDK is not installed and the repo ships only `lib/` + `pubspec.yaml` (no `android/ios/...` platform folders, which would require `flutter create .`). Treat the backend as the end-to-end-testable surface.
- **LiveKit** (`deploy/`) — optional, only for real audio/video calls, and needs Docker (not installed). The backend's `/livekit/token` endpoint mints valid tokens without LiveKit running, so calls token issuance is testable but an actual call connection is not.

### Environment

- The update script creates the virtualenv at `backend/.venv` and installs `backend/requirements.txt`. Activate it with `source backend/.venv/bin/activate` before running any backend command.
- `backend/.env` is auto-created from `backend/.env.example` by the update script. `backend/config.py` also provides working dev defaults, so the app runs even without `.env`.
- The `python3-venv` system package is required to create the venv; it is already provisioned in the VM image (not part of the update script).

### Running / testing the backend

- Run standard commands from `README.md` (Quick start, Tests). In short: run the server with `uvicorn main:app --reload --host 0.0.0.0 --port 8000` from `backend/`, and tests with `pytest -q` from `backend/`.
- There is no public signup. Create users via `POST /admin/users` with header `X-Admin-Token: <ADMIN_TOKEN from .env>`, then `POST /login` to get a JWT.
- Chat delivery is over the WebSocket at `/ws/{room_id}?token=<jwt>&last_id=<int>`; the server replays messages with `id > last_id` on connect, then broadcasts live.

### Gotchas

- SQLite `DATABASE_PATH` defaults to the relative path `team_app.db`, resolved against the process's CWD. Always run the server AND `scripts/create_user.py` from the same directory (run the server from `backend/`, so its DB is `backend/team_app.db`). `scripts/create_user.py` run from the repo root writes a DIFFERENT `team_app.db` in the repo root that the server won't see — prefer the `POST /admin/users` HTTP endpoint (hits the running server's DB) instead.
- The DB file (`*.db`) and `.env` are gitignored, so a fresh clone starts with an empty database.
