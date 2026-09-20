#include "seki_types.h"

#include <string.h>

/*
 * Recursive declarations are rejected by typed-core formation, but the surface
 * parser cannot see the cycle while it builds one declaration at a time. Width
 * derivation therefore carries its own descent budget so a cyclic module fails
 * closed here instead of exhausting the host stack.
 */
#define SEKI_TYPE_MAX_DEPTH 32U

int
seki_checked_add(uint32_t left, uint32_t right, uint32_t *result)
{
    if (left > UINT32_MAX - right) {
        return 0;
    }
    *result = left + right;
    return 1;
}

int
seki_checked_mul(uint32_t left, uint32_t right, uint32_t *result)
{
    if (left != 0U && right > UINT32_MAX / left) {
        return 0;
    }
    *result = left * right;
    return 1;
}

/*
 * `choice_bits` and `counter_bits` from the cost algebra serve `Index[N]` and
 * the array intrinsics. Both are outside the A0 subset, so they are added with
 * the forms that need them rather than carried unused.
 */
uint32_t
seki_tag_bits(uint32_t tag)
{
    uint32_t bits = 0U;
    while (tag != 0U) {
        bits += 1U;
        tag >>= 1;
    }
    return bits;
}

void
seki_type_table_init(struct seki_type_table *table)
{
    memset(table, 0, sizeof *table);
}

uint32_t
seki_type_intern(struct seki_type_table *table, uint32_t kind, uint32_t a,
    uint32_t b)
{
    size_t index;
    for (index = 0U; index < table->count; index += 1U) {
        if (table->entries[index].kind == kind &&
            table->entries[index].a == a && table->entries[index].b == b) {
            return (uint32_t)index;
        }
    }
    if (table->count == SEKI_TYPE_TABLE_CAPACITY) {
        return SEKI_TYPE_INVALID;
    }
    table->entries[table->count].kind = kind;
    table->entries[table->count].a = a;
    table->entries[table->count].b = b;
    index = table->count;
    table->count += 1U;
    return (uint32_t)index;
}

static uint32_t
find_declaration(const struct seki_module_prefix *module,
    const struct seki_name *name)
{
    size_t index;
    for (index = 0U; index < module->declaration_count; index += 1U) {
        if (seki_name_equal(&module->declarations[index].name, name)) {
            return (uint32_t)index;
        }
    }
    return SEKI_TYPE_INVALID;
}

static uint32_t
resolve_named(const struct seki_module_prefix *module,
    struct seki_type_table *table, const struct seki_name *name)
{
    uint32_t declaration;
    if (seki_name_is(name, "Unit")) {
        return seki_type_intern(table, SEKI_T_UNIT, 0U, 0U);
    }
    if (seki_name_is(name, "Bool")) {
        return seki_type_intern(table, SEKI_T_BOOL, 0U, 0U);
    }
    if (seki_name_is(name, "U8")) {
        return seki_type_intern(table, SEKI_T_U8, 0U, 0U);
    }
    if (seki_name_is(name, "U16")) {
        return seki_type_intern(table, SEKI_T_U16, 0U, 0U);
    }
    if (seki_name_is(name, "U32")) {
        return seki_type_intern(table, SEKI_T_U32, 0U, 0U);
    }
    if (seki_name_is(name, "U64")) {
        return seki_type_intern(table, SEKI_T_U64, 0U, 0U);
    }
    declaration = find_declaration(module, name);
    if (declaration == SEKI_TYPE_INVALID) {
        return SEKI_TYPE_INVALID;
    }
    return seki_type_intern(table, SEKI_T_DECLARED, declaration, 0U);
}

static uint32_t seki_type_resolve_argument(
    const struct seki_module_prefix *module, struct seki_type_table *table,
    const struct seki_type_arg *argument);

uint32_t
seki_type_resolve(const struct seki_module_prefix *module,
    struct seki_type_table *table, const struct seki_type_ref *reference)
{
    switch (reference->kind) {
    case SEKI_TYPE_NAMED:
        return resolve_named(module, table, &reference->name);
    case SEKI_TYPE_BYTES:
        if (reference->length == 0U) {
            return SEKI_TYPE_INVALID;
        }
        return seki_type_intern(table, SEKI_T_BYTES, reference->length, 0U);
    case SEKI_TYPE_DIGEST:
        if (!seki_name_is(&reference->algorithm, "sha256") ||
            reference->length != 32U) {
            return SEKI_TYPE_INVALID;
        }
        return seki_type_intern(table, SEKI_T_DIGEST, reference->length, 0U);
    case SEKI_TYPE_APPLIED:
    default:
        break;
    }
    if (seki_name_is(&reference->name, "Decision") &&
        reference->argument_count == 2U) {
        const uint32_t accepted = seki_type_resolve_argument(module, table,
            &reference->arguments[0]);
        const uint32_t rejection = seki_type_resolve_argument(module, table,
            &reference->arguments[1]);
        if (accepted == SEKI_TYPE_INVALID || rejection == SEKI_TYPE_INVALID) {
            return SEKI_TYPE_INVALID;
        }
        return seki_type_intern(table, SEKI_T_DECISION, accepted, rejection);
    }
    return SEKI_TYPE_INVALID;
}

/* Resolves a `Decision[A, R]` type argument, which may name Unit or Bool. */
static uint32_t
seki_type_resolve_argument(const struct seki_module_prefix *module,
    struct seki_type_table *table, const struct seki_type_arg *argument)
{
    if (argument->kind != SEKI_TYPE_ARG_TYPE_NAME) {
        return SEKI_TYPE_INVALID;
    }
    return resolve_named(module, table, &argument->name);
}

uint32_t
seki_type_expand(const struct seki_module_prefix *module,
    struct seki_type_table *table, uint32_t type)
{
    uint32_t depth;
    for (depth = 0U; depth < SEKI_TYPE_MAX_DEPTH; depth += 1U) {
        const struct seki_type_decl *declaration;
        if (type >= table->count ||
            table->entries[type].kind != SEKI_T_DECLARED) {
            return type;
        }
        if (table->entries[type].a >= module->declaration_count) {
            return SEKI_TYPE_INVALID;
        }
        declaration = &module->declarations[table->entries[type].a];
        if (declaration->kind != SEKI_DECL_ALIAS &&
            declaration->kind != SEKI_DECL_NOMINAL) {
            return type;
        }
        type = seki_type_resolve(module, table, &declaration->value.target);
        if (type == SEKI_TYPE_INVALID) {
            return SEKI_TYPE_INVALID;
        }
    }
    return SEKI_TYPE_INVALID;
}

static int
declared_value_bits(const struct seki_module_prefix *module,
    struct seki_type_table *table, uint32_t declaration_index,
    uint32_t depth, uint32_t *bits);

static int
value_bits(const struct seki_module_prefix *module,
    struct seki_type_table *table, uint32_t type, uint32_t depth,
    uint32_t *bits)
{
    const struct seki_type *entry;
    if (depth >= SEKI_TYPE_MAX_DEPTH || type >= table->count) {
        return 0;
    }
    entry = &table->entries[type];
    switch (entry->kind) {
    case SEKI_T_UNIT:
        *bits = 0U;
        return 1;
    case SEKI_T_BOOL:
        *bits = 1U;
        return 1;
    case SEKI_T_U8:
        *bits = 8U;
        return 1;
    case SEKI_T_U16:
        *bits = 16U;
        return 1;
    case SEKI_T_U32:
        *bits = 32U;
        return 1;
    case SEKI_T_U64:
        *bits = 64U;
        return 1;
    case SEKI_T_BYTES:
    case SEKI_T_DIGEST:
        return seki_checked_mul(8U, entry->a, bits);
    case SEKI_T_DECISION: {
        uint32_t accepted = 0U;
        uint32_t rejection = 0U;
        if (!value_bits(module, table, entry->a, depth + 1U, &accepted) ||
            !value_bits(module, table, entry->b, depth + 1U, &rejection)) {
            return 0;
        }
        return seki_checked_add(1U,
            accepted > rejection ? accepted : rejection, bits);
    }
    case SEKI_T_DECLARED:
        return declared_value_bits(module, table, entry->a, depth + 1U, bits);
    default:
        break;
    }
    return 0;
}

static int
lookup_field_bits(const struct seki_module_prefix *module,
    struct seki_type_table *table, const struct seki_type_ref *reference,
    uint32_t depth, uint32_t *bits)
{
    const uint32_t type = seki_type_resolve(module, table, reference);
    if (type == SEKI_TYPE_INVALID) {
        return 0;
    }
    return value_bits(module, table, type, depth, bits);
}

static int
declared_value_bits(const struct seki_module_prefix *module,
    struct seki_type_table *table, uint32_t declaration_index,
    uint32_t depth, uint32_t *bits)
{
    const struct seki_type_decl *declaration;
    size_t index;
    if (declaration_index >= module->declaration_count ||
        depth >= SEKI_TYPE_MAX_DEPTH) {
        return 0;
    }
    declaration = &module->declarations[declaration_index];
    switch (declaration->kind) {
    case SEKI_DECL_ALIAS:
    case SEKI_DECL_NOMINAL:
        return lookup_field_bits(module, table, &declaration->value.target,
            depth + 1U, bits);
    case SEKI_DECL_RECORD: {
        uint32_t total = 0U;
        for (index = 0U; index < declaration->value.record.field_count;
            index += 1U) {
            uint32_t field = 0U;
            if (!lookup_field_bits(module, table,
                &declaration->value.record.fields[index].type, depth + 1U,
                &field) || !seki_checked_add(total, field, &total)) {
                return 0;
            }
        }
        *bits = total;
        return 1;
    }
    case SEKI_DECL_VARIANT: {
        uint32_t maximum_tag = 0U;
        uint32_t widest_payload = 0U;
        for (index = 0U; index < declaration->value.variant.case_count;
            index += 1U) {
            const struct seki_variant_case *item =
                &declaration->value.variant.cases[index];
            uint32_t payload = 0U;
            size_t field;
            if (item->tag > maximum_tag) {
                maximum_tag = item->tag;
            }
            for (field = 0U; field < item->payload_count; field += 1U) {
                uint32_t width = 0U;
                if (!lookup_field_bits(module, table,
                    &item->payload[field].type, depth + 1U, &width) ||
                    !seki_checked_add(payload, width, &payload)) {
                    return 0;
                }
            }
            if (payload > widest_payload) {
                widest_payload = payload;
            }
        }
        return seki_checked_add(seki_tag_bits(maximum_tag), widest_payload,
            bits);
    }
    default:
        break;
    }
    return 0;
}

int
seki_type_value_bits(const struct seki_module_prefix *module,
    struct seki_type_table *table, uint32_t type, uint32_t *bits)
{
    if (module == NULL || table == NULL || bits == NULL) {
        return 0;
    }
    *bits = 0U;
    return value_bits(module, table, type, 0U, bits);
}
