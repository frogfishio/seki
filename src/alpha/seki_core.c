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

static void put_input_record(struct core_buffer *buffer) { put_declared(buffer, 0U); }
static void put_rejection_type(struct core_buffer *buffer) { put_declared(buffer, 1U); }
static void put_unit(struct core_buffer *buffer) { put_u8(buffer, 0U); }
static void put_bool(struct core_buffer *buffer) { put_u8(buffer, 1U); }
static void put_type_u8(struct core_buffer *buffer) { put_u8(buffer, 2U); }

static int
variant_tag_for_name(const struct seki_variant_decl *variant,
    const struct seki_name *name, uint32_t *tag)
{
    size_t index;
    for (index = 0U; index < variant->case_count; index += 1U) {
        if (seki_name_equal(&variant->cases[index].name, name)) {
            *tag = variant->cases[index].tag;
            return 1;
        }
    }
    return 0;
}

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
name_precedes(const struct seki_name *left, const struct seki_name *right)
{
    const size_t shared = left->length < right->length ?
        left->length : right->length;
    const int comparison = memcmp(left->bytes, right->bytes, shared);
    return comparison < 0 || (comparison == 0 && left->length < right->length);
}

static int
extract_u8_decision(const struct seki_module_prefix *module,
    uint32_t *threshold, uint32_t *field_index, uint32_t *case_index,
    uint32_t *precedence_index, uint32_t *exact_live_bits)
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
    size_t index;
    int found_field = 0;
    int found_case = 0;
    int found_precedence = 0;

    if (module->header.path_count == 0U ||
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
        module->declarations[0].value.record.field_count == 0U ||
        module->declarations[1].kind != SEKI_DECL_VARIANT ||
        module->declarations[1].value.variant.case_count == 0U ||
        !name_precedes(&module->declarations[0].name,
            &module->declarations[1].name)) {
        return 0;
    }
    for (index = 0U;
        index < module->declarations[0].value.record.field_count; index += 1U) {
        const struct seki_type_ref *type =
            &module->declarations[0].value.record.fields[index].type;
        if (type->kind != SEKI_TYPE_NAMED || !seki_name_is(&type->name, "U8")) {
            return 0;
        }
        if (index != 0U && !name_precedes(
            &module->declarations[0].value.record.fields[index - 1U].name,
            &module->declarations[0].value.record.fields[index].name)) {
            return 0;
        }
    }
    for (index = 0U;
        index < module->declarations[1].value.variant.case_count; index += 1U) {
        const struct seki_variant_case *item =
            &module->declarations[1].value.variant.cases[index];
        if (item->tag > UINT8_MAX || item->payload_count != 0U) {
            return 0;
        }
        if (index != 0U &&
            module->declarations[1].value.variant.cases[index - 1U].tag >=
                item->tag) {
            return 0;
        }
    }
    kernel = &module->kernels[0];
    if (kernel->parameter_count != 1U ||
        kernel->parameters[0].type.kind != SEKI_TYPE_NAMED ||
        !seki_name_equal(&kernel->parameters[0].type.name,
            &module->declarations[0].name) ||
        kernel->result.kind != SEKI_TYPE_APPLIED ||
        !seki_name_is(&kernel->result.name, "Decision") ||
        kernel->result.argument_count != 2U ||
        kernel->result.arguments[0].kind != SEKI_TYPE_ARG_TYPE_NAME ||
        !seki_name_is(&kernel->result.arguments[0].name, "Unit") ||
        kernel->result.arguments[1].kind != SEKI_TYPE_ARG_TYPE_NAME ||
        !seki_name_equal(&kernel->result.arguments[1].name,
            &module->declarations[1].name) ||
        !seki_name_is(&kernel->arithmetic_policy, "checked") ||
        kernel->rejection_count == 0U ||
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
        !seki_name_equal(&if_true->value.rejection.owner,
            &module->declarations[1].name) ||
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
        (size_t)left->value.field.receiver >= kernel->expression_count ||
        right->kind != SEKI_EXPR_NATURAL || right->value.natural > UINT8_MAX ||
        accepted->kind != SEKI_EXPR_UNIT) {
        return 0;
    }
    receiver = &kernel->expressions[left->value.field.receiver];
    if (receiver->kind != SEKI_EXPR_VALUE_NAME ||
        !seki_name_equal(&receiver->value.name,
            &kernel->parameters[0].label)) {
        return 0;
    }
    for (index = 0U;
        index < module->declarations[0].value.record.field_count; index += 1U) {
        if (seki_name_equal(&left->value.field.field,
            &module->declarations[0].value.record.fields[index].name)) {
            *field_index = (uint32_t)index;
            found_field = 1;
            break;
        }
    }
    for (index = 0U;
        index < module->declarations[1].value.variant.case_count; index += 1U) {
        if (seki_name_equal(&if_true->value.rejection.item,
            &module->declarations[1].value.variant.cases[index].name)) {
            *case_index = (uint32_t)index;
            found_case = 1;
            break;
        }
    }
    for (index = 0U; index < kernel->rejection_count; index += 1U) {
        uint32_t ignored_tag = 0U;
        size_t earlier;
        if (!seki_name_equal(&kernel->rejections[index].owner,
            &module->declarations[1].name) ||
            !variant_tag_for_name(&module->declarations[1].value.variant,
                &kernel->rejections[index].item, &ignored_tag)) {
            return 0;
        }
        for (earlier = 0U; earlier < index; earlier += 1U) {
            if (seki_name_equal(&kernel->rejections[earlier].item,
                &kernel->rejections[index].item)) {
                return 0;
            }
        }
        if (seki_name_equal(&kernel->rejections[index].item,
            &if_true->value.rejection.item)) {
            *precedence_index = (uint32_t)index;
            found_precedence = 1;
        }
    }
    if (!found_field || !found_case || !found_precedence) {
        return 0;
    }
    *threshold = right->value.natural;
    {
        const uint32_t record_bits =
            (uint32_t)module->declarations[0].value.record.field_count * 8U;
        const uint32_t projection_peak = record_bits * 2U + 8U;
        const uint32_t comparison_peak = record_bits + 17U;
        *exact_live_bits = projection_peak > comparison_peak ?
            projection_peak : comparison_peak;
    }
    if (kernel->bounds.live_bits < *exact_live_bits) {
        return 0;
    }
    return 1;
}

static void
put_kernel(struct core_buffer *buffer, const struct seki_module_prefix *module,
    uint32_t threshold, uint32_t field_index, uint32_t case_index,
    uint32_t precedence_index, uint32_t exact_live_bits)
{
    const struct seki_kernel_decl *kernel = &module->kernels[0];
    const struct seki_variant_decl *variant =
        &module->declarations[1].value.variant;
    size_t index;
    uint32_t rejection_tag = variant->cases[case_index].tag;
    put_name(buffer, &kernel->name);
    put_u32(buffer, 1U);
    put_name(buffer, &kernel->parameters[0].label);
    put_u32(buffer, 1U);
    put_input_record(buffer);
    put_u8(buffer, 19U);
    put_unit(buffer);
    put_rejection_type(buffer);
    put_u32(buffer, (uint32_t)kernel->rejection_count);
    for (index = 0U; index < kernel->rejection_count; index += 1U) {
        uint32_t ordered_tag = 0U;
        if (!variant_tag_for_name(variant, &kernel->rejections[index].item,
            &ordered_tag)) {
            buffer->failed = 1;
            return;
        }
        put_local_type_ref(buffer, 1U);
        put_u32(buffer, ordered_tag);
    }

    put_u8(buffer, 4U);
    put_bool(buffer);
    put_u8(buffer, 19U);
    put_u8(buffer, 0U);
    put_type_u8(buffer);
    put_u8(buffer, 7U);
    put_input_record(buffer);
    put_u8(buffer, 4U);
    put_u32(buffer, 0U);
    put_u8(buffer, 0U);
    put_local_type_ref(buffer, 0U);
    put_u32(buffer, field_index);
    put_type_u8(buffer);
    put_u8(buffer, 2U);
    put_u8(buffer, 0U);
    put_u8(buffer, (uint8_t)threshold);

    put_u8(buffer, 1U);
    put_rejection_type(buffer);
    put_u8(buffer, 8U);
    put_local_type_ref(buffer, 1U);
    put_u32(buffer, rejection_tag);
    put_u32(buffer, 0U);
    put_u32(buffer, precedence_index);
    put_u8(buffer, 0U);
    put_unit(buffer);
    put_u8(buffer, 0U);

    put_bounds(buffer, kernel->bounds.steps, kernel->bounds.live_bits,
        kernel->bounds.control_depth, kernel->bounds.workspace_bits);
    put_bounds(buffer, 8U, exact_live_bits, 5U, 0U);
    put_u8(buffer, 0U);
}

static int
encode_u8_decision(const struct seki_module_prefix *module,
    unsigned char *output, size_t capacity, size_t *output_length,
    uint32_t threshold, uint32_t field_index, uint32_t case_index,
    uint32_t precedence_index, uint32_t exact_live_bits)
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
    put_name(&payload, &module->declarations[0].name);
    put_u8(&payload, 2U);
    put_u32(&payload, (uint32_t)
        module->declarations[0].value.record.field_count);
    for (index = 0U;
        index < module->declarations[0].value.record.field_count; index += 1U) {
        put_name(&payload,
            &module->declarations[0].value.record.fields[index].name);
        put_type_u8(&payload);
    }
    put_name(&payload, &module->declarations[1].name);
    put_u8(&payload, 3U);
    put_u32(&payload, (uint32_t)
        module->declarations[1].value.variant.case_count);
    for (index = 0U;
        index < module->declarations[1].value.variant.case_count; index += 1U) {
        put_u32(&payload,
            module->declarations[1].value.variant.cases[index].tag);
        put_name(&payload,
            &module->declarations[1].value.variant.cases[index].name);
        put_u8(&payload, 0U);
    }
    put_u32(&payload, 0U);
    put_u32(&payload, 1U);
    put_kernel(&payload, module, threshold, field_index, case_index,
        precedence_index, exact_live_bits);
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
    uint32_t field_index = 0U;
    uint32_t case_index = 0U;
    uint32_t precedence_index = 0U;
    uint32_t exact_live_bits = 0U;
    if (module == NULL || output == NULL || output_length == NULL ||
        error == NULL) {
        return 0;
    }
    error->code = "A0-CORE-0000";
    error->message = "invalid core-emitter state";
    if (!extract_u8_decision(module, &threshold, &field_index, &case_index,
        &precedence_index, &exact_live_bits)) {
        error->code = "A0-CORE-0001";
        error->message = "module is outside the U8-decision core slice";
        return 0;
    }
    if (!encode_u8_decision(module, output, capacity, output_length,
        threshold, field_index, case_index, precedence_index,
        exact_live_bits)) {
        error->code = "A0-CORE-0002";
        error->message = "candidate typed-core output exceeds capacity";
        return 0;
    }
    return 1;
}
