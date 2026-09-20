#include "seki_c_backend.h"

#include <stdint.h>
#include <string.h>

#define DECODED_NAME_CAPACITY 64U
#define DECODED_FIELD_CAPACITY 32U
#define DECODED_CASE_CAPACITY 32U
#define RESTRICTED_MAX_EXPRESSIONS 256U
#define RESTRICTED_MAX_TAILS 128U

struct decoded_name {
    char bytes[DECODED_NAME_CAPACITY];
    size_t length;
};

/*
 * SCB-0 `CompareOp` discriminants, plus the two equality terms, in the one
 * order the printer indexes. A term the decoder does not recognise never
 * reaches this enumeration.
 */
enum restricted_compare {
    RESTRICTED_LESS = 0,
    RESTRICTED_LESS_EQUAL = 1,
    RESTRICTED_GREATER = 2,
    RESTRICTED_GREATER_EQUAL = 3,
    RESTRICTED_EQUAL = 4,
    RESTRICTED_NOT_EQUAL = 5
};

/*
 * Restricted-C value terms. The decoder builds this arena from SCB-0 and the
 * printer walks it; no stage assumes a particular tree shape.
 */
enum restricted_term {
    RESTRICTED_LOCAL,
    RESTRICTED_PROJECT,
    RESTRICTED_INT_LIT,
    RESTRICTED_UNIT_LIT,
    RESTRICTED_BOOL_LIT,
    RESTRICTED_VARIANT,
    RESTRICTED_COMPARE
};

struct restricted_expression {
    enum restricted_term kind;
    enum restricted_compare compare;
    /*
     * LOCAL    a = environment slot
     * PROJECT  a = record expression, b = field index
     * INT_LIT  a = value
     * BOOL_LIT a = 0 or 1
     * VARIANT  a = stable tag
     * COMPARE  a = left, b = right
     */
    uint32_t a;
    uint32_t b;
};

enum restricted_tail_kind {
    RESTRICTED_ACCEPT,
    RESTRICTED_REJECT,
    RESTRICTED_IF
};

struct restricted_tail {
    enum restricted_tail_kind kind;
    /*
     * ACCEPT  a = accepted value expression
     * REJECT  a = reason expression, b = precedence index
     * IF      a = condition, b = when-true tail, c = when-false tail
     */
    uint32_t a;
    uint32_t b;
    uint32_t c;
};

struct restricted_kernel {
    uint32_t rejection_tags[DECODED_CASE_CAPACITY];
    size_t rejection_count;
    struct decoded_name name;
    struct decoded_name parameter_name;
    struct restricted_expression expressions[RESTRICTED_MAX_EXPRESSIONS];
    size_t expression_count;
    struct restricted_tail tails[RESTRICTED_MAX_TAILS];
    size_t tail_count;
    uint32_t body_root;
    /* First projected field and first constructed rejection, retained only for
     * the E0 compatibility-ABI test and the `inspect` threshold report. */
    uint8_t threshold;
    uint8_t rejection_tag;
};

struct restricted_module {
    uint32_t profile_version;
    /*
     * Canonical table positions of the two declarations. The typed core orders
     * its type table by name, so whether the record or the variant comes first
     * depends on the program's own identifiers. Every emitted reference uses
     * these positions rather than a fixed 0/1 assumption.
     */
    uint32_t record_position;
    uint32_t variant_position;
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
    uint32_t field_count = 0U;
    uint32_t case_count = 0U;
    uint32_t declaration_index;
    uint32_t position;
    struct decoded_name previous;
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
    module->record_position = UINT32_MAX;
    module->variant_position = UINT32_MAX;
    for (position = 0U; position < 2U && !reader->failed; position += 1U) {
        struct decoded_name name;
        uint8_t body;
        read_name(reader, &name);
        if (position == 1U && !reader->failed &&
            !decoded_name_precedes(&previous, &name)) {
            reader_fail(reader, "type declarations are not canonically ordered");
            break;
        }
        previous = name;
        body = read_u8(reader);
        if (reader->failed) {
            break;
        }
        if (body == 2U) {
            if (module->record_position != UINT32_MAX) {
                reader_fail(reader, "slice requires exactly one record");
                break;
            }
            module->record_position = position;
            module->record_name = name;
            field_count = read_u32(reader);
            if (!reader->failed && (field_count == 0U ||
                field_count > DECODED_FIELD_CAPACITY)) {
                reader_fail(reader,
                    "record field count exceeds backend capacity");
                break;
            }
            module->field_count = (size_t)field_count;
            for (declaration_index = 0U;
                declaration_index < field_count && !reader->failed;
                declaration_index += 1U) {
                read_name(reader, &module->fields[declaration_index]);
                expect_u8(reader, 2U, "input field must be U8");
                if (!reader->failed && declaration_index != 0U &&
                    !decoded_name_precedes(
                        &module->fields[declaration_index - 1U],
                        &module->fields[declaration_index])) {
                    reader_fail(reader,
                        "record fields are not canonically ordered");
                }
            }
        } else if (body == 3U) {
            if (module->variant_position != UINT32_MAX) {
                reader_fail(reader, "slice requires exactly one variant");
                break;
            }
            module->variant_position = position;
            module->variant_name = name;
            case_count = read_u32(reader);
            if (!reader->failed && (case_count == 0U ||
                case_count > DECODED_CASE_CAPACITY)) {
                reader_fail(reader,
                    "variant case count exceeds backend capacity");
                break;
            }
            module->case_count = (size_t)case_count;
            for (declaration_index = 0U;
                declaration_index < case_count && !reader->failed;
                declaration_index += 1U) {
                rejection_tag = read_u32(reader);
                if (!reader->failed && rejection_tag > UINT8_MAX) {
                    reader_fail(reader,
                        "rejection tag exceeds C representation");
                }
                module->case_tags[declaration_index] = rejection_tag;
                read_name(reader, &module->cases[declaration_index]);
                expect_u8(reader, 0U, "rejection case must have no payload");
                if (!reader->failed && declaration_index != 0U &&
                    module->case_tags[declaration_index - 1U] >=
                        rejection_tag) {
                    reader_fail(reader,
                        "variant cases are not canonically ordered");
                }
            }
        } else {
            reader_fail(reader, "declaration must be a record or a variant");
        }
    }
    if (!reader->failed && (module->record_position == UINT32_MAX ||
        module->variant_position == UINT32_MAX)) {
        reader_fail(reader, "slice requires one record and one variant");
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

/*
 * Decodes one `Expr`: its claimed type value followed by its term. Returns the
 * arena index, or leaves the reader failed.
 */
static uint32_t
add_expression(struct reader *reader, struct restricted_module *module,
    const struct restricted_expression *expression)
{
    uint32_t index;
    if (reader->failed) {
        return 0U;
    }
    if (module->kernel.expression_count == RESTRICTED_MAX_EXPRESSIONS) {
        reader_fail(reader, "kernel expressions exceed backend capacity");
        return 0U;
    }
    index = (uint32_t)module->kernel.expression_count;
    module->kernel.expressions[index] = *expression;
    module->kernel.expression_count += 1U;
    return index;
}

/*
 * Reads one claimed type value, restricted to the forms this projection can
 * represent in C. `Declared` references are checked against the canonical
 * positions established by the header.
 */
static void
expect_claimed_type(struct reader *reader, struct restricted_module *module)
{
    const uint8_t tag = read_u8(reader);
    if (reader->failed) {
        return;
    }
    switch (tag) {
    case 0U:
    case 1U:
    case 2U:
        return;
    case 19U:
        expect_u8(reader, 0U, "decision result must accept Unit");
        expect_declared_type(reader, module->variant_position);
        return;
    case 21U: {
        const uint8_t local = read_u8(reader);
        const uint32_t position = read_u32(reader);
        if (!reader->failed && (local != 0U ||
            (position != module->record_position &&
             position != module->variant_position))) {
            reader_fail(reader, "declared type is outside the module");
        }
        return;
    }
    default:
        break;
    }
    reader_fail(reader, "claimed type is outside the restricted-C slice");
}

static uint32_t
decode_expression(struct reader *reader, struct restricted_module *module)
{
    struct restricted_expression expression;
    uint8_t term;
    memset(&expression, 0, sizeof expression);
    if (reader->failed) {
        return 0U;
    }
    expect_claimed_type(reader, module);
    term = read_u8(reader);
    if (reader->failed) {
        return 0U;
    }
    switch (term) {
    case 0U:
        expression.kind = RESTRICTED_UNIT_LIT;
        break;
    case 1U: {
        const uint8_t value = read_u8(reader);
        if (!reader->failed && value > 1U) {
            reader_fail(reader, "boolean literal is not 0 or 1");
            return 0U;
        }
        expression.kind = RESTRICTED_BOOL_LIT;
        expression.a = value;
        break;
    }
    case 2U:
        expect_u8(reader, 0U, "integer literal family must be U8");
        expression.kind = RESTRICTED_INT_LIT;
        expression.a = read_u8(reader);
        if (module->kernel.threshold == 0U) {
            module->kernel.threshold = (uint8_t)expression.a;
        }
        break;
    case 4U:
        expression.kind = RESTRICTED_LOCAL;
        expression.a = read_u32(reader);
        if (!reader->failed && expression.a != 0U) {
            reader_fail(reader, "condition references unexpected parameter");
            return 0U;
        }
        break;
    case 7U: {
        const uint32_t record = decode_expression(reader, module);
        expression.kind = RESTRICTED_PROJECT;
        expression.a = record;
        expect_u8(reader, 0U, "field owner must be a record type");
        expect_local_type(reader, module->record_position);
        expression.b = read_u32(reader);
        if (!reader->failed &&
            (size_t)expression.b >= module->field_count) {
            reader_fail(reader, "projection field index is out of range");
            return 0U;
        }
        if (!reader->failed && module->field_name.length == 0U) {
            module->field_name = module->fields[expression.b];
        }
        break;
    }
    case 8U: {
        size_t selected = 0U;
        expect_local_type(reader, module->variant_position);
        expression.kind = RESTRICTED_VARIANT;
        expression.a = read_u32(reader);
        if (!reader->failed && !case_index_for_tag(module, expression.a,
            &selected)) {
            reader_fail(reader, "rejection constructs an unknown case");
            return 0U;
        }
        expect_u32(reader, 0U, "rejection case takes no arguments");
        if (!reader->failed && module->case_name.length == 0U) {
            module->case_name = module->cases[selected];
            module->kernel.rejection_tag = (uint8_t)expression.a;
        }
        break;
    }
    case 14U:
    case 15U:
    case 19U: {
        if (term == 19U) {
            const uint8_t operation = read_u8(reader);
            if (!reader->failed && operation > 3U) {
                reader_fail(reader, "unknown comparison operator");
                return 0U;
            }
            expression.compare = (enum restricted_compare)operation;
        } else {
            expression.compare = term == 14U ?
                RESTRICTED_EQUAL : RESTRICTED_NOT_EQUAL;
        }
        expression.kind = RESTRICTED_COMPARE;
        expression.a = decode_expression(reader, module);
        expression.b = decode_expression(reader, module);
        break;
    }
    default:
        reader_fail(reader, "term is outside the restricted-C slice");
        return 0U;
    }
    return add_expression(reader, module, &expression);
}

static uint32_t
decode_tail(struct reader *reader, struct restricted_module *module,
    unsigned depth)
{
    struct restricted_tail tail;
    uint8_t kind;
    uint32_t index;
    memset(&tail, 0, sizeof tail);
    if (reader->failed) {
        return 0U;
    }
    /* Kernel control nests, so descent is bounded by the arena rather than by
     * the host stack. */
    if (depth >= RESTRICTED_MAX_TAILS) {
        reader_fail(reader, "kernel control nesting exceeds backend capacity");
        return 0U;
    }
    kind = read_u8(reader);
    if (reader->failed) {
        return 0U;
    }
    switch (kind) {
    case 0U:
        tail.kind = RESTRICTED_ACCEPT;
        tail.a = decode_expression(reader, module);
        break;
    case 1U:
        tail.kind = RESTRICTED_REJECT;
        tail.a = decode_expression(reader, module);
        tail.b = read_u32(reader);
        if (!reader->failed &&
            ((size_t)tail.b >= module->kernel.rejection_count ||
             module->kernel.expressions[tail.a].kind != RESTRICTED_VARIANT ||
             module->kernel.rejection_tags[tail.b] !=
                module->kernel.expressions[tail.a].a)) {
            reader_fail(reader, "rejection precedence index is inconsistent");
            return 0U;
        }
        break;
    case 4U:
        tail.kind = RESTRICTED_IF;
        tail.a = decode_expression(reader, module);
        tail.b = decode_tail(reader, module, depth + 1U);
        tail.c = decode_tail(reader, module, depth + 1U);
        break;
    default:
        reader_fail(reader, "kernel control is outside the restricted-C slice");
        return 0U;
    }
    if (reader->failed) {
        return 0U;
    }
    if (module->kernel.tail_count == RESTRICTED_MAX_TAILS) {
        reader_fail(reader, "kernel control exceeds backend capacity");
        return 0U;
    }
    index = (uint32_t)module->kernel.tail_count;
    module->kernel.tails[index] = tail;
    module->kernel.tail_count += 1U;
    return index;
}

static void
decode_kernel(struct reader *reader, struct restricted_module *module)
{
    uint32_t declared[4];
    uint32_t exact[4];
    uint32_t rejection_count;
    uint32_t rejection_index;
    size_t component;

    expect_u32(reader, 1U, "restricted-C slice requires one kernel");
    read_name(reader, &module->kernel.name);
    expect_u32(reader, 1U, "kernel requires one parameter label");
    read_name(reader, &module->kernel.parameter_name);
    expect_u32(reader, 1U, "kernel requires one parameter type");
    expect_declared_type(reader, module->record_position);
    expect_u8(reader, 19U, "kernel result must be a Decision");
    expect_u8(reader, 0U, "accepted result must be Unit");
    expect_declared_type(reader, module->variant_position);
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
        expect_local_type(reader, module->variant_position);
        ordered_tag = read_u32(reader);
        if (!case_index_for_tag(module, ordered_tag, &ignored_case)) {
            reader_fail(reader, "rejection order references unknown case");
        }
        module->kernel.rejection_tags[rejection_index] = ordered_tag;
    }

    module->kernel.body_root = decode_tail(reader, module, 0U);

    /*
     * The projection checks that the stored exact bounds are well formed and
     * within the declared ceiling. Equality between the stored bounds and the
     * canonical derivation is an admission obligation, checked by the semantic
     * checker against the cost algebra; re-deriving it here with a second,
     * weaker algebra would create a checker that silently disagrees.
     */
    for (component = 0U; component < 4U; component += 1U) {
        declared[component] = read_u32(reader);
    }
    for (component = 0U; component < 4U; component += 1U) {
        exact[component] = read_u32(reader);
        if (!reader->failed && exact[component] > declared[component]) {
            reader_fail(reader, "exact bound exceeds the declared ceiling");
            return;
        }
    }
    expect_u8(reader, 0U, "publication must be disabled");
}

/*
 * Theorem and claim vectors are module metadata, not part of the restricted C
 * slice. Check that each is a strictly increasing vector of known tags rather
 * than one specific list, so a module stating a different obligation set still
 * projects to C.
 */
static void
expect_tag_vector(struct reader *reader, uint8_t maximum, const char *what)
{
    const uint32_t count = read_u32(reader);
    uint32_t index;
    int has_previous = 0;
    uint8_t previous = 0U;
    if (!reader->failed && count > (uint32_t)maximum + 1U) {
        reader_fail(reader, what);
        return;
    }
    for (index = 0U; index < count && !reader->failed; index += 1U) {
        const uint8_t tag = read_u8(reader);
        if (reader->failed) {
            return;
        }
        if (tag > maximum || (has_previous && tag <= previous)) {
            reader_fail(reader, what);
            return;
        }
        previous = tag;
        has_previous = 1;
    }
}

static void
decode_footer(struct reader *reader)
{
    expect_u32(reader, 0U, "exported domains must be empty");
    expect_u32(reader, 2U, "both types must be exported");
    expect_u32(reader, 0U, "first type export index changed");
    expect_u32(reader, 1U, "second type export index changed");
    expect_u32(reader, 0U, "exported functions must be empty");
    expect_u32(reader, 1U, "the kernel must be exported");
    expect_u32(reader, 0U, "kernel export index changed");
    /*
     * Theorem and claim vectors are module metadata, not part of the restricted
     * C slice. The backend checks that each is a strictly increasing vector of
     * known tags rather than one specific list, so a module that states a
     * different obligation set still projects to C.
     */
    expect_tag_vector(reader, 6U, "theorem requirement");
    expect_tag_vector(reader, 7U, "claim ceiling");
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
text_put_parameter_identifier(struct text_buffer *buffer,
    const struct restricted_module *module)
{
    if (!uses_e0_compatibility_abi(module)) {
        text_put(buffer, "seki_p_");
    }
    text_put_name(buffer, &module->kernel.parameter_name, 0);
}

static const char *
restricted_compare_text(enum restricted_compare compare)
{
    static const char *const spellings[] = {
        " < ", " <= ", " > ", " >= ", " == ", " != "
    };
    return spellings[compare];
}

static void
text_put_indent(struct text_buffer *output, unsigned depth)
{
    unsigned level;
    for (level = 0U; level < depth; level += 1U) {
        text_put(output, "    ");
    }
}

static void
print_expression(struct text_buffer *output,
    const struct restricted_module *module, uint32_t index)
{
    const struct restricted_expression *expression;
    if (output->failed ||
        (size_t)index >= module->kernel.expression_count) {
        output->failed = 1;
        return;
    }
    expression = &module->kernel.expressions[index];
    switch (expression->kind) {
    case RESTRICTED_LOCAL:
        text_put_parameter_identifier(output, module);
        break;
    case RESTRICTED_PROJECT:
        print_expression(output, module, expression->a);
        text_put(output, ".");
        if (!uses_e0_compatibility_abi(module)) {
            text_put(output, "seki_f_");
        }
        if ((size_t)expression->b >= module->field_count) {
            output->failed = 1;
            return;
        }
        text_put_name(output, &module->fields[expression->b], 0);
        break;
    case RESTRICTED_INT_LIT:
        text_put(output, "UINT8_C(");
        text_put_u8(output, (uint8_t)expression->a);
        text_put(output, ")");
        break;
    case RESTRICTED_BOOL_LIT:
        text_put(output, expression->a != 0U ? "1" : "0");
        break;
    case RESTRICTED_COMPARE:
        print_expression(output, module, expression->a);
        text_put(output, restricted_compare_text(expression->compare));
        print_expression(output, module, expression->b);
        break;
    case RESTRICTED_UNIT_LIT:
    case RESTRICTED_VARIANT:
    default:
        /* Neither appears in a C value position: the decision result carries
         * them as the tag/reason pair written by print_tail. */
        output->failed = 1;
        break;
    }
}

static void
print_tail(struct text_buffer *output, const struct restricted_module *module,
    uint32_t index, unsigned depth)
{
    const struct restricted_tail *tail;
    if (output->failed || (size_t)index >= module->kernel.tail_count) {
        output->failed = 1;
        return;
    }
    tail = &module->kernel.tails[index];
    switch (tail->kind) {
    case RESTRICTED_ACCEPT:
        text_put_indent(output, depth);
        text_put(output, "result.tag = UINT8_C(0);\n");
        text_put_indent(output, depth);
        text_put(output, "result.reason = UINT8_C(0);\n");
        break;
    case RESTRICTED_REJECT: {
        const struct restricted_expression *reason;
        if ((size_t)tail->a >= module->kernel.expression_count) {
            output->failed = 1;
            return;
        }
        reason = &module->kernel.expressions[tail->a];
        text_put_indent(output, depth);
        text_put(output, "result.tag = UINT8_C(1);\n");
        text_put_indent(output, depth);
        text_put(output, "result.reason = UINT8_C(");
        text_put_u8(output, (uint8_t)reason->a);
        text_put(output, ");\n");
        break;
    }
    case RESTRICTED_IF:
        text_put_indent(output, depth);
        text_put(output, "if (");
        print_expression(output, module, tail->a);
        text_put(output, ") {\n");
        print_tail(output, module, tail->b, depth + 1U);
        text_put_indent(output, depth);
        text_put(output, "} else {\n");
        print_tail(output, module, tail->c, depth + 1U);
        text_put_indent(output, depth);
        text_put(output, "}\n");
        break;
    default:
        output->failed = 1;
        break;
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
    text_put(&output, "_decision result;\n");
    print_tail(&output, module, module->kernel.body_root, 1U);
    text_put(&output,
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
