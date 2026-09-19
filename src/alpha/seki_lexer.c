#include "seki_lexer.h"

#include <limits.h>

static int
ascii_alpha(unsigned char value)
{
    return (value >= (unsigned char)'a' && value <= (unsigned char)'z') ||
        (value >= (unsigned char)'A' && value <= (unsigned char)'Z');
}

static int
ascii_digit(unsigned char value)
{
    return value >= (unsigned char)'0' && value <= (unsigned char)'9';
}

static int
ascii_hex(unsigned char value)
{
    return ascii_digit(value) ||
        (value >= (unsigned char)'a' && value <= (unsigned char)'f') ||
        (value >= (unsigned char)'A' && value <= (unsigned char)'F');
}

static int
ascii_ident_rest(unsigned char value)
{
    return ascii_alpha(value) || ascii_digit(value) ||
        value == (unsigned char)'_';
}

static void
advance_regular(struct seki_lexer *lexer)
{
    lexer->offset += 1U;
    lexer->column += 1U;
}

static void
skip_trivia(struct seki_lexer *lexer)
{
    for (;;) {
        while (lexer->offset < lexer->length) {
            const unsigned char value = lexer->source[lexer->offset];
            if (value == (unsigned char)' ' || value == (unsigned char)'\t') {
                advance_regular(lexer);
            } else if (value == (unsigned char)'\r') {
                lexer->offset += 1U;
                if (lexer->offset < lexer->length &&
                    lexer->source[lexer->offset] == (unsigned char)'\n') {
                    lexer->offset += 1U;
                }
                lexer->line += 1U;
                lexer->column = 1U;
            } else if (value == (unsigned char)'\n') {
                lexer->offset += 1U;
                lexer->line += 1U;
                lexer->column = 1U;
            } else {
                break;
            }
        }
        if (lexer->offset + 1U < lexer->length &&
            lexer->source[lexer->offset] == (unsigned char)';' &&
            lexer->source[lexer->offset + 1U] == (unsigned char)';') {
            while (lexer->offset < lexer->length &&
                lexer->source[lexer->offset] != (unsigned char)'\r' &&
                lexer->source[lexer->offset] != (unsigned char)'\n') {
                advance_regular(lexer);
            }
            continue;
        }
        return;
    }
}

static int
fail(struct seki_lexer *lexer, struct seki_lex_error *error,
    size_t line, size_t column, const char *code, const char *message)
{
    lexer->failed = 1;
    error->code = code;
    error->message = message;
    error->line = line;
    error->column = column;
    return 0;
}

static void
set_simple(struct seki_token *token, enum seki_token_kind kind,
    const unsigned char *start, size_t length, size_t line, size_t column)
{
    token->kind = kind;
    token->start = start;
    token->length = length;
    token->number = UINT32_C(0);
    token->line = line;
    token->column = column;
}

void
seki_lexer_init(struct seki_lexer *lexer,
    const unsigned char *source, size_t length)
{
    lexer->source = source;
    lexer->length = length;
    lexer->offset = 0U;
    lexer->line = 1U;
    lexer->column = 1U;
    lexer->failed = 0;
}

int
seki_lexer_next(struct seki_lexer *lexer, struct seki_token *token,
    struct seki_lex_error *error)
{
    const unsigned char *start;
    unsigned char value;
    size_t line;
    size_t column;

    if (lexer->failed) {
        return fail(lexer, error, lexer->line, lexer->column,
            "A0-LEX-0004", "lexer called after failure");
    }
    skip_trivia(lexer);
    line = lexer->line;
    column = lexer->column;
    if (lexer->offset == lexer->length) {
        set_simple(token, SEKI_TOKEN_EOF, lexer->source + lexer->offset,
            0U, line, column);
        return 1;
    }
    start = lexer->source + lexer->offset;
    value = *start;
    if (ascii_alpha(value) || value == (unsigned char)'_') {
        advance_regular(lexer);
        while (lexer->offset < lexer->length &&
            ascii_ident_rest(lexer->source[lexer->offset])) {
            advance_regular(lexer);
        }
        set_simple(token, SEKI_TOKEN_IDENT, start,
            (size_t)((lexer->source + lexer->offset) - start), line, column);
        return 1;
    }
    if (ascii_digit(value)) {
        uint32_t number = UINT32_C(0);
        do {
            const uint32_t digit =
                (uint32_t)(lexer->source[lexer->offset] - (unsigned char)'0');
            if (number > (UINT32_MAX - digit) / UINT32_C(10)) {
                return fail(lexer, error, line, column, "A0-LEX-0001",
                    "integer literal exceeds U32");
            }
            number = number * UINT32_C(10) + digit;
            advance_regular(lexer);
        } while (lexer->offset < lexer->length &&
            ascii_digit(lexer->source[lexer->offset]));
        set_simple(token, SEKI_TOKEN_NUMBER, start,
            (size_t)((lexer->source + lexer->offset) - start), line, column);
        token->number = number;
        return 1;
    }
    if (value == (unsigned char)'"') {
        advance_regular(lexer);
        start = lexer->source + lexer->offset;
        while (lexer->offset < lexer->length &&
            ascii_hex(lexer->source[lexer->offset])) {
            advance_regular(lexer);
        }
        if (lexer->source + lexer->offset == start ||
            lexer->offset == lexer->length ||
            lexer->source[lexer->offset] != (unsigned char)'"') {
            return fail(lexer, error, line, column, "A0-LEX-0002",
                "string literal must contain nonempty hexadecimal bytes");
        }
        set_simple(token, SEKI_TOKEN_STRING, start,
            (size_t)((lexer->source + lexer->offset) - start), line, column);
        advance_regular(lexer);
        return 1;
    }

#define SIMPLE(character, token_kind) \
    case character: \
        advance_regular(lexer); \
        set_simple(token, token_kind, start, 1U, line, column); \
        return 1

    switch (value) {
    SIMPLE('.', SEKI_TOKEN_DOT);
    SIMPLE(',', SEKI_TOKEN_COMMA);
    SIMPLE('@', SEKI_TOKEN_AT);
    SIMPLE('{', SEKI_TOKEN_LBRACE);
    SIMPLE('}', SEKI_TOKEN_RBRACE);
    SIMPLE('[', SEKI_TOKEN_LBRACKET);
    SIMPLE(']', SEKI_TOKEN_RBRACKET);
    SIMPLE('(', SEKI_TOKEN_LPAREN);
    SIMPLE(')', SEKI_TOKEN_RPAREN);
    SIMPLE('+', SEKI_TOKEN_PLUS);
    SIMPLE('*', SEKI_TOKEN_STAR);
    SIMPLE('/', SEKI_TOKEN_SLASH);
    SIMPLE('%', SEKI_TOKEN_PERCENT);
    case ':':
        advance_regular(lexer);
        if (lexer->offset < lexer->length &&
            lexer->source[lexer->offset] == (unsigned char)':') {
            advance_regular(lexer);
            set_simple(token, SEKI_TOKEN_DOUBLE_COLON, start, 2U, line, column);
        } else if (lexer->offset < lexer->length &&
            lexer->source[lexer->offset] == (unsigned char)'=') {
            advance_regular(lexer);
            set_simple(token, SEKI_TOKEN_BIND, start, 2U, line, column);
        } else {
            set_simple(token, SEKI_TOKEN_COLON, start, 1U, line, column);
        }
        return 1;
    case '-':
        advance_regular(lexer);
        if (lexer->offset < lexer->length &&
            lexer->source[lexer->offset] == (unsigned char)'>') {
            advance_regular(lexer);
            set_simple(token, SEKI_TOKEN_ARROW, start, 2U, line, column);
        } else {
            set_simple(token, SEKI_TOKEN_MINUS, start, 1U, line, column);
        }
        return 1;
    case '<':
    case '>': {
        const enum seki_token_kind plain = value == (unsigned char)'<'
            ? SEKI_TOKEN_LESS : SEKI_TOKEN_GREATER;
        const enum seki_token_kind equal = value == (unsigned char)'<'
            ? SEKI_TOKEN_LESS_EQUAL : SEKI_TOKEN_GREATER_EQUAL;
        advance_regular(lexer);
        if (lexer->offset < lexer->length &&
            lexer->source[lexer->offset] == (unsigned char)'=') {
            advance_regular(lexer);
            set_simple(token, equal, start, 2U, line, column);
        } else {
            set_simple(token, plain, start, 1U, line, column);
        }
        return 1;
    }
    case '=':
    case '!':
    case '&':
        advance_regular(lexer);
        if (lexer->offset < lexer->length &&
            lexer->source[lexer->offset] ==
                (value == (unsigned char)'&' ? (unsigned char)'&' :
                    (unsigned char)'=')) {
            const enum seki_token_kind kind = value == (unsigned char)'='
                ? SEKI_TOKEN_EQUAL : value == (unsigned char)'!'
                    ? SEKI_TOKEN_NOT_EQUAL : SEKI_TOKEN_AND;
            advance_regular(lexer);
            set_simple(token, kind, start, 2U, line, column);
            return 1;
        }
        break;
    case '|':
        advance_regular(lexer);
        if (lexer->offset < lexer->length &&
            lexer->source[lexer->offset] == (unsigned char)'|') {
            advance_regular(lexer);
            set_simple(token, SEKI_TOKEN_OR, start, 2U, line, column);
        } else {
            set_simple(token, SEKI_TOKEN_PIPE, start, 1U, line, column);
        }
        return 1;
    default:
        break;
    }
#undef SIMPLE

    return fail(lexer, error, line, column, "A0-LEX-0003",
        "unsupported or incomplete token");
}
