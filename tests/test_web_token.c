/* Тесты проверки токена веб-панели (0.4.0.RC1, правки по ревью):
 *  - token_eq: сравнение за постоянное время (равные/разные/префикс/пустой);
 *  - header_value: заголовок ищется ТОЛЬКО в блоке заголовков (не в URL/теле) и
 *    без учёта регистра имени;
 *  - cookie_value: cookie берётся из заголовка Cookie, а не из строки запроса.
 * web.c включается в TU, чтобы дотянуться до static-функций.
 * Запуск: make test (хост-компилятор).
 */
#define _GNU_SOURCE
#include "web.c"

#include <stdio.h>
#include <string.h>

static int failures = 0;
#define CHECK(cond, msg) do { if (cond) printf("ok  %s\n", msg); \
    else { printf("FAIL %s\n", msg); failures++; } } while (0)

int main(void)
{
    char v[128];

    printf("=== token_eq ===\n");
    CHECK(token_eq("secret", "secret") == 1, "равные токены");
    CHECK(token_eq("secret", "secreT") == 0, "разный регистр — не равны");
    CHECK(token_eq("secret", "secre") == 0, "префикс не проходит");
    CHECK(token_eq("secret", "secret2") == 0, "длиннее — не проходит");
    CHECK(token_eq("", "") == 1, "две пустые строки равны");
    CHECK(token_eq("secret", "") == 0, "пустой против непустого");

    printf("=== header_value ===\n");
    {
        const char *req =
            "GET /api/status HTTP/1.1\r\n"
            "Host: 192.168.1.1:8087\r\n"
            "X-Auth-Token: secret\r\n"
            "Cookie: a=1; susanin_token=cookietok; b=2\r\n"
            "\r\n";
        CHECK(header_value(req, "X-Auth-Token", v, sizeof(v)) == 1 && !strcmp(v, "secret"),
              "X-Auth-Token из заголовков");
        CHECK(header_value(req, "x-auth-token", v, sizeof(v)) == 1 && !strcmp(v, "secret"),
              "имя заголовка без учёта регистра");
        CHECK(cookie_value(req, "susanin_token", v, sizeof(v)) == 1 && !strcmp(v, "cookietok"),
              "cookie susanin_token");
        CHECK(cookie_value(req, "other", v, sizeof(v)) == 0, "нет такой cookie");
    }

    printf("=== подделка токена в URL/теле не проходит ===\n");
    {
        const char *req =
            "GET /?x=susanin_token=secret HTTP/1.1\r\n"
            "Host: 192.168.1.1\r\n"
            "\r\n"
            "susanin_token=secret";
        CHECK(header_value(req, "X-Auth-Token", v, sizeof(v)) == 0,
              "в заголовках токена нет");
        CHECK(cookie_value(req, "susanin_token", v, sizeof(v)) == 0,
              "в Cookie токена нет — URL/тело не считаются");
    }

    printf("=== пустые запросы не ломают разбор ===\n");
    CHECK(header_value("", "X-Auth-Token", v, sizeof(v)) == 0, "пустой запрос — нет заголовка");
    CHECK(cookie_value("GET / HTTP/1.1\r\n\r\n", "susanin_token", v, sizeof(v)) == 0,
          "нет Cookie — нет значения");

    printf("\n%s (%d fail)\n", failures ? "FAILED" : "ALL OK", failures);
    return failures ? 1 : 0;
}
