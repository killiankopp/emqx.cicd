#!/usr/bin/env bash
set -euo pipefail

NS=${1:-emqx}
SECRET_NAME=${2:-emqx-auth}

if kubectl get secret -n "$NS" "$SECRET_NAME" >/dev/null 2>&1; then
  echo "[INFO] Secret $SECRET_NAME already exists in namespace $NS. Skipping creation."
  exit 0
fi

# Allow overriding via env vars; otherwise generate safe defaults
ADMIN_USERNAME=${EMQX_ADMIN_USERNAME:-admin}
ADMIN_PASSWORD=${EMQX_ADMIN_PASSWORD:-}
ERLANG_COOKIE=${EMQX_ERLANG_COOKIE:-}

rand_str() {
  local len=${1:-16}
  # Prefer openssl if available, fallback to tr
  if command -v openssl >/dev/null 2>&1; then
    # base64 then strip non-alnum; loop until enough length
    local out=""
    while [ ${#out} -lt $len ]; do
      out+=$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c $len || true)
    done
    echo "${out:0:$len}"
  else
    LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c $len
  fi
}

if [ -z "$ADMIN_PASSWORD" ]; then
  ADMIN_PASSWORD=$(rand_str 20)
fi

if [ -z "$ERLANG_COOKIE" ]; then
  ERLANG_COOKIE=$(rand_str 32)
fi

cat <<EOF | kubectl apply -n "$NS" -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
type: Opaque
data:
  admin-username: $(printf "%s" "$ADMIN_USERNAME" | base64)
  admin-password: $(printf "%s" "$ADMIN_PASSWORD" | base64)
  erlang-cookie: $(printf "%s" "$ERLANG_COOKIE" | base64)
EOF

echo "[INFO] Created secret $SECRET_NAME in namespace $NS"
echo "[INFO] Username: $ADMIN_USERNAME"
echo "[INFO] Password: $ADMIN_PASSWORD"
