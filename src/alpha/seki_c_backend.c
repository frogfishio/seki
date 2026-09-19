#include "seki_c_backend.h"

#include <stdint.h>
#include <string.h>

enum restricted_decision {
    RESTRICTED_ACCEPT_UNIT,
    RESTRICTED_REJECT_UNDERAGE
};

struct restricted_kernel {
    uint32_t parameter_index;
    uint32_t field_index;
    uint8_t threshold;
    enum restricted_decision if_true;
    enum restricted_decision if_false;
};

struct restricted_module {
    uint32_t profile_version;
    struct restricted_kernel kernel;
};

struct reader {
    const unsigned char *bytes;
    size_t length;
    size_t offset;
    int failed;
    const char *message;
};

struct text_buffer {
    char *bytes;
    size_t capacity;
    size_t length;
    int failed;
};

static void
reader_fail(struct reader *reader, const char *message)
{
    if (!reader->failed) {
        reader->failed = 1;
        reader->message = message;
    }
}

static uint8_t
read_u8(struct reader *reader)
{
    if (reader->failed || reader->offset == reader->length) {
        reader_fail(reader, "truncated SCB-0 input");
        return 0U;
    }
    return reader->bytes[reader->offset++];
}

static uint32_t
read_u32(struct reader *reader)
{
    uint32_t value;
    if (reader->failed || reader->length - reader->offset < 4U) {
        reader_fail(reader, "truncated SCB-0 U32");
        return 0U;
    }
    value = ((uint32_t)reader->bytes[reader->offset] << 24) |
        ((uint32_t)reader->bytes[reader->offset + 1U] << 16) |
        ((uint32_t)reader->bytes[reader->offset + 2U] << 8) |
        (uint32_t)reader->bytes[reader->offset + 3U];
    reader->offset += 4U;
    return value;
}

static void
expect_u8(struct reader *reader, uint8_t expected, const char *message)
{
    if (read_u8(reader) != expected) {
        reader_fail(reader, message);
    }
}

static void
expect_u32(struct reader *reader, uint32_t expected, const char *message)
{
    if (read_u32(reader) != expected) {
        reader_fail(reader, message);
    }
}

static void
expect_raw(struct reader *reader, const unsigned char *expected, size_t length,
    const char *message)
{
    if (reader->failed) {
        return;
    }
    if (length > reader->length - reader->offset ||
        memcmp(reader->bytes + reader->offset, expected, length) != 0) {
        reader_fail(reader, message);
        return;
    }
    reader->offset += length;
}

static void
expect_name(struct reader *reader, const char *expected)
{
    const size_t length = strlen(expected);
    expect_u32(reader, (uint32_t)length, "unexpected SCB-0 name length");
    expect_raw(reader, (const unsigned char *)expected, length,
        "unexpected SCB-0 name");
}

static void
expect_local_type(struct reader *reader, uint32_t index)
{
    expect_u8(reader, 0U, "expected local type reference");
    expect_u32(reader, index, "unexpected local type index");
}

static void
expect_declared_type(struct reader *reader, uint32_t index)
{
    expect_u8(reader, 21U, "expected declared type");
    expect_local_type(reader, index);
}

static void
expect_bounds(struct reader *reader, uint32_t steps, uint32_t live_bits,
    uint32_t control_depth, uint32_t workspace_bits)
{
    expect_u32(reader, steps, "unexpected exact step bound");
    expect_u32(reader, live_bits, "unexpected exact live-bit bound");
    expect_u32(reader, control_depth, "unexpected exact control-depth bound");
    expect_u32(reader, workspace_bits, "unexpected exact workspace bound");
}

static void
decode_header(struct reader *reader, struct restricted_module *module)
{
    static const unsigned char magic[4] = {'S', 'E', 'K', 'I'};
    const uint32_t payload_length_expected =
        reader->length >= 13U ? (uint32_t)(reader->length - 13U) : 0U;
    expect_raw(reader, magic, sizeof magic, "bad SCB-0 magic");
    expect_u32(reader, 0U, "unsupported SCB-0 envelope version");
    expect_u8(reader, 0U, "expected SCB-0 module object");
    expect_u32(reader, payload_length_expected, "SCB-0 payload length mismatch");
    expect_u32(reader, 0U, "unsupported typed-core schema");
    expect_u32(reader, 3U, "unexpected module path length");
    expect_name(reader, "seki");
    expect_name(reader, "experiments");
    expect_name(reader, "minimum_age");
    expect_u32(reader, 1U, "unexpected module version");
    expect_name(reader, "c11_bounded");
    module->profile_version = read_u32(reader);
    if (!reader->failed && module->profile_version != 1U) {
        reader_fail(reader, "unsupported alpha profile version");
    }
    expect_u32(reader, 0U, "imports must be empty");
    expect_u32(reader, 0U, "domains must be empty");
    expect_u32(reader, 2U, "minimum-age slice requires two declarations");
    expect_name(reader, "Applicant");
    expect_u8(reader, 2U, "Applicant must be a record");
    expect_u32(reader, 1U, "Applicant must have one field");
    expect_name(reader, "age");
    expect_u8(reader, 2U, "Applicant.age must be U8");
    expect_name(reader, "Rejection");
    expect_u8(reader, 3U, "Rejection must be a variant");
    expect_u32(reader, 1U, "Rejection must have one case");
    expect_u32(reader, 1U, "Underage tag must be one");
    expect_name(reader, "Underage");
    expect_u8(reader, 0U, "Underage must have no payload");
    expect_u32(reader, 0U, "functions must be empty");
}

static void
decode_kernel(struct reader *reader, struct restricted_module *module)
{
    uint32_t declared_steps;
    uint32_t declared_live;
    uint32_t declared_depth;

    expect_u32(reader, 1U, "minimum-age slice requires one kernel");
    expect_name(reader, "decide");
    expect_u32(reader, 1U, "decide requires one parameter label");
    expect_name(reader, "applicant");
    expect_u32(reader, 1U, "decide requires one parameter type");
    expect_declared_type(reader, 0U);
    expect_u8(reader, 19U, "decide result must be Decision");
    expect_u8(reader, 0U, "accepted result must be Unit");
    expect_declared_type(reader, 1U);
    expect_u32(reader, 1U, "decide requires one rejection-order entry");
    expect_local_type(reader, 1U);
    expect_u32(reader, 1U, "unexpected rejection tag");

    expect_u8(reader, 4U, "kernel body must be If");
    expect_u8(reader, 1U, "If condition must claim Bool");
    expect_u8(reader, 19U, "condition must be Compare");
    expect_u8(reader, 0U, "condition must use LessThan");
    expect_u8(reader, 2U, "projection must claim U8");
    expect_u8(reader, 7U, "condition left side must be Project");
    expect_declared_type(reader, 0U);
    expect_u8(reader, 4U, "projection base must be Local");
    module->kernel.parameter_index = read_u32(reader);
    expect_u8(reader, 0U, "field owner must be local");
    expect_local_type(reader, 0U);
    module->kernel.field_index = read_u32(reader);
    expect_u8(reader, 2U, "comparison literal must claim U8");
    expect_u8(reader, 2U, "comparison right side must be IntLit");
    expect_u8(reader, 0U, "comparison literal family must be U8");
    module->kernel.threshold = read_u8(reader);

    expect_u8(reader, 1U, "true branch must reject");
    expect_declared_type(reader, 1U);
    expect_u8(reader, 8U, "rejection value must construct a variant");
    expect_local_type(reader, 1U);
    expect_u32(reader, 1U, "true branch must construct Underage");
    expect_u32(reader, 0U, "Underage must have no arguments");
    expect_u32(reader, 0U, "unexpected rejection precedence index");
    module->kernel.if_true = RESTRICTED_REJECT_UNDERAGE;

    expect_u8(reader, 0U, "false branch must accept");
    expect_u8(reader, 0U, "accepted value must claim Unit");
    expect_u8(reader, 0U, "accepted value must be Unit literal");
    module->kernel.if_false = RESTRICTED_ACCEPT_UNIT;

    declared_steps = read_u32(reader);
    declared_live = read_u32(reader);
    declared_depth = read_u32(reader);
    (void)read_u32(reader);
    if (!reader->failed && (declared_steps < 8U || declared_live < 25U ||
        declared_depth < 5U)) {
        reader_fail(reader, "declared resource ceiling below exact bound");
    }
    expect_bounds(reader, 8U, 25U, 5U, 0U);
    expect_u8(reader, 0U, "publication must be disabled");
    if (!reader->failed && (module->kernel.parameter_index != 0U ||
        module->kernel.field_index != 0U)) {
        reader_fail(reader, "condition references unexpected input field");
    }
}

static void
decode_footer(struct reader *reader)
{
    expect_u32(reader, 0U, "exported domains must be empty");
    expect_u32(reader, 2U, "both types must be exported");
    expect_u32(reader, 0U, "Applicant export index changed");
    expect_u32(reader, 1U, "Rejection export index changed");
    expect_u32(reader, 0U, "exported functions must be empty");
    expect_u32(reader, 1U, "decide must be exported");
    expect_u32(reader, 0U, "decide export index changed");
    expect_u32(reader, 5U, "theorem requirement count changed");
    expect_u8(reader, 0U, "theorem requirement changed");
    expect_u8(reader, 1U, "theorem requirement changed");
    expect_u8(reader, 2U, "theorem requirement changed");
    expect_u8(reader, 3U, "theorem requirement changed");
    expect_u8(reader, 4U, "theorem requirement changed");
    expect_u32(reader, 3U, "claim count changed");
    expect_u8(reader, 0U, "claim ceiling changed");
    expect_u8(reader, 1U, "claim ceiling changed");
    expect_u8(reader, 3U, "claim ceiling changed");
    expect_u32(reader, 1048576U, "module-byte profile changed");
    expect_u32(reader, 32U, "import profile changed");
    expect_u32(reader, 4096U, "declaration profile changed");
    expect_u32(reader, 65536U, "expression profile changed");
    expect_u32(reader, 256U, "syntax-depth profile changed");
    expect_u32(reader, 32U, "call-depth profile changed");
    expect_bounds(reader, 16777216U, 8388608U, 256U, 8388608U);
    expect_u32(reader, 0U, "derivation schema changed");
    expect_u32(reader, 2U, "type derivation count changed");
    expect_u32(reader, 0U, "type derivation order changed");
    expect_u32(reader, 1U, "type derivation order changed");
    expect_u32(reader, 0U, "function derivations must be empty");
}

static int
decode_module(const unsigned char *core, size_t core_length,
    struct restricted_module *module, struct seki_backend_error *error)
{
    struct reader reader = {core, core_length, 0U, 0, NULL};
    memset(module, 0, sizeof *module);
    decode_header(&reader, module);
    decode_kernel(&reader, module);
    decode_footer(&reader);
    if (!reader.failed && reader.offset != reader.length) {
        reader_fail(&reader, "trailing SCB-0 bytes");
    }
    if (reader.failed) {
        error->code = "A0-BACKEND-0001";
        error->message = reader.message;
        error->offset = reader.offset;
        return 0;
    }
    return 1;
}

static void
text_put(struct text_buffer *buffer, const char *text)
{
    const size_t length = strlen(text);
    if (buffer->failed || length > buffer->capacity - buffer->length) {
        buffer->failed = 1;
        return;
    }
    memcpy(buffer->bytes + buffer->length, text, length);
    buffer->length += length;
}

static void
text_put_u8(struct text_buffer *buffer, uint8_t value)
{
    char reversed[3];
    size_t length = 0U;
    size_t index;
    do {
        reversed[length++] = (char)('0' + (value % 10U));
        value = (uint8_t)(value / 10U);
    } while (value != 0U);
    for (index = length; index > 0U; index -= 1U) {
        const char digit[2] = {reversed[index - 1U], '\0'};
        text_put(buffer, digit);
    }
}

static void
print_decision(struct text_buffer *output, enum restricted_decision decision)
{
    if (decision == RESTRICTED_REJECT_UNDERAGE) {
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
print_module(const struct restricted_module *module, char *c_source,
    size_t c_capacity, size_t *c_length)
{
    struct text_buffer output = {c_source, c_capacity, 0U, 0};
    text_put(&output,
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
    text_put_u8(&output, module->kernel.threshold);
    text_put(&output, ")) {\n");
    print_decision(&output, module->kernel.if_true);
    text_put(&output, "    } else {\n");
    print_decision(&output, module->kernel.if_false);
    text_put(&output,
        "    }\n"
        "    return result;\n"
        "}\n");
    if (output.failed) {
        return 0;
    }
    *c_length = output.length;
    return 1;
}

int
seki_core_to_c(const unsigned char *core, size_t core_length,
    char *c_source, size_t c_capacity, size_t *c_length,
    struct seki_backend_error *error)
{
    struct restricted_module module;
    if (core == NULL || c_source == NULL || c_length == NULL || error == NULL) {
        return 0;
    }
    error->code = "A0-BACKEND-0000";
    error->message = "invalid backend state";
    error->offset = 0U;
    if (!decode_module(core, core_length, &module, error)) {
        return 0;
    }
    if (!print_module(&module, c_source, c_capacity, c_length)) {
        error->code = "A0-BACKEND-0002";
        error->message = "restricted-C output exceeds capacity";
        return 0;
    }
    return 1;
}

int
seki_inspect_core(const unsigned char *core, size_t core_length,
    struct seki_core_inspection *inspection,
    struct seki_backend_error *error)
{
    struct restricted_module module;
    if (core == NULL || inspection == NULL || error == NULL) {
        return 0;
    }
    error->code = "A0-BACKEND-0000";
    error->message = "invalid backend state";
    error->offset = 0U;
    if (!decode_module(core, core_length, &module, error)) {
        return 0;
    }
    inspection->profile_version = module.profile_version;
    inspection->threshold = module.kernel.threshold;
    return 1;
}
