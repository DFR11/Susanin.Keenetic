Susanin.Keenetic — сборка 0.4.0

Точную версию/сборку смотрите в выводе `susanin-agent version` и в report.txt.

Это сборка 0.4.0 (архив сохранил прежнее имя `…-0.4.0-dev.tar.gz`; содержимое
соответствует релизу 0.4.0). В ней: XRay-egress (VLESS/REALITY), веб-панель
(в том числе Memo-редактор списков — правка всего файла текстом), профили
маршрутизации, совместимость с qWDTT (включая режим «клиенты qWDTT через Susanin»),
возврат на основной VPN (failback), watchdog Xray и лимит памяти, DNS-снифинг,
dns_hijack для клиентов OpenConnect, пресет порогов `precision`. Обычный режим
(VPN из «Других подключений») работает как раньше.

Важно про бэкапы: снимок правил — ОДИН каталог `/opt/susanin/var/datapath.bak`,
бэкап списка — один `<список>.txt.bak`; копии перезаписываются и не накапливаются.

Документация (папка docs/):
  README.md          — обзор и установка (то же, что на GitHub)
  DEPLOY.md          — установка/обновление/удаление
  TROUBLESHOOTING.md — если что-то не работает
  USER_GUIDE.md      — быстрый старт и настройки
  XRAY.md            — про XRay подробно
  TESTBUILD.md       — dev-заметки (в релизный .ipk не входит)

Перед установкой на роутере нужен Entware с пакетами
ca-certificates ipset iptables conntrack wget-ssl:
  opkg update && opkg install ca-certificates ipset iptables conntrack wget-ssl

Рекомендуется пакет .ipk (обновление через opkg, данные не перезаписываются).
Установщик сам определит архитектуру и поставит пакет из последнего релиза:
  wget -qO- https://raw.githubusercontent.com/R17a/Susanin.Keenetic/main/install.sh | sh -s -- --ipk
Плюс Xray для VLESS/REALITY: добавьте --with-xray-tproxy.

Установка из этого архива (работает и на старых BusyBox, где tar не знает --exclude):
  cd /opt/tmp
  wget -qO- https://raw.githubusercontent.com/R17a/Susanin.Keenetic/main/bootstrap.sh | sh -s -- --yes

  Варианты (если сохранить файл susanin-install.sh рядом):
    sh susanin-install.sh --check                 # arch/ядро/BusyBox, без установки
    sh susanin-install.sh --file <архив> --yes    # из скачанного архива
    sh susanin-install.sh --channel stable --yes  # последний релиз
    sh susanin-install.sh --with-xray --yes       # + Xray для tproxy

Установка из распакованного архива (без интернета):
  1) tar -xzf susanin-keenetic-0.4.0-dev.tar.gz && cd susanin-keenetic-0.4.0-dev
  2) sh install.sh --yes
     (бинарник под вашу архитектуру install.sh выберет сам; конфиг и списки
      susanin.conf / vpn_always.txt / vpn_never.txt при обновлении не перезаписываются)
  3) Проверить: sh /opt/susanin/tools/susanin.sh status
               /opt/susanin/bin/susanin-agent version

Структура пакета:
  install.sh      установщик (запускать из корня пакета)
  bin/            susanin-agent.<arch> (mips, mipsel, aarch64, armv7, x86_64)
  tools/          скрипты (susanin.sh, datapath.sh, xray-egress.sh, ...)
  etc/            config.example.conf, cdn_ranges.txt, xray-tproxy.json.example, vpn_always/never.txt
  init/           S93xray-tproxy, S94susanin, S95susanin-web
  www/            файлы веб-панели
  xray/           README.txt, SHA256SUMS, LICENSE (бинарников Xray в архиве нет —
                  они лежат в репозитории, develop/xray/; ставит их --with-xray)
  docs/           документация

Благодарности: за помощь проекту (тестирование на реальных роутерах, отчёты с
логами, разбор проблем) — Gave_Karen, pegakmop, NJmist.
