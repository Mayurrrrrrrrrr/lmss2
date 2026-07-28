#!/usr/bin/env bash
set -Eeuo pipefail

APPLY="${1:-}"
RELEASES="/home/ubuntu/releases"
BACKUPS="/home/ubuntu/lms-backups"
WEB_ROOT="/var/www"
OLD_BUILDS="/home/ubuntu/builds"

keep_release() {
  case "$1" in
    app-release.aab|app-release.apk|android-signing-secure.env|\
    deploy_phase8_release.sh|firefly-lms-release-secure.jks|\
    lmss2-phase8-4f425b2.tar.gz|phase8-4f425b2)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

remove_target() {
  local target="$1"
  local allowed_prefix="$2"
  [[ "$target" == "$allowed_prefix/"* ]] ||
    { echo "REFUSED unsafe target: $target" >&2; exit 1; }
  if [[ "$APPLY" == "--apply" ]]; then
    rm -rf -- "$target"
    echo "REMOVED $target"
  else
    echo "WOULD_REMOVE $target"
  fi
}

echo "=== RELEASE INVENTORY ==="
for target in "$RELEASES"/*; do
  [[ -e "$target" ]] || continue
  name="$(basename "$target")"
  if keep_release "$name"; then
    echo "KEEP $target"
  else
    remove_target "$target" "$RELEASES"
  fi
done

echo "=== BACKUP INVENTORY ==="
mapfile -t backup_paths < <(
  find "$BACKUPS" -mindepth 1 -maxdepth 1 -printf '%T@ %p\n' |
    sort -rn |
    cut -d' ' -f2-
)
for index in "${!backup_paths[@]}"; do
  target="${backup_paths[$index]}"
  if (( index < 2 )); then
    echo "KEEP $target"
  else
    remove_target "$target" "$BACKUPS"
  fi
done

echo "=== WEB STAGING INVENTORY ==="
for target in "$WEB_ROOT"/lms-web.previous-* "$WEB_ROOT"/lms-web.phase*; do
  [[ -e "$target" ]] || continue
  remove_target "$target" "$WEB_ROOT"
done
echo "KEEP $WEB_ROOT/lms-web"

echo "=== OLD BUILD INVENTORY ==="
if [[ -d "$OLD_BUILDS" ]]; then
  if [[ "$APPLY" == "--apply" ]]; then
    rm -rf -- "$OLD_BUILDS"
    echo "REMOVED $OLD_BUILDS"
  else
    echo "WOULD_REMOVE $OLD_BUILDS"
  fi
fi

echo "=== DISK ==="
df -h /
