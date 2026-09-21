#include "seki_core.h"

#include <stdint.h>
#include <string.h>

#include "seki_types.h"

/*
 * Ceilings of the `c11_bounded @ 1` profile, reproduced from
 * spec/profiles/C11_BOUNDED_V0_DRAFT.md. They are written into every module's
 * declared ceiling; admission compares the derived module observations against
 * them.
 */
#define SEKI_PROFILE_MAX_TYPED_CORE_BYTES 1048576U
#define SEKI_PROFILE_MAX_IMPORTS 32U
#define SEKI_PROFILE_MAX_DECLARATIONS 4096U
#define SEKI_PROFILE_MAX_EXPRESSION_NODES 65536U
#define SEKI_PROFILE_MAX_NESTING 256U
#define SEKI_PROFILE_MAX_CALL_DEPTH 32U
#define SEKI_PROFILE_MAX_STEPS 16777216U
#define SEKI_PROFILE_MAX_LIVE_BITS 8388608U
#define SEKI_PROFILE_MAX_CONTROL_DEPTH 256U
#define SEKI_PROFILE_MAX_WORKSPACE_BITS 8388608U

/* SCB-0 `Term` discriminants used by the alpha subset. */
#define SEKI_TERM_UNIT_LIT 0U
#define SEKI_TERM_BOOL_LIT 1U
#define SEKI_TERM_INT_LIT 2U
#define SEKI_TERM_LOCAL 4U
#define SEKI_TERM_RECORD 6U
#define SEKI_TERM_PROJECT 7U
#define SEKI_TERM_VARIANT 8U
#define SEKI_TERM_EQUAL 14U
#define SEKI_TERM_NOT_EQUAL 15U
#define SEKI_TERM_AND_THEN 17U
#define SEKI_TERM_OR_ELSE 18U
#define SEKI_TERM_COMPARE 19U

/* SCB-0 `KernelExpr` discriminants used by the alpha subset. */
#define SEKI_KERNEL_ACCEPT 0U
#define SEKI_KERNEL_REJECT 1U
#define SEKI_KERNEL_REQUIRE 2U
#define SEKI_KERNEL_LET 3U
#define SEKI_KERNEL_IF 4U
#define SEKI_KERNEL_MATCH 5U

struct core_buffer {
    unsigned char *bytes;
    size_t capacity;
    size_t length;
    int failed;
};

/*
 * Canonical table layout.
 *
 * Source order is a developer convenience; the typed core orders every table by
 * its typed key. This layout is the one place that translates between the two,
 * so a declaration written in any order emits the same canonical bytes and
 * every emitted reference uses the canonical position.
 */
struct seki_layout {
    uint32_t type_position[SEKI_MODULE_MAX_DECLARATIONS];
    uint32_t type_order[SEKI_MODULE_MAX_DECLARATIONS];
    uint32_t field_position[SEKI_MODULE_MAX_DECLARATIONS]
        [SEKI_RECORD_MAX_FIELDS];
    uint32_t field_order[SEKI_MODULE_MAX_DECLARATIONS][SEKI_RECORD_MAX_FIELDS];
    uint32_t case_order[SEKI_MODULE_MAX_DECLARATIONS][SEKI_VARIANT_MAX_CASES];
    uint32_t kernel_order[SEKI_MODULE_MAX_KERNELS];
    uint32_t dependency_order[SEKI_MODULE_MAX_DECLARATIONS];
};

struct emitter {
    const struct seki_module_prefix *module;
    struct seki_elaboration *elaboration;
    const struct seki_layout *layout;
    const struct seki_kernel_decl *kernel;
    const struct seki_kernel_elab *kernel_elaboration;
    struct core_buffer *buffer;
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

/* Integer literals are written most-significant octet first, matching every
 * other multi-octet field in the envelope. */
static void
put_integer(struct core_buffer *buffer, uint32_t value, uint32_t width_bits)
{
    unsigned char bytes[8];
    const size_t width = width_bits / 8U;
    size_t index;
    if (width > sizeof bytes) {
        buffer->failed = 1;
        return;
    }
    for (index = 0U; index < width; index += 1U) {
        const size_t shift = (width - 1U - index) * 8U;
        bytes[index] = shift >= 32U ? 0U :
            (unsigned char)(value >> shift);
    }
    put_raw(buffer, bytes, width);
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
put_type_ref(struct core_buffer *buffer, uint32_t position)
{
    put_u8(buffer, 0U);
    put_u32(buffer, position);
}

static void
put_bounds(struct core_buffer *buffer,
    const struct seki_resource_bounds *bounds)
{
    put_u32(buffer, bounds->steps);
    put_u32(buffer, bounds->live_bits);
    put_u32(buffer, bounds->control_depth);
    put_u32(buffer, bounds->workspace_bits);
}

static int
name_precedes(const struct seki_name *left, const struct seki_name *right)
{
    const size_t shared = left->length < right->length ?
        left->length : right->length;
    const int comparison = shared == 0U ? 0 :
        memcmp(left->bytes, right->bytes, shared);
    return comparison < 0 || (comparison == 0 && left->length < right->length);
}

/* ---------------------------------------------------------------------- */
/* Canonical layout                                                        */
/* ---------------------------------------------------------------------- */

static void
sort_by_name(const struct seki_name *keys, uint32_t *order, size_t count)
{
    size_t index;
    for (index = 0U; index < count; index += 1U) {
        order[index] = (uint32_t)index;
    }
    for (index = 1U; index < count; index += 1U) {
        const uint32_t candidate = order[index];
        size_t position = index;
        while (position > 0U &&
            name_precedes(&keys[candidate], &keys[order[position - 1U]])) {
            order[position] = order[position - 1U];
            position -= 1U;
        }
        order[position] = candidate;
    }
}

static void
build_type_layout(const struct seki_module_prefix *module,
    struct seki_layout *layout)
{
    struct seki_name names[SEKI_MODULE_MAX_DECLARATIONS];
    size_t index;
    for (index = 0U; index < module->declaration_count; index += 1U) {
        names[index] = module->declarations[index].name;
    }
    sort_by_name(names, layout->type_order, module->declaration_count);
    for (index = 0U; index < module->declaration_count; index += 1U) {
        layout->type_position[layout->type_order[index]] = (uint32_t)index;
    }
}

static void
build_member_layout(const struct seki_module_prefix *module,
    struct seki_layout *layout)
{
    size_t index;
    for (index = 0U; index < module->declaration_count; index += 1U) {
        const struct seki_type_decl *declaration = &module->declarations[index];
        if (declaration->kind == SEKI_DECL_RECORD) {
            struct seki_name names[SEKI_RECORD_MAX_FIELDS];
            const size_t count = declaration->value.record.field_count;
            size_t field;
            for (field = 0U; field < count; field += 1U) {
                names[field] = declaration->value.record.fields[field].name;
            }
            sort_by_name(names, layout->field_order[index], count);
            for (field = 0U; field < count; field += 1U) {
                layout->field_position[index]
                    [layout->field_order[index][field]] = (uint32_t)field;
            }
        } else if (declaration->kind == SEKI_DECL_VARIANT) {
            /* Variant case keys are stable U32 tags, ordered numerically. */
            const size_t count = declaration->value.variant.case_count;
            size_t position;
            size_t item;
            for (item = 0U; item < count; item += 1U) {
                layout->case_order[index][item] = (uint32_t)item;
            }
            for (item = 1U; item < count; item += 1U) {
                const uint32_t candidate = layout->case_order[index][item];
                position = item;
                while (position > 0U &&
                    declaration->value.variant.cases[candidate].tag <
                    declaration->value.variant.cases
                        [layout->case_order[index][position - 1U]].tag) {
                    layout->case_order[index][position] =
                        layout->case_order[index][position - 1U];
                    position -= 1U;
                }
                layout->case_order[index][position] = candidate;
            }
        }
    }
}

static void
build_kernel_layout(const struct seki_module_prefix *module,
    struct seki_layout *layout)
{
    struct seki_name names[SEKI_MODULE_MAX_KERNELS];
    size_t index;
    for (index = 0U; index < module->kernel_count; index += 1U) {
        names[index] = module->kernels[index].name;
    }
    sort_by_name(names, layout->kernel_order, module->kernel_count);
}

/*
 * Records the canonical positions that one declaration's body depends on.
 * Only locally declared types create an ordering obligation.
 */
static void
declaration_dependencies(const struct seki_module_prefix *module,
    const struct seki_layout *layout, size_t declaration, int *dependent)
{
    const struct seki_type_decl *entry = &module->declarations[declaration];
    size_t index;
    const struct seki_type_ref *references[SEKI_RECORD_MAX_FIELDS +
        SEKI_VARIANT_MAX_CASES * SEKI_VARIANT_MAX_PAYLOAD_FIELDS + 1U];
    size_t count = 0U;
    switch (entry->kind) {
    case SEKI_DECL_ALIAS:
    case SEKI_DECL_NOMINAL:
        references[count++] = &entry->value.target;
        break;
    case SEKI_DECL_RECORD:
        for (index = 0U; index < entry->value.record.field_count;
            index += 1U) {
            references[count++] = &entry->value.record.fields[index].type;
        }
        break;
    case SEKI_DECL_VARIANT:
        for (index = 0U; index < entry->value.variant.case_count;
            index += 1U) {
            const struct seki_variant_case *item =
                &entry->value.variant.cases[index];
            size_t field;
            for (field = 0U; field < item->payload_count; field += 1U) {
                references[count++] = &item->payload[field].type;
            }
        }
        break;
    default:
        break;
    }
    for (index = 0U; index < count; index += 1U) {
        size_t candidate;
        if (references[index]->kind != SEKI_TYPE_NAMED) {
            continue;
        }
        for (candidate = 0U; candidate < module->declaration_count;
            candidate += 1U) {
            if (seki_name_equal(&module->declarations[candidate].name,
                &references[index]->name)) {
                dependent[layout->type_position[candidate]] = 1;
                break;
            }
        }
    }
}

/*
 * The derivation bundle records the greedy topological order over the
 * canonical type table: at each position, the lowest-indexed declaration whose
 * dependencies are already placed. Admission recomputes it and rejects any
 * other permutation, so this must match exactly.
 */
static int
build_dependency_order(const struct seki_module_prefix *module,
    struct seki_layout *layout)
{
    int dependencies[SEKI_MODULE_MAX_DECLARATIONS]
        [SEKI_MODULE_MAX_DECLARATIONS];
    int placed[SEKI_MODULE_MAX_DECLARATIONS];
    size_t position;
    memset(dependencies, 0, sizeof dependencies);
    memset(placed, 0, sizeof placed);
    for (position = 0U; position < module->declaration_count;
        position += 1U) {
        declaration_dependencies(module, layout, layout->type_order[position],
            dependencies[position]);
    }
    for (position = 0U; position < module->declaration_count;
        position += 1U) {
        size_t candidate;
        int selected = 0;
        for (candidate = 0U; candidate < module->declaration_count;
            candidate += 1U) {
            size_t dependency;
            int ready = 1;
            if (placed[candidate]) {
                continue;
            }
            for (dependency = 0U; dependency < module->declaration_count;
                dependency += 1U) {
                if (dependencies[candidate][dependency] &&
                    !placed[dependency]) {
                    ready = 0;
                    break;
                }
            }
            if (ready) {
                layout->dependency_order[position] = (uint32_t)candidate;
                placed[candidate] = 1;
                selected = 1;
                break;
            }
        }
        if (!selected) {
            /* Every remaining declaration depends on an unplaced one, which
             * is a cycle. Typed-core formation rejects recursive types. */
            return 0;
        }
    }
    return 1;
}

static int
build_layout(const struct seki_module_prefix *module,
    struct seki_layout *layout)
{
    memset(layout, 0, sizeof *layout);
    build_type_layout(module, layout);
    build_member_layout(module, layout);
    build_kernel_layout(module, layout);
    return build_dependency_order(module, layout);
}

/* ---------------------------------------------------------------------- */
/* Type values                                                             */
/* ---------------------------------------------------------------------- */

static void
put_type_value(struct emitter *emitter, uint32_t type)
{
    const struct seki_type *entry;
    if (type >= emitter->elaboration->types.count) {
        emitter->buffer->failed = 1;
        return;
    }
    entry = &emitter->elaboration->types.entries[type];
    put_u8(emitter->buffer, (uint8_t)entry->kind);
    switch (entry->kind) {
    case SEKI_T_BYTES:
        put_u32(emitter->buffer, entry->a);
        break;
    case SEKI_T_DIGEST:
        put_u8(emitter->buffer, 0U);
        put_u32(emitter->buffer, entry->a);
        break;
    case SEKI_T_DECISION:
        put_type_value(emitter, entry->a);
        put_type_value(emitter, entry->b);
        break;
    case SEKI_T_DECLARED:
        if (entry->a >= emitter->module->declaration_count) {
            emitter->buffer->failed = 1;
            return;
        }
        put_type_ref(emitter->buffer, emitter->layout->type_position[entry->a]);
        break;
    default:
        break;
    }
}

static void
put_surface_type(struct emitter *emitter, const struct seki_type_ref *reference)
{
    const uint32_t type = seki_type_resolve(emitter->module,
        &emitter->elaboration->types, reference);
    if (type == SEKI_TYPE_INVALID) {
        emitter->buffer->failed = 1;
        return;
    }
    put_type_value(emitter, type);
}

/* ---------------------------------------------------------------------- */
/* Terms                                                                   */
/* ---------------------------------------------------------------------- */

static uint32_t
integer_tag(const struct seki_elaboration *elaboration, uint32_t type,
    uint32_t *width_bits)
{
    switch (elaboration->types.entries[type].kind) {
    case SEKI_T_U8:
        *width_bits = 8U;
        return 0U;
    case SEKI_T_U16:
        *width_bits = 16U;
        return 1U;
    case SEKI_T_U32:
        *width_bits = 32U;
        return 2U;
    case SEKI_T_U64:
        *width_bits = 64U;
        return 3U;
    default:
        break;
    }
    *width_bits = 0U;
    return UINT32_MAX;
}

/* Canonical payload field order is by name, like every other keyed table. */
static void
sort_payload_order(const struct seki_variant_case *item, uint32_t *order)
{
    size_t index;
    for (index = 0U; index < item->payload_count; index += 1U) {
        order[index] = (uint32_t)index;
    }
    for (index = 1U; index < item->payload_count; index += 1U) {
        const uint32_t candidate = order[index];
        size_t position = index;
        while (position > 0U &&
            name_precedes(&item->payload[candidate].name,
                &item->payload[order[position - 1U]].name)) {
            order[position] = order[position - 1U];
            position -= 1U;
        }
        order[position] = candidate;
    }
}

static void
put_expression(struct emitter *emitter, uint32_t expression_index)
{
    const struct seki_expression *expression;
    const struct seki_expr_info *info;
    if (emitter->buffer->failed ||
        (size_t)expression_index >= emitter->kernel->expression_count) {
        emitter->buffer->failed = 1;
        return;
    }
    expression = &emitter->kernel->expressions[expression_index];
    info = &emitter->kernel_elaboration->expressions[expression_index];
    put_type_value(emitter, info->type);
    switch (expression->kind) {
    case SEKI_EXPR_UNIT:
        put_u8(emitter->buffer, SEKI_TERM_UNIT_LIT);
        break;
    case SEKI_EXPR_BOOL:
        put_u8(emitter->buffer, SEKI_TERM_BOOL_LIT);
        put_u8(emitter->buffer, expression->value.boolean ? 1U : 0U);
        break;
    case SEKI_EXPR_NATURAL: {
        uint32_t width = 0U;
        const uint32_t tag = integer_tag(emitter->elaboration, info->type,
            &width);
        if (tag == UINT32_MAX) {
            emitter->buffer->failed = 1;
            return;
        }
        put_u8(emitter->buffer, SEKI_TERM_INT_LIT);
        put_u8(emitter->buffer, (uint8_t)tag);
        put_integer(emitter->buffer, expression->value.natural, width);
        break;
    }
    case SEKI_EXPR_VALUE_NAME:
        put_u8(emitter->buffer, SEKI_TERM_LOCAL);
        put_u32(emitter->buffer, info->a);
        break;
    case SEKI_EXPR_RECORD: {
        const struct seki_type_decl *declaration;
        size_t field;
        if (info->a >= emitter->module->declaration_count) {
            emitter->buffer->failed = 1;
            return;
        }
        declaration = &emitter->module->declarations[info->a];
        put_u8(emitter->buffer, SEKI_TERM_RECORD);
        put_type_ref(emitter->buffer, emitter->layout->type_position[info->a]);
        put_u32(emitter->buffer,
            (uint32_t)declaration->value.record.field_count);
        /* Constructor fields are keyed by FieldRef and must be strictly
         * increasing, so they are written in canonical field order. */
        for (field = 0U; field < declaration->value.record.field_count;
            field += 1U) {
            const uint32_t source =
                emitter->layout->field_order[info->a][field];
            size_t entry;
            uint32_t value = UINT32_MAX;
            for (entry = 0U; entry < (size_t)expression->value.record.count;
                entry += 1U) {
                const struct seki_record_init *initialiser =
                    &emitter->kernel->record_fields
                        [expression->value.record.first + entry];
                if (seki_name_equal(&initialiser->name,
                    &declaration->value.record.fields[source].name)) {
                    value = initialiser->value;
                    break;
                }
            }
            if (value == UINT32_MAX) {
                emitter->buffer->failed = 1;
                return;
            }
            put_u8(emitter->buffer, 0U);
            put_type_ref(emitter->buffer,
                emitter->layout->type_position[info->a]);
            put_u32(emitter->buffer, (uint32_t)field);
            put_expression(emitter, value);
        }
        break;
    }
    case SEKI_EXPR_FIELD:
        put_u8(emitter->buffer, SEKI_TERM_PROJECT);
        put_expression(emitter, expression->value.field.receiver);
        /* FieldRef: FieldOwnerRef(record_type, TypeRef) then field index. */
        put_u8(emitter->buffer, 0U);
        put_type_ref(emitter->buffer,
            emitter->layout->type_position[info->a]);
        put_u32(emitter->buffer,
            emitter->layout->field_position[info->a][info->b]);
        break;
    case SEKI_EXPR_COMPARE: {
        const enum seki_compare_operator operator =
            expression->value.compare.operator;
        if (operator == SEKI_COMPARE_EQUAL) {
            put_u8(emitter->buffer, SEKI_TERM_EQUAL);
        } else if (operator == SEKI_COMPARE_NOT_EQUAL) {
            put_u8(emitter->buffer, SEKI_TERM_NOT_EQUAL);
        } else {
            put_u8(emitter->buffer, SEKI_TERM_COMPARE);
            put_u8(emitter->buffer, (uint8_t)operator);
        }
        put_expression(emitter, expression->value.compare.left);
        put_expression(emitter, expression->value.compare.right);
        break;
    }
    case SEKI_EXPR_AND:
    case SEKI_EXPR_OR:
        put_u8(emitter->buffer, expression->kind == SEKI_EXPR_AND ?
            SEKI_TERM_AND_THEN : SEKI_TERM_OR_ELSE);
        put_expression(emitter, expression->value.logical.left);
        put_expression(emitter, expression->value.logical.right);
        break;
    default:
        emitter->buffer->failed = 1;
        break;
    }
}

/*
 * The rejection reason is a variant construction built inline; the surface has
 * no expression node for it. Payload fields are keyed by name and must be
 * strictly increasing, so they are written in canonical name order.
 */
static void
put_rejection_reason(struct emitter *emitter, const struct seki_expr_info *info,
    uint32_t first, uint32_t count)
{
    const struct seki_type_decl *declaration;
    const struct seki_variant_case *selected = NULL;
    uint32_t order[SEKI_VARIANT_MAX_PAYLOAD_FIELDS];
    size_t index;

    put_type_value(emitter, emitter->kernel_elaboration->rejection_type);
    put_u8(emitter->buffer, SEKI_TERM_VARIANT);
    put_type_ref(emitter->buffer, emitter->layout->type_position[info->a]);
    put_u32(emitter->buffer, info->b);
    put_u32(emitter->buffer, count);
    if (count == 0U) {
        return;
    }
    if (info->a >= emitter->module->declaration_count ||
        count > SEKI_VARIANT_MAX_PAYLOAD_FIELDS) {
        emitter->buffer->failed = 1;
        return;
    }
    declaration = &emitter->module->declarations[info->a];
    for (index = 0U; index < declaration->value.variant.case_count;
        index += 1U) {
        if (declaration->value.variant.cases[index].tag == info->b) {
            selected = &declaration->value.variant.cases[index];
            break;
        }
    }
    if (selected == NULL || selected->payload_count != (size_t)count) {
        emitter->buffer->failed = 1;
        return;
    }
    sort_payload_order(selected, order);
    for (index = 0U; index < (size_t)count; index += 1U) {
        const struct seki_name *name =
            &selected->payload[order[index]].name;
        size_t entry;
        uint32_t value = UINT32_MAX;
        for (entry = 0U; entry < (size_t)count; entry += 1U) {
            const struct seki_record_init *initialiser =
                &emitter->kernel->record_fields[first + entry];
            if (seki_name_equal(&initialiser->name, name)) {
                value = initialiser->value;
                break;
            }
        }
        if (value == UINT32_MAX) {
            emitter->buffer->failed = 1;
            return;
        }
        put_name(emitter->buffer, name);
        put_expression(emitter, value);
    }
}

static void
put_kernel_expression(struct emitter *emitter, uint32_t expression_index)
{
    const struct seki_expression *expression;
    const struct seki_expr_info *info;
    if (emitter->buffer->failed ||
        (size_t)expression_index >= emitter->kernel->expression_count) {
        emitter->buffer->failed = 1;
        return;
    }
    expression = &emitter->kernel->expressions[expression_index];
    info = &emitter->kernel_elaboration->expressions[expression_index];
    switch (expression->kind) {
    case SEKI_EXPR_ACCEPT:
        put_u8(emitter->buffer, SEKI_KERNEL_ACCEPT);
        put_expression(emitter, expression->value.accept.value);
        break;
    case SEKI_EXPR_REJECT:
        put_u8(emitter->buffer, SEKI_KERNEL_REJECT);
        put_rejection_reason(emitter, info,
            expression->value.rejection.first,
            expression->value.rejection.count);
        put_u32(emitter->buffer, info->c);
        break;
    case SEKI_EXPR_LET:
        put_u8(emitter->buffer, SEKI_KERNEL_LET);
        put_expression(emitter, expression->value.let.value);
        put_kernel_expression(emitter, expression->value.let.body);
        break;
    case SEKI_EXPR_REQUIRE:
        put_u8(emitter->buffer, SEKI_KERNEL_REQUIRE);
        put_expression(emitter, expression->value.require.condition);
        put_rejection_reason(emitter, info, expression->value.require.first,
            expression->value.require.count);
        put_u32(emitter->buffer, info->c);
        put_kernel_expression(emitter,
            expression->value.require.continuation);
        break;
    case SEKI_EXPR_MATCH: {
        const struct seki_type_decl *declaration;
        size_t index;
        if (info->a >= emitter->module->declaration_count) {
            emitter->buffer->failed = 1;
            return;
        }
        declaration = &emitter->module->declarations[info->a];
        put_u8(emitter->buffer, SEKI_KERNEL_MATCH);
        put_expression(emitter, expression->value.match.scrutinee);
        put_u32(emitter->buffer,
            (uint32_t)declaration->value.variant.case_count);
        /* Arms are keyed by ConstructorRef and must be strictly increasing,
         * so they are written in canonical stable-tag order. */
        for (index = 0U; index < declaration->value.variant.case_count;
            index += 1U) {
            const struct seki_variant_case *item =
                &declaration->value.variant.cases
                    [emitter->layout->case_order[info->a][index]];
            size_t entry;
            uint32_t body = UINT32_MAX;
            for (entry = 0U; entry < (size_t)expression->value.match.count;
                entry += 1U) {
                const struct seki_match_arm *arm =
                    &emitter->kernel->match_arms
                        [expression->value.match.first + entry];
                if (seki_name_equal(&arm->item, &item->name)) {
                    body = arm->body;
                    break;
                }
            }
            if (body == UINT32_MAX) {
                emitter->buffer->failed = 1;
                return;
            }
            /* ConstructorRef: SumTypeRef(declared_variant, TypeRef) + tag. */
            put_u8(emitter->buffer, 0U);
            put_type_ref(emitter->buffer,
                emitter->layout->type_position[info->a]);
            put_u32(emitter->buffer, item->tag);
            put_kernel_expression(emitter, body);
        }
        break;
    }
    case SEKI_EXPR_IF:
        put_u8(emitter->buffer, SEKI_KERNEL_IF);
        put_expression(emitter, expression->value.conditional.condition);
        put_kernel_expression(emitter, expression->value.conditional.if_true);
        put_kernel_expression(emitter, expression->value.conditional.if_false);
        break;
    default:
        emitter->buffer->failed = 1;
        break;
    }
}

/* ---------------------------------------------------------------------- */
/* Declarations and kernels                                                */
/* ---------------------------------------------------------------------- */

static void sort_payload_order(const struct seki_variant_case *item,
    uint32_t *order);

static void
put_declaration(struct emitter *emitter, size_t declaration_index)
{
    const struct seki_type_decl *declaration =
        &emitter->module->declarations[declaration_index];
    uint32_t payload_order[SEKI_VARIANT_MAX_PAYLOAD_FIELDS];
    size_t index;
    put_name(emitter->buffer, &declaration->name);
    switch (declaration->kind) {
    case SEKI_DECL_ALIAS:
        put_u8(emitter->buffer, 0U);
        put_surface_type(emitter, &declaration->value.target);
        break;
    case SEKI_DECL_NOMINAL:
        put_u8(emitter->buffer, 1U);
        put_surface_type(emitter, &declaration->value.target);
        break;
    case SEKI_DECL_RECORD:
        put_u8(emitter->buffer, 2U);
        put_u32(emitter->buffer,
            (uint32_t)declaration->value.record.field_count);
        for (index = 0U; index < declaration->value.record.field_count;
            index += 1U) {
            const struct seki_field_decl *field =
                &declaration->value.record.fields
                    [emitter->layout->field_order[declaration_index][index]];
            put_name(emitter->buffer, &field->name);
            put_surface_type(emitter, &field->type);
        }
        break;
    case SEKI_DECL_VARIANT:
        put_u8(emitter->buffer, 3U);
        put_u32(emitter->buffer,
            (uint32_t)declaration->value.variant.case_count);
        for (index = 0U; index < declaration->value.variant.case_count;
            index += 1U) {
            const struct seki_variant_case *item =
                &declaration->value.variant.cases
                    [emitter->layout->case_order[declaration_index][index]];
            size_t payload;
            put_u32(emitter->buffer, item->tag);
            put_name(emitter->buffer, &item->name);
            if (item->payload_count == 0U) {
                put_u8(emitter->buffer, 0U);
                continue;
            }
            put_u8(emitter->buffer, 1U);
            put_u32(emitter->buffer, (uint32_t)item->payload_count);
            /* Payload fields are keyed by name like every other table, so
             * they are declared in canonical order rather than source order. */
            sort_payload_order(item, payload_order);
            for (payload = 0U; payload < item->payload_count; payload += 1U) {
                const struct seki_field_decl *field =
                    &item->payload[payload_order[payload]];
                put_name(emitter->buffer, &field->name);
                put_surface_type(emitter, &field->type);
            }
        }
        break;
    default:
        emitter->buffer->failed = 1;
        break;
    }
}

static void
put_kernel(struct emitter *emitter, size_t kernel_index)
{
    const struct seki_kernel_decl *kernel =
        &emitter->module->kernels[kernel_index];
    const struct seki_kernel_elab *elaboration =
        &emitter->elaboration->kernels[kernel_index];
    size_t index;

    emitter->kernel = kernel;
    emitter->kernel_elaboration = elaboration;

    /* FunctionKey: base name then the ordered parameter labels. */
    put_name(emitter->buffer, &kernel->name);
    put_u32(emitter->buffer, (uint32_t)kernel->parameter_count);
    for (index = 0U; index < kernel->parameter_count; index += 1U) {
        put_name(emitter->buffer, &kernel->parameters[index].label);
    }

    put_u32(emitter->buffer, (uint32_t)kernel->parameter_count);
    for (index = 0U; index < kernel->parameter_count; index += 1U) {
        put_type_value(emitter, elaboration->parameter_types[index]);
    }
    put_type_value(emitter, elaboration->result_type);

    put_u32(emitter->buffer, (uint32_t)kernel->rejection_count);
    for (index = 0U; index < kernel->rejection_count; index += 1U) {
        const struct seki_type *rejection =
            &emitter->elaboration->types.entries[elaboration->rejection_type];
        const struct seki_type_decl *declaration;
        size_t item;
        int found = 0;
        if (rejection->kind != SEKI_T_DECLARED ||
            rejection->a >= emitter->module->declaration_count) {
            emitter->buffer->failed = 1;
            return;
        }
        declaration = &emitter->module->declarations[rejection->a];
        put_type_ref(emitter->buffer,
            emitter->layout->type_position[rejection->a]);
        for (item = 0U; item < declaration->value.variant.case_count;
            item += 1U) {
            if (seki_name_equal(&declaration->value.variant.cases[item].name,
                &kernel->rejections[index].item)) {
                put_u32(emitter->buffer,
                    declaration->value.variant.cases[item].tag);
                found = 1;
                break;
            }
        }
        if (!found) {
            emitter->buffer->failed = 1;
            return;
        }
    }

    put_kernel_expression(emitter, kernel->body_root);

    put_bounds(emitter->buffer, &kernel->bounds);
    put_bounds(emitter->buffer, &elaboration->exact);
    put_u8(emitter->buffer, kernel->publication_eligible ? 1U : 0U);
}

/* ---------------------------------------------------------------------- */
/* Header vectors                                                          */
/* ---------------------------------------------------------------------- */

static const char *const seki_theorem_names[] = {
    "type_well_formed", "totality", "determinism", "resource_bounds",
    "rejection_precedence", "representation", "publication_equivalence"
};

static const char *const seki_claim_names[] = {
    "semantic_evaluation", "lean_projection", "representation_correspondence",
    "restricted_c_source", "clight_refinement", "certified_lean_equivalence",
    "installed_binary", "publication"
};

/*
 * Theorem and claim vectors are strictly increasing by tag. Emitting them from
 * the registry order rather than the source order makes the encoding
 * insensitive to how the header was written, while an unknown name fails
 * closed.
 */
static int
put_tag_vector(struct core_buffer *buffer, const struct seki_name *names,
    size_t name_count, const char *const *registry, size_t registry_count)
{
    uint32_t tags[SEKI_HEADER_MAX_REQUIREMENTS];
    size_t count = 0U;
    size_t index;
    if (name_count > SEKI_HEADER_MAX_REQUIREMENTS) {
        return 0;
    }
    for (index = 0U; index < registry_count; index += 1U) {
        size_t candidate;
        for (candidate = 0U; candidate < name_count; candidate += 1U) {
            if (seki_name_is(&names[candidate], registry[index])) {
                tags[count++] = (uint32_t)index;
                break;
            }
        }
    }
    if (count != name_count) {
        return 0;
    }
    put_u32(buffer, (uint32_t)count);
    for (index = 0U; index < count; index += 1U) {
        put_u8(buffer, (uint8_t)tags[index]);
    }
    return 1;
}

/* ---------------------------------------------------------------------- */
/* Module                                                                  */
/* ---------------------------------------------------------------------- */

static int
encode_module(struct emitter *emitter, struct core_buffer *payload)
{
    const struct seki_module_prefix *module = emitter->module;
    size_t index;

    emitter->buffer = payload;

    put_u32(payload, 0U);                       /* schema_version */
                                                /* language: zero octets */
    put_u32(payload, (uint32_t)module->header.path_count);
    for (index = 0U; index < module->header.path_count; index += 1U) {
        put_name(payload, &module->header.path[index]);
    }
    put_u32(payload, module->header.module_version);
    put_name(payload, &module->header.profile);
    put_u32(payload, module->header.profile_version);
    put_u32(payload, 0U);                       /* imports */
    put_u32(payload, 0U);                       /* domains */

    put_u32(payload, (uint32_t)module->declaration_count);
    for (index = 0U; index < module->declaration_count; index += 1U) {
        put_declaration(emitter, emitter->layout->type_order[index]);
    }

    put_u32(payload, 0U);                       /* functions */
    put_u32(payload, (uint32_t)module->kernel_count);
    for (index = 0U; index < module->kernel_count; index += 1U) {
        put_kernel(emitter, emitter->layout->kernel_order[index]);
    }

    /* Exports: every declaration and kernel in the surface is exported. */
    put_u32(payload, 0U);
    put_u32(payload, (uint32_t)module->declaration_count);
    for (index = 0U; index < module->declaration_count; index += 1U) {
        put_u32(payload, (uint32_t)index);
    }
    put_u32(payload, 0U);
    put_u32(payload, (uint32_t)module->kernel_count);
    for (index = 0U; index < module->kernel_count; index += 1U) {
        put_u32(payload, (uint32_t)index);
    }

    if (!put_tag_vector(payload, module->header.requirements,
        module->header.requirement_count, seki_theorem_names,
        sizeof seki_theorem_names / sizeof seki_theorem_names[0])) {
        return 0;
    }
    if (!put_tag_vector(payload, module->header.claims,
        module->header.claim_count, seki_claim_names,
        sizeof seki_claim_names / sizeof seki_claim_names[0])) {
        return 0;
    }

    put_u32(payload, SEKI_PROFILE_MAX_TYPED_CORE_BYTES);
    put_u32(payload, SEKI_PROFILE_MAX_IMPORTS);
    put_u32(payload, SEKI_PROFILE_MAX_DECLARATIONS);
    put_u32(payload, SEKI_PROFILE_MAX_EXPRESSION_NODES);
    put_u32(payload, SEKI_PROFILE_MAX_NESTING);
    put_u32(payload, SEKI_PROFILE_MAX_CALL_DEPTH);
    put_u32(payload, SEKI_PROFILE_MAX_STEPS);
    put_u32(payload, SEKI_PROFILE_MAX_LIVE_BITS);
    put_u32(payload, SEKI_PROFILE_MAX_CONTROL_DEPTH);
    put_u32(payload, SEKI_PROFILE_MAX_WORKSPACE_BITS);

    put_u32(payload, 0U);                       /* derivation schema_version */
    put_u32(payload, (uint32_t)module->declaration_count);
    for (index = 0U; index < module->declaration_count; index += 1U) {
        put_u32(payload, emitter->layout->dependency_order[index]);
    }
    put_u32(payload, 0U);                       /* function_dependency_order */
    return !payload->failed;
}

int
seki_emit_core(const struct seki_module_prefix *module,
    struct seki_elaboration *elaboration, unsigned char *output,
    size_t capacity, size_t *output_length, struct seki_core_error *error)
{
    unsigned char payload_bytes[SEKI_CORE_CAPACITY];
    struct core_buffer payload = {payload_bytes, sizeof payload_bytes, 0U, 0};
    struct core_buffer encoded = {output, capacity, 0U, 0};
    static const unsigned char magic[4] = {'S', 'E', 'K', 'I'};
    struct seki_layout layout;
    struct emitter emitter;

    if (module == NULL || elaboration == NULL || output == NULL ||
        output_length == NULL || error == NULL) {
        return 0;
    }
    error->code = "A0-CORE-0000";
    error->message = "invalid core-emitter state";

    if (module->declaration_count == 0U || module->kernel_count == 0U) {
        error->code = "A0-CORE-0003";
        error->message = "module declares no type or no kernel";
        return 0;
    }
    if (!build_layout(module, &layout)) {
        error->code = "A0-CORE-0004";
        error->message = "type declarations are recursive";
        return 0;
    }

    memset(&emitter, 0, sizeof emitter);
    emitter.module = module;
    emitter.elaboration = elaboration;
    emitter.layout = &layout;

    if (!encode_module(&emitter, &payload) || payload.length > UINT32_MAX) {
        error->code = "A0-CORE-0001";
        error->message = "module is outside the alpha typed-core subset";
        return 0;
    }

    put_raw(&encoded, magic, sizeof magic);
    put_u32(&encoded, 0U);
    put_u8(&encoded, 0U);
    put_u32(&encoded, (uint32_t)payload.length);
    put_raw(&encoded, payload.bytes, payload.length);
    if (encoded.failed) {
        error->code = "A0-CORE-0002";
        error->message = "candidate typed-core output exceeds capacity";
        return 0;
    }
    *output_length = encoded.length;
    return 1;
}
