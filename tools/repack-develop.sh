#!/bin/sh
# repack-develop.sh — пересобрать develop-дистрибутив после синхронизации:
#   1) пересчитать develop/SHA256SUMS;
#   2) перепаковать develop/susanin-keenetic-0.4.0-dev.tar.gz
#      (корень архива — susanin-keenetic-0.4.0-dev/, как в прежних сборках).
#
# Запускать ПОСЛЕ сборки бинарников (tools/wsl-build.sh) и раскладки их в
# develop/bin: иначе в архив попадут старые бинарники, а SHA256SUMS будет
# описывать новый набор файлов.
#
# Usage: sh tools/repack-develop.sh [--bin DIR]
#   --bin DIR — откуда взять бинарники (по умолчанию ../build)
set -eu

SRC=$(cd "$(dirname "$0")/.." && pwd)
DEV="$SRC/develop"
BINDIR="$SRC/build"
PKG=susanin-keenetic-0.4.0-dev

while [ $# -gt 0 ]; do
    case "$1" in
        --bin) BINDIR="$2"; shift 2 ;;
        -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "repack-develop: неизвестный параметр: $1" >&2; exit 2 ;;
    esac
done

[ -d "$DEV" ] || { echo "repack-develop: нет каталога $DEV" >&2; exit 1; }

# 1) Бинарники: develop/bin собирается из build/ (в git develop/bin не хранится —
# это была вторая копия тех же 5 файлов; build/ остаётся источником истины).
mkdir -p "$DEV/bin"
if [ -d "$BINDIR" ]; then
    for b in "$BINDIR"/susanin-agent.*; do
        [ -f "$b" ] || continue
        case "$b" in *.openwrt-*) continue ;; esac
        cp -f "$b" "$DEV/bin/"
        echo "repack-develop: bin/$(basename "$b") <- $(basename "$BINDIR")"
    done
fi

# 2) Проверка: в develop должно лежать ВСЁ из единого списка поставки
#    (packaging/manifest.txt) и ничего dev-only. Иначе архив уедет с дырой.
if [ -f "$SRC/tools/check-shipping.sh" ]; then
    if ! sh "$SRC/tools/check-shipping.sh" --develop "$DEV" >/tmp/susanin-ship.log 2>&1; then
        echo "repack-develop: состав develop расходится с packaging/manifest.txt:" >&2
        cat /tmp/susanin-ship.log >&2
        exit 1
    fi
fi

cd "$DEV"
LIST=$(mktemp 2>/dev/null || echo "/tmp/susanin-devlist.$$")
# ipk/ — «рабочая» публикация пакетов в ветке (её скачивает install.sh --ipk);
# в dev-архив её не кладём: он и так 2.5 МБ, а пакеты качаются по отдельности.
find . -type f ! -name SHA256SUMS ! -name "$PKG.tar.gz" ! -path "./xray/xray.*" \
    ! -path "./ipk/*" -print | sed 's|^\./||' | sort > "$LIST"

# 3) SHA256SUMS (пути — относительно корня пакета, как ждёт bootstrap.sh).
: > SHA256SUMS
while IFS= read -r f; do
    sha256sum "./$f" >> SHA256SUMS
done < "$LIST"
echo "repack-develop: SHA256SUMS ($(wc -l < SHA256SUMS) файлов)"

# 4) Архив: корневой каталог $PKG — как в прежних dev-сборках.
# Внутрь попадает и сам SHA256SUMS (bootstrap.sh проверяет по нему целостность),
# но сам список сумм его, конечно, не содержит.
rm -f "$PKG.tar.gz"
STAGE=$(mktemp -d 2>/dev/null || echo "/tmp/susanin-devpack.$$")
mkdir -p "$STAGE/$PKG"
{ cat "$LIST"; echo "SHA256SUMS"; } | tar -cf - -T - | tar -xf - -C "$STAGE/$PKG"
tar -czf "$PKG.tar.gz" -C "$STAGE" "$PKG"
rm -rf "$STAGE"
rm -f "$LIST"

echo "repack-develop: готово"
echo "  $DEV/$PKG.tar.gz ($(du -h "$DEV/$PKG.tar.gz" | awk '{print $1}'))"
echo "  $DEV/SHA256SUMS"
