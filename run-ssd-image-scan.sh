#!/bin/bash
set -uo pipefail

IMAGE="${1:-}"
SRC_ARG="${2:-.}"
CLI_IMAGE="${CLI_IMAGE:-docker.io/opsmx11/ssd-scanner-cli:eab0bcd4-202611081729}"

fail() { echo "[ERROR] $*" >&2; exit 1; }

[ -n "$IMAGE" ] || fail "Nothing to scan. Usage: ./run-ssd-image-scan.sh <image>:<tag> [source folder]"
[ -n "${SSD_UPLOAD_URL:-}" ] || fail "Set SSD_UPLOAD_URL to your SSD address: export SSD_UPLOAD_URL=https://<ssd-host>"
[ -n "${SSD_TOKEN:-}" ] || fail "Set SSD_TOKEN to your SSD team token: export SSD_TOKEN='...'"
command -v docker >/dev/null 2>&1 || fail "Docker is not installed."
docker info >/dev/null 2>&1 || fail "Docker is not running, or this user can't use it."

case "$IMAGE" in *@*) fail "Pass the image by tag, as it is deployed (<image>:<tag>), not by digest." ;; esac
NAME="${IMAGE%:*}"
TAG="${IMAGE##*:}"
{ [ "$NAME" != "$IMAGE" ] && [ -n "$TAG" ] && [[ "$TAG" != */* ]]; } || fail "Add the tag the image is deployed with: $IMAGE:<tag>"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Pulling $IMAGE with this machine's registry login..."
  docker pull "$IMAGE" >/dev/null || fail "Could not pull $IMAGE. Log in to the registry first (docker login / ECR / GCR helper)."
fi

DIGESTS="$(docker image inspect "$IMAGE" --format '{{range .RepoDigests}}{{println .}}{{end}}' | grep -c .)"
[ "$DIGESTS" -gt 0 ] || fail "$IMAGE has no registry digest on this machine (built locally, never pushed). Push it, then pull it and run this again."

[ -d "$SRC_ARG" ] || fail "Source folder not found: $SRC_ARG"
SRC="$(cd "$SRC_ARG" && pwd)"
IS_GIT=0
git -C "$SRC" rev-parse --git-dir >/dev/null 2>&1 && IS_GIT=1
url="${REPO_URL:-}"
[ -n "$url" ] || [ "$IS_GIT" -eq 0 ] || url="$(git -C "$SRC" remote get-url origin 2>/dev/null)"
[ -n "$url" ] || fail "Can't tell which repository built this image. Run from its git checkout, or set REPO_URL=https://github.com/<org>/<repo>"
url="$(printf '%s' "$url" | sed -E 's#^[^@/]+@([^:/]+):#https://\1/#; s#^ssh://[^@/]+@([^/:]+)(:[0-9]+)?/#https://\1/#; s#^(https?://)[^@/]+@#\1#; s#\.git$##; s#^https://(ssh\.dev\.azure\.com|vs-ssh\.visualstudio\.com)/v3/([^/]+)/([^/]+)/([^/]+)$#https://dev.azure.com/\2/\3/_git/\4#')"
BRANCH="${BRANCH_NAME:-}"
[ -n "$BRANCH" ] || [ "$IS_GIT" -eq 0 ] || BRANCH="$(git -C "$SRC" rev-parse --abbrev-ref HEAD 2>/dev/null)"
{ [ -z "$BRANCH" ] || [ "$BRANCH" = HEAD ]; } && BRANCH=main
COMMIT="${COMMIT:-}"
[ -n "$COMMIT" ] || [ "$IS_GIT" -eq 0 ] || COMMIT="$(git -C "$SRC" rev-parse HEAD 2>/dev/null)"
[ -n "$COMMIT" ] || fail "Can't tell which commit built this image. Run from its git checkout, or set COMMIT=<commit sha>"
BUILD_ID="${BUILD_ID:-$(date +%Y%m%d%H%M%S)}"

SOCK_GID="$(docker run --rm --entrypoint stat -v /var/run/docker.sock:/var/run/docker.sock "$CLI_IMAGE" -c %g /var/run/docker.sock 2>/dev/null)"
[ -n "$SOCK_GID" ] || fail "Could not read the Docker socket from the scanner image $CLI_IMAGE."

LOG="$(mktemp -t ssd-image-scan.XXXXXX.log)"
echo "============================================================"
echo " SSD image scan"
echo "  image      : $IMAGE"
echo "  repository : $url"
echo "  branch     : $BRANCH"
echo "  commit     : $COMMIT"
echo "  build id   : $BUILD_ID"
echo "  SSD        : $SSD_UPLOAD_URL"
echo "  scanner    : $CLI_IMAGE"
echo "============================================================"
docker run --rm \
  --group-add "$SOCK_GID" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$SRC:/home/scanner/source:ro" \
  "$CLI_IMAGE" \
    --scanners=syft,trivy \
    --syft-scanners=sbom \
    --trivy-scanners=imagesecretscan,imagelicensescan \
    --artifact-type=image \
    --artifact-name="$NAME" \
    --artifact-tag="$TAG" \
    --send-image-digest \
    --source-code-path=/home/scanner/source \
    --repository-url="$url" \
    --branch="$BRANCH" \
    --head-commit="$COMMIT" \
    --build-id="$BUILD_ID" \
    --upload-url="$SSD_UPLOAD_URL" \
    --ssd-token="$SSD_TOKEN" 2>&1 | tee "$LOG"
RC=${PIPESTATUS[0]}
PLAIN="$(sed 's/\x1b\[[0-9;]*m//g' "$LOG")"
echo "============================================================"
[ "$RC" -eq 0 ] || { echo " FAILED: the scanner exited with code $RC"; echo " log: $LOG"; exit "$RC"; }
if ! printf '%s\n' "$PLAIN" | grep -q 'Successfully sent build event'; then
  echo " FAILED: SSD did not accept the scan (check the token and that SSD is reachable)"; echo " log: $LOG"; exit 1
fi
SHA="$(printf '%s\n' "$PLAIN" | grep -o 'sha256:[a-f0-9]\{64\}' | head -1)"
echo " SUBMITTED: $IMAGE"
[ -z "$SHA" ] || echo " image digest: $SHA (the same digest Kubernetes shows as imageID for pods running this image)"
echo " SSD is processing it now; results appear in the UI in a few minutes:"
[ -z "$SHA" ] || echo "   ${SSD_UPLOAD_URL%/}/ui/artifact-security/generated?artifactSha=sha256%3A${SHA#sha256:}"
echo " Once the image is deployed, it shows under Security Issues > Deployed Artifacts, linked to this scan."
echo " log: $LOG"
