#!/usr/bin/env bash
# Wrapper around docker compose for VPS deployments.
#
# Resolves the Tailscale interface IP before starting so the server port is
# bound only to the tailnet interface and is unreachable from the public internet.
#
# Usage:
#   ./scripts/vps-start.sh up -d              # start (or restart) in background
#   ./scripts/vps-start.sh down               # stop all services
#   ./scripts/vps-start.sh logs -f server     # tail server logs
#   ./scripts/vps-start.sh up -d --build      # rebuild image then start
#   ./scripts/vps-start.sh exec server sh     # open a shell in the server container
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$REPO_ROOT/.env"
COMPOSE_FILE="$REPO_ROOT/docker/docker-compose.vps.yml"

# ── Preflight checks ──────────────────────────────────────────────────────────

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: .env not found at $ENV_FILE"
  echo "  Copy ENV_TEMPLATE to .env and fill in the required values, then re-run."
  exit 1
fi

# Load .env so we pick up any manually set TAILSCALE_IP (and other vars).
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

# ── Tailscale IP resolution ───────────────────────────────────────────────────

if [[ -z "${TAILSCALE_IP:-}" ]]; then
  if command -v tailscale &>/dev/null; then
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || true)
  fi

  if [[ -z "${TAILSCALE_IP:-}" ]]; then
    echo "WARNING: Could not detect Tailscale IP — binding to 127.0.0.1 (localhost only)."
    echo "  Make sure Tailscale is running on this host ('sudo tailscale up'),"
    echo "  or set TAILSCALE_IP explicitly in .env."
    TAILSCALE_IP="127.0.0.1"
  else
    echo "Detected Tailscale IP: $TAILSCALE_IP"
  fi
fi

export TAILSCALE_IP
echo "Server will bind to $TAILSCALE_IP:3100"

# ── Delegate to docker compose ────────────────────────────────────────────────

exec docker compose -f "$COMPOSE_FILE" "$@"
