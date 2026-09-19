/*
 * E0-VS1 closed-subset Seki frontend.
 *
 * Experimental only: this recognizes and type-checks the language slice used
 * by minimum_age.seki and emits its SCB-0 candidate. It is not the v0 compiler.
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum token_kind {
    TOKEN_EOF,
    TOKEN_IDENT,
    TOKEN_NUMBER,
    TOKEN_DOT,
    TOKEN_COLON,
    TOKEN_COMMA,
    TOKEN_AT,
    TOKEN_LBRACE,
    TOKEN_RBRACE,
    TOKEN_LBRACKET,
    TOKEN_RBRACKET,
    TOKEN_LPAREN,
    TOKEN_RPAREN,
    TOKEN_DOUBLE_COLON,
    TOKEN_ARROW,
    TOKEN_LESS
};

struct token {
    enum token_kind kind;
    const unsigned char *start;
    size_t length;
    uint32_t number;
    size_t line;
    size_t column;
};

struct parser {
    const unsigned char *source;
    size_t length;
    size_t offset;
    size_t line;
    size_t column;
    struct token current;
    int failed;
    const char *reason;
};

struct module {
    uint32_t threshold;
    uint32_t declared_steps;
    uint32_t declared_live;
    uint32_t declared_depth;
    uint32_t declared_workspace;
};

struct buffer {
    unsigned char bytes[2048];
    size_t length;
    int failed;
};

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
ascii_ident_rest(unsigned char value)
{
    return ascii_alpha(value) || ascii_digit(value) || value == (unsigned char)'_';
}

static void
advance_byte(struct parser *parser)
{
    const unsigned char value = parser->source[parser->offset];
    parser->offset += 1U;
    if (value == (unsigned char)'\n') {
        parser->line += 1U;
        parser->column = 1U;
    } else {
        parser->column += 1U;
    }
}

static void
skip_trivia(struct parser *parser)
{
    for (;;) {
        while (parser->offset < parser->length) {
            const unsigned char value = parser->source[parser->offset];
            if (value != (unsigned char)' ' && value != (unsigned char)'\t' &&
                value != (unsigned char)'\r' && value != (unsigned char)'\n') {
                break;
            }
            advance_byte(parser);
        }
        if (parser->offset + 1U < parser->length &&
            parser->source[parser->offset] == (unsigned char)';' &&
            parser->source[parser->offset + 1U] == (unsigned char)';') {
            while (parser->offset < parser->length &&
                parser->source[parser->offset] != (unsigned char)'\n') {
                advance_byte(parser);
            }
            continue;
        }
        break;
    }
}

static void
fail_at(struct parser *parser, const char *reason)
{
    if (!parser->failed) {
        parser->failed = 1;
        parser->reason = reason;
    }
}

static void
next_token(struct parser *parser)
{
    const unsigned char *start;
    size_t token_line;
    size_t token_column;
    unsigned char value;

    if (parser->failed) {
        return;
    }
    skip_trivia(parser);
    token_line = parser->line;
    token_column = parser->column;
    if (parser->offset == parser->length) {
        parser->current = (struct token){
            TOKEN_EOF, parser->source + parser->offset, 0U, UINT32_C(0),
            token_line, token_column
        };
        return;
    }
    start = parser->source + parser->offset;
    value = *start;
    if (ascii_alpha(value) || value == (unsigned char)'_') {
        advance_byte(parser);
        while (parser->offset < parser->length &&
            ascii_ident_rest(parser->source[parser->offset])) {
            advance_byte(parser);
        }
        parser->current = (struct token){
            TOKEN_IDENT, start, (size_t)((parser->source + parser->offset) - start),
            UINT32_C(0), token_line, token_column
        };
        return;
    }
    if (ascii_digit(value)) {
        uint32_t number = UINT32_C(0);
        advance_byte(parser);
        number = (uint32_t)(value - (unsigned char)'0');
        while (parser->offset < parser->length &&
            ascii_digit(parser->source[parser->offset])) {
            const uint32_t digit =
                (uint32_t)(parser->source[parser->offset] - (unsigned char)'0');
            if (number > (UINT32_MAX - digit) / UINT32_C(10)) {
                fail_at(parser, "integer literal exceeds U32");
                return;
            }
            number = number * UINT32_C(10) + digit;
            advance_byte(parser);
        }
        parser->current = (struct token){
            TOKEN_NUMBER, start, (size_t)((parser->source + parser->offset) - start),
            number, token_line, token_column
        };
        return;
    }
    advance_byte(parser);
    parser->current = (struct token){
        TOKEN_EOF, start, 1U, UINT32_C(0), token_line, token_column
    };
    switch (value) {
    case '.': parser->current.kind = TOKEN_DOT; return;
    case ',': parser->current.kind = TOKEN_COMMA; return;
    case '@': parser->current.kind = TOKEN_AT; return;
    case '{': parser->current.kind = TOKEN_LBRACE; return;
    case '}': parser->current.kind = TOKEN_RBRACE; return;
    case '[': parser->current.kind = TOKEN_LBRACKET; return;
    case ']': parser->current.kind = TOKEN_RBRACKET; return;
    case '(': parser->current.kind = TOKEN_LPAREN; return;
    case ')': parser->current.kind = TOKEN_RPAREN; return;
    case '<': parser->current.kind = TOKEN_LESS; return;
    case ':':
        if (parser->offset < parser->length &&
            parser->source[parser->offset] == (unsigned char)':') {
            advance_byte(parser);
            parser->current.kind = TOKEN_DOUBLE_COLON;
            parser->current.length = 2U;
        } else {
            parser->current.kind = TOKEN_COLON;
        }
        return;
    case '-':
        if (parser->offset < parser->length &&
            parser->source[parser->offset] == (unsigned char)'>') {
            advance_byte(parser);
            parser->current.kind = TOKEN_ARROW;
            parser->current.length = 2U;
            return;
        }
        break;
    default:
        break;
    }
    fail_at(parser, "unsupported character in E0 source");
}

static int
token_is(const struct token *token, const char *text)
{
    const size_t length = strlen(text);
    return token->kind == TOKEN_IDENT && token->length == length &&
        memcmp(token->start, text, length) == 0;
}

static void
expect_kind(struct parser *parser, enum token_kind kind, const char *reason)
{
    if (parser->failed) {
        return;
    }
    if (parser->current.kind != kind) {
        fail_at(parser, reason);
        return;
    }
    next_token(parser);
}

static void
expect_ident(struct parser *parser, const char *text)
{
    if (parser->failed) {
        return;
    }
    if (!token_is(&parser->current, text)) {
        fail_at(parser, "unexpected identifier in closed E0 subset");
        return;
    }
    next_token(parser);
}

static uint32_t
expect_number(struct parser *parser)
{
    uint32_t result = UINT32_C(0);
    if (parser->failed) {
        return result;
    }
    if (parser->current.kind != TOKEN_NUMBER) {
        fail_at(parser, "expected natural number");
        return result;
    }
    result = parser->current.number;
    next_token(parser);
    return result;
}

static void
expect_qualified(struct parser *parser, const char *owner, const char *member)
{
    expect_ident(parser, owner);
    expect_kind(parser, TOKEN_DOUBLE_COLON, "expected ::");
    expect_ident(parser, member);
}

static void
parse_claims(struct parser *parser)
{
    unsigned flags = 0U;
    size_t index;
    for (index = 0U; index < 3U; index += 1U) {
        if (token_is(&parser->current, "semantic_evaluation")) {
            flags |= 1U;
        } else if (token_is(&parser->current, "lean_projection")) {
            flags |= 2U;
        } else if (token_is(&parser->current, "restricted_c_source")) {
            flags |= 4U;
        } else {
            fail_at(parser, "unsupported E0 claim");
            return;
        }
        next_token(parser);
        if (index + 1U < 3U) {
            expect_kind(parser, TOKEN_COMMA, "expected comma in claims");
        }
    }
    if (flags != 7U) {
        fail_at(parser, "missing or duplicate E0 claim");
    }
}

static void
parse_requirements(struct parser *parser)
{
    static const char *const names[5] = {
        "type_well_formed", "totality", "determinism", "resource_bounds",
        "rejection_precedence"
    };
    unsigned flags = 0U;
    size_t index;
    size_t candidate;
    for (index = 0U; index < 5U; index += 1U) {
        int matched = 0;
        for (candidate = 0U; candidate < 5U; candidate += 1U) {
            if (token_is(&parser->current, names[candidate])) {
                flags |= 1U << candidate;
                matched = 1;
                break;
            }
        }
        if (!matched) {
            fail_at(parser, "unsupported E0 theorem requirement");
            return;
        }
        next_token(parser);
        if (index + 1U < 5U) {
            expect_kind(parser, TOKEN_COMMA, "expected comma in requirements");
        }
    }
    if (flags != 31U) {
        fail_at(parser, "missing or duplicate E0 theorem requirement");
    }
}

static void
parse_header(struct parser *parser)
{
    expect_ident(parser, "module");
    expect_ident(parser, "seki");
    expect_kind(parser, TOKEN_DOUBLE_COLON, "expected module separator");
    expect_ident(parser, "experiments");
    expect_kind(parser, TOKEN_DOUBLE_COLON, "expected module separator");
    expect_ident(parser, "minimum_age");
    expect_kind(parser, TOKEN_AT, "expected module version marker");
    if (expect_number(parser) != UINT32_C(1)) {
        fail_at(parser, "unsupported E0 module version");
    }
    expect_ident(parser, "profile");
    expect_kind(parser, TOKEN_COLON, "expected profile colon");
    expect_ident(parser, "c11_bounded");
    expect_kind(parser, TOKEN_AT, "expected profile version marker");
    if (expect_number(parser) != UINT32_C(1)) {
        fail_at(parser, "unsupported E0 profile version");
    }
    expect_ident(parser, "claims");
    expect_kind(parser, TOKEN_COLON, "expected claims colon");
    parse_claims(parser);
    expect_ident(parser, "requires");
    expect_kind(parser, TOKEN_COLON, "expected requires colon");
    parse_requirements(parser);
    expect_kind(parser, TOKEN_DOT, "expected header terminator");
}

static void
parse_types(struct parser *parser)
{
    expect_ident(parser, "export");
    expect_ident(parser, "record");
    expect_ident(parser, "Applicant");
    expect_kind(parser, TOKEN_LBRACE, "expected record body");
    expect_ident(parser, "age");
    expect_kind(parser, TOKEN_COLON, "expected field colon");
    expect_ident(parser, "U8");
    expect_kind(parser, TOKEN_RBRACE, "expected record close");
    expect_kind(parser, TOKEN_DOT, "expected record terminator");

    expect_ident(parser, "export");
    expect_ident(parser, "variant");
    expect_ident(parser, "Rejection");
    expect_kind(parser, TOKEN_LBRACKET, "expected variant body");
    expect_ident(parser, "Underage");
    expect_kind(parser, TOKEN_AT, "expected variant tag marker");
    if (expect_number(parser) != UINT32_C(1)) {
        fail_at(parser, "Underage must retain stable tag 1");
    }
    expect_kind(parser, TOKEN_DOT, "expected variant-case terminator");
    expect_kind(parser, TOKEN_RBRACKET, "expected variant close");
    expect_kind(parser, TOKEN_DOT, "expected variant terminator");
}

static void
parse_result_type(struct parser *parser)
{
    expect_ident(parser, "Decision");
    expect_kind(parser, TOKEN_LBRACKET, "expected Decision type arguments");
    expect_ident(parser, "Unit");
    expect_kind(parser, TOKEN_COMMA, "expected Decision type comma");
    expect_ident(parser, "Rejection");
    expect_kind(parser, TOKEN_RBRACKET, "expected Decision type close");
}

static void
parse_kernel_body(struct parser *parser, struct module *module)
{
    expect_kind(parser, TOKEN_LBRACKET, "expected kernel body");
    expect_kind(parser, TOKEN_LPAREN, "expected grouped field projection");
    expect_ident(parser, "applicant");
    expect_ident(parser, "age");
    expect_kind(parser, TOKEN_RPAREN, "expected projection group close");
    expect_kind(parser, TOKEN_LESS, "expected minimum-age comparison");
    module->threshold = expect_number(parser);
    if (module->threshold > UINT8_MAX) {
        fail_at(parser, "minimum-age literal does not fit U8");
    }
    expect_ident(parser, "ifTrue");
    expect_kind(parser, TOKEN_COLON, "expected ifTrue colon");
    expect_kind(parser, TOKEN_LBRACKET, "expected true branch");
    expect_ident(parser, "reject");
    expect_qualified(parser, "Rejection", "Underage");
    expect_kind(parser, TOKEN_RBRACKET, "expected true branch close");
    expect_ident(parser, "ifFalse");
    expect_kind(parser, TOKEN_COLON, "expected ifFalse colon");
    expect_kind(parser, TOKEN_LBRACKET, "expected false branch");
    expect_ident(parser, "accept");
    expect_ident(parser, "unit");
    expect_kind(parser, TOKEN_RBRACKET, "expected false branch close");
    expect_kind(parser, TOKEN_RBRACKET, "expected kernel body close");
    expect_kind(parser, TOKEN_DOT, "expected kernel terminator");
}

static void
parse_kernel(struct parser *parser, struct module *module)
{
    expect_ident(parser, "export");
    expect_ident(parser, "kernel");
    expect_ident(parser, "decide");
    expect_ident(parser, "applicant");
    expect_kind(parser, TOKEN_COLON, "expected parameter colon");
    expect_ident(parser, "Applicant");
    expect_kind(parser, TOKEN_ARROW, "expected kernel result arrow");
    parse_result_type(parser);
    expect_ident(parser, "arithmetic");
    expect_kind(parser, TOKEN_COLON, "expected arithmetic colon");
    expect_ident(parser, "checked");
    expect_ident(parser, "bounded");
    expect_ident(parser, "steps");
    expect_kind(parser, TOKEN_COLON, "expected steps colon");
    module->declared_steps = expect_number(parser);
    expect_ident(parser, "liveBits");
    expect_kind(parser, TOKEN_COLON, "expected liveBits colon");
    module->declared_live = expect_number(parser);
    expect_ident(parser, "controlDepth");
    expect_kind(parser, TOKEN_COLON, "expected controlDepth colon");
    module->declared_depth = expect_number(parser);
    expect_ident(parser, "workspaceBits");
    expect_kind(parser, TOKEN_COLON, "expected workspaceBits colon");
    module->declared_workspace = expect_number(parser);
    expect_ident(parser, "rejects");
    expect_kind(parser, TOKEN_COLON, "expected rejects colon");
    expect_qualified(parser, "Rejection", "Underage");
    expect_ident(parser, "publication");
    expect_kind(parser, TOKEN_COLON, "expected publication colon");
    expect_ident(parser, "none");
    parse_kernel_body(parser, module);
}

static int
parse_source(const unsigned char *source, size_t length, struct module *module,
    size_t *error_line, size_t *error_column, const char **reason)
{
    struct parser parser = {
        source, length, 0U, 1U, 1U,
        {TOKEN_EOF, source, 0U, UINT32_C(0), 1U, 1U},
        0, NULL
    };
    memset(module, 0, sizeof *module);
    next_token(&parser);
    parse_header(&parser);
    parse_types(&parser);
    parse_kernel(&parser, module);
    if (!parser.failed && parser.current.kind != TOKEN_EOF) {
        fail_at(&parser, "unexpected declaration after E0 kernel");
    }
    if (!parser.failed &&
        (module->declared_steps < UINT32_C(8) ||
         module->declared_live < UINT32_C(25) ||
         module->declared_depth < UINT32_C(5))) {
        fail_at(&parser, "declared resource ceiling is below the derived E0 bound");
    }
    if (parser.failed) {
        *error_line = parser.current.line;
        *error_column = parser.current.column;
        *reason = parser.reason;
        return 0;
    }
    return 1;
}

static void
put_raw(struct buffer *buffer, const unsigned char *bytes, size_t length)
{
    if (buffer->failed || length > sizeof buffer->bytes - buffer->length) {
        buffer->failed = 1;
        return;
    }
    memcpy(buffer->bytes + buffer->length, bytes, length);
    buffer->length += length;
}

static void put_u8(struct buffer *buffer, uint8_t value) { put_raw(buffer, &value, 1U); }

static void
put_u32(struct buffer *buffer, uint32_t value)
{
    const unsigned char bytes[4] = {
        (unsigned char)(value >> 24), (unsigned char)(value >> 16),
        (unsigned char)(value >> 8), (unsigned char)value
    };
    put_raw(buffer, bytes, sizeof bytes);
}

static void
put_name(struct buffer *buffer, const char *value)
{
    const size_t length = strlen(value);
    if (length > UINT32_MAX) {
        buffer->failed = 1;
        return;
    }
    put_u32(buffer, (uint32_t)length);
    put_raw(buffer, (const unsigned char *)value, length);
}

static void put_local_type_ref(struct buffer *b, uint32_t i) { put_u8(b, 0U); put_u32(b, i); }
static void put_declared(struct buffer *b, uint32_t i) { put_u8(b, 21U); put_local_type_ref(b, i); }
static void put_applicant(struct buffer *b) { put_declared(b, 0U); }
static void put_rejection(struct buffer *b) { put_declared(b, 1U); }
static void put_unit(struct buffer *b) { put_u8(b, 0U); }
static void put_bool(struct buffer *b) { put_u8(b, 1U); }
static void put_type_u8(struct buffer *b) { put_u8(b, 2U); }

static void
put_bounds(struct buffer *buffer, uint32_t steps, uint32_t live,
    uint32_t depth, uint32_t workspace)
{
    put_u32(buffer, steps); put_u32(buffer, live);
    put_u32(buffer, depth); put_u32(buffer, workspace);
}

static void
put_kernel(struct buffer *buffer, const struct module *module)
{
    put_name(buffer, "decide");
    put_u32(buffer, 1U); put_name(buffer, "applicant");
    put_u32(buffer, 1U); put_applicant(buffer);
    put_u8(buffer, 19U); put_unit(buffer); put_rejection(buffer);
    put_u32(buffer, 1U); put_local_type_ref(buffer, 1U); put_u32(buffer, 1U);

    put_u8(buffer, 4U);
    put_bool(buffer); put_u8(buffer, 19U); put_u8(buffer, 0U);
    put_type_u8(buffer); put_u8(buffer, 7U);
    put_applicant(buffer); put_u8(buffer, 4U); put_u32(buffer, 0U);
    put_u8(buffer, 0U); put_local_type_ref(buffer, 0U); put_u32(buffer, 0U);
    put_type_u8(buffer); put_u8(buffer, 2U); put_u8(buffer, 0U);
    put_u8(buffer, (uint8_t)module->threshold);

    put_u8(buffer, 1U);
    put_rejection(buffer); put_u8(buffer, 8U);
    put_local_type_ref(buffer, 1U); put_u32(buffer, 1U); put_u32(buffer, 0U);
    put_u32(buffer, 0U);
    put_u8(buffer, 0U); put_unit(buffer); put_u8(buffer, 0U);

    put_bounds(buffer, module->declared_steps, module->declared_live,
        module->declared_depth, module->declared_workspace);
    put_bounds(buffer, 8U, 25U, 5U, 0U);
    put_u8(buffer, 0U);
}

static int
encode_module(const struct module *module, struct buffer *output)
{
    struct buffer payload = {{0}, 0U, 0};
    static const unsigned char magic[4] = {'S', 'E', 'K', 'I'};

    put_u32(&payload, 0U);
    put_u32(&payload, 3U); put_name(&payload, "seki");
    put_name(&payload, "experiments"); put_name(&payload, "minimum_age");
    put_u32(&payload, 1U); put_name(&payload, "c11_bounded"); put_u32(&payload, 1U);
    put_u32(&payload, 0U); put_u32(&payload, 0U);
    put_u32(&payload, 2U);
    put_name(&payload, "Applicant"); put_u8(&payload, 2U); put_u32(&payload, 1U);
    put_name(&payload, "age"); put_type_u8(&payload);
    put_name(&payload, "Rejection"); put_u8(&payload, 3U); put_u32(&payload, 1U);
    put_u32(&payload, 1U); put_name(&payload, "Underage"); put_u8(&payload, 0U);
    put_u32(&payload, 0U);
    put_u32(&payload, 1U); put_kernel(&payload, module);
    put_u32(&payload, 0U);
    put_u32(&payload, 2U); put_u32(&payload, 0U); put_u32(&payload, 1U);
    put_u32(&payload, 0U);
    put_u32(&payload, 1U); put_u32(&payload, 0U);
    put_u32(&payload, 5U);
    put_u8(&payload, 0U); put_u8(&payload, 1U); put_u8(&payload, 2U);
    put_u8(&payload, 3U); put_u8(&payload, 4U);
    put_u32(&payload, 3U); put_u8(&payload, 0U); put_u8(&payload, 1U); put_u8(&payload, 3U);
    put_u32(&payload, 1048576U); put_u32(&payload, 32U);
    put_u32(&payload, 4096U); put_u32(&payload, 65536U);
    put_u32(&payload, 256U); put_u32(&payload, 32U);
    put_bounds(&payload, 16777216U, 8388608U, 256U, 8388608U);
    put_u32(&payload, 0U); put_u32(&payload, 2U);
    put_u32(&payload, 0U); put_u32(&payload, 1U); put_u32(&payload, 0U);

    if (payload.failed || payload.length > UINT32_MAX) {
        return 0;
    }
    memset(output, 0, sizeof *output);
    put_raw(output, magic, sizeof magic);
    put_u32(output, 0U); put_u8(output, 0U);
    put_u32(output, (uint32_t)payload.length);
    put_raw(output, payload.bytes, payload.length);
    return !output->failed;
}

static int
read_source(const char *path, unsigned char *bytes, size_t capacity, size_t *length)
{
    FILE *file = fopen(path, "rb");
    size_t count;
    int extra;
    if (file == NULL) {
        return 0;
    }
    count = fread(bytes, 1U, capacity, file);
    if (ferror(file)) {
        (void)fclose(file);
        return 0;
    }
    extra = fgetc(file);
    if (extra != EOF || fclose(file) != 0) {
        return 0;
    }
    *length = count;
    return 1;
}

static int
write_output(const char *path, const struct buffer *output)
{
    FILE *file = fopen(path, "wb");
    int ok;
    if (file == NULL) {
        return 0;
    }
    ok = fwrite(output->bytes, 1U, output->length, file) == output->length;
    if (fclose(file) != 0) {
        ok = 0;
    }
    return ok;
}

int
main(int argc, char **argv)
{
    unsigned char source[65536];
    size_t source_length = 0U;
    size_t error_line = 1U;
    size_t error_column = 1U;
    const char *reason = "unknown failure";
    struct module module;
    struct buffer output;

    if (argc != 3) {
        (void)fprintf(stderr, "usage: sekic-e0 INPUT.seki OUTPUT.scb0\n");
        return 64;
    }
    if (!read_source(argv[1], source, sizeof source, &source_length)) {
        (void)fprintf(stderr, "E0-IO: cannot read bounded source: %s\n", argv[1]);
        return 74;
    }
    if (!parse_source(source, source_length, &module,
        &error_line, &error_column, &reason)) {
        (void)fprintf(stderr, "E0-SOURCE:%zu:%zu: %s\n",
            error_line, error_column, reason);
        return 65;
    }
    if (!encode_module(&module, &output)) {
        (void)fprintf(stderr, "E0-INTERNAL: SCB-0 output overflow\n");
        return 70;
    }
    if (!write_output(argv[2], &output)) {
        (void)fprintf(stderr, "E0-IO: cannot write output: %s\n", argv[2]);
        return 74;
    }
    return 0;
}
