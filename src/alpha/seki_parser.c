#include "seki_parser.h"

#include <string.h>

#include "seki_lexer.h"

struct parser {
    struct seki_lexer lexer;
    struct seki_token current;
    struct seki_parse_error *error;
    int failed;
};

int
seki_name_equal(const struct seki_name *left, const struct seki_name *right)
{
    return left->length == right->length &&
        memcmp(left->bytes, right->bytes, left->length) == 0;
}

int
seki_name_is(const struct seki_name *name, const char *text)
{
    const size_t length = strlen(text);
    return name->length == length && memcmp(name->bytes, text, length) == 0;
}

static int
token_is(const struct seki_token *token, const char *text)
{
    const size_t length = strlen(text);
    return token->kind == SEKI_TOKEN_IDENT && token->length == length &&
        memcmp(token->start, text, length) == 0;
}

static void
parser_fail(struct parser *parser, const char *code, const char *message)
{
    if (!parser->failed) {
        parser->failed = 1;
        parser->error->code = code;
        parser->error->message = message;
        parser->error->line = parser->current.line;
        parser->error->column = parser->current.column;
    }
}

static void
advance(struct parser *parser)
{
    struct seki_lex_error lex_error;
    if (parser->failed) {
        return;
    }
    if (!seki_lexer_next(&parser->lexer, &parser->current, &lex_error)) {
        parser->failed = 1;
        parser->error->code = lex_error.code;
        parser->error->message = lex_error.message;
        parser->error->line = lex_error.line;
        parser->error->column = lex_error.column;
    }
}

static void
expect_kind(struct parser *parser, enum seki_token_kind kind,
    const char *message)
{
    if (parser->failed) {
        return;
    }
    if (parser->current.kind != kind) {
        parser_fail(parser, "A0-PARSE-0001", message);
        return;
    }
    advance(parser);
}

static void
expect_word(struct parser *parser, const char *word)
{
    if (parser->failed) {
        return;
    }
    if (!token_is(&parser->current, word)) {
        parser_fail(parser, "A0-PARSE-0002", "expected header keyword");
        return;
    }
    advance(parser);
}

static struct seki_name
take_value_name(struct parser *parser)
{
    struct seki_name name = {NULL, 0U};
    if (parser->failed) {
        return name;
    }
    if (parser->current.kind != SEKI_TOKEN_IDENT ||
        parser->current.length == 0U || parser->current.start[0] < 'a' ||
        parser->current.start[0] > 'z') {
        parser_fail(parser, "A0-PARSE-0003",
            "expected lower-case value or module name");
        return name;
    }
    name.bytes = parser->current.start;
    name.length = parser->current.length;
    advance(parser);
    return name;
}

static uint32_t
take_number(struct parser *parser)
{
    uint32_t number = UINT32_C(0);
    if (parser->failed) {
        return number;
    }
    if (parser->current.kind != SEKI_TOKEN_NUMBER) {
        parser_fail(parser, "A0-PARSE-0004", "expected natural number");
        return number;
    }
    number = parser->current.number;
    advance(parser);
    return number;
}

static int
contains_name(const struct seki_name *names, size_t count,
    const struct seki_name *candidate)
{
    size_t index;
    for (index = 0U; index < count; index += 1U) {
        if (seki_name_equal(&names[index], candidate)) {
            return 1;
        }
    }
    return 0;
}

static void
parse_name_list(struct parser *parser, struct seki_name *names,
    size_t capacity, size_t *count, const char *following_keyword)
{
    for (;;) {
        struct seki_name name;
        if (*count == capacity) {
            parser_fail(parser, "A0-PARSE-0005",
                "header name list exceeds fixed capacity");
            return;
        }
        name = take_value_name(parser);
        if (parser->failed) {
            return;
        }
        if (seki_name_is(&name, following_keyword)) {
            parser_fail(parser, "A0-PARSE-0006", "header name list is empty");
            return;
        }
        if (contains_name(names, *count, &name)) {
            parser_fail(parser, "A0-PARSE-0007", "duplicate header name");
            return;
        }
        names[*count] = name;
        *count += 1U;
        if (parser->current.kind != SEKI_TOKEN_COMMA) {
            return;
        }
        advance(parser);
    }
}

int
seki_parse_module_header(const unsigned char *source, size_t length,
    struct seki_module_header *header, struct seki_parse_error *error)
{
    struct parser parser;

    if (source == NULL || header == NULL || error == NULL) {
        return 0;
    }
    memset(header, 0, sizeof *header);
    error->code = "A0-PARSE-0000";
    error->message = "invalid parser state";
    error->line = 0U;
    error->column = 0U;
    memset(&parser, 0, sizeof parser);
    parser.error = error;
    seki_lexer_init(&parser.lexer, source, length);
    advance(&parser);

    expect_word(&parser, "module");
    for (;;) {
        if (header->path_count == SEKI_HEADER_MAX_PATH_COMPONENTS) {
            parser_fail(&parser, "A0-PARSE-0008",
                "module path exceeds fixed capacity");
            break;
        }
        header->path[header->path_count++] = take_value_name(&parser);
        if (parser.failed || parser.current.kind != SEKI_TOKEN_DOUBLE_COLON) {
            break;
        }
        advance(&parser);
    }
    expect_kind(&parser, SEKI_TOKEN_AT, "expected module version marker");
    header->module_version = take_number(&parser);
    expect_word(&parser, "profile");
    expect_kind(&parser, SEKI_TOKEN_COLON, "expected profile colon");
    header->profile = take_value_name(&parser);
    expect_kind(&parser, SEKI_TOKEN_AT, "expected profile version marker");
    header->profile_version = take_number(&parser);
    expect_word(&parser, "claims");
    expect_kind(&parser, SEKI_TOKEN_COLON, "expected claims colon");
    parse_name_list(&parser, header->claims, SEKI_HEADER_MAX_CLAIMS,
        &header->claim_count, "requires");
    expect_word(&parser, "requires");
    expect_kind(&parser, SEKI_TOKEN_COLON, "expected requires colon");
    parse_name_list(&parser, header->requirements,
        SEKI_HEADER_MAX_REQUIREMENTS, &header->requirement_count, "");
    expect_kind(&parser, SEKI_TOKEN_DOT, "expected header terminator");

    if (!parser.failed && (header->path_count == 0U ||
        header->claim_count == 0U || header->requirement_count == 0U)) {
        parser_fail(&parser, "A0-PARSE-0006",
            "module header requires nonempty path, claims, and requirements");
    }
    return !parser.failed;
}

