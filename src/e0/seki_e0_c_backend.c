/*
 * E0-VS1 closed-subset SCB-0 to restricted-C backend.
 *
 * Experimental only. This independently reopens the complete minimum-age
 * typed-core shape, projects it into a deliberately tiny restricted-C AST,
 * and prints deterministic C11 bytes. It is not the v0 backend or C profile.
 */
#include <stdint.h>
#include <stdio.h>
#include <string.h>

enum rc_expression_kind {
    RC_LESS_THAN_U8
};

enum rc_decision_kind {
    RC_ACCEPT_UNIT,
    RC_REJECT_UNDERAGE
};

struct rc_expression {
    enum rc_expression_kind kind;
    uint32_t parameter_index;
    uint32_t field_index;
    uint8_t literal;
};

struct rc_kernel {
    struct rc_expression condition;
    enum rc_decision_kind when_true;
    enum rc_decision_kind when_false;
};

struct rc_module {
    uint32_t profile_version;
    struct rc_kernel kernel;
};

struct reader {
    const uint8_t *bytes;
    size_t length;
    size_t offset;
    int failed;
    const char *reason;
};

struct text_buffer {
    char bytes[4096];
    size_t length;
    int failed;
};

static void
reader_fail(struct reader *reader, const char *reason)
{
    if (!reader->failed) {
        reader->failed = 1;
        reader->reason = reason;
    }
}

static uint8_t
read_u8(struct reader *reader)
{
    if (reader->failed || reader->offset == reader->length) {
        reader_fail(reader, "truncated SCB-0 input");
        return UINT8_C(0);
    }
    return reader->bytes[reader->offset++];
}

static uint32_t
read_u32(struct reader *reader)
{
    uint32_t value;
    if (reader->failed || reader->length - reader->offset < 4U) {
        reader_fail(reader, "truncated SCB-0 U32");
        return UINT32_C(0);
    }
    value = ((uint32_t)reader->bytes[reader->offset] << 24) |
        ((uint32_t)reader->bytes[reader->offset + 1U] << 16) |
        ((uint32_t)reader->bytes[reader->offset + 2U] << 8) |
        (uint32_t)reader->bytes[reader->offset + 3U];
    reader->offset += 4U;
    return value;
}

static void
expect_u8(struct reader *reader, uint8_t expected, const char *reason)
{
    if (read_u8(reader) != expected) {
        reader_fail(reader, reason);
    }
}

static void
expect_u32(struct reader *reader, uint32_t expected, const char *reason)
{
    if (read_u32(reader) != expected) {
        reader_fail(reader, reason);
    }
}

static void
expect_raw(struct reader *reader, const uint8_t *expected, size_t length,
    const char *reason)
{
    if (reader->failed) {
        return;
    }
    if (length > reader->length - reader->offset ||
        memcmp(reader->bytes + reader->offset, expected, length) != 0) {
        reader_fail(reader, reason);
        return;
    }
    reader->offset += length;
}

static void
expect_name(struct reader *reader, const char *expected)
{
    const size_t length = strlen(expected);
    if (length > UINT32_MAX) {
        reader_fail(reader, "internal name exceeds U32");
        return;
    }
    expect_u32(reader, (uint32_t)length, "unexpected SCB-0 name length");
    expect_raw(reader, (const uint8_t *)expected, length,
        "unexpected SCB-0 name");
}

static void
expect_local_type_ref(struct reader *reader, uint32_t index)
{
    expect_u8(reader, UINT8_C(0), "expected local type reference");
    expect_u32(reader, index, "unexpected local type index");
}

static void
expect_declared_type(struct reader *reader, uint32_t index)
{
    expect_u8(reader, UINT8_C(21), "expected declared type");
    expect_local_type_ref(reader, index);
}

static void
expect_bounds(struct reader *reader, uint32_t steps, uint32_t live,
    uint32_t depth, uint32_t workspace)
{
    expect_u32(reader, steps, "unexpected exact step bound");
    expect_u32(reader, live, "unexpected exact live-bit bound");
    expect_u32(reader, depth, "unexpected exact control-depth bound");
    expect_u32(reader, workspace, "unexpected exact workspace bound");
}

static void
decode_header_and_types(struct reader *reader, struct rc_module *module)
{
    static const uint8_t magic[4] = {'S', 'E', 'K', 'I'};
    uint32_t payload_length;

    expect_raw(reader, magic, sizeof magic, "bad SCB-0 magic");
    expect_u32(reader, UINT32_C(0), "unsupported SCB-0 envelope version");
    expect_u8(reader, UINT8_C(0), "expected SCB-0 module object");
    payload_length = read_u32(reader);
    if (!reader->failed && payload_length != reader->length - reader->offset) {
        reader_fail(reader, "SCB-0 payload length mismatch");
    }

    expect_u32(reader, UINT32_C(0), "unsupported typed-core schema");
    expect_u32(reader, UINT32_C(3), "unexpected module path length");
    expect_name(reader, "seki");
    expect_name(reader, "experiments");
    expect_name(reader, "minimum_age");
    expect_u32(reader, UINT32_C(1), "unexpected module version");
    expect_name(reader, "c11_bounded");
    module->profile_version = read_u32(reader);
    if (module->profile_version != UINT32_C(1)) {
        reader_fail(reader, "unsupported E0 profile version");
    }
    expect_u32(reader, UINT32_C(0), "E0 imports must be empty");
    expect_u32(reader, UINT32_C(0), "E0 domains must be empty");

    expect_u32(reader, UINT32_C(2), "E0 requires two declarations");
    expect_name(reader, "Applicant");
    expect_u8(reader, UINT8_C(2), "Applicant must be a record");
    expect_u32(reader, UINT32_C(1), "Applicant must have one field");
    expect_name(reader, "age");
    expect_u8(reader, UINT8_C(2), "Applicant.age must be U8");
    expect_name(reader, "Rejection");
    expect_u8(reader, UINT8_C(3), "Rejection must be a variant");
    expect_u32(reader, UINT32_C(1), "Rejection must have one case");
    expect_u32(reader, UINT32_C(1), "Underage tag must be one");
    expect_name(reader, "Underage");
    expect_u8(reader, UINT8_C(0), "Underage must have no payload");
    expect_u32(reader, UINT32_C(0), "E0 functions must be empty");
}

static void
decode_kernel(struct reader *reader, struct rc_module *module)
{
    uint32_t declared_steps;
    uint32_t declared_live;
    uint32_t declared_depth;
    uint32_t declared_workspace;

    expect_u32(reader, UINT32_C(1), "E0 requires one kernel");
    expect_name(reader, "decide");
    expect_u32(reader, UINT32_C(1), "decide requires one parameter label");
    expect_name(reader, "applicant");
    expect_u32(reader, UINT32_C(1), "decide requires one parameter type");
    expect_declared_type(reader, UINT32_C(0));
    expect_u8(reader, UINT8_C(19), "decide result must be Decision");
    expect_u8(reader, UINT8_C(0), "accepted result must be Unit");
    expect_declared_type(reader, UINT32_C(1));
    expect_u32(reader, UINT32_C(1), "decide requires one rejection order entry");
    expect_local_type_ref(reader, UINT32_C(1));
    expect_u32(reader, UINT32_C(1), "unexpected rejection tag");

    expect_u8(reader, UINT8_C(4), "kernel body must be If");
    expect_u8(reader, UINT8_C(1), "If condition must claim Bool");
    expect_u8(reader, UINT8_C(19), "condition must be Compare");
    expect_u8(reader, UINT8_C(0), "condition must use LessThan");
    expect_u8(reader, UINT8_C(2), "projection must claim U8");
    expect_u8(reader, UINT8_C(7), "condition left side must be Project");
    expect_declared_type(reader, UINT32_C(0));
    expect_u8(reader, UINT8_C(4), "projection base must be Local");
    module->kernel.condition.parameter_index = read_u32(reader);
    expect_u8(reader, UINT8_C(0), "field owner must be local");
    expect_local_type_ref(reader, UINT32_C(0));
    module->kernel.condition.field_index = read_u32(reader);
    expect_u8(reader, UINT8_C(2), "comparison literal must claim U8");
    expect_u8(reader, UINT8_C(2), "comparison right side must be IntLit");
    expect_u8(reader, UINT8_C(0), "comparison literal family must be U8");
    module->kernel.condition.literal = read_u8(reader);

    expect_u8(reader, UINT8_C(1), "true branch must reject");
    expect_declared_type(reader, UINT32_C(1));
    expect_u8(reader, UINT8_C(8), "rejection value must construct a variant");
    expect_local_type_ref(reader, UINT32_C(1));
    expect_u32(reader, UINT32_C(1), "true branch must construct Underage");
    expect_u32(reader, UINT32_C(0), "Underage must have no arguments");
    expect_u32(reader, UINT32_C(0), "unexpected rejection precedence index");
    module->kernel.when_true = RC_REJECT_UNDERAGE;

    expect_u8(reader, UINT8_C(0), "false branch must accept");
    expect_u8(reader, UINT8_C(0), "accepted value must claim Unit");
    expect_u8(reader, UINT8_C(0), "accepted value must be Unit literal");
    module->kernel.when_false = RC_ACCEPT_UNIT;

    declared_steps = read_u32(reader);
    declared_live = read_u32(reader);
    declared_depth = read_u32(reader);
    declared_workspace = read_u32(reader);
    if (!reader->failed &&
        (declared_steps < UINT32_C(8) || declared_live < UINT32_C(25) ||
         declared_depth < UINT32_C(5))) {
        reader_fail(reader, "declared resource ceiling below exact bound");
    }
    (void)declared_workspace;
    expect_bounds(reader, UINT32_C(8), UINT32_C(25), UINT32_C(5), UINT32_C(0));
    expect_u8(reader, UINT8_C(0), "publication must be disabled");

    module->kernel.condition.kind = RC_LESS_THAN_U8;
    if (!reader->failed &&
        (module->kernel.condition.parameter_index != UINT32_C(0) ||
         module->kernel.condition.field_index != UINT32_C(0))) {
        reader_fail(reader, "condition references unexpected input field");
    }
}

static void
decode_footer(struct reader *reader)
{
    expect_u32(reader, UINT32_C(0), "exported domains must be empty");
    expect_u32(reader, UINT32_C(2), "both E0 types must be exported");
    expect_u32(reader, UINT32_C(0), "Applicant export index changed");
    expect_u32(reader, UINT32_C(1), "Rejection export index changed");
    expect_u32(reader, UINT32_C(0), "exported functions must be empty");
    expect_u32(reader, UINT32_C(1), "decide must be exported");
    expect_u32(reader, UINT32_C(0), "decide export index changed");
    expect_u32(reader, UINT32_C(5), "theorem requirement count changed");
    expect_u8(reader, UINT8_C(0), "theorem requirement changed");
    expect_u8(reader, UINT8_C(1), "theorem requirement changed");
    expect_u8(reader, UINT8_C(2), "theorem requirement changed");
    expect_u8(reader, UINT8_C(3), "theorem requirement changed");
    expect_u8(reader, UINT8_C(4), "theorem requirement changed");
    expect_u32(reader, UINT32_C(3), "claim count changed");
    expect_u8(reader, UINT8_C(0), "claim ceiling changed");
    expect_u8(reader, UINT8_C(1), "claim ceiling changed");
    expect_u8(reader, UINT8_C(3), "claim ceiling changed");
    expect_u32(reader, UINT32_C(1048576), "module byte profile changed");
    expect_u32(reader, UINT32_C(32), "import profile changed");
    expect_u32(reader, UINT32_C(4096), "declaration profile changed");
    expect_u32(reader, UINT32_C(65536), "expression profile changed");
    expect_u32(reader, UINT32_C(256), "syntax-depth profile changed");
    expect_u32(reader, UINT32_C(32), "call-depth profile changed");
    expect_bounds(reader, UINT32_C(16777216), UINT32_C(8388608),
        UINT32_C(256), UINT32_C(8388608));
    expect_u32(reader, UINT32_C(0), "derivation schema changed");
    expect_u32(reader, UINT32_C(2), "type derivation count changed");
    expect_u32(reader, UINT32_C(0), "type derivation order changed");
    expect_u32(reader, UINT32_C(1), "type derivation order changed");
    expect_u32(reader, UINT32_C(0), "function derivations must be empty");
}

static int
decode_module(const uint8_t *bytes, size_t length, struct rc_module *module,
    size_t *error_offset, const char **reason)
{
    struct reader reader = {bytes, length, 0U, 0, NULL};
    memset(module, 0, sizeof *module);
    decode_header_and_types(&reader, module);
    decode_kernel(&reader, module);
    decode_footer(&reader);
    if (!reader.failed && reader.offset != reader.length) {
        reader_fail(&reader, "trailing SCB-0 bytes");
    }
    if (reader.failed) {
        *error_offset = reader.offset;
        *reason = reader.reason;
        return 0;
    }
    return 1;
}

static void
text_put(struct text_buffer *buffer, const char *text)
{
    const size_t length = strlen(text);
    if (buffer->failed || length > sizeof buffer->bytes - buffer->length) {
        buffer->failed = 1;
        return;
    }
    memcpy(buffer->bytes + buffer->length, text, length);
    buffer->length += length;
}

static void
text_put_u8_decimal(struct text_buffer *buffer, uint8_t value)
{
    char reversed[3];
    size_t length = 0U;
    size_t index;
    do {
        reversed[length++] = (char)('0' + (value % UINT8_C(10)));
        value = (uint8_t)(value / UINT8_C(10));
    } while (value != UINT8_C(0));
    for (index = length; index > 0U; index -= 1U) {
        const char digit[2] = {reversed[index - 1U], '\0'};
        text_put(buffer, digit);
    }
}

static void
print_result(struct text_buffer *output, enum rc_decision_kind result)
{
    if (result == RC_REJECT_UNDERAGE) {
        text_put(output,
            "        result.tag = UINT8_C(1);\n"
            "        result.reason = UINT8_C(1);\n");
    } else {
        text_put(output,
            "        result.tag = UINT8_C(0);\n"
            "        result.reason = UINT8_C(0);\n");
    }
}

static int
print_module(const struct rc_module *module, struct text_buffer *output)
{
    memset(output, 0, sizeof *output);
    if (module->profile_version != UINT32_C(1) ||
        module->kernel.condition.kind != RC_LESS_THAN_U8) {
        return 0;
    }
    text_put(output,
        "#include <stdint.h>\n"
        "\n"
        "typedef struct {\n"
        "    uint8_t age;\n"
        "} seki_e0_applicant;\n"
        "\n"
        "typedef struct {\n"
        "    uint8_t tag;\n"
        "    uint8_t reason;\n"
        "} seki_e0_decision;\n"
        "\n"
        "seki_e0_decision seki_e0_decide(seki_e0_applicant applicant);\n"
        "\n"
        "seki_e0_decision\n"
        "seki_e0_decide(seki_e0_applicant applicant)\n"
        "{\n"
        "    seki_e0_decision result;\n"
        "    if (applicant.age < UINT8_C(");
    text_put_u8_decimal(output, module->kernel.condition.literal);
    text_put(output, ")) {\n");
    print_result(output, module->kernel.when_true);
    text_put(output, "    } else {\n");
    print_result(output, module->kernel.when_false);
    text_put(output,
        "    }\n"
        "    return result;\n"
        "}\n");
    return !output->failed;
}

static int
read_file(const char *path, uint8_t *bytes, size_t capacity, size_t *length)
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
write_file(const char *path, const char *bytes, size_t length)
{
    FILE *file = fopen(path, "wb");
    int ok;
    if (file == NULL) {
        return 0;
    }
    ok = fwrite(bytes, 1U, length, file) == length;
    if (fclose(file) != 0) {
        ok = 0;
    }
    return ok;
}

int
main(int argc, char **argv)
{
    uint8_t input[2048];
    size_t input_length = 0U;
    size_t error_offset = 0U;
    const char *reason = "unknown failure";
    struct rc_module module;
    struct text_buffer output;

    if (argc != 3) {
        (void)fprintf(stderr, "usage: seki-e0-c-backend INPUT.scb0 OUTPUT.c\n");
        return 64;
    }
    if (!read_file(argv[1], input, sizeof input, &input_length)) {
        (void)fprintf(stderr, "E0-IO: cannot read bounded SCB-0 input: %s\n", argv[1]);
        return 74;
    }
    if (!decode_module(input, input_length, &module, &error_offset, &reason)) {
        (void)fprintf(stderr, "E0-SCB:%zu: %s\n", error_offset, reason);
        return 65;
    }
    if (!print_module(&module, &output)) {
        (void)fprintf(stderr, "E0-INTERNAL: restricted-C output overflow\n");
        return 70;
    }
    if (!write_file(argv[2], output.bytes, output.length)) {
        (void)fprintf(stderr, "E0-IO: cannot write C output: %s\n", argv[2]);
        return 74;
    }
    return 0;
}
