#include "seki_c_backend.h"

#include <stdint.h>
#include <string.h>

enum restricted_decision {
    RESTRICTED_ACCEPT_UNIT,
    RESTRICTED_REJECT_UNDERAGE
};

#define DECODED_NAME_CAPACITY 64U
#define DECODED_FIELD_CAPACITY 32U
#define DECODED_CASE_CAPACITY 32U

struct decoded_name {
    char bytes[DECODED_NAME_CAPACITY];
    size_t length;
};

struct restricted_kernel {
    uint32_t parameter_index;
    uint32_t field_index;
    uint8_t threshold;
    uint8_t rejection_tag;
    uint32_t rejection_tags[DECODED_CASE_CAPACITY];
    size_t rejection_count;
    uint32_t precedence_index;
    struct decoded_name name;
    struct decoded_name parameter_name;
    enum restricted_decision if_true;
    enum restricted_decision if_false;
};

struct restricted_module {
    uint32_t profile_version;
    struct decoded_name module_name;
    struct decoded_name record_name;
    struct decoded_name field_name;
    struct decoded_name fields[DECODED_FIELD_CAPACITY];
    size_t field_count;
    struct decoded_name variant_name;
    struct decoded_name case_name;
    struct decoded_name cases[DECODED_CASE_CAPACITY];
    uint32_t case_tags[DECODED_CASE_CAPACITY];
    size_t case_count;
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
read_name(struct reader *reader, struct decoded_name *name)
{
    const uint32_t encoded_length = read_u32(reader);
    size_t index;
    if (reader->failed) {
        return;
    }
    if (encoded_length == 0U || encoded_length >= DECODED_NAME_CAPACITY ||
        (size_t)encoded_length > reader->length - reader->offset) {
        reader_fail(reader, "SCB-0 name exceeds backend capacity");
        return;
    }
    name->length = (size_t)encoded_length;
    for (index = 0U; index < name->length; index += 1U) {
        const unsigned char value = reader->bytes[reader->offset + index];
        if (!((value >= (unsigned char)'a' && value <= (unsigned char)'z') ||
            (value >= (unsigned char)'A' && value <= (unsigned char)'Z') ||
            (value >= (unsigned char)'0' && value <= (unsigned char)'9') ||
            value == (unsigned char)'_')) {
            reader_fail(reader, "SCB-0 name contains a non-identifier byte");
            return;
        }
        name->bytes[index] = (char)value;
    }
    name->bytes[name->length] = '\0';
    reader->offset += name->length;
}

static int
decoded_name_precedes(const struct decoded_name *left,
    const struct decoded_name *right)
{
    const size_t shared = left->length < right->length ?
        left->length : right->length;
    const int comparison = memcmp(left->bytes, right->bytes, shared);
    return comparison < 0 || (comparison == 0 && left->length < right->length);
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
    uint32_t path_count;
    uint32_t path_index;
    uint32_t rejection_tag;
    uint32_t field_count;
    uint32_t case_count;
    uint32_t declaration_index;
    const uint32_t payload_length_expected =
        reader->length >= 13U ? (uint32_t)(reader->length - 13U) : 0U;
    expect_raw(reader, magic, sizeof magic, "bad SCB-0 magic");
    expect_u32(reader, 0U, "unsupported SCB-0 envelope version");
    expect_u8(reader, 0U, "expected SCB-0 module object");
    expect_u32(reader, payload_length_expected, "SCB-0 payload length mismatch");
    expect_u32(reader, 0U, "unsupported typed-core schema");
    path_count = read_u32(reader);
    if (!reader->failed && (path_count == 0U || path_count > 8U)) {
        reader_fail(reader, "module path is outside backend capacity");
    }
    for (path_index = 0U; path_index < path_count && !reader->failed;
        path_index += 1U) {
        read_name(reader, &module->module_name);
    }
    (void)read_u32(reader);
    expect_name(reader, "c11_bounded");
    module->profile_version = read_u32(reader);
    if (!reader->failed && module->profile_version != 1U) {
        reader_fail(reader, "unsupported alpha profile version");
    }
    expect_u32(reader, 0U, "imports must be empty");
    expect_u32(reader, 0U, "domains must be empty");
    expect_u32(reader, 2U, "U8-decision slice requires two declarations");
    read_name(reader, &module->record_name);
    expect_u8(reader, 2U, "first declaration must be a record");
    field_count = read_u32(reader);
    if (!reader->failed && (field_count == 0U ||
        field_count > DECODED_FIELD_CAPACITY)) {
        reader_fail(reader, "record field count exceeds backend capacity");
    }
    module->field_count = (size_t)field_count;
    for (declaration_index = 0U;
        declaration_index < field_count && !reader->failed;
        declaration_index += 1U) {
        read_name(reader, &module->fields[declaration_index]);
        expect_u8(reader, 2U, "input field must be U8");
        if (!reader->failed && declaration_index != 0U &&
            !decoded_name_precedes(&module->fields[declaration_index - 1U],
                &module->fields[declaration_index])) {
            reader_fail(reader, "record fields are not canonically ordered");
        }
    }
    read_name(reader, &module->variant_name);
    if (!reader->failed && !decoded_name_precedes(&module->record_name,
        &module->variant_name)) {
        reader_fail(reader, "type declarations are not canonically ordered");
    }
    expect_u8(reader, 3U, "second declaration must be a variant");
    case_count = read_u32(reader);
    if (!reader->failed && (case_count == 0U ||
        case_count > DECODED_CASE_CAPACITY)) {
        reader_fail(reader, "variant case count exceeds backend capacity");
    }
    module->case_count = (size_t)case_count;
    for (declaration_index = 0U;
        declaration_index < case_count && !reader->failed;
        declaration_index += 1U) {
        rejection_tag = read_u32(reader);
        if (!reader->failed && rejection_tag > UINT8_MAX) {
            reader_fail(reader, "rejection tag exceeds C representation");
        }
        module->case_tags[declaration_index] = rejection_tag;
        read_name(reader, &module->cases[declaration_index]);
        expect_u8(reader, 0U, "rejection case must have no payload");
        if (!reader->failed && declaration_index != 0U &&
            module->case_tags[declaration_index - 1U] >= rejection_tag) {
            reader_fail(reader, "variant cases are not canonically ordered");
        }
    }
    expect_u32(reader, 0U, "functions must be empty");
}

static int
case_index_for_tag(const struct restricted_module *module, uint32_t tag,
    size_t *case_index)
{
    size_t index;
    for (index = 0U; index < module->case_count; index += 1U) {
        if (module->case_tags[index] == tag) {
            *case_index = index;
            return 1;
        }
    }
    return 0;
}

static void
decode_kernel(struct reader *reader, struct restricted_module *module)
{
    uint32_t declared_steps;
    uint32_t declared_live;
    uint32_t declared_depth;
    uint32_t rejection_count;
    uint32_t rejection_index;
    uint32_t constructed_tag;
    uint32_t exact_live_bits;
    size_t selected_case = 0U;

    expect_u32(reader, 1U, "U8-decision slice requires one kernel");
    read_name(reader, &module->kernel.name);
    expect_u32(reader, 1U, "kernel requires one parameter label");
    read_name(reader, &module->kernel.parameter_name);
    expect_u32(reader, 1U, "kernel requires one parameter type");
    expect_declared_type(reader, 0U);
    expect_u8(reader, 19U, "decide result must be Decision");
    expect_u8(reader, 0U, "accepted result must be Unit");
    expect_declared_type(reader, 1U);
    rejection_count = read_u32(reader);
    if (!reader->failed && (rejection_count == 0U ||
        rejection_count > DECODED_CASE_CAPACITY)) {
        reader_fail(reader, "rejection order exceeds backend capacity");
    }
    module->kernel.rejection_count = (size_t)rejection_count;
    for (rejection_index = 0U;
        rejection_index < rejection_count && !reader->failed;
        rejection_index += 1U) {
        size_t ignored_case = 0U;
        uint32_t ordered_tag;
        expect_local_type(reader, 1U);
        ordered_tag = read_u32(reader);
        if (!case_index_for_tag(module, ordered_tag, &ignored_case)) {
            reader_fail(reader, "rejection order references unknown case");
        }
        module->kernel.rejection_tags[rejection_index] = ordered_tag;
    }

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
    if (!reader->failed &&
        (size_t)module->kernel.field_index >= module->field_count) {
        reader_fail(reader, "projection field index is out of range");
    } else if (!reader->failed) {
        module->field_name = module->fields[module->kernel.field_index];
    }
    expect_u8(reader, 2U, "comparison literal must claim U8");
    expect_u8(reader, 2U, "comparison right side must be IntLit");
    expect_u8(reader, 0U, "comparison literal family must be U8");
    module->kernel.threshold = read_u8(reader);

    expect_u8(reader, 1U, "true branch must reject");
    expect_declared_type(reader, 1U);
    expect_u8(reader, 8U, "rejection value must construct a variant");
    expect_local_type(reader, 1U);
    constructed_tag = read_u32(reader);
    if (!reader->failed && !case_index_for_tag(module, constructed_tag,
        &selected_case)) {
        reader_fail(reader, "true branch constructs unknown rejection");
    } else if (!reader->failed) {
        module->kernel.rejection_tag = (uint8_t)constructed_tag;
        module->case_name = module->cases[selected_case];
    }
    expect_u32(reader, 0U, "Underage must have no arguments");
    module->kernel.precedence_index = read_u32(reader);
    if (!reader->failed &&
        ((size_t)module->kernel.precedence_index >=
            module->kernel.rejection_count ||
         module->kernel.rejection_tags[module->kernel.precedence_index] !=
            constructed_tag)) {
        reader_fail(reader, "rejection precedence index is inconsistent");
    }
    module->kernel.if_true = RESTRICTED_REJECT_UNDERAGE;

    expect_u8(reader, 0U, "false branch must accept");
    expect_u8(reader, 0U, "accepted value must claim Unit");
    expect_u8(reader, 0U, "accepted value must be Unit literal");
    module->kernel.if_false = RESTRICTED_ACCEPT_UNIT;

    declared_steps = read_u32(reader);
    declared_live = read_u32(reader);
    declared_depth = read_u32(reader);
    (void)read_u32(reader);
    if (!reader->failed && (declared_steps < 8U || declared_depth < 5U)) {
        reader_fail(reader, "declared resource ceiling below exact bound");
    }
    exact_live_bits = (uint32_t)module->field_count * 16U + 8U;
    if ((uint32_t)module->field_count * 8U + 17U > exact_live_bits) {
        exact_live_bits = (uint32_t)module->field_count * 8U + 17U;
    }
    if (!reader->failed && declared_live < exact_live_bits) {
        reader_fail(reader, "declared live-bit ceiling below exact bound");
    }
    expect_bounds(reader, 8U, exact_live_bits, 5U, 0U);
    expect_u8(reader, 0U, "publication must be disabled");
    if (!reader->failed && module->kernel.parameter_index != 0U) {
        reader_fail(reader, "condition references unexpected parameter");
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

static int
decoded_name_is(const struct decoded_name *name, const char *text)
{
    const size_t length = strlen(text);
    return name->length == length && memcmp(name->bytes, text, length) == 0;
}

static void
text_put_name(struct text_buffer *buffer, const struct decoded_name *name,
    int lower_case)
{
    size_t index;
    for (index = 0U; index < name->length; index += 1U) {
        char character = name->bytes[index];
        if (lower_case && character >= 'A' && character <= 'Z') {
            character = (char)(character - 'A' + 'a');
        }
        if (buffer->failed || buffer->length == buffer->capacity) {
            buffer->failed = 1;
            return;
        }
        buffer->bytes[buffer->length++] = character;
    }
}

static int
uses_e0_compatibility_abi(const struct restricted_module *module)
{
    return decoded_name_is(&module->module_name, "minimum_age") &&
        decoded_name_is(&module->record_name, "Applicant") &&
        decoded_name_is(&module->field_name, "age") &&
        decoded_name_is(&module->variant_name, "Rejection") &&
        decoded_name_is(&module->case_name, "Underage") &&
        decoded_name_is(&module->kernel.name, "decide") &&
        decoded_name_is(&module->kernel.parameter_name, "applicant") &&
        module->kernel.rejection_tag == 1U;
}

static void
text_put_prefix(struct text_buffer *buffer,
    const struct restricted_module *module)
{
    if (uses_e0_compatibility_abi(module)) {
        text_put(buffer, "seki_e0");
    } else {
        text_put(buffer, "seki_a0_");
        text_put_name(buffer, &module->module_name, 1);
    }
}

static void
text_put_field_identifier(struct text_buffer *buffer,
    const struct restricted_module *module)
{
    if (!uses_e0_compatibility_abi(module)) {
        text_put(buffer, "seki_f_");
    }
    text_put_name(buffer, &module->field_name, 0);
}

static void
text_put_parameter_identifier(struct text_buffer *buffer,
    const struct restricted_module *module)
{
    if (!uses_e0_compatibility_abi(module)) {
        text_put(buffer, "seki_p_");
    }
    text_put_name(buffer, &module->kernel.parameter_name, 0);
}

static void
print_decision(struct text_buffer *output, enum restricted_decision decision,
    uint8_t rejection_tag)
{
    if (decision == RESTRICTED_REJECT_UNDERAGE) {
        text_put(output,
            "        result.tag = UINT8_C(1);\n"
            "        result.reason = UINT8_C(");
        text_put_u8(output, rejection_tag);
        text_put(output, ");\n");
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
    size_t field_index;
    text_put(&output,
        "#include <stdint.h>\n"
        "\n"
        "typedef struct {\n");
    for (field_index = 0U; field_index < module->field_count;
        field_index += 1U) {
        text_put(&output, "    uint8_t ");
        if (!uses_e0_compatibility_abi(module)) {
            text_put(&output, "seki_f_");
        }
        text_put_name(&output, &module->fields[field_index], 0);
        text_put(&output, ";\n");
    }
    text_put(&output, "} ");
    text_put_prefix(&output, module);
    text_put(&output, "_");
    text_put_name(&output, &module->record_name, 1);
    text_put(&output,
        ";\n"
        "\n"
        "typedef struct {\n"
        "    uint8_t tag;\n"
        "    uint8_t reason;\n"
        "} ");
    text_put_prefix(&output, module);
    text_put(&output, "_decision;\n\n");
    text_put_prefix(&output, module);
    text_put(&output, "_decision ");
    text_put_prefix(&output, module);
    text_put(&output, "_");
    text_put_name(&output, &module->kernel.name, 0);
    text_put(&output, "(");
    text_put_prefix(&output, module);
    text_put(&output, "_");
    text_put_name(&output, &module->record_name, 1);
    text_put(&output, " ");
    text_put_parameter_identifier(&output, module);
    text_put(&output, ");\n\n");
    text_put_prefix(&output, module);
    text_put(&output, "_decision\n");
    text_put_prefix(&output, module);
    text_put(&output, "_");
    text_put_name(&output, &module->kernel.name, 0);
    text_put(&output, "(");
    text_put_prefix(&output, module);
    text_put(&output, "_");
    text_put_name(&output, &module->record_name, 1);
    text_put(&output, " ");
    text_put_parameter_identifier(&output, module);
    text_put(&output, ")\n{\n    ");
    text_put_prefix(&output, module);
    text_put(&output, "_decision result;\n    if (");
    text_put_parameter_identifier(&output, module);
    text_put(&output, ".");
    text_put_field_identifier(&output, module);
    text_put(&output, " < UINT8_C(");
    text_put_u8(&output, module->kernel.threshold);
    text_put(&output, ")) {\n");
    print_decision(&output, module->kernel.if_true,
        module->kernel.rejection_tag);
    text_put(&output, "    } else {\n");
    print_decision(&output, module->kernel.if_false,
        module->kernel.rejection_tag);
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
