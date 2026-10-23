Susanin.Keenetic {{TAG}}

### Скачивание

Все файлы — в блоке **Assets** ниже. Имена:

| Архитектура Entware | Пакет `.ipk` | Архив |
|---|---|---|
| `mipsel-3.4` (Viva, Giga, Ultra…) | `susanin-keenetic_{{VER}}_mipsel-3.4.ipk` | `susanin-keenetic-deploy-mipsel.tar.gz` |
| `mips-3.4` | `susanin-keenetic_{{VER}}_mips-3.4.ipk` | `susanin-keenetic-deploy-mips.tar.gz` |
| `aarch64-3.10` | `susanin-keenetic_{{VER}}_aarch64-3.10.ipk` | `susanin-keenetic-deploy-aarch64.tar.gz` |
| `armv7sf-k3.2` | `susanin-keenetic_{{VER}}_armv7sf-k3.2.ipk` | `susanin-keenetic-deploy-armv7.tar.gz` |
| `x86-64` | `susanin-keenetic_{{VER}}_x86-64.ipk` | `susanin-keenetic-deploy-x86_64.tar.gz` |

Свою архитектуру показывает `opkg print-architecture | awk '{print $2}'`.
Скачать пакет и проверить SHA256 (пример для `mipsel-3.4`, подставьте свой):

```sh
cd /opt/tmp
wget https://github.com/R17a/Susanin.Keenetic/releases/download/{{TAG}}/susanin-keenetic_{{VER}}_mipsel-3.4.ipk
wget https://github.com/R17a/Susanin.Keenetic/releases/download/{{TAG}}/SHA256SUMS
sha256sum -c SHA256SUMS 2>/dev/null | grep mipsel-3.4    # ожидаем: ...: OK
```

Архив — так же: `wget .../{{TAG}}/susanin-keenetic-deploy-mipsel.tar.gz`.

### Установка (первый раз)

Пакетом Entware `.ipk` — установщик сам определит архитектуру, скачает пакет,
сверит SHA256 и поставит (рекомендуется):

```sh
opkg update && opkg install ca-certificates wget-ssl
wget -qO- https://raw.githubusercontent.com/R17a/Susanin.Keenetic/main/install.sh | sh -s -- --ipk
```

Вручную — скачать свой `.ipk` (см. «Скачивание») и поставить:

```sh
opkg install /opt/tmp/susanin-keenetic_{{VER}}_<arch>.ipk
```

Из tar-архива:

```sh
opkg update && opkg install ca-certificates ipset iptables conntrack wget-ssl
wget -qO- https://raw.githubusercontent.com/R17a/Susanin.Keenetic/main/install.sh | sh
```

Установщик определяет LAN/VPN и (при наличии) OpenConnect, запрашивает
подтверждение и запускает демон. Существующие `susanin.conf`, `vpn_always.txt`,
`vpn_never.txt` и кэш сохраняются.

### Обновление

```sh
# если ставили .ipk: скачать новый пакет (см. «Скачивание»), затем
opkg install /opt/tmp/susanin-keenetic_{{VER}}_<arch>.ipk

# если ставили архивом:
sh /opt/susanin/tools/susanin.sh update {{TAG}}
```

`--force` не нужен: версия новее установленной, конфиг и списки сохраняются.
`susanin.sh update` делает бэкап `susanin.conf`/`susanin.state` в
`/opt/susanin/var/backup/`, заменяет бинарь и скрипты, **не трогая** `etc/` и
`var/`, затем перезапускает демон. Версию после обновления видно первой строкой
в `susanin-agent status`.

### Удаление

```sh
opkg remove susanin-keenetic                          # если ставили .ipk (данные остаются)
sh /opt/susanin/tools/susanin.sh uninstall            # снять службу/правила, конфиг сохранить
sh /opt/susanin/tools/susanin.sh uninstall --purge    # удалить всё
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

5 архитектур: `mipsel`, `mips`, `aarch64`, `armv7`, `x86_64` — к релизу
приложены архивы `susanin-keenetic-deploy-<arch>.tar.gz`, пакеты
`susanin-keenetic_{{VER}}_<arch>.ipk` и общий `SHA256SUMS`.

**Проверено**: mipsel — Keenetic Viva, KeeneticOS 5.1.4–5.1.5, Entware
(+ клиент OpenConnect). Остальные архитектуры собраны и приложены готовыми
архивами, но на живом железе не тестировались — сообщайте об ошибках в Issues.

### Благодарности

За помощь проекту (тестирование на реальных роутерах, отчёты с логами, разбор
проблем) — спасибо **Gave_Karen**, **pegakmop**, **NJmist**.
