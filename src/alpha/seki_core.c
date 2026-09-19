#include "seki_core.h"

#include <stdint.h>
#include <string.h>

struct core_buffer {
    unsigned char *bytes;
    size_t capacity;
    size_t length;
    int failed;
};

static void
put_raw(struct core_buffer *buffer, const unsigned char *bytes, size_t length)
{
    if (buffer->failed || length > buffer->capacity - buffer->length) {
        buffer->failed = 1;
        return;
    }
    memcpy(buffer->bytes + buffer->length, bytes, length);
    buffer->length += length;
}

static void
put_u8(struct core_buffer *buffer, uint8_t value)
{
    put_raw(buffer, &value, 1U);
}

static void
put_u32(struct core_buffer *buffer, uint32_t value)
{
    const unsigned char bytes[4] = {
        (unsigned char)(value >> 24), (unsigned char)(value >> 16),
        (unsigned char)(value >> 8), (unsigned char)value
    };
    put_raw(buffer, bytes, sizeof bytes);
}

static void
put_name(struct core_buffer *buffer, const struct seki_name *name)
{
    if (name->length > UINT32_MAX) {
        buffer->failed = 1;
        return;
    }
    put_u32(buffer, (uint32_t)name->length);
    put_raw(buffer, name->bytes, name->length);
}

static void
put_text(struct core_buffer *buffer, const char *text)
{
    struct seki_name name;
    name.bytes = (const unsigned char *)text;
    name.length = strlen(text);
    put_name(buffer, &name);
}

static void
put_local_type_ref(struct core_buffer *buffer, uint32_t index)
{
    put_u8(buffer, 0U);
    put_u32(buffer, index);
}

static void
put_declared(struct core_buffer *buffer, uint32_t index)
{
    put_u8(buffer, 21U);
    put_local_type_ref(buffer, index);
}

static void put_applicant(struct core_buffer *buffer) { put_declared(buffer, 0U); }
static void put_rejection(struct core_buffer *buffer) { put_declared(buffer, 1U); }
static void put_unit(struct core_buffer *buffer) { put_u8(buffer, 0U); }
static void put_bool(struct core_buffer *buffer) { put_u8(buffer, 1U); }
static void put_type_u8(struct core_buffer *buffer) { put_u8(buffer, 2U); }

static void
put_bounds(struct core_buffer *buffer, uint32_t steps, uint32_t live,
    uint32_t depth, uint32_t workspace)
{
    put_u32(buffer, steps);
    put_u32(buffer, live);
    put_u32(buffer, depth);
    put_u32(buffer, workspace);
}

static int
has_names(const struct seki_name *names, size_t count,
    const char *const *expected, size_t expected_count)
{
    size_t index;
    size_t candidate;
    if (count != expected_count) {
        return 0;
    }
    for (index = 0U; index < expected_count; index += 1U) {
        int found = 0;
        for (candidate = 0U; candidate < count; candidate += 1U) {
            if (seki_name_is(&names[candidate], expected[index])) {
                found = 1;
                break;
            }
        }
        if (!found) {
            return 0;
        }
    }
    return 1;
}

static int
extract_minimum_age(const struct seki_module_prefix *module,
    uint32_t *threshold)
{
    static const char *const claims[] = {
        "semantic_evaluation", "lean_projection", "restricted_c_source"
    };
    static const char *const requirements[] = {
        "type_well_formed", "totality", "determinism", "resource_bounds",
        "rejection_precedence"
    };
    const struct seki_kernel_decl *kernel;
    const struct seki_expression *root;
    const struct seki_expression *condition;
    const struct seki_expression *left;
    const struct seki_expression *receiver;
    const struct seki_expression *right;
    const struct seki_expression *if_true;
    const struct seki_expression *if_false;
    const struct seki_expression *accepted;

    if (module->header.path_count != 3U ||
        !seki_name_is(&module->header.path[0], "seki") ||
        !seki_name_is(&module->header.path[1], "experiments") ||
        !seki_name_is(&module->header.path[2], "minimum_age") ||
        module->header.module_version != 1U ||
        !seki_name_is(&module->header.profile, "c11_bounded") ||
        module->header.profile_version != 1U ||
        !has_names(module->header.claims, module->header.claim_count, claims,
            sizeof claims / sizeof claims[0]) ||
        !has_names(module->header.requirements,
            module->header.requirement_count, requirements,
            sizeof requirements / sizeof requirements[0]) ||
        module->declaration_count != 2U || module->kernel_count != 1U) {
        return 0;
    }
    if (module->declarations[0].kind != SEKI_DECL_RECORD ||
        !seki_name_is(&module->declarations[0].name, "Applicant") ||
        module->declarations[0].value.record.field_count != 1U ||
        !seki_name_is(&module->declarations[0].value.record.fields[0].name,
            "age") ||
        !seki_name_is(&module->declarations[0].value.record.fields[0].type.name,
            "U8") || module->declarations[1].kind != SEKI_DECL_VARIANT ||
        !seki_name_is(&module->declarations[1].name, "Rejection") ||
        module->declarations[1].value.variant.case_count != 1U ||
        !seki_name_is(&module->declarations[1].value.variant.cases[0].name,
            "Underage") ||
        module->declarations[1].value.variant.cases[0].tag != 1U ||
        module->declarations[1].value.variant.cases[0].payload_count != 0U) {
        return 0;
    }
    kernel = &module->kernels[0];
    if (!seki_name_is(&kernel->name, "decide") ||
        kernel->parameter_count != 1U ||
        !seki_name_is(&kernel->parameters[0].label, "applicant") ||
        kernel->parameters[0].type.kind != SEKI_TYPE_NAMED ||
        !seki_name_is(&kernel->parameters[0].type.name, "Applicant") ||
        kernel->result.kind != SEKI_TYPE_APPLIED ||
        !seki_name_is(&kernel->result.name, "Decision") ||
        kernel->result.argument_count != 2U ||
        kernel->result.arguments[0].kind != SEKI_TYPE_ARG_TYPE_NAME ||
        !seki_name_is(&kernel->result.arguments[0].name, "Unit") ||
        kernel->result.arguments[1].kind != SEKI_TYPE_ARG_TYPE_NAME ||
        !seki_name_is(&kernel->result.arguments[1].name, "Rejection") ||
        !seki_name_is(&kernel->arithmetic_policy, "checked") ||
        kernel->rejection_count != 1U ||
        !seki_name_is(&kernel->rejections[0].owner, "Rejection") ||
        !seki_name_is(&kernel->rejections[0].item, "Underage") ||
        kernel->publication_eligible != 0 ||
        kernel->bounds.steps < 8U || kernel->bounds.live_bits < 25U ||
        kernel->bounds.control_depth < 5U ||
        (size_t)kernel->body_root >= kernel->expression_count) {
        return 0;
    }
    root = &kernel->expressions[kernel->body_root];
    if (root->kind != SEKI_EXPR_IF ||
        (size_t)root->value.conditional.condition >= kernel->expression_count ||
        (size_t)root->value.conditional.if_true >= kernel->expression_count ||
        (size_t)root->value.conditional.if_false >= kernel->expression_count) {
        return 0;
    }
    condition = &kernel->expressions[root->value.conditional.condition];
    if_true = &kernel->expressions[root->value.conditional.if_true];
    if_false = &kernel->expressions[root->value.conditional.if_false];
    if (condition->kind != SEKI_EXPR_COMPARE ||
        condition->value.compare.operator != SEKI_COMPARE_LESS ||
        if_true->kind != SEKI_EXPR_REJECT ||
        !seki_name_is(&if_true->value.rejection.owner, "Rejection") ||
        !seki_name_is(&if_true->value.rejection.item, "Underage") ||
        if_false->kind != SEKI_EXPR_ACCEPT ||
        (size_t)condition->value.compare.left >= kernel->expression_count ||
        (size_t)condition->value.compare.right >= kernel->expression_count ||
        (size_t)if_false->value.accept.value >= kernel->expression_count) {
        return 0;
    }
    left = &kernel->expressions[condition->value.compare.left];
    right = &kernel->expressions[condition->value.compare.right];
    accepted = &kernel->expressions[if_false->value.accept.value];
    if (left->kind != SEKI_EXPR_FIELD ||
        !seki_name_is(&left->value.field.field, "age") ||
        (size_t)left->value.field.receiver >= kernel->expression_count ||
        right->kind != SEKI_EXPR_NATURAL || right->value.natural > UINT8_MAX ||
        accepted->kind != SEKI_EXPR_UNIT) {
        return 0;
    }
    receiver = &kernel->expressions[left->value.field.receiver];
    if (receiver->kind != SEKI_EXPR_VALUE_NAME ||
        !seki_name_is(&receiver->value.name, "applicant")) {
        return 0;
    }
    *threshold = right->value.natural;
    return 1;
}

static void
put_kernel(struct core_buffer *buffer, const struct seki_kernel_decl *kernel,
    uint32_t threshold)
{
    put_name(buffer, &kernel->name);
    put_u32(buffer, 1U);
    put_name(buffer, &kernel->parameters[0].label);
    put_u32(buffer, 1U);
    put_applicant(buffer);
    put_u8(buffer, 19U);
    put_unit(buffer);
    put_rejection(buffer);
    put_u32(buffer, 1U);
    put_local_type_ref(buffer, 1U);
    put_u32(buffer, 1U);

    put_u8(buffer, 4U);
    put_bool(buffer);
    put_u8(buffer, 19U);
    put_u8(buffer, 0U);
    put_type_u8(buffer);
    put_u8(buffer, 7U);
    put_applicant(buffer);
    put_u8(buffer, 4U);
    put_u32(buffer, 0U);
    put_u8(buffer, 0U);
    put_local_type_ref(buffer, 0U);
    put_u32(buffer, 0U);
    put_type_u8(buffer);
    put_u8(buffer, 2U);
    put_u8(buffer, 0U);
    put_u8(buffer, (uint8_t)threshold);

    put_u8(buffer, 1U);
    put_rejection(buffer);
    put_u8(buffer, 8U);
    put_local_type_ref(buffer, 1U);
    put_u32(buffer, 1U);
    put_u32(buffer, 0U);
    put_u32(buffer, 0U);
    put_u8(buffer, 0U);
    put_unit(buffer);
    put_u8(buffer, 0U);

    put_bounds(buffer, kernel->bounds.steps, kernel->bounds.live_bits,
        kernel->bounds.control_depth, kernel->bounds.workspace_bits);
    put_bounds(buffer, 8U, 25U, 5U, 0U);
    put_u8(buffer, 0U);
}

static int
encode_minimum_age(const struct seki_module_prefix *module,
    unsigned char *output, size_t capacity, size_t *output_length,
    uint32_t threshold)
{
    unsigned char payload_bytes[SEKI_CORE_CAPACITY];
    struct core_buffer payload = {
        payload_bytes, sizeof payload_bytes, 0U, 0
    };
    struct core_buffer encoded = {output, capacity, 0U, 0};
    static const unsigned char magic[4] = {'S', 'E', 'K', 'I'};
    size_t index;

    put_u32(&payload, 0U);
    put_u32(&payload, (uint32_t)module->header.path_count);
    for (index = 0U; index < module->header.path_count; index += 1U) {
        put_name(&payload, &module->header.path[index]);
    }
    put_u32(&payload, module->header.module_version);
    put_name(&payload, &module->header.profile);
    put_u32(&payload, module->header.profile_version);
    put_u32(&payload, 0U);
    put_u32(&payload, 0U);
    put_u32(&payload, 2U);
    put_text(&payload, "Applicant");
    put_u8(&payload, 2U);
    put_u32(&payload, 1U);
    put_text(&payload, "age");
    put_type_u8(&payload);
    put_text(&payload, "Rejection");
    put_u8(&payload, 3U);
    put_u32(&payload, 1U);
    put_u32(&payload, 1U);
    put_text(&payload, "Underage");
    put_u8(&payload, 0U);
    put_u32(&payload, 0U);
    put_u32(&payload, 1U);
    put_kernel(&payload, &module->kernels[0], threshold);
    put_u32(&payload, 0U);
    put_u32(&payload, 2U);
    put_u32(&payload, 0U);
    put_u32(&payload, 1U);
    put_u32(&payload, 0U);
    put_u32(&payload, 1U);
    put_u32(&payload, 0U);
    put_u32(&payload, 5U);
    put_u8(&payload, 0U);
    put_u8(&payload, 1U);
    put_u8(&payload, 2U);
    put_u8(&payload, 3U);
    put_u8(&payload, 4U);
    put_u32(&payload, 3U);
    put_u8(&payload, 0U);
    put_u8(&payload, 1U);
    put_u8(&payload, 3U);
    put_u32(&payload, 1048576U);
    put_u32(&payload, 32U);
    put_u32(&payload, 4096U);
    put_u32(&payload, 65536U);
    put_u32(&payload, 256U);
    put_u32(&payload, 32U);
    put_bounds(&payload, 16777216U, 8388608U, 256U, 8388608U);
    put_u32(&payload, 0U);
    put_u32(&payload, 2U);
    put_u32(&payload, 0U);
    put_u32(&payload, 1U);
    put_u32(&payload, 0U);

    if (payload.failed || payload.length > UINT32_MAX) {
        return 0;
    }
    put_raw(&encoded, magic, sizeof magic);
    put_u32(&encoded, 0U);
    put_u8(&encoded, 0U);
    put_u32(&encoded, (uint32_t)payload.length);
    put_raw(&encoded, payload.bytes, payload.length);
    if (encoded.failed) {
        return 0;
    }
    *output_length = encoded.length;
    return 1;
}

int
seki_emit_core(const struct seki_module_prefix *module,
    unsigned char *output, size_t capacity, size_t *output_length,
    struct seki_core_error *error)
{
    uint32_t threshold = 0U;
    if (module == NULL || output == NULL || output_length == NULL ||
        error == NULL) {
        return 0;
    }
    error->code = "A0-CORE-0000";
    error->message = "invalid core-emitter state";
    if (!extract_minimum_age(module, &threshold)) {
        error->code = "A0-CORE-0001";
        error->message = "module is outside the current core-emission slice";
        return 0;
    }
    if (!encode_minimum_age(module, output, capacity, output_length,
        threshold)) {
        error->code = "A0-CORE-0002";
        error->message = "candidate typed-core output exceeds capacity";
        return 0;
    }
    return 1;
}
