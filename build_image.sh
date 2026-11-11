#!/usr/bin/env bash
# Build (and optionally push) the subnetcalc image from this checkout.
# Usage: ./build_image.sh          -> build + local smoke test only
#        ./build_image.sh --push   -> also push to ghcr.io (needs `docker login ghcr.io`)
# Tag: ghcr.io/adelerhof/subnetcalc-main:<yyyymmddHHMMSS>; the Deployment in
# adelerhof/service-visualsubnetcalc (k8smanifest/visualsubnetcalc-deployment.yml)
# pins the image by digest, printed after the push.
# (Replaced 2026-11-11: the old script cloned upstream ckabalan/visualsubnetcalc.)
set -euo pipefail
cd "$(dirname "$0")"
[ -z "$(git status --porcelain)" ] || { echo "working tree not clean, commit first" >&2; exit 1; }
TAG=$(date +%Y%m%d%H%M%S)
IMG=ghcr.io/adelerhof/subnetcalc-main
docker build --pull . --file Dockerfile \
  --label org.opencontainers.image.revision="$(git rev-parse HEAD)" \
  --label org.opencontainers.image.source=https://github.com/adelerhof/visualsubnetcalc \
  --tag "$IMG:$TAG"

# smoke test with the same restrictions as the k8s Deployment
docker rm -f subnetcalc-smoke >/dev/null 2>&1 || true
docker run -d --name subnetcalc-smoke -p 127.0.0.1:18080:8080 \
  --user 10000:10000 --read-only --tmpfs /tmp --cap-drop ALL --security-opt no-new-privileges \
  "$IMG:$TAG" >/dev/null
trap 'docker rm -f subnetcalc-smoke >/dev/null 2>&1' EXIT
for _ in $(seq 1 30); do curl -sf -o /dev/null http://127.0.0.1:18080/ && break; sleep 0.5; done
for path in / /js/main.js /css/bootstrap.min.css; do
  got=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:18080$path")
  [ "$got" = 200 ] || { echo "smoke test failed: $path -> $got" >&2; exit 1; }
done
echo "smoke test OK: $IMG:$TAG"

if [ "${1:-}" = "--push" ]; then
  docker push "$IMG:$TAG"
  digest=$(docker inspect --format '{{index .RepoDigests 0}}' "$IMG:$TAG")
  echo "pushed $IMG:$TAG"
  echo "digest for the Deployment: $digest"
fi
