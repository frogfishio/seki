#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "seki_lexer.h"

static int
token_text_is(const struct seki_token *token, const char *text)
{
    const size_t length = strlen(text);
    return token->length == length && memcmp(token->start, text, length) == 0;
}

static int
check_sequence(void)
{
    static const unsigned char source[] =
        ";; first\r\nname::Type := 4294967295 -> \"00aF\" "
        ". , @ { } [ ] ( ) : < <= > >= == != && || + - * / % |";
    static const enum seki_token_kind expected[] = {
        SEKI_TOKEN_IDENT, SEKI_TOKEN_DOUBLE_COLON, SEKI_TOKEN_IDENT,
        SEKI_TOKEN_BIND, SEKI_TOKEN_NUMBER, SEKI_TOKEN_ARROW,
        SEKI_TOKEN_STRING, SEKI_TOKEN_DOT, SEKI_TOKEN_COMMA, SEKI_TOKEN_AT,
        SEKI_TOKEN_LBRACE, SEKI_TOKEN_RBRACE, SEKI_TOKEN_LBRACKET,
        SEKI_TOKEN_RBRACKET, SEKI_TOKEN_LPAREN, SEKI_TOKEN_RPAREN,
        SEKI_TOKEN_COLON, SEKI_TOKEN_LESS, SEKI_TOKEN_LESS_EQUAL,
        SEKI_TOKEN_GREATER, SEKI_TOKEN_GREATER_EQUAL, SEKI_TOKEN_EQUAL,
        SEKI_TOKEN_NOT_EQUAL, SEKI_TOKEN_AND, SEKI_TOKEN_OR,
        SEKI_TOKEN_PLUS, SEKI_TOKEN_MINUS, SEKI_TOKEN_STAR,
        SEKI_TOKEN_SLASH, SEKI_TOKEN_PERCENT, SEKI_TOKEN_PIPE,
        SEKI_TOKEN_EOF
    };
    struct seki_lexer lexer;
    struct seki_token token;
    struct seki_lex_error error;
    size_t index;

    seki_lexer_init(&lexer, source, sizeof source - 1U);
    for (index = 0U; index < sizeof expected / sizeof expected[0]; index += 1U) {
        if (!seki_lexer_next(&lexer, &token, &error) ||
            token.kind != expected[index]) {
            return 0;
        }
        if (index == 0U && (!token_text_is(&token, "name") ||
            token.line != 2U || token.column != 1U)) {
            return 0;
        }
        if (token.kind == SEKI_TOKEN_NUMBER && token.number != UINT32_MAX) {
            return 0;
        }
        if (token.kind == SEKI_TOKEN_STRING && !token_text_is(&token, "00aF")) {
            return 0;
        }
    }
    return 1;
}

static int
rejects(const char *source, const char *code)
{
    struct seki_lexer lexer;
    struct seki_token token;
    struct seki_lex_error error;

    seki_lexer_init(&lexer, (const unsigned char *)source, strlen(source));
    return !seki_lexer_next(&lexer, &token, &error) &&
        strcmp(error.code, code) == 0;
}

int
main(void)
{
    if (!check_sequence()) {
        return 1;
    }
    if (!rejects("4294967296", "A0-LEX-0001")) {
        return 2;
    }
    if (!rejects("\"xyz\"", "A0-LEX-0002")) {
        return 3;
    }
    if (!rejects("#", "A0-LEX-0003")) {
        return 4;
    }
    if (!rejects("=", "A0-LEX-0003")) {
        return 5;
    }
    return 0;
}

