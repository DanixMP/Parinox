#!/usr/bin/env python3
"""CLI to create users without public signup.

Usage:
  python scripts/create_user.py alice 'password' 'Alice' [--admin]
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Allow importing backend modules when run from repo root
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))

from auth import hash_password  # noqa: E402
from db import get_db, init_db  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(description="Create a Team App user")
    parser.add_argument("username")
    parser.add_argument("password")
    parser.add_argument("display_name")
    parser.add_argument("--bio", default="")
    parser.add_argument("--admin", action="store_true")
    args = parser.parse_args()

    init_db()
    with get_db() as conn:
        existing = conn.execute("SELECT id FROM users WHERE username = ?", (args.username,)).fetchone()
        if existing:
            print(f"Username '{args.username}' already exists (id={existing['id']})", file=sys.stderr)
            sys.exit(1)
        cur = conn.execute(
            """
            INSERT INTO users (username, password_hash, display_name, bio, is_admin)
            VALUES (?, ?, ?, ?, ?)
            """,
            (args.username, hash_password(args.password), args.display_name, args.bio, int(args.admin)),
        )
        print(f"Created user id={cur.lastrowid} username={args.username}")


if __name__ == "__main__":
    main()
