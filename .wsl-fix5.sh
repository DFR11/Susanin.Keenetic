#!/bin/sh
# Временный скрипт: сборка после правок (token необязателен, oc+ не авто, мобильные списки).
set -u
cd "$(dirname "$0")" || exit 1

echo "== sh -n / shellcheck =="
sh -n install.sh bootstrap.sh && echo "  sh -n OK"
shellcheck -S error install.sh bootstrap.sh tools/*.sh >/dev/null 2>&1 && echo "  shellcheck OK"

echo "== host -Werror + тесты =="
make clean >/dev/null 2>&1 || true
make CC=gcc CFLAGS="-O2 -std=c11 -Wall -Wextra -Wpedantic -Werror" >/tmp/b.log 2>&1 \
    && echo "  сборка OK" || { echo "  ОШИБКА:"; tail -20 /tmp/b.log; exit 1; }
make test >/tmp/t.log 2>&1 && echo "  make test OK" || { echo "  тесты упали"; tail -12 /tmp/t.log; exit 1; }

echo "== 5 архитектур =="
sh tools/wsl-build.sh mipsel mips aarch64 armv7 x86_64 2>&1 | grep -E '^== building|delivered|warning:|error' | sed 's/^/  /'
for a in mipsel mips aarch64 armv7 x86_64; do printf '  %-8s ' "$a"; strings "build/susanin-agent.$a" | grep -m1 -o '0\.4\.0\.RC1'; done

echo "== dev-архив + .ipk + публикация =="
cp -f install.sh develop/install.sh
cp -f bootstrap.sh develop/bootstrap.sh
for f in README.md DEPLOY.md USER_GUIDE.md TROUBLESHOOTING.md XRAY.md CHANGELOG.md; do cp -f "$f" "develop/docs/$f"; done
cp -f www/style.css www/app.js www/config.js develop/www/ 2>/dev/null || true
rm -rf dist
sh tools/make-ipk.sh --bin build --out dist --publish-develop 2>&1 | tail -3 | sed 's/^/  /'
sh tools/repack-develop.sh 2>&1 | tail -2 | sed 's/^/  /'
( cd dist && sha256sum -c SHA256SUMS 2>&1 | grep -c ': OK$' | sed 's/^/  dist OK: /' )
( cd develop && sha256sum -c SHA256SUMS 2>&1 | grep -c ': OK$' | sed 's/^/  develop OK: /' )
( cd develop/ipk && sha256sum -c SHA256SUMS 2>&1 | grep -c ': OK$' | sed 's/^/  developipk OK: /')
