#!/usr/bin/env bash
# Curl checks for the Imgix-compatible gateway.
# Brings up compose.test.yaml (S3 server, imgproxy, gateway), seeds one image and
# one video into a bucket, runs the checks, and tears everything down.
# Needs: docker (compose v2), curl >= 7.75 (for --aws-sigv4), shasum or sha256sum.
set -euo pipefail

cd "$(dirname "$0")"

S3_PORT="${IMG_TEST_S3_PORT:-19000}"
GW_PORT="${IMG_TEST_GATEWAY_PORT:-18080}"
export IMG_TEST_S3_PORT="$S3_PORT" IMG_TEST_GATEWAY_PORT="$GW_PORT"
S3="http://127.0.0.1:${S3_PORT}"
GW="http://127.0.0.1:${GW_PORT}"
BUCKET="campsite-test-media"
S3_AUTH=(--aws-sigv4 "aws:amz:us-east-1:s3" --user "campsite-test:campsite-test-only")
COMPOSE=(docker compose -f compose.test.yaml)

TMP="$(mktemp -d)"
cleanup() {
  "${COMPOSE[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT

sha() {
  if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

PASS=0
FAIL=0
check() { # name, condition result (0 = pass)
  if [ "$2" -eq 0 ]; then
    echo "PASS $1"
    PASS=$((PASS + 1))
  else
    echo "FAIL $1"
    FAIL=$((FAIL + 1))
  fi
}
header() { # file, header name -> value (case-insensitive), trimmed
  grep -i "^$2:" "$1" | head -1 | cut -d: -f2- | tr -d '\r' | sed 's/^ *//'
}
status() { head -1 "$1" | awk '{print $2}'; }

"${COMPOSE[@]}" up -d --quiet-pull >/dev/null 2>&1

# Wait for the S3 server (bucket creation succeeds) and the gateway.
for _ in $(seq 1 60); do
  if curl -fs -o /dev/null "${S3_AUTH[@]}" -X PUT "$S3/$BUCKET" 2>/dev/null && curl -s -o /dev/null "$GW/" 2>/dev/null; then break; fi
  sleep 1
done

# Seed the bucket.
curl -fsS -o /dev/null "${S3_AUTH[@]}" -H "Content-Type: image/png" -T fixtures/sample.png "$S3/$BUCKET/o/test/p/sample.png"
curl -fsS -o /dev/null "${S3_AUTH[@]}" -H "Content-Type: video/mp4" -T fixtures/sample.mp4 "$S3/$BUCKET/o/test/p/sample.mp4"

printf '<html><body><script>document.title="x"</script></body></html>' >"$TMP/evil.html"
printf '<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>' >"$TMP/evil.svg"
curl -fsS -o /dev/null "${S3_AUTH[@]}" -H "Content-Type: text/html" -T "$TMP/evil.html" "$S3/$BUCKET/o/test/p/evil.html"
curl -fsS -o /dev/null "${S3_AUTH[@]}" -H "Content-Type: image/svg+xml" -T "$TMP/evil.svg" "$S3/$BUCKET/o/test/p/evil.svg"

# A 30 MB object, fetched slowly below, checks imgproxy's server timeouts.
dd if=/dev/urandom of="$TMP/big.bin" bs=1048576 count=30 2>/dev/null
curl -fsS -o /dev/null "${S3_AUTH[@]}" -H "Content-Type: application/octet-stream" -T "$TMP/big.bin" "$S3/$BUCKET/o/test/p/big.bin"

PNG_SHA="$(sha fixtures/sample.png)"
MP4_SHA="$(sha fixtures/sample.mp4)"

# Checks report and count failures instead of exiting.
set +e

# 1. ?w=64&h=64&fit=crop returns a 64x64 image.
curl -s -D "$TMP/h1" -o "$TMP/b1" "$GW/o/test/p/sample.png?w=64&h=64&fit=crop"
[ "$(status "$TMP/h1")" = "200" ] && [ "$(header "$TMP/h1" X-Result-Width)" = "64" ] &&
  [ "$(header "$TMP/h1" X-Result-Height)" = "64" ] && [ "$(header "$TMP/h1" Content-Type)" = "image/png" ]
check "w=64&h=64&fit=crop returns a 64x64 image" $?

# 2. ?dl= returns the original bytes as an attachment.
curl -s -D "$TMP/h2" -o "$TMP/b2" "$GW/o/test/p/sample.png?dl="
[ "$(status "$TMP/h2")" = "200" ] && [ "$(sha "$TMP/b2")" = "$PNG_SHA" ] &&
  header "$TMP/h2" Content-Disposition | grep -q '^attachment'
check "dl= returns the original bytes (same SHA-256) with Content-Disposition: attachment" $?

# 3. A video path returns the file with Accept-Ranges: bytes.
curl -s -D "$TMP/h3" -o "$TMP/b3" "$GW/o/test/p/sample.mp4"
[ "$(status "$TMP/h3")" = "200" ] && [ "$(sha "$TMP/b3")" = "$MP4_SHA" ] &&
  [ "$(header "$TMP/h3" Accept-Ranges)" = "bytes" ] && [ "$(header "$TMP/h3" Content-Type)" = "video/mp4" ]
check "video returns the original file with Accept-Ranges: bytes" $?

# Extra checks.
curl -s -D "$TMP/h4" -o "$TMP/b4" -H "Range: bytes=0-99" "$GW/o/test/p/sample.mp4"
[ "$(status "$TMP/h4")" = "206" ] && [ "$(wc -c <"$TMP/b4" | tr -d ' ')" = "100" ] &&
  header "$TMP/h4" Content-Range | grep -q '^bytes 0-99/'
check "video Range request returns 206 with 100 bytes" $?

curl -s -D "$TMP/h5" -o "$TMP/b5" "$GW/o/test/p/sample.png"
[ "$(status "$TMP/h5")" = "200" ] && [ "$(sha "$TMP/b5")" = "$PNG_SHA" ]
check "no parameters returns the original bytes" $?

curl -s -D "$TMP/h6" -o "$TMP/b6" "$GW/o/test/p/sample.png?auto=compress%2Cformat&dpr=2&w=50&q=60"
[ "$(status "$TMP/h6")" = "200" ] && [ "$(header "$TMP/h6" X-Result-Width)" = "100" ]
check "auto=compress,format&dpr=2&w=50&q=60 returns width 100" $?

curl -s -D "$TMP/h7" -o "$TMP/b7" "$GW/o/test/p/sample.png?auto=compress%2Cformat&rect=10,20,30,40"
[ "$(status "$TMP/h7")" = "200" ] && [ "$(header "$TMP/h7" X-Result-Width)" = "30" ] &&
  [ "$(header "$TMP/h7" X-Result-Height)" = "40" ]
check "rect=10,20,30,40 returns a 30x40 crop" $?

curl -s -D "$TMP/h8" -o "$TMP/b8" "$GW/o/test/p/sample.png?fm=mp4"
[ "$(status "$TMP/h8")" = "200" ] && [ "$(sha "$TMP/b8")" = "$PNG_SHA" ]
check "unsupported fm=mp4 falls back to the original" $?

curl -s -D "$TMP/h9" -o "$TMP/b9" "$GW/o/test/p/sample.png?blend-color=3b82f6&w=40&h=40&fit=crop"
[ "$(status "$TMP/h9")" = "200" ] && [ "$(header "$TMP/h9" X-Result-Width)" = "40" ]
check "unsupported blend-color is ignored, resize still applied" $?

# About 15 s at 2 MB/s: longer than imgproxy's default 10 s write timeout.
curl -s -D "$TMP/h11" -o "$TMP/b11" --limit-rate 2M "$GW/o/test/p/big.bin?dl="
[ "$(status "$TMP/h11")" = "200" ] && [ "$(sha "$TMP/b11")" = "$(sha "$TMP/big.bin")" ]
check "slow 30 MB download is complete (same SHA-256)" $?

curl -s -D "$TMP/h10" -o "$TMP/b10" "$GW/o/test/p/missing.png?w=10"
[ "$(status "$TMP/h10")" = "404" ]
check "missing key returns 404" $?

# Uploaded content must never render as a page on the gateway host.
SANDBOX_CSP="default-src 'none'; img-src 'self'; media-src 'self'; style-src 'unsafe-inline'; sandbox"
safe_headers() { # headers file -> 0 when CSP sandbox and nosniff are set
  [ "$(header "$1" Content-Security-Policy)" = "$SANDBOX_CSP" ] && [ "$(header "$1" X-Content-Type-Options)" = "nosniff" ]
}
for ext in html svg; do
  curl -s -D "$TMP/h_$ext" -o /dev/null "$GW/o/test/p/evil.$ext"
  [ "$(status "$TMP/h_$ext")" = "200" ] && header "$TMP/h_$ext" Content-Disposition | grep -q '^attachment' && safe_headers "$TMP/h_$ext"
  check "uploaded .$ext is served as attachment with sandbox CSP and nosniff" $?
done

safe_headers "$TMP/h5" && header "$TMP/h5" Content-Disposition | grep -q '^inline' && [ "$(header "$TMP/h5" Content-Type)" = "image/png" ]
check "a normal image renders inline, with sandbox CSP and nosniff" $?

safe_headers "$TMP/h3" && header "$TMP/h3" Content-Disposition | grep -q '^inline'
check "a video renders inline, with sandbox CSP and nosniff" $?

header "$TMP/h11" Content-Disposition | grep -q '^attachment; filename="big.bin"'
check "download keeps the filename" $?

for p in "/../other-bucket/x.png" "/o/%2e%2e/x.png" "/o/%2E%2e/%2E%2E/x.png" "/o/..%2fx.png"; do
  [ "$(curl -s --path-as-is -o /dev/null -w '%{http_code}' "$GW$p")" = "400" ]
  check "dot-segment path $p is rejected with 400" $?
done

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
