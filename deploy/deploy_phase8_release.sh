#!/usr/bin/env bash
set -Eeuo pipefail

# Usage:
#   sudo -E bash deploy/deploy_phase8_release.sh \
#     /home/ubuntu/releases/lmss2-phase8-<commit>.tar.gz <commit> \
#     /home/ubuntu/releases/firefly-lms-release-secure.jks \
#     /home/ubuntu/releases/android-signing-secure.env \
#     [/home/ubuntu/releases/app-release.apk] \
#     [/home/ubuntu/releases/app-release.aab]

ARCHIVE="${1:?release archive is required}"
RELEASE_ID="${2:?release identifier is required}"
LMS_KEYSTORE_PATH="${3:?release keystore path is required}"
SIGNING_ENV="${4:?signing environment file is required}"
PREBUILT_APK="${5:-}"
PREBUILT_AAB="${6:-}"
LMS_KEYSTORE_PASSWORD=""
LMS_KEY_ALIAS=""
LMS_KEY_PASSWORD=""
VERSION="${LMS_RELEASE_VERSION:-1.1.0}"
MINIMUM_VERSION="${LMS_MIN_ANDROID_VERSION:-1.0.0}"
APP_ROOT="/home/ubuntu/releases/phase8-${RELEASE_ID}"
SOURCE_ROOT="${APP_ROOT}/lmss2"
FLUTTER="${FLUTTER_BIN:-/home/ubuntu/build-tools/flutter/bin/flutter}"
BACKEND_LIVE="/home/ubuntu/lms_v2_backend"
WEB_LIVE="/var/www/lms-web"
BACKUP_ROOT="/home/ubuntu/lms-backups"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
BACKUP="${BACKUP_ROOT}/phase8-${RELEASE_ID}-${STAMP}"
WEB_NEXT="/var/www/lms-web.phase8-${RELEASE_ID}-${STAMP}"
APK_NAME="firefly-lms-${VERSION}.apk"
APK_URL="https://lms2.yuktaa.com/downloads/${APK_NAME}"

fail() {
  echo "PHASE8_FAILED: $*" >&2
  exit 1
}

load_signing_environment() {
  local key value
  [[ -f "$SIGNING_ENV" ]] || fail "signing environment file is missing"
  while IFS='=' read -r key value || [[ -n "$key" ]]; do
    value="${value%$'\r'}"
    case "$key" in
      LMS_KEYSTORE_PASSWORD) LMS_KEYSTORE_PASSWORD="$value" ;;
      LMS_KEY_ALIAS) LMS_KEY_ALIAS="$value" ;;
      LMS_KEY_PASSWORD) LMS_KEY_PASSWORD="$value" ;;
    esac
  done < "$SIGNING_ENV"
  export LMS_KEYSTORE_PATH LMS_KEYSTORE_PASSWORD LMS_KEY_ALIAS LMS_KEY_PASSWORD
}

flutter_as_ubuntu() {
  runuser -u ubuntu -- env \
    HOME=/home/ubuntu \
    PUB_CACHE=/home/ubuntu/.pub-cache \
    LMS_KEYSTORE_PATH="$LMS_KEYSTORE_PATH" \
    LMS_KEYSTORE_PASSWORD="$LMS_KEYSTORE_PASSWORD" \
    LMS_KEY_ALIAS="$LMS_KEY_ALIAS" \
    LMS_KEY_PASSWORD="$LMS_KEY_PASSWORD" \
    "$FLUTTER" "$@"
}

[[ "$(id -u)" -eq 0 ]] || fail "run this workflow with sudo -E"
[[ "$RELEASE_ID" =~ ^[A-Za-z0-9._-]+$ ]] ||
  fail "release identifier contains unsupported characters"
[[ -f "$ARCHIVE" ]] || fail "archive not found: $ARCHIVE"
[[ -x "$FLUTTER" ]] || fail "Flutter SDK not found: $FLUTTER"
if [[ -n "$PREBUILT_APK" || -n "$PREBUILT_AAB" ]]; then
  [[ -s "$PREBUILT_APK" ]] || fail "prebuilt APK is missing or empty"
  [[ -s "$PREBUILT_AAB" ]] || fail "prebuilt AAB is missing or empty"
else
  load_signing_environment
  [[ -f "${LMS_KEYSTORE_PATH:-}" ]] || fail "release keystore is missing"
  [[ -n "${LMS_KEYSTORE_PASSWORD:-}" ]] || fail "LMS_KEYSTORE_PASSWORD is missing"
  [[ -n "${LMS_KEY_ALIAS:-}" ]] || fail "LMS_KEY_ALIAS is missing"
  [[ -n "${LMS_KEY_PASSWORD:-}" ]] || fail "LMS_KEY_PASSWORD is missing"
fi
command -v libreoffice >/dev/null || fail "LibreOffice is required for PPT/DOC conversion"
command -v rsync >/dev/null || fail "rsync is required"

echo "[1/10] Extracting isolated release"
rm -rf -- "$APP_ROOT"
mkdir -p "$APP_ROOT" "$BACKUP"
tar -xzf "$ARCHIVE" -C "$APP_ROOT"
chown -R ubuntu:ubuntu "$APP_ROOT"
[[ -f "$SOURCE_ROOT/lmss2/pubspec.yaml" ]] || fail "unexpected archive layout"
[[ -f "$SOURCE_ROOT/lms_v2_backend/app/main.py" ]] || fail "backend source is missing"

echo "[2/10] Validating backend"
python3 -m compileall -q "$SOURCE_ROOT/lms_v2_backend/app"

echo "[3/10] Resolving Flutter dependencies"
cd "$SOURCE_ROOT/lmss2"
flutter_as_ubuntu pub get

echo "[4/10] Running strict Flutter analysis"
flutter_as_ubuntu analyze

echo "[5/10] Building web and signed Android artifacts"
flutter_as_ubuntu build web --release --no-wasm-dry-run
if [[ -n "$PREBUILT_APK" ]]; then
  mkdir -p \
    build/app/outputs/flutter-apk \
    build/app/outputs/bundle/release
  install -m 644 "$PREBUILT_APK" \
    build/app/outputs/flutter-apk/app-release.apk
  install -m 644 "$PREBUILT_AAB" \
    build/app/outputs/bundle/release/app-release.aab
else
  flutter_as_ubuntu build apk --release
  flutter_as_ubuntu build appbundle --release
fi
[[ -s build/web/index.html ]] || fail "web build is incomplete"
[[ -s build/app/outputs/flutter-apk/app-release.apk ]] || fail "APK build is incomplete"
[[ -s build/app/outputs/bundle/release/app-release.aab ]] || fail "AAB build is incomplete"

echo "[6/10] Backing up production"
mkdir -p "$BACKUP/backend-live"
rsync -a \
  --exclude venv --exclude .env --exclude __pycache__ \
  "$BACKEND_LIVE/" "$BACKUP/backend-live/"
cp -a "$WEB_LIVE" "$BACKUP/web-live"

rollback() {
  echo "Deployment failed; restoring backend and frontend." >&2
  if [[ -d "$BACKUP/backend-live" ]]; then
    rsync -a --delete \
      --exclude venv --exclude .env --exclude __pycache__ \
      "$BACKUP/backend-live/" "$BACKEND_LIVE/"
  fi
  if [[ -d "$BACKUP/web-live" ]]; then
    rm -rf -- "$WEB_LIVE"
    cp -a "$BACKUP/web-live" "$WEB_LIVE"
  fi
  systemctl restart lms-backend.service || true
}
trap rollback ERR

echo "[7/10] Updating backend"
rsync -a --delete \
  --exclude venv --exclude .env --exclude __pycache__ \
  "$SOURCE_ROOT/lms_v2_backend/" "$BACKEND_LIVE/"
chown -R ubuntu:ubuntu "$BACKEND_LIVE"
systemctl restart lms-backend.service

for _ in {1..24}; do
  if curl -fsS http://127.0.0.1:8000/api/health >/dev/null; then
    break
  fi
  sleep 5
done
curl -fsS http://127.0.0.1:8000/api/health >/dev/null ||
  fail "backend health check failed"

echo "[8/10] Running database and role audits"
cd "$BACKEND_LIVE"
PYTHONPATH="$BACKEND_LIVE" ./venv/bin/python scripts/phase4_schema_audit.py
PYTHONPATH="$BACKEND_LIVE" ./venv/bin/python scripts/phase4_role_audit.py
PYTHONPATH="$BACKEND_LIVE" ./venv/bin/python scripts/phase2_participant_audit.py
PYTHONPATH="$BACKEND_LIVE" ./venv/bin/python scripts/phase3_trainer_audit.py

echo "[9/10] Publishing web portal and Android download"
mkdir -p "$WEB_NEXT/downloads"
rsync -a --delete "$SOURCE_ROOT/lmss2/build/web/" "$WEB_NEXT/"
install -m 644 \
  "$SOURCE_ROOT/lmss2/build/app/outputs/flutter-apk/app-release.apk" \
  "$WEB_NEXT/downloads/$APK_NAME"
install -m 644 \
  "$SOURCE_ROOT/lmss2/build/app/outputs/bundle/release/app-release.aab" \
  "$BACKUP/firefly-lms-${VERSION}.aab"
chown -R www-data:www-data "$WEB_NEXT"
mv "$WEB_LIVE" "${WEB_LIVE}.previous-${STAMP}"
mv "$WEB_NEXT" "$WEB_LIVE"
systemctl reload caddy 2>/dev/null || systemctl reload nginx

PYTHONPATH="$BACKEND_LIVE" ./venv/bin/python scripts/set_android_release.py \
  --version "$VERSION" \
  --minimum "$MINIMUM_VERSION" \
  --url "$APK_URL" \
  --apply

echo "[10/10] Public smoke tests"
curl -fsSI https://lms2.yuktaa.com/ >/dev/null
curl -fsS https://lms2.yuktaa.com/api/health >/dev/null
curl -fsSI "$APK_URL" >/dev/null

trap - ERR
echo "PHASE8_DEPLOYED"
echo "RELEASE=$RELEASE_ID"
echo "APK=$APK_URL"
echo "BACKUP=$BACKUP"
