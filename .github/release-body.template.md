Susanin.Keenetic {{TAG}}

### Установка (первый раз)

Пакетом Entware `.ipk` (рекомендуется; архитектура и SHA256 проверяются сами):
```sh
opkg update && opkg install ca-certificates wget-ssl
wget -qO- https://raw.githubusercontent.com/R17a/Susanin.Keenetic/main/install.sh | sh -s -- --ipk
```
Из tar-архива:
```sh
opkg update && opkg install ca-certificates ipset iptables conntrack wget-ssl
wget -qO- https://raw.githubusercontent.com/R17a/Susanin.Keenetic/main/install.sh | sh
```
Установщик определяет архитектуру, LAN/VPN и (при наличии) OpenConnect,
запрашивает подтверждение и запускает демон. Существующие `susanin.conf`,
`vpn_always.txt`, `vpn_never.txt` и кэш сохраняются.

### Обновление
```sh
opkg install /opt/tmp/susanin-keenetic_{{VER}}_<arch>.ipk   # если ставили .ipk
sh /opt/susanin/tools/susanin.sh update {{TAG}}             # если ставили архивом
```
`update` печатает `installed → target`, делает бэкап `susanin.conf` и
`susanin.state` в `/opt/susanin/var/backup/`, заменяет бинарь и скрипты,
**не трогая** `etc/` и `var/`, затем перезапускает демон.
Версию после обновления видно первой строкой в `susanin-agent status`.

### Удаление
```sh
sh /opt/susanin/tools/susanin.sh uninstall
sh /opt/susanin/tools/susanin.sh uninstall --purge
```

### Что нового
<!-- CHANGELOG -->
### Диагностика

Если что-то работает не так — сначала запустите диагностику: проверит окружение,
настройки и списки, выдаст рекомендации:
```sh
sh /opt/susanin/tools/diagnose.sh
```
Для отправки полного отчёта (логи, состояние) — соберите и приложите вывод:
```sh
sh /opt/susanin/tools/report.sh
# или без установки:
wget -qO- https://raw.githubusercontent.com/R17a/Susanin.Keenetic/{{TAG}}/tools/report.sh | sh
```
Отчёт сохраняется в `/opt/susanin/var/report.txt`.

### Сборки
- архивы: `susanin-keenetic-deploy-mipsel.tar.gz`, `…-mips.tar.gz`,
  `…-aarch64.tar.gz`, `…-armv7.tar.gz`, `…-x86_64.tar.gz` и `SHA256SUMS`;
- пакеты Entware: `susanin-keenetic_{{VER}}_mipsel-3.4.ipk`, `…_mips-3.4.ipk`,
  `…_aarch64-3.10.ipk`, `…_armv7sf-k3.2.ipk`, `…_x86-64.ipk` (`opkg install <файл>.ipk`).

**Проверено**: mipsel — Keenetic Viva, KeeneticOS 5.1.4–5.1.5, Entware
(+ клиент OpenConnect). Остальные архитектуры собраны и приложены готовыми
архивами, но на живом железе не тестировались — сообщайте об ошибках в Issues.

### Благодарности
За помощь проекту (тестирование на реальных роутерах, отчёты с логами, разбор
проблем) — спасибо **Gave_Karen**, **pegakmop**, **NJmist**.
