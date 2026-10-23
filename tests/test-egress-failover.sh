#!/bin/sh
# Тест логики tools/egress-failover.sh (резервный egress через Xray).
# Ничего не требует от системы: /opt/susanin подменяется переменными окружения,
# ping/agent/Xray — заглушками. Запуск: sh tests/test-egress-failover.sh
set -u

SRC=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SH="$SRC/tools/egress-failover.sh"
[ -f "$SH" ] || { echo "не найден $SH"; exit 1; }

T=$(mktemp -d "${TMPDIR:-/tmp}/susanin-failover-test.XXXXXX") || exit 1
trap 'rm -rf "$T"' EXIT INT TERM

FAIL=0
ck() { # ck <описание> <ожидаемое> <фактическое>
    if [ "$2" = "$3" ]; then
        echo "  ok   $1"
    else
        echo "  FAIL $1: ожидалось '$2', получено '$3'"
        FAIL=1
    fi
}
mode_now() { sed -n 's/^egress_type=//p' "$T/etc/susanin.conf"; }
set_mode() { sed -i "s/^egress_type=.*/egress_type=$1/" "$T/etc/susanin.conf"; }

mkdir -p "$T/bin" "$T/etc" "$T/var"
cat > "$T/etc/susanin.conf" <<'EOF'
# тестовый конфиг
egress_type=interface
egress_interface=nwg1
tproxy_port=12345
mark_ok=0x20000000
mark_mask=0x30000000
EOF
cat > "$T/etc/failover.conf" <<'EOF'
enable=1
primary=
probe=1.1.1.1 8.8.8.8
interval=1
miss=2
recover=2
cooldown=0
boot_grace=0
keep_xray=0
iface_check=0
EOF

# Заглушка ping: результат определяется наличием файла-флага.
cat > "$T/bin/ping" <<EOF
#!/bin/sh
[ -f "$T/ok" ] && exit 0
exit 1
EOF
chmod +x "$T/bin/ping"
# xray_init — заглушка (реальный init-скрипт на тестовой машине не нужен),
# xray_wait=1 — чтобы отказ «порт не слушается» проверялся за секунду, а не 25.
printf 'xray_wait=1\nxray_init=%s/no-init\n' "$T" >> "$T/etc/failover.conf"

PATH="$T/bin:$PATH"
export PATH
export SUSANIN_CONF="$T/etc/susanin.conf"
export FAILOVER_CONF="$T/etc/failover.conf"
export SUSANIN_VAR="$T/var"
export SUSANIN_XRAY_BIN="$T/no-xray"        # Xray «не установлен»
export SUSANIN_XRAY_CFG="$T/no-xray.json"
export SUSANIN_SH="$T/no-agent.sh"

echo "1) конфиг и статус"
out=$(sh "$SH" status)
case "$out" in *"failover:     ENABLED"*) ck "enable распознан" 0 0 ;; *) ck "enable распознан" 0 1 ;; esac
case "$out" in *"primary iface: nwg1"*) ck "primary взят из egress_interface" 0 0 ;; *) ck "primary взят из egress_interface" 0 1 ;; esac

echo "2) Xray недоступен -> переключение ОТМЕНЕНО (нет чёрной дыры)"
rm -f "$T/ok"
sh "$SH" once >/dev/null 2>&1
ck "после 1 неудачи режим не менялся" "interface" "$(mode_now)"
ck "счётчик fails=1" "1" "$(sed -n 's/^fails=//p' "$T/var/failover.state")"
sh "$SH" once >/dev/null 2>&1
ck "после 2 неудач режим всё ещё interface" "interface" "$(mode_now)"
grep -q "ОТКАЗ: нет" "$T/var/failover.log" 2>/dev/null && ck "в логе отказ из-за отсутствия Xray" 0 0 || ck "в логе отказ из-за отсутствия Xray" 0 1
ck "конфиг не переписан при отказе" "interface" "$(mode_now)"

echo "3) Xray доступен -> уход в tproxy"
printf '#!/bin/sh\nexit 0\n' > "$T/no-xray"; chmod +x "$T/no-xray"; : > "$T/no-xray.json"
# порт tproxy «слушается»: подсовываем свой /proc/net/tcp нельзя, поэтому
# используем реальный сценарий отказа (порт не слушается) — он тоже важен.
sh "$SH" once >/dev/null 2>&1
ck "порт не слушается -> режим НЕ менялся" "interface" "$(mode_now)"
grep -q "не слушает" "$T/var/failover.log" 2>/dev/null && ck "в логе отказ из-за порта" 0 0 || ck "в логе отказ из-за порта" 0 1

echo "4) режим tproxy + живой основной -> возврат в interface"
: > "$T/ok"
set_mode tproxy
sh "$SH" once >/dev/null 2>&1
ck "после 1 успеха ещё tproxy" "tproxy" "$(mode_now)"
sh "$SH" once >/dev/null 2>&1
ck "после recover успехов вернулись в interface" "interface" "$(mode_now)"
grep -q "возвращаю egress_type=interface" "$T/var/failover.log" 2>/dev/null && ck "в логе возврат" 0 0 || ck "в логе возврат" 0 1
ck "создан бэкап susanin.conf" "yes" "$([ -f "$T/etc/susanin.conf.failover-bak" ] && echo yes || echo no)"

echo "5) enable=0 -> режим не трогаем"
sed -i 's/^enable=.*/enable=0/' "$T/etc/failover.conf"
set_mode tproxy
rm -f "$T/ok"
sh "$SH" once >/dev/null 2>&1
ck "режим не тронут при enable=0" "tproxy" "$(mode_now)"

echo "6) детектор LISTEN-порта (awk по /proc/net/tcp)"
AWK_OK='length($2) >= 5 && substr($2, length($2)-4) == h && $4 == "0A" { n++ } END { exit !(n > 0) }'
printf '  sl  local_address rem_address   st\n   0: 0100007F:3039 00000000:0000 0A 00:00000000 00:00000000 00000000\n' > "$T/tcp_listen"
printf '   0: 0100007F:3039 00000000:0000 01 00:00000000 00:00000000 00000000\n' > "$T/tcp_estab"
awk -v h=":3039" "$AWK_OK" "$T/tcp_listen" && ck "LISTEN найден" 0 0 || ck "LISTEN найден" 0 1
awk -v h=":3039" "$AWK_OK" "$T/tcp_estab" && ck "не-LISTEN не считается" 0 1 || ck "не-LISTEN не считается" 0 0
awk -v h=":3039" "$AWK_OK" /dev/null && ck "пустой файл не считается" 0 1 || ck "пустой файл не считается" 0 0
awk -v h=":3039" "$AWK_OK" "$T/tcp_listen" >/dev/null 2>&1
printf '   0: 00000000000000000000000000000000:3039 00000000000000000000000000000000:0000 0A 00:00000000 00:00000000 00000000\n' > "$T/tcp6_listen"
awk -v h=":3039" "$AWK_OK" "$T/tcp6_listen" && ck "LISTEN на IPv6 найден" 0 0 || ck "LISTEN на IPv6 найден" 0 1

echo
if [ "$FAIL" = 0 ]; then echo "ИТОГ: все проверки пройдены"; else echo "ИТОГ: ЕСТЬ ОШИБКИ"; fi
exit "$FAIL"
