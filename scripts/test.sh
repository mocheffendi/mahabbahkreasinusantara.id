#!/usr/bin/env bash
# =========================================================
# scripts/test.sh — pengujian ringan landing page statis.
# Dipakai oleh GitHub Actions (step "Test") dan bisa dijalankan lokal.
# =========================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

pass()  { printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail()  { printf '  \033[31m✗ %s\033[0m\n' "$1"; exit 1; }
title() { printf '\n\033[1m%s\033[0m\n' "$1"; }

title "1) File wajib"
for f in Dockerfile nginx.conf public/index.html public/css/style.css \
         public/js/main.js public/images/manifest.json; do
  [ -f "$f" ] || fail "hilang: $f"
  pass "$f"
done

title "2) Validitas manifest & ketersediaan aset gambar"
command -v jq >/dev/null 2>&1 || fail "jq tidak tersedia di runner"
jq empty public/images/manifest.json || fail "manifest.json bukan JSON valid"
total=$(jq '[.[] | length] | add' public/images/manifest.json)
[ "$total" -gt 0 ] || fail "manifest tidak berisi gambar"
pass "manifest valid — total $total gambar"

missing=0
while IFS= read -r p; do
  [ -f "public/$p" ] || { printf '    \033[31mhilang: public/%s\033[0m\n' "$p"; missing=$((missing + 1)); }
done < <(jq -r '.[] | .[] | .thumb, .full' public/images/manifest.json)
[ "$missing" -eq 0 ] || fail "$missing aset gambar tidak ditemukan"
pass "semua thumb & full tersedia"

title "3) Struktur HTML dasar"
grep -qi '<!DOCTYPE html>' public/index.html || fail "index.html tanpa DOCTYPE"
grep -qi '</html>'        public/index.html || fail "index.html tidak ditutup"
grep -q  'lang="id"'      public/index.html || fail "index.html tanpa lang=id"
grep -qi '<meta name="viewport"' public/index.html || fail "index.html tanpa meta viewport"
pass "struktur HTML dasar ok"

title "4) Referensi aset lokal"
grep -q "css/style.css" public/index.html || fail "index.html tidak merujuk css/style.css"
pass "index.html → css/style.css"
grep -q "js/main.js" public/index.html || fail "index.html tidak merujuk js/main.js"
pass "index.html → js/main.js"
grep -q "images/manifest.json" public/js/main.js || fail "main.js tidak memuat images/manifest.json"
pass "main.js → images/manifest.json"

title "5) Nomor WhatsApp"
grep -q "6282228329788" public/index.html || fail "nomor WA tidak ada di index.html"
grep -q "6282228329788" public/js/main.js  || fail "nomor WA tidak ada di main.js"
pass "nomor WA terpasang"

title "6) Line ending file kritis (harus LF)"
if grep -rlU $'\r' Dockerfile nginx.conf docker-compose*.yml scripts 2>/dev/null | grep -q .; then
  fail "terdeteksi CRLF pada file skrip/konfigurasi"
fi
pass "line ending LF"

printf '\n\033[32m🎉 Semua test lulus (%s gambar).\033[0m\n' "$total"
