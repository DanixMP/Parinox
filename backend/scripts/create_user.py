#!/usr/bin/env python3
"""CLI to create a user without going through the admin HTTP endpoint.

Usage:
  python scripts/create_user.py alice 'password' 'Alice'
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND))

from auth import hash_password  # noqa: E402
from db import execute, fetchone, init_db  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser(description="Create a Parinox user")
    parser.add_argument("username")
    parser.add_argument("password")
    parser.add_argument("display_name")
    parser.add_argument("--bio", default="")
    args = parser.parse_args()

    init_db()
    existing = fetchone("SELECT id FROM users WHERE username = ?", (args.username,))
    if existing is not None:
        print(f"Error: username '{args.username}' already exists", file=sys.stderr)
        return 1

    user_id = execute(
        "INSERT INTO users (username, password_hash, display_name, bio) VALUES (?, ?, ?, ?)",
        (args.username, hash_password(args.password), args.display_name, args.bio),
    )
    print(f"Created user id={user_id} username={args.username}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
