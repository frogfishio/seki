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

static struct seki_name
take_type_name(struct parser *parser)
{
    struct seki_name name = {NULL, 0U};
    if (parser->failed) {
        return name;
    }
    if (parser->current.kind != SEKI_TOKEN_IDENT ||
        parser->current.length == 0U || parser->current.start[0] < 'A' ||
        parser->current.start[0] > 'Z') {
        parser_fail(parser, "A0-PARSE-0009", "expected upper-case type name");
        return name;
    }
    name.bytes = parser->current.start;
    name.length = parser->current.length;
    advance(parser);
    return name;
}

static void
parse_header(struct parser *parser, struct seki_module_header *header)
{
    expect_word(parser, "module");
    for (;;) {
        if (header->path_count == SEKI_HEADER_MAX_PATH_COMPONENTS) {
            parser_fail(parser, "A0-PARSE-0008",
                "module path exceeds fixed capacity");
            break;
        }
        header->path[header->path_count++] = take_value_name(parser);
        if (parser->failed || parser->current.kind != SEKI_TOKEN_DOUBLE_COLON) {
            break;
        }
        advance(parser);
    }
    expect_kind(parser, SEKI_TOKEN_AT, "expected module version marker");
    header->module_version = take_number(parser);
    expect_word(parser, "profile");
    expect_kind(parser, SEKI_TOKEN_COLON, "expected profile colon");
    header->profile = take_value_name(parser);
    expect_kind(parser, SEKI_TOKEN_AT, "expected profile version marker");
    header->profile_version = take_number(parser);
    expect_word(parser, "claims");
    expect_kind(parser, SEKI_TOKEN_COLON, "expected claims colon");
    parse_name_list(parser, header->claims, SEKI_HEADER_MAX_CLAIMS,
        &header->claim_count, "requires");
    expect_word(parser, "requires");
    expect_kind(parser, SEKI_TOKEN_COLON, "expected requires colon");
    parse_name_list(parser, header->requirements,
        SEKI_HEADER_MAX_REQUIREMENTS, &header->requirement_count, "");
    expect_kind(parser, SEKI_TOKEN_DOT, "expected header terminator");

    if (!parser->failed && (header->path_count == 0U ||
        header->claim_count == 0U || header->requirement_count == 0U)) {
        parser_fail(parser, "A0-PARSE-0006",
            "module header requires nonempty path, claims, and requirements");
    }
}

static int
init_parser(struct parser *parser, const unsigned char *source, size_t length,
    struct seki_parse_error *error)
{
    if (source == NULL || error == NULL) {
        return 0;
    }
    error->code = "A0-PARSE-0000";
    error->message = "invalid parser state";
    error->line = 0U;
    error->column = 0U;
    memset(parser, 0, sizeof *parser);
    parser->error = error;
    seki_lexer_init(&parser->lexer, source, length);
    advance(parser);
    return !parser->failed;
}

static struct seki_type_ref
parse_type_ref(struct parser *parser)
{
    struct seki_type_ref type;
    memset(&type, 0, sizeof type);
    type.name = take_type_name(parser);
    if (parser->failed) {
        return type;
    }
    type.kind = SEKI_TYPE_NAMED;
    if (seki_name_is(&type.name, "Bytes")) {
        type.kind = SEKI_TYPE_BYTES;
        expect_kind(parser, SEKI_TOKEN_LBRACKET, "expected Bytes type open");
        type.length = take_number(parser);
        expect_kind(parser, SEKI_TOKEN_RBRACKET, "expected Bytes type close");
    } else if (seki_name_is(&type.name, "Digest")) {
        type.kind = SEKI_TYPE_DIGEST;
        expect_kind(parser, SEKI_TOKEN_LBRACKET, "expected Digest type open");
        type.algorithm = take_value_name(parser);
        expect_kind(parser, SEKI_TOKEN_COMMA, "expected Digest type comma");
        type.length = take_number(parser);
        expect_kind(parser, SEKI_TOKEN_RBRACKET, "expected Digest type close");
    } else if (parser->current.kind == SEKI_TOKEN_LBRACKET) {
        type.kind = SEKI_TYPE_APPLIED;
        advance(parser);
        while (!parser->failed &&
            parser->current.kind != SEKI_TOKEN_RBRACKET) {
            struct seki_type_arg argument;
            if (type.argument_count == SEKI_TYPE_MAX_ARGUMENTS) {
                parser_fail(parser, "A0-PARSE-0019",
                    "type argument list exceeds fixed capacity");
                break;
            }
            memset(&argument, 0, sizeof argument);
            if (parser->current.kind == SEKI_TOKEN_NUMBER) {
                argument.kind = SEKI_TYPE_ARG_NUMBER;
                argument.number = take_number(parser);
            } else if (parser->current.kind == SEKI_TOKEN_IDENT &&
                parser->current.length != 0U &&
                parser->current.start[0] >= 'A' &&
                parser->current.start[0] <= 'Z') {
                argument.kind = SEKI_TYPE_ARG_TYPE_NAME;
                argument.name = take_type_name(parser);
            } else if (parser->current.kind == SEKI_TOKEN_IDENT) {
                argument.kind = SEKI_TYPE_ARG_VALUE_NAME;
                argument.name = take_value_name(parser);
            } else {
                parser_fail(parser, "A0-PARSE-0020",
                    "expected simple type argument");
                break;
            }
            type.arguments[type.argument_count++] = argument;
            if (parser->current.kind == SEKI_TOKEN_COMMA) {
                advance(parser);
            } else if (parser->current.kind != SEKI_TOKEN_RBRACKET) {
                parser_fail(parser, "A0-PARSE-0021",
                    "expected comma or type-argument close");
            }
        }
        if (!parser->failed && type.argument_count == 0U) {
            parser_fail(parser, "A0-PARSE-0022",
                "applied type requires an argument");
        }
        expect_kind(parser, SEKI_TOKEN_RBRACKET,
            "expected applied type close");
    }
    return type;
}

static int
contains_field(const struct seki_field_decl *fields, size_t count,
    const struct seki_name *name)
{
    size_t index;
    for (index = 0U; index < count; index += 1U) {
        if (seki_name_equal(&fields[index].name, name)) {
            return 1;
        }
    }
    return 0;
}

static void
parse_fields(struct parser *parser, struct seki_field_decl *fields,
    size_t capacity, size_t *count, enum seki_token_kind closing)
{
    while (!parser->failed && parser->current.kind != closing) {
        struct seki_field_decl field;
        if (*count == capacity) {
            parser_fail(parser, "A0-PARSE-0010",
                "field list exceeds fixed capacity");
            return;
        }
        memset(&field, 0, sizeof field);
        field.name = take_value_name(parser);
        if (contains_field(fields, *count, &field.name)) {
            parser_fail(parser, "A0-PARSE-0011", "duplicate field name");
            return;
        }
        expect_kind(parser, SEKI_TOKEN_COLON, "expected field colon");
        field.type = parse_type_ref(parser);
        fields[*count] = field;
        *count += 1U;
        if (parser->current.kind == SEKI_TOKEN_COMMA) {
            advance(parser);
        } else if (parser->current.kind != closing) {
            parser_fail(parser, "A0-PARSE-0012",
                "expected comma or field-list close");
        }
    }
}

static void
parse_record(struct parser *parser, struct seki_type_decl *declaration)
{
    declaration->kind = SEKI_DECL_RECORD;
    declaration->name = take_type_name(parser);
    expect_kind(parser, SEKI_TOKEN_LBRACE, "expected record body");
    parse_fields(parser, declaration->value.record.fields,
        SEKI_RECORD_MAX_FIELDS, &declaration->value.record.field_count,
        SEKI_TOKEN_RBRACE);
    if (!parser->failed && declaration->value.record.field_count == 0U) {
        parser_fail(parser, "A0-PARSE-0013", "record must contain a field");
    }
    expect_kind(parser, SEKI_TOKEN_RBRACE, "expected record close");
    expect_kind(parser, SEKI_TOKEN_DOT, "expected record terminator");
}

static void
parse_alias(struct parser *parser, struct seki_type_decl *declaration,
    enum seki_type_decl_kind kind)
{
    declaration->kind = kind;
    declaration->name = take_type_name(parser);
    expect_kind(parser, SEKI_TOKEN_BIND, "expected type alias binding");
    declaration->value.target = parse_type_ref(parser);
    expect_kind(parser, SEKI_TOKEN_DOT, "expected type alias terminator");
}

static int
variant_has_case(const struct seki_variant_decl *variant,
    const struct seki_name *name, uint32_t tag)
{
    size_t index;
    for (index = 0U; index < variant->case_count; index += 1U) {
        if (seki_name_equal(&variant->cases[index].name, name) ||
            variant->cases[index].tag == tag) {
            return 1;
        }
    }
    return 0;
}

static void
parse_variant(struct parser *parser, struct seki_type_decl *declaration)
{
    struct seki_variant_decl *variant = &declaration->value.variant;
    declaration->kind = SEKI_DECL_VARIANT;
    declaration->name = take_type_name(parser);
    expect_kind(parser, SEKI_TOKEN_LBRACKET, "expected variant body");
    while (!parser->failed && parser->current.kind != SEKI_TOKEN_RBRACKET) {
        struct seki_variant_case item;
        if (variant->case_count == SEKI_VARIANT_MAX_CASES) {
            parser_fail(parser, "A0-PARSE-0014",
                "variant case list exceeds fixed capacity");
            return;
        }
        memset(&item, 0, sizeof item);
        item.name = take_type_name(parser);
        if (parser->current.kind == SEKI_TOKEN_LPAREN) {
            advance(parser);
            parse_fields(parser, item.payload,
                SEKI_VARIANT_MAX_PAYLOAD_FIELDS, &item.payload_count,
                SEKI_TOKEN_RPAREN);
            expect_kind(parser, SEKI_TOKEN_RPAREN,
                "expected variant payload close");
        }
        expect_kind(parser, SEKI_TOKEN_AT, "expected variant tag marker");
        item.tag = take_number(parser);
        if (variant_has_case(variant, &item.name, item.tag)) {
            parser_fail(parser, "A0-PARSE-0015",
                "duplicate variant case name or tag");
            return;
        }
        expect_kind(parser, SEKI_TOKEN_DOT,
            "expected variant-case terminator");
        variant->cases[variant->case_count++] = item;
    }
    if (!parser->failed && variant->case_count == 0U) {
        parser_fail(parser, "A0-PARSE-0016", "variant must contain a case");
    }
    expect_kind(parser, SEKI_TOKEN_RBRACKET, "expected variant close");
    expect_kind(parser, SEKI_TOKEN_DOT, "expected variant terminator");
}

static struct seki_variant_ref
parse_variant_ref(struct parser *parser)
{
    struct seki_variant_ref reference;
    memset(&reference, 0, sizeof reference);
    reference.owner = take_type_name(parser);
    expect_kind(parser, SEKI_TOKEN_DOUBLE_COLON,
        "expected variant reference separator");
    reference.item = take_type_name(parser);
    return reference;
}

static uint32_t
add_expression(struct parser *parser, struct seki_kernel_decl *kernel,
    const struct seki_expression *expression)
{
    uint32_t index = UINT32_MAX;
    if (parser->failed) {
        return index;
    }
    if (kernel->expression_count == SEKI_KERNEL_MAX_EXPRESSIONS) {
        parser_fail(parser, "A0-PARSE-0030",
            "kernel expression arena exceeds fixed capacity");
        return index;
    }
    index = (uint32_t)kernel->expression_count;
    kernel->expressions[kernel->expression_count++] = *expression;
    return index;
}

static uint32_t parse_value_expression(struct parser *parser,
    struct seki_kernel_decl *kernel);

static uint32_t
parse_primary_expression(struct parser *parser,
    struct seki_kernel_decl *kernel)
{
    struct seki_expression expression;
    uint32_t result = UINT32_MAX;
    memset(&expression, 0, sizeof expression);

    if (parser->current.kind == SEKI_TOKEN_NUMBER) {
        expression.kind = SEKI_EXPR_NATURAL;
        expression.value.natural = take_number(parser);
        result = add_expression(parser, kernel, &expression);
    } else if (token_is(&parser->current, "true") ||
        token_is(&parser->current, "false")) {
        expression.kind = SEKI_EXPR_BOOL;
        expression.value.boolean = token_is(&parser->current, "true");
        advance(parser);
        result = add_expression(parser, kernel, &expression);
    } else if (token_is(&parser->current, "unit")) {
        expression.kind = SEKI_EXPR_UNIT;
        advance(parser);
        result = add_expression(parser, kernel, &expression);
    } else if (parser->current.kind == SEKI_TOKEN_IDENT &&
        parser->current.length != 0U && parser->current.start[0] >= 'a' &&
        parser->current.start[0] <= 'z') {
        expression.kind = SEKI_EXPR_VALUE_NAME;
        expression.value.name = take_value_name(parser);
        result = add_expression(parser, kernel, &expression);
    } else if (parser->current.kind == SEKI_TOKEN_LPAREN) {
        advance(parser);
        result = parse_value_expression(parser, kernel);
        expect_kind(parser, SEKI_TOKEN_RPAREN,
            "expected parenthesized expression close");
    } else {
        parser_fail(parser, "A0-PARSE-0031", "expected value expression");
    }
    return result;
}

static uint32_t
parse_projection_expression(struct parser *parser,
    struct seki_kernel_decl *kernel)
{
    uint32_t result = parse_primary_expression(parser, kernel);
    while (!parser->failed && parser->current.kind == SEKI_TOKEN_IDENT &&
        parser->current.length != 0U && parser->current.start[0] >= 'a' &&
        parser->current.start[0] <= 'z' &&
        !token_is(&parser->current, "ifTrue") &&
        !token_is(&parser->current, "ifFalse")) {
        struct seki_expression expression;
        memset(&expression, 0, sizeof expression);
        expression.kind = SEKI_EXPR_FIELD;
        expression.value.field.receiver = result;
        expression.value.field.field = take_value_name(parser);
        result = add_expression(parser, kernel, &expression);
    }
    return result;
}

static int
take_compare_operator(struct parser *parser,
    enum seki_compare_operator *operator)
{
    switch (parser->current.kind) {
    case SEKI_TOKEN_LESS:
        *operator = SEKI_COMPARE_LESS;
        break;
    case SEKI_TOKEN_LESS_EQUAL:
        *operator = SEKI_COMPARE_LESS_EQUAL;
        break;
    case SEKI_TOKEN_GREATER:
        *operator = SEKI_COMPARE_GREATER;
        break;
    case SEKI_TOKEN_GREATER_EQUAL:
        *operator = SEKI_COMPARE_GREATER_EQUAL;
        break;
    case SEKI_TOKEN_EQUAL:
        *operator = SEKI_COMPARE_EQUAL;
        break;
    case SEKI_TOKEN_NOT_EQUAL:
        *operator = SEKI_COMPARE_NOT_EQUAL;
        break;
    default:
        return 0;
    }
    advance(parser);
    return 1;
}

static uint32_t
parse_value_expression(struct parser *parser,
    struct seki_kernel_decl *kernel)
{
    uint32_t left = parse_projection_expression(parser, kernel);
    enum seki_compare_operator operator;
    if (!parser->failed && take_compare_operator(parser, &operator)) {
        struct seki_expression expression;
        const uint32_t right = parse_projection_expression(parser, kernel);
        memset(&expression, 0, sizeof expression);
        expression.kind = SEKI_EXPR_COMPARE;
        expression.value.compare.operator = operator;
        expression.value.compare.left = left;
        expression.value.compare.right = right;
        left = add_expression(parser, kernel, &expression);
    }
    return left;
}

static uint32_t parse_kernel_tail(struct parser *parser,
    struct seki_kernel_decl *kernel);

static uint32_t
parse_kernel_block(struct parser *parser, struct seki_kernel_decl *kernel)
{
    uint32_t root;
    expect_kind(parser, SEKI_TOKEN_LBRACKET, "expected kernel-tail block");
    root = parse_kernel_tail(parser, kernel);
    expect_kind(parser, SEKI_TOKEN_RBRACKET,
        "expected kernel-tail block close");
    return root;
}

static uint32_t
parse_kernel_tail(struct parser *parser, struct seki_kernel_decl *kernel)
{
    struct seki_expression expression;
    memset(&expression, 0, sizeof expression);
    if (token_is(&parser->current, "accept")) {
        advance(parser);
        expression.kind = SEKI_EXPR_ACCEPT;
        expression.value.accept.value = parse_value_expression(parser, kernel);
        return add_expression(parser, kernel, &expression);
    }
    if (token_is(&parser->current, "reject")) {
        advance(parser);
        expression.kind = SEKI_EXPR_REJECT;
        expression.value.rejection = parse_variant_ref(parser);
        return add_expression(parser, kernel, &expression);
    }
    expression.kind = SEKI_EXPR_IF;
    expression.value.conditional.condition =
        parse_value_expression(parser, kernel);
    if (!token_is(&parser->current, "ifTrue")) {
        parser_fail(parser, "A0-PARSE-0032",
            "expected kernel ifTrue branch");
        return UINT32_MAX;
    }
    advance(parser);
    expect_kind(parser, SEKI_TOKEN_COLON, "expected ifTrue colon");
    expression.value.conditional.if_true = parse_kernel_block(parser, kernel);
    if (!token_is(&parser->current, "ifFalse")) {
        parser_fail(parser, "A0-PARSE-0033",
            "expected kernel ifFalse branch");
        return UINT32_MAX;
    }
    advance(parser);
    expect_kind(parser, SEKI_TOKEN_COLON, "expected ifFalse colon");
    expression.value.conditional.if_false = parse_kernel_block(parser, kernel);
    return add_expression(parser, kernel, &expression);
}

static void
parse_kernel_body(struct parser *parser, struct seki_kernel_decl *kernel)
{
    expect_kind(parser, SEKI_TOKEN_LBRACKET, "expected kernel body");
    kernel->body_root = parse_kernel_tail(parser, kernel);
    expect_kind(parser, SEKI_TOKEN_RBRACKET, "expected kernel body close");
    expect_kind(parser, SEKI_TOKEN_DOT, "expected kernel terminator");
}

static void
parse_kernel(struct parser *parser, struct seki_kernel_decl *kernel)
{
    kernel->name = take_value_name(parser);
    while (!parser->failed && parser->current.kind != SEKI_TOKEN_ARROW) {
        struct seki_parameter_decl parameter;
        if (kernel->parameter_count == SEKI_CALLABLE_MAX_PARAMETERS) {
            parser_fail(parser, "A0-PARSE-0024",
                "kernel parameter list exceeds fixed capacity");
            return;
        }
        memset(&parameter, 0, sizeof parameter);
        parameter.label = take_value_name(parser);
        expect_kind(parser, SEKI_TOKEN_COLON,
            "expected kernel parameter colon");
        parameter.type = parse_type_ref(parser);
        kernel->parameters[kernel->parameter_count++] = parameter;
    }
    expect_kind(parser, SEKI_TOKEN_ARROW, "expected kernel result arrow");
    kernel->result = parse_type_ref(parser);
    expect_word(parser, "arithmetic");
    expect_kind(parser, SEKI_TOKEN_COLON,
        "expected arithmetic policy colon");
    kernel->arithmetic_policy = take_value_name(parser);
    if (!parser->failed &&
        !seki_name_is(&kernel->arithmetic_policy, "checked") &&
        !seki_name_is(&kernel->arithmetic_policy, "wrapping") &&
        !seki_name_is(&kernel->arithmetic_policy, "saturating")) {
        parser_fail(parser, "A0-PARSE-0025", "unknown arithmetic policy");
    }
    expect_word(parser, "bounded");
    expect_word(parser, "steps");
    expect_kind(parser, SEKI_TOKEN_COLON, "expected steps colon");
    kernel->bounds.steps = take_number(parser);
    expect_word(parser, "liveBits");
    expect_kind(parser, SEKI_TOKEN_COLON, "expected liveBits colon");
    kernel->bounds.live_bits = take_number(parser);
    expect_word(parser, "controlDepth");
    expect_kind(parser, SEKI_TOKEN_COLON, "expected controlDepth colon");
    kernel->bounds.control_depth = take_number(parser);
    expect_word(parser, "workspaceBits");
    expect_kind(parser, SEKI_TOKEN_COLON, "expected workspaceBits colon");
    kernel->bounds.workspace_bits = take_number(parser);
    expect_word(parser, "rejects");
    expect_kind(parser, SEKI_TOKEN_COLON, "expected rejects colon");
    for (;;) {
        if (kernel->rejection_count == SEKI_KERNEL_MAX_REJECTIONS) {
            parser_fail(parser, "A0-PARSE-0026",
                "kernel rejection list exceeds fixed capacity");
            return;
        }
        kernel->rejections[kernel->rejection_count++] =
            parse_variant_ref(parser);
        if (parser->current.kind != SEKI_TOKEN_COMMA) {
            break;
        }
        advance(parser);
    }
    expect_word(parser, "publication");
    expect_kind(parser, SEKI_TOKEN_COLON, "expected publication colon");
    if (token_is(&parser->current, "none")) {
        kernel->publication_eligible = 0;
        advance(parser);
    } else if (token_is(&parser->current, "eligible")) {
        kernel->publication_eligible = 1;
        advance(parser);
    } else {
        parser_fail(parser, "A0-PARSE-0027",
            "expected publication mode");
    }
    parse_kernel_body(parser, kernel);
}

static int
module_has_declaration(const struct seki_module_prefix *module,
    const struct seki_name *name)
{
    size_t index;
    for (index = 0U; index < module->declaration_count; index += 1U) {
        if (seki_name_equal(&module->declarations[index].name, name)) {
            return 1;
        }
    }
    return 0;
}

static int
module_has_kernel(const struct seki_module_prefix *module,
    const struct seki_name *name)
{
    size_t index;
    for (index = 0U; index < module->kernel_count; index += 1U) {
        if (seki_name_equal(&module->kernels[index].name, name)) {
            return 1;
        }
    }
    return 0;
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
    if (!init_parser(&parser, source, length, error)) {
        return 0;
    }
    parse_header(&parser, header);
    return !parser.failed;
}

int
seki_parse_module_prefix(const unsigned char *source, size_t length,
    struct seki_module_prefix *module, struct seki_parse_error *error)
{
    struct parser parser;
    if (source == NULL || module == NULL || error == NULL) {
        return 0;
    }
    memset(module, 0, sizeof *module);
    if (!init_parser(&parser, source, length, error)) {
        return 0;
    }
    parse_header(&parser, &module->header);
    while (!parser.failed && token_is(&parser.current, "export")) {
        struct seki_type_decl declaration;
        advance(&parser);
        if (token_is(&parser.current, "kernel")) {
            struct seki_kernel_decl kernel;
            if (module->kernel_count == SEKI_MODULE_MAX_KERNELS) {
                parser_fail(&parser, "A0-PARSE-0028",
                    "kernel list exceeds fixed capacity");
                break;
            }
            advance(&parser);
            memset(&kernel, 0, sizeof kernel);
            parse_kernel(&parser, &kernel);
            if (module_has_kernel(module, &kernel.name)) {
                parser_fail(&parser, "A0-PARSE-0029",
                    "duplicate kernel name");
                break;
            }
            module->kernels[module->kernel_count++] = kernel;
            continue;
        }
        if (module->declaration_count == SEKI_MODULE_MAX_DECLARATIONS) {
            parser_fail(&parser, "A0-PARSE-0017",
                "declaration list exceeds fixed capacity");
            break;
        }
        memset(&declaration, 0, sizeof declaration);
        if (token_is(&parser.current, "record")) {
            advance(&parser);
            parse_record(&parser, &declaration);
        } else if (token_is(&parser.current, "variant")) {
            advance(&parser);
            parse_variant(&parser, &declaration);
        } else if (token_is(&parser.current, "type")) {
            advance(&parser);
            parse_alias(&parser, &declaration, SEKI_DECL_ALIAS);
        } else if (token_is(&parser.current, "nominal")) {
            advance(&parser);
            parse_alias(&parser, &declaration, SEKI_DECL_NOMINAL);
        } else {
            break;
        }
        if (module_has_declaration(module, &declaration.name)) {
            parser_fail(&parser, "A0-PARSE-0018",
                "duplicate type declaration name");
            break;
        }
        module->declarations[module->declaration_count++] = declaration;
    }
    return !parser.failed;
}
