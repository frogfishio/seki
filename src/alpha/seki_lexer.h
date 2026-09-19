#ifndef SEKI_ALPHA_LEXER_H
#define SEKI_ALPHA_LEXER_H

#include <stddef.h>
#include <stdint.h>

enum seki_token_kind {
    SEKI_TOKEN_EOF,
    SEKI_TOKEN_IDENT,
    SEKI_TOKEN_NUMBER,
    SEKI_TOKEN_STRING,
    SEKI_TOKEN_DOT,
    SEKI_TOKEN_COLON,
    SEKI_TOKEN_COMMA,
    SEKI_TOKEN_AT,
    SEKI_TOKEN_LBRACE,
    SEKI_TOKEN_RBRACE,
    SEKI_TOKEN_LBRACKET,
    SEKI_TOKEN_RBRACKET,
    SEKI_TOKEN_LPAREN,
    SEKI_TOKEN_RPAREN,
    SEKI_TOKEN_DOUBLE_COLON,
    SEKI_TOKEN_ARROW,
    SEKI_TOKEN_BIND,
    SEKI_TOKEN_LESS,
    SEKI_TOKEN_LESS_EQUAL,
    SEKI_TOKEN_GREATER,
    SEKI_TOKEN_GREATER_EQUAL,
    SEKI_TOKEN_EQUAL,
    SEKI_TOKEN_NOT_EQUAL,
    SEKI_TOKEN_AND,
    SEKI_TOKEN_OR,
    SEKI_TOKEN_PLUS,
    SEKI_TOKEN_MINUS,
    SEKI_TOKEN_STAR,
    SEKI_TOKEN_SLASH,
    SEKI_TOKEN_PERCENT,
    SEKI_TOKEN_PIPE
};

struct seki_token {
    enum seki_token_kind kind;
    const unsigned char *start;
    size_t length;
    uint32_t number;
    size_t line;
    size_t column;
};

struct seki_lex_error {
    const char *code;
    const char *message;
    size_t line;
    size_t column;
};

struct seki_lexer {
    const unsigned char *source;
    size_t length;
    size_t offset;
    size_t line;
    size_t column;
    int failed;
};

void seki_lexer_init(struct seki_lexer *lexer,
    const unsigned char *source, size_t length);

int seki_lexer_next(struct seki_lexer *lexer, struct seki_token *token,
    struct seki_lex_error *error);

#endif

