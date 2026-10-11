#ifndef SUSANIN_WEB_CHOICES_H
#define SUSANIN_WEB_CHOICES_H

#include "config.h"

#include <stddef.h>

/* «Известные системе» значения для веб-панели (GET /api/choices).
 *
 * Панель показывает их выпадающим списком, чтобы интерфейсы, подсети,
 * таблицы маршрутизации, метки и файлы профилей выбирались, а не вводились
 * руками. Всё, что недоступно (нет /sys/class/net, нет `ip`, нет каталога
 * профилей), отдаётся пустыми массивами — без ошибок и без падений.
 *
 * Разбор («чистые» функции choice_*) отделён от обращений к системе
 * (collect_*), чтобы покрываться host-тестом без /sys и без root. */

#define CHOICE_MAX_IFACES 96
#define CHOICE_MAX_SUBNETS 128
#define CHOICE_MAX_TABLES 32
#define CHOICE_MAX_LISTS 64
#define CHOICE_MAX_FILE (1 << 20) /* кап на чтение susanin.conf (1 МиБ) */
#define CHOICE_MAX_USED_MARKS 16  /* столько профилей в конфиге быть не может */

/* Свободные fwmark для профилей: 0x40000000 + k*0x10000, k = 0..15. */
#define SUSANIN_MARK_BASE 0x40000000UL
#define SUSANIN_MARK_STEP 0x10000UL
#define SUSANIN_MARK_STEP_COUNT 16

/* Каталог со списками профилей (файлы *.txt) — подсказка панели. */
#define SUSANIN_PROFILES_LIST_DIR "/opt/susanin/etc/profiles"

#define CHOICE_NAME_MAX 32
#define CHOICE_KIND_MAX 16
#define CHOICE_VAL_MAX 300

typedef struct {
    char field[CHOICE_NAME_MAX];
    char value[CHOICE_VAL_MAX];
} choice_item;

typedef struct {
    choice_item ifaces[CHOICE_MAX_IFACES];
    size_t n_ifaces;
    choice_item subnets[CHOICE_MAX_SUBNETS];
    size_t n_subnets;
    choice_item tables[CHOICE_MAX_TABLES];
    size_t n_tables;
    choice_item lists[CHOICE_MAX_LISTS];
    size_t n_lists;
    choice_item used_marks[CHOICE_MAX_USED_MARKS];
    size_t n_used_marks;
} choice_set;

/* --- чистые функции (покрываются host-тестом) ------------------------- */

/* iface -> tunnel | bridge | physical (можно отдать и в JSON-поле). */
const char *choice_iface_kind(const char *name);

/* kind интерфейса по тому, что лежит в /sys/class/net/<if>/:
 * есть каталог bridge или DEVTYPE=bridge в uevent -> bridge,
 * имя из семейства туннелей -> tunnel, иначе physical.
 * uevent может быть NULL (не прочитался). */
const char *choice_dev_kind(const char *name, const char *uevent);

/* Разбор одной строки `ip -4 -o addr show`:
 * "2: eth0    inet 192.168.1.1/24 brd ... scope global eth0\..."
 * Имя интерфейса берётся из токена перед «\» (реальный формат) либо из
 * отдельного токена dev; если ни того, ни другого нет — 0 (не выдумываем).
 * Заполняет subnet ("192.168.1.1/24") и dev ("eth0"). 1 — разобрано. */
int choice_parse_dev(const char *line, char *subnet, size_t subsz,
                     char *dev, size_t devsz);

/* Разбор строки конфига "key=value" -> key/value (обрезанные по краям).
 * Комментарии и строки без '=' игнорируются. 1 — есть пара. */
int choice_parse_conf_line(const char *line, char *key, size_t keysz,
                           char *val, size_t valsz);

/* "0x40000000" -> 1 и *out; "profile1" или мусор -> 0. */
int choice_looks_like_mark(const char *tok, unsigned long *out);

/* Заполнена ли метка профиля (задан ключ profileN_mark). */
int choice_mark_used(unsigned long mark, const unsigned long *used, size_t n);

/* Кратчайший десятичный номер свободной метки из диапазона
 * 0x40000000..0x400f0000, пропуская занятые. -1 — свободных нет. */
int choice_mark_free_used(const unsigned long *used, size_t n);

/* --- сбор из системы ------------------------------------------------- */

/* ifaces: field = имя интерфейса, value = "up"/"down". Классификация (kind)
 * считается при сборке JSON: она требует /sys/class/net/<if>/uevent. */
void choice_json_init(choice_set *cs);
void collect_ifaces(choice_set *cs, const char *netdir);
void collect_subnets(choice_set *cs);
/* Занятые таблицы/метки из конфига: и разобранные профили (все слоты cfg,
 * не только n_profiles), и любой profileN_table/profileN_mark, найденный в
 * тексте файла (значение могло быть выставлено вручную). conf_path/ cfg
 * могут быть NULL. */
void collect_used(choice_set *cs, const char *conf_path,
                  const susanin_config *cfg);
void collect_list_files(choice_set *cs, const char *dir);

/* --- ответ ------------------------------------------------------------ */

/* Какие источники опрашивать. Панель включает все; host-тест — только те,
 * что не зависят от системы (иначе тест звал бы `ip` и /sys). */
#define WC_SRC_IFACES 0x1 /* /sys/class/net */
#define WC_SRC_SUBNETS 0x2 /* `ip -4 -o addr show` */
#define WC_SRC_USED 0x4   /* susanin.conf: занятые таблицы/метки */
#define WC_SRC_LISTS 0x8  /* каталог списков профилей */
#define WC_SRC_ALL 0xF

/* JSON для GET /api/choices. src — битовая маска WC_SRC_*. Возврат: число
 * записанных байт (без NUL); 0 — не удалось собрать (нет памяти, пустой
 * буфер или ответ не поместился), вызывающий отдаёт пустой объект. */
size_t wc_write_json_src(const susanin_config *cfg, const char *conf_path,
                         const char *netdir, const char *listdir,
                         unsigned src, char *out, size_t outsz);

/* То же со всеми источниками (то, что отдаёт GET /api/choices). */
size_t wc_write_json(const susanin_config *cfg, const char *conf_path,
                     const char *netdir, const char *listdir,
                     char *out, size_t outsz);

/* Каталог для collect_list_files (подсказка панели тем же значением). */
const char *wc_list_dir(void);

#endif
