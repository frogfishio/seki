#include "seki_checker.h"

#include <stddef.h>
#include <stdint.h>
#include <string.h>

/*
 * Environment slots follow the typed-core convention: slot zero is the
 * innermost binding. Kernel parameters are therefore installed in reverse
 * declaration order, and `Let` prepends. The emitter writes these indices
 * directly as `Local` references.
 */
#define SEKI_ENV_CAPACITY \
    (SEKI_CALLABLE_MAX_PARAMETERS + SEKI_KERNEL_MAX_EXPRESSIONS)

/*
 * Slot zero is the innermost binding. Parameters are installed in reverse
 * declaration order and each binding prepends, which is the typed core's own
 * convention, so a slot index is written straight out as a `Local` reference.
 */
struct environment {
    uint32_t slots[SEKI_ENV_CAPACITY];
    struct seki_name names[SEKI_ENV_CAPACITY];
    size_t count;
};

/* Returns the slot holding `name`, innermost first, or SEKI_TYPE_INVALID. */
static uint32_t
environment_lookup(const struct environment *environment,
    const struct seki_name *name)
{
    size_t index;
    for (index = 0U; index < environment->count; index += 1U) {
        if (seki_name_equal(&environment->names[index], name)) {
            return (uint32_t)index;
        }
    }
    return SEKI_TYPE_INVALID;
}

struct cost {
    uint32_t steps;
    uint32_t live;
    uint32_t depth;
    uint32_t workspace;
};

/*
 * An integer literal carries no type of its own; it adopts one from the
 * position it appears in. `is_natural` marks a node still awaiting that
 * context, so a literal compared against nothing concrete fails closed rather
 * than defaulting to a width the source never stated.
 */
struct inferred {
    uint32_t type;
    int is_natural;
    uint32_t natural;
};

struct checker {
    const struct seki_module_prefix *module;
    const struct seki_kernel_decl *kernel;
    struct seki_elaboration *elaboration;
    struct seki_kernel_elab *kernel_elaboration;
    struct seki_check_error *error;
    int failed;
};

static void
check_fail(struct checker *checker, const char *code, const char *message)
{
    if (!checker->failed) {
        checker->failed = 1;
        checker->error->code = code;
        checker->error->message = message;
    }
}

static uint32_t
declaration_index(const struct seki_module_prefix *module,
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
resolve(struct checker *checker, const struct seki_type_ref *reference)
{
    const uint32_t type = seki_type_resolve(checker->module,
        &checker->elaboration->types, reference);
    if (type == SEKI_TYPE_INVALID) {
        check_fail(checker, "A0-CHECK-0012",
            "type is unknown or outside the alpha subset");
    }
    return type;
}

static uint32_t
width_of(struct checker *checker, uint32_t type)
{
    uint32_t bits = 0U;
    if (type == SEKI_TYPE_INVALID) {
        return 0U;
    }
    if (!seki_type_value_bits(checker->module, &checker->elaboration->types,
        type, &bits)) {
        check_fail(checker, "A0-CHECK-0013",
            "semantic value width is unbounded or overflows U32");
        return 0U;
    }
    return bits;
}

static int
type_is_unsigned(const struct seki_elaboration *elaboration, uint32_t type)
{
    if (type >= elaboration->types.count) {
        return 0;
    }
    switch (elaboration->types.entries[type].kind) {
    case SEKI_T_U8:
    case SEKI_T_U16:
    case SEKI_T_U32:
    case SEKI_T_U64:
        return 1;
    default:
        break;
    }
    return 0;
}

static uint32_t
unsigned_width(const struct seki_elaboration *elaboration, uint32_t type)
{
    switch (elaboration->types.entries[type].kind) {
    case SEKI_T_U8:
        return 8U;
    case SEKI_T_U16:
        return 16U;
    case SEKI_T_U32:
        return 32U;
    default:
        break;
    }
    return 64U;
}

static int
natural_fits(uint32_t value, uint32_t width)
{
    if (width >= 32U) {
        return 1;
    }
    return value < (UINT32_C(1) << width);
}

/* Declaration field and payload types are resolved before any kernel body, so
 * a malformed declaration is reported against the declaration rather than the
 * first expression that happens to touch it. */
static void
resolve_declarations(struct checker *checker)
{
    size_t index;
    for (index = 0U; index < checker->module->declaration_count &&
        !checker->failed; index += 1U) {
        const struct seki_type_decl *declaration =
            &checker->module->declarations[index];
        size_t field;
        switch (declaration->kind) {
        case SEKI_DECL_ALIAS:
        case SEKI_DECL_NOMINAL:
            (void)resolve(checker, &declaration->value.target);
            break;
        case SEKI_DECL_RECORD:
            for (field = 0U; field < declaration->value.record.field_count &&
                !checker->failed; field += 1U) {
                (void)resolve(checker,
                    &declaration->value.record.fields[field].type);
            }
            break;
        case SEKI_DECL_VARIANT:
            for (field = 0U; field < declaration->value.variant.case_count &&
                !checker->failed; field += 1U) {
                const struct seki_variant_case *item =
                    &declaration->value.variant.cases[field];
                size_t payload;
                for (payload = 0U; payload < item->payload_count &&
                    !checker->failed; payload += 1U) {
                    (void)resolve(checker, &item->payload[payload].type);
                }
            }
            break;
        default:
            break;
        }
        if (!checker->failed) {
            /* Reject a declaration whose width cannot be derived, which is how
             * a recursive declaration surfaces at this stage. */
            const uint32_t type = seki_declaration_is_alias(checker->module,
                (uint32_t)index) ? 0U : seki_type_intern(
                &checker->elaboration->types, SEKI_T_DECLARED,
                (uint32_t)index, 0U);
            if (type == SEKI_TYPE_INVALID) {
                check_fail(checker, "A0-CHECK-0014",
                    "module exceeds the fixed type-table capacity");
            } else {
                (void)width_of(checker, type);
            }
        }
    }
}

static const struct seki_type_ref *
find_record_field(const struct checker *checker, uint32_t owner_declaration,
    const struct seki_name *field, uint32_t *field_index)
{
    const struct seki_type_decl *declaration;
    size_t index;
    if (owner_declaration >= checker->module->declaration_count) {
        return NULL;
    }
    declaration = &checker->module->declarations[owner_declaration];
    if (declaration->kind != SEKI_DECL_RECORD) {
        return NULL;
    }
    for (index = 0U; index < declaration->value.record.field_count;
        index += 1U) {
        if (seki_name_equal(&declaration->value.record.fields[index].name,
            field)) {
            *field_index = (uint32_t)index;
            return &declaration->value.record.fields[index].type;
        }
    }
    return NULL;
}

static void
record_info(struct checker *checker, uint32_t expression_index, uint32_t type,
    uint32_t a, uint32_t b, uint32_t c)
{
    struct seki_expr_info *info =
        &checker->kernel_elaboration->expressions[expression_index];
    info->type = type;
    info->a = a;
    info->b = b;
    info->c = c;
}

static struct inferred
infer_expression(struct checker *checker, uint32_t expression_index,
    const struct environment *environment);

/*
 * Assigns a concrete integer type to a literal that was inferred without one.
 * Returns zero when the literal does not fit the adopted width.
 */
static int
adopt_natural(struct checker *checker, uint32_t expression_index,
    struct inferred *value, uint32_t type)
{
    if (!value->is_natural) {
        return 1;
    }
    if (!type_is_unsigned(checker->elaboration, type) ||
        !natural_fits(value->natural,
            unsigned_width(checker->elaboration, type))) {
        return 0;
    }
    value->type = type;
    value->is_natural = 0;
    record_info(checker, expression_index, type, 0U, 0U, 0U);
    return 1;
}

static struct inferred
infer_expression(struct checker *checker, uint32_t expression_index,
    const struct environment *environment)
{
    struct inferred inferred = {SEKI_TYPE_INVALID, 0, 0U};
    const struct seki_expression *expression;
    if (checker->failed) {
        return inferred;
    }
    if ((size_t)expression_index >= checker->kernel->expression_count) {
        check_fail(checker, "A0-CHECK-0001", "expression index is invalid");
        return inferred;
    }
    expression = &checker->kernel->expressions[expression_index];
    switch (expression->kind) {
    case SEKI_EXPR_VALUE_NAME: {
        const uint32_t slot = environment_lookup(environment,
            &expression->value.name);
        if (slot == SEKI_TYPE_INVALID) {
            check_fail(checker, "A0-CHECK-0002", "unknown value name");
            break;
        }
        inferred.type = environment->slots[slot];
        record_info(checker, expression_index, inferred.type, slot, 0U, 0U);
        break;
    }
    case SEKI_EXPR_BOOL:
        inferred.type = seki_type_intern(&checker->elaboration->types,
            SEKI_T_BOOL, 0U, 0U);
        record_info(checker, expression_index, inferred.type, 0U, 0U, 0U);
        break;
    case SEKI_EXPR_UNIT:
        inferred.type = seki_type_intern(&checker->elaboration->types,
            SEKI_T_UNIT, 0U, 0U);
        record_info(checker, expression_index, inferred.type, 0U, 0U, 0U);
        break;
    case SEKI_EXPR_NATURAL:
        inferred.is_natural = 1;
        inferred.natural = expression->value.natural;
        break;
    case SEKI_EXPR_FIELD: {
        const struct inferred receiver = infer_expression(checker,
            expression->value.field.receiver, environment);
        const struct seki_type_ref *field_type = NULL;
        uint32_t field_index = 0U;
        uint32_t owner = SEKI_TYPE_INVALID;
        if (checker->failed) {
            break;
        }
        owner = seki_type_expand(checker->module, &checker->elaboration->types,
            receiver.type);
        if (owner != SEKI_TYPE_INVALID &&
            owner < checker->elaboration->types.count &&
            checker->elaboration->types.entries[owner].kind ==
                SEKI_T_DECLARED) {
            field_type = find_record_field(checker,
                checker->elaboration->types.entries[owner].a,
                &expression->value.field.field, &field_index);
        }
        if (field_type == NULL) {
            check_fail(checker, "A0-CHECK-0003",
                "field does not belong to receiver record");
            break;
        }
        inferred.type = resolve(checker, field_type);
        record_info(checker, expression_index, inferred.type,
            checker->elaboration->types.entries[owner].a, field_index, 0U);
        break;
    }
    case SEKI_EXPR_RECORD: {
        const uint32_t owner = declaration_index(checker->module,
            &expression->value.record.type_name);
        const struct seki_type_decl *declaration;
        size_t field;
        if (owner == SEKI_TYPE_INVALID ||
            checker->module->declarations[owner].kind != SEKI_DECL_RECORD) {
            check_fail(checker, "A0-CHECK-0020",
                "record literal does not name a declared record");
            break;
        }
        declaration = &checker->module->declarations[owner];
        if (declaration->value.record.field_count !=
            (size_t)expression->value.record.count) {
            check_fail(checker, "A0-CHECK-0021",
                "record literal does not initialise every field exactly once");
            break;
        }
        /* Each declared field must be supplied once, with a matching type.
         * The literal's own order is free; emission uses canonical order. */
        for (field = 0U; field < declaration->value.record.field_count;
            field += 1U) {
            const struct seki_field_decl *declared =
                &declaration->value.record.fields[field];
            const uint32_t declared_type = resolve(checker, &declared->type);
            uint32_t supplied = UINT32_MAX;
            size_t entry;
            struct inferred value;
            if (checker->failed) {
                return inferred;
            }
            for (entry = 0U; entry < (size_t)expression->value.record.count;
                entry += 1U) {
                const struct seki_record_init *initialiser =
                    &checker->kernel->record_fields
                        [expression->value.record.first + entry];
                if (seki_name_equal(&initialiser->name, &declared->name)) {
                    supplied = initialiser->value;
                    break;
                }
            }
            if (supplied == UINT32_MAX) {
                check_fail(checker, "A0-CHECK-0021",
                    "record literal does not initialise every field "
                    "exactly once");
                return inferred;
            }
            value = infer_expression(checker, supplied, environment);
            if (checker->failed) {
                return inferred;
            }
            (void)adopt_natural(checker, supplied, &value, declared_type);
            if (value.type != declared_type) {
                check_fail(checker, "A0-CHECK-0022",
                    "record literal field does not match its declared type");
                return inferred;
            }
        }
        inferred.type = seki_type_intern(&checker->elaboration->types,
            SEKI_T_DECLARED, owner, 0U);
        record_info(checker, expression_index, inferred.type, owner, 0U, 0U);
        break;
    }
    case SEKI_EXPR_COMPARE: {
        const uint32_t left_index = expression->value.compare.left;
        const uint32_t right_index = expression->value.compare.right;
        struct inferred left = infer_expression(checker, left_index,
            environment);
        struct inferred right = infer_expression(checker, right_index,
            environment);
        const int ordered = expression->value.compare.operator <=
            SEKI_COMPARE_GREATER_EQUAL;
        if (checker->failed) {
            break;
        }
        if (left.is_natural && right.is_natural) {
            check_fail(checker, "A0-CHECK-0015",
                "integer literal has no inferred integer type");
            break;
        }
        if (!adopt_natural(checker, left_index, &left, right.type) ||
            !adopt_natural(checker, right_index, &right, left.type)) {
            check_fail(checker, "A0-CHECK-0004",
                "comparison operands are incompatible");
            break;
        }
        if (left.type != right.type) {
            check_fail(checker, "A0-CHECK-0004",
                "comparison operands are incompatible");
            break;
        }
        if (ordered && !type_is_unsigned(checker->elaboration, left.type)) {
            check_fail(checker, "A0-CHECK-0004",
                "ordered comparison requires numeric operands");
            break;
        }
        inferred.type = seki_type_intern(&checker->elaboration->types,
            SEKI_T_BOOL, 0U, 0U);
        record_info(checker, expression_index, inferred.type, 0U, 0U, 0U);
        break;
    }
    case SEKI_EXPR_AND:
    case SEKI_EXPR_OR: {
        const uint32_t boolean = seki_type_intern(&checker->elaboration->types,
            SEKI_T_BOOL, 0U, 0U);
        const struct inferred left = infer_expression(checker,
            expression->value.logical.left, environment);
        const struct inferred right = infer_expression(checker,
            expression->value.logical.right, environment);
        if (checker->failed) {
            break;
        }
        if (boolean == SEKI_TYPE_INVALID || left.is_natural ||
            right.is_natural || left.type != boolean ||
            right.type != boolean) {
            check_fail(checker, "A0-CHECK-0018",
                "Boolean operands must both have type Bool");
            break;
        }
        inferred.type = boolean;
        record_info(checker, expression_index, inferred.type, 0U, 0U, 0U);
        break;
    }
    default:
        check_fail(checker, "A0-CHECK-0005",
            "kernel control used as a value expression");
        break;
    }
    if (!checker->failed && !inferred.is_natural &&
        inferred.type == SEKI_TYPE_INVALID) {
        check_fail(checker, "A0-CHECK-0012",
            "type is unknown or outside the alpha subset");
    }
    return inferred;
}

static int
variant_case_tag(const struct seki_module_prefix *module,
    uint32_t variant_declaration, const struct seki_name *item, uint32_t *tag)
{
    const struct seki_type_decl *declaration;
    size_t index;
    if (variant_declaration >= module->declaration_count) {
        return 0;
    }
    declaration = &module->declarations[variant_declaration];
    if (declaration->kind != SEKI_DECL_VARIANT) {
        return 0;
    }
    for (index = 0U; index < declaration->value.variant.case_count;
        index += 1U) {
        if (seki_name_equal(&declaration->value.variant.cases[index].name,
            item)) {
            *tag = declaration->value.variant.cases[index].tag;
            return 1;
        }
    }
    return 0;
}

static int
kernel_precedence_index(const struct seki_kernel_decl *kernel,
    const struct seki_variant_ref *reference, uint32_t *precedence)
{
    size_t index;
    for (index = 0U; index < kernel->rejection_count; index += 1U) {
        if (seki_name_equal(&kernel->rejections[index].owner,
            &reference->owner) &&
            seki_name_equal(&kernel->rejections[index].item,
                &reference->item)) {
            *precedence = (uint32_t)index;
            return 1;
        }
    }
    return 0;
}

/*
 * Resolves a rejection reference against the kernel's Decision result and its
 * ordered inventory, recording the variant declaration, stable tag, and
 * precedence index. Shared by `reject` and `require`.
 */
static int
resolve_rejection(struct checker *checker, uint32_t expression_index,
    const struct seki_variant_ref *reference)
{
    const uint32_t rejection = checker->kernel_elaboration->rejection_type;
    uint32_t variant_declaration = SEKI_TYPE_INVALID;
    uint32_t tag = 0U;
    uint32_t precedence = 0U;
    if (rejection < checker->elaboration->types.count &&
        checker->elaboration->types.entries[rejection].kind ==
            SEKI_T_DECLARED) {
        variant_declaration = checker->elaboration->types.entries[rejection].a;
    }
    if (variant_declaration == SEKI_TYPE_INVALID ||
        declaration_index(checker->module, &reference->owner) !=
            variant_declaration ||
        !variant_case_tag(checker->module, variant_declaration,
            &reference->item, &tag)) {
        check_fail(checker, "A0-CHECK-0007",
            "rejection does not belong to Decision result");
        return 0;
    }
    if (!kernel_precedence_index(checker->kernel, reference, &precedence)) {
        check_fail(checker, "A0-CHECK-0008",
            "rejection is absent from ordered inventory");
        return 0;
    }
    record_info(checker, expression_index, SEKI_TYPE_INVALID,
        variant_declaration, tag, precedence);
    return 1;
}

static void
check_kernel_tail(struct checker *checker, uint32_t expression_index,
    const struct environment *environment)
{
    const struct seki_expression *expression;
    if (checker->failed) {
        return;
    }
    if ((size_t)expression_index >= checker->kernel->expression_count) {
        check_fail(checker, "A0-CHECK-0001", "expression index is invalid");
        return;
    }
    expression = &checker->kernel->expressions[expression_index];
    record_info(checker, expression_index, SEKI_TYPE_INVALID, 0U, 0U, 0U);
    if (expression->kind == SEKI_EXPR_ACCEPT) {
        const uint32_t value_index = expression->value.accept.value;
        struct inferred value = infer_expression(checker, value_index,
            environment);
        if (checker->failed) {
            return;
        }
        (void)adopt_natural(checker, value_index, &value,
            checker->kernel_elaboration->accepted_type);
        if (value.type != checker->kernel_elaboration->accepted_type) {
            check_fail(checker, "A0-CHECK-0006",
                "accepted value does not match Decision result");
        }
    } else if (expression->kind == SEKI_EXPR_REJECT) {
        (void)resolve_rejection(checker, expression_index,
            &expression->value.rejection);
    } else if (expression->kind == SEKI_EXPR_REQUIRE) {
        const uint32_t boolean = seki_type_intern(&checker->elaboration->types,
            SEKI_T_BOOL, 0U, 0U);
        const struct inferred condition = infer_expression(checker,
            expression->value.require.condition, environment);
        if (checker->failed) {
            return;
        }
        if (condition.is_natural || boolean == SEKI_TYPE_INVALID ||
            condition.type != boolean) {
            check_fail(checker, "A0-CHECK-0009",
                "kernel condition must have type Bool");
            return;
        }
        if (!resolve_rejection(checker, expression_index,
            &expression->value.require.rejection)) {
            return;
        }
        check_kernel_tail(checker, expression->value.require.continuation,
            environment);
    } else if (expression->kind == SEKI_EXPR_LET) {
        const uint32_t value_index = expression->value.let.value;
        const struct inferred value = infer_expression(checker, value_index,
            environment);
        struct environment extended;
        size_t index;
        if (checker->failed) {
            return;
        }
        if (value.is_natural) {
            /* A binding has no annotation, so a bare literal has nothing to
             * take its width from. */
            check_fail(checker, "A0-CHECK-0015",
                "integer literal has no inferred integer type");
            return;
        }
        if (environment_lookup(environment, &expression->value.let.name) !=
            SEKI_TYPE_INVALID) {
            check_fail(checker, "A0-CHECK-0019",
                "binding shadows a visible local");
            return;
        }
        if (environment->count == SEKI_ENV_CAPACITY) {
            check_fail(checker, "A0-CHECK-0016",
                "kernel environment exceeds fixed capacity");
            return;
        }
        /* The binding becomes slot zero and every visible local shifts out. */
        extended.count = environment->count + 1U;
        extended.slots[0] = value.type;
        extended.names[0] = expression->value.let.name;
        for (index = 0U; index < environment->count; index += 1U) {
            extended.slots[index + 1U] = environment->slots[index];
            extended.names[index + 1U] = environment->names[index];
        }
        record_info(checker, expression_index, SEKI_TYPE_INVALID, 0U, 0U, 0U);
        check_kernel_tail(checker, expression->value.let.body, &extended);
    } else if (expression->kind == SEKI_EXPR_IF) {
        const struct inferred condition = infer_expression(checker,
            expression->value.conditional.condition, environment);
        const uint32_t boolean = seki_type_intern(&checker->elaboration->types,
            SEKI_T_BOOL, 0U, 0U);
        if (!checker->failed && (condition.is_natural ||
            boolean == SEKI_TYPE_INVALID || condition.type != boolean)) {
            check_fail(checker, "A0-CHECK-0009",
                "kernel condition must have type Bool");
        }
        check_kernel_tail(checker, expression->value.conditional.if_true,
            environment);
        check_kernel_tail(checker, expression->value.conditional.if_false,
            environment);
    } else {
        check_fail(checker, "A0-CHECK-0010",
            "kernel path lacks terminal accept or reject");
    }
}

/*
 * Section 3 of the resource-cost algebra. `base` is the summed width of the
 * live environment slots at this point in the fixed evaluation schedule.
 */
static struct cost
cost_of_expression(struct checker *checker, uint32_t expression_index,
    const struct environment *environment, uint32_t base);

static struct cost
cost_strict(struct checker *checker, const uint32_t *children,
    size_t child_count, uint32_t result_type,
    const struct environment *environment, uint32_t base)
{
    struct cost total = {1U, base, 1U, 0U};
    uint32_t retained = 0U;
    uint32_t peak = 0U;
    size_t index;
    for (index = 0U; index < child_count; index += 1U) {
        uint32_t child_base = 0U;
        struct cost child;
        if (!seki_checked_add(base, retained, &child_base)) {
            check_fail(checker, "A0-CHECK-0013",
                "semantic value width is unbounded or overflows U32");
            return total;
        }
        child = cost_of_expression(checker, children[index], environment,
            child_base);
        if (!seki_checked_add(total.steps, child.steps, &total.steps)) {
            check_fail(checker, "A0-CHECK-0013",
                "semantic value width is unbounded or overflows U32");
            return total;
        }
        if (child.live > total.live) {
            total.live = child.live;
        }
        if (child.depth + 1U > total.depth) {
            total.depth = child.depth + 1U;
        }
        if (child.workspace > total.workspace) {
            total.workspace = child.workspace;
        }
        if (!seki_checked_add(retained,
            width_of(checker, checker->kernel_elaboration
                ->expressions[children[index]].type), &retained)) {
            check_fail(checker, "A0-CHECK-0013",
                "semantic value width is unbounded or overflows U32");
            return total;
        }
    }
    if (!seki_checked_add(base, retained, &peak) ||
        !seki_checked_add(peak, width_of(checker, result_type), &peak)) {
        check_fail(checker, "A0-CHECK-0013",
            "semantic value width is unbounded or overflows U32");
        return total;
    }
    if (peak > total.live) {
        total.live = peak;
    }
    return total;
}

static struct cost
cost_of_expression(struct checker *checker, uint32_t expression_index,
    const struct environment *environment, uint32_t base)
{
    struct cost cost = {1U, base, 1U, 0U};
    const struct seki_expression *expression;
    uint32_t result_type;
    if (checker->failed ||
        (size_t)expression_index >= checker->kernel->expression_count) {
        return cost;
    }
    expression = &checker->kernel->expressions[expression_index];
    result_type =
        checker->kernel_elaboration->expressions[expression_index].type;
    switch (expression->kind) {
    case SEKI_EXPR_VALUE_NAME:
    case SEKI_EXPR_BOOL:
    case SEKI_EXPR_UNIT:
    case SEKI_EXPR_NATURAL:
        if (!seki_checked_add(base, width_of(checker, result_type),
            &cost.live)) {
            check_fail(checker, "A0-CHECK-0013",
                "semantic value width is unbounded or overflows U32");
        }
        break;
    case SEKI_EXPR_FIELD: {
        const uint32_t receiver = expression->value.field.receiver;
        const struct cost child = cost_of_expression(checker, receiver,
            environment, base);
        uint32_t peak = 0U;
        cost.steps = child.steps + 1U;
        cost.live = child.live;
        cost.depth = child.depth + 1U;
        cost.workspace = child.workspace;
        /* Projection retains the complete record while allocating the field. */
        if (!seki_checked_add(base, width_of(checker,
            checker->kernel_elaboration->expressions[receiver].type),
            &peak) || !seki_checked_add(peak,
                width_of(checker, result_type), &peak)) {
            check_fail(checker, "A0-CHECK-0013",
                "semantic value width is unbounded or overflows U32");
            break;
        }
        if (peak > cost.live) {
            cost.live = peak;
        }
        break;
    }
    case SEKI_EXPR_COMPARE: {
        const uint32_t children[2] = {
            expression->value.compare.left, expression->value.compare.right
        };
        cost = cost_strict(checker, children, 2U, result_type, environment,
            base);
        break;
    }
    case SEKI_EXPR_RECORD: {
        /* Children are visited in canonical field order, which is the order
         * the emitter writes them, so the derivation matches the encoding. */
        uint32_t children[SEKI_RECORD_MAX_FIELDS];
        const struct seki_expr_info *info =
            &checker->kernel_elaboration->expressions[expression_index];
        const struct seki_type_decl *declaration;
        size_t field;
        if (info->a >= checker->module->declaration_count) {
            check_fail(checker, "A0-CHECK-0020",
                "record literal does not name a declared record");
            break;
        }
        declaration = &checker->module->declarations[info->a];
        for (field = 0U; field < declaration->value.record.field_count;
            field += 1U) {
            size_t entry;
            children[field] = UINT32_MAX;
            for (entry = 0U; entry < (size_t)expression->value.record.count;
                entry += 1U) {
                const struct seki_record_init *initialiser =
                    &checker->kernel->record_fields
                        [expression->value.record.first + entry];
                if (seki_name_equal(&initialiser->name,
                    &declaration->value.record.fields[field].name)) {
                    children[field] = initialiser->value;
                    break;
                }
            }
            if (children[field] == UINT32_MAX) {
                check_fail(checker, "A0-CHECK-0021",
                    "record literal does not initialise every field "
                    "exactly once");
                return cost;
            }
        }
        cost = cost_strict(checker, children,
            declaration->value.record.field_count, result_type, environment,
            base);
        break;
    }
    case SEKI_EXPR_AND:
    case SEKI_EXPR_OR: {
        /*
         * Short-circuit control releases the left result before evaluating
         * the right, so both are charged at the same base and the live peak is
         * their maximum rather than their sum. The right operand's steps are
         * still charged: the bound is worst case.
         */
        const struct cost left = cost_of_expression(checker,
            expression->value.logical.left, environment, base);
        const struct cost right = cost_of_expression(checker,
            expression->value.logical.right, environment, base);
        uint32_t steps = 0U;
        if (!seki_checked_add(left.steps, right.steps, &steps) ||
            !seki_checked_add(steps, 1U, &cost.steps)) {
            check_fail(checker, "A0-CHECK-0013",
                "semantic value width is unbounded or overflows U32");
            break;
        }
        cost.live = left.live > right.live ? left.live : right.live;
        cost.depth = (left.depth > right.depth ? left.depth : right.depth) + 1U;
        cost.workspace = left.workspace > right.workspace ?
            left.workspace : right.workspace;
        break;
    }
    default:
        check_fail(checker, "A0-CHECK-0005",
            "kernel control used as a value expression");
        break;
    }
    return cost;
}

static struct cost
cost_of_kernel_tail(struct checker *checker, uint32_t expression_index,
    const struct environment *environment, uint32_t base, uint32_t result_type)
{
    struct cost cost = {1U, base, 1U, 0U};
    const struct seki_expression *expression;
    if (checker->failed ||
        (size_t)expression_index >= checker->kernel->expression_count) {
        return cost;
    }
    expression = &checker->kernel->expressions[expression_index];
    if (expression->kind == SEKI_EXPR_ACCEPT ||
        expression->kind == SEKI_EXPR_REJECT) {
        /* KernelReject builds its reason term inline; KernelAccept evaluates
         * the accepted value. Both retain that child while allocating the
         * enclosing Decision result. */
        const int is_accept = expression->kind == SEKI_EXPR_ACCEPT;
        const uint32_t child_index = is_accept ?
            expression->value.accept.value : UINT32_MAX;
        struct cost child = {1U, base, 1U, 0U};
        uint32_t child_width = 0U;
        uint32_t peak = 0U;
        if (is_accept) {
            child = cost_of_expression(checker, child_index, environment,
                base);
            child_width = width_of(checker, checker->kernel_elaboration
                ->expressions[child_index].type);
        } else {
            /* The rejection reason is one variant construction with no
             * arguments: a single step whose result is the rejection type. */
            child_width = width_of(checker,
                checker->kernel_elaboration->rejection_type);
            if (!seki_checked_add(base, child_width, &child.live)) {
                check_fail(checker, "A0-CHECK-0013",
                    "semantic value width is unbounded or overflows U32");
                return cost;
            }
        }
        cost.steps = child.steps + 1U;
        cost.live = child.live;
        cost.depth = child.depth + 1U;
        cost.workspace = child.workspace;
        if (!seki_checked_add(base, child_width, &peak) ||
            !seki_checked_add(peak, width_of(checker, result_type), &peak)) {
            check_fail(checker, "A0-CHECK-0013",
                "semantic value width is unbounded or overflows U32");
            return cost;
        }
        if (peak > cost.live) {
            cost.live = peak;
        }
        return cost;
    }
    if (expression->kind == SEKI_EXPR_LET) {
        /*
         * The value moves into the environment rather than being copied, so
         * the body runs with the binding's width added to the base and the
         * live peak is the maximum of the two phases, not their sum.
         */
        const uint32_t value_index = expression->value.let.value;
        const struct cost value = cost_of_expression(checker, value_index,
            environment, base);
        const uint32_t value_width = width_of(checker,
            checker->kernel_elaboration->expressions[value_index].type);
        struct environment extended;
        struct cost body;
        uint32_t body_base = 0U;
        size_t index;
        if (!seki_checked_add(base, value_width, &body_base)) {
            check_fail(checker, "A0-CHECK-0013",
                "semantic value width is unbounded or overflows U32");
            return cost;
        }
        extended.count = environment->count + 1U;
        extended.slots[0] =
            checker->kernel_elaboration->expressions[value_index].type;
        extended.names[0] = expression->value.let.name;
        for (index = 0U; index < environment->count; index += 1U) {
            extended.slots[index + 1U] = environment->slots[index];
            extended.names[index + 1U] = environment->names[index];
        }
        body = cost_of_kernel_tail(checker, expression->value.let.body,
            &extended, body_base, result_type);
        if (!seki_checked_add(value.steps, body.steps, &cost.steps) ||
            !seki_checked_add(cost.steps, 1U, &cost.steps)) {
            check_fail(checker, "A0-CHECK-0013",
                "semantic value width is unbounded or overflows U32");
            return cost;
        }
        cost.live = value.live > body.live ? value.live : body.live;
        cost.depth = (value.depth > body.depth ? value.depth : body.depth) + 1U;
        cost.workspace = value.workspace > body.workspace ?
            value.workspace : body.workspace;
        return cost;
    }
    if (expression->kind == SEKI_EXPR_REQUIRE) {
        /*
         * The rejection reason is one variant construction: a single step
         * whose result is retained while the enclosing Decision is built. The
         * failing and continuing paths are alternatives, so steps take their
         * maximum.
         */
        const struct cost condition = cost_of_expression(checker,
            expression->value.require.condition, environment, base);
        const struct cost continuation = cost_of_kernel_tail(checker,
            expression->value.require.continuation, environment, base,
            result_type);
        const uint32_t reason_width = width_of(checker,
            checker->kernel_elaboration->rejection_type);
        uint32_t reason_live = 0U;
        uint32_t reason_peak = 0U;
        uint32_t steps = 0U;
        if (!seki_checked_add(base, reason_width, &reason_live) ||
            !seki_checked_add(reason_live, width_of(checker, result_type),
                &reason_peak)) {
            check_fail(checker, "A0-CHECK-0013",
                "semantic value width is unbounded or overflows U32");
            return cost;
        }
        /* The reason costs one step; the continuation may cost more. */
        if (!seki_checked_add(condition.steps,
            continuation.steps > 1U ? continuation.steps : 1U, &steps) ||
            !seki_checked_add(steps, 1U, &cost.steps)) {
            check_fail(checker, "A0-CHECK-0013",
                "semantic value width is unbounded or overflows U32");
            return cost;
        }
        cost.live = condition.live;
        if (reason_live > cost.live) {
            cost.live = reason_live;
        }
        if (reason_peak > cost.live) {
            cost.live = reason_peak;
        }
        if (continuation.live > cost.live) {
            cost.live = continuation.live;
        }
        cost.depth = condition.depth > continuation.depth ?
            condition.depth : continuation.depth;
        if (cost.depth < 1U) {
            cost.depth = 1U;
        }
        cost.depth += 1U;
        cost.workspace = condition.workspace > continuation.workspace ?
            condition.workspace : continuation.workspace;
        return cost;
    }
    if (expression->kind == SEKI_EXPR_IF) {
        const struct cost condition = cost_of_expression(checker,
            expression->value.conditional.condition, environment, base);
        const struct cost yes = cost_of_kernel_tail(checker,
            expression->value.conditional.if_true, environment, base,
            result_type);
        const struct cost no = cost_of_kernel_tail(checker,
            expression->value.conditional.if_false, environment, base,
            result_type);
        const uint32_t branch = yes.steps > no.steps ? yes.steps : no.steps;
        uint32_t steps = 0U;
        if (!seki_checked_add(condition.steps, branch, &steps) ||
            !seki_checked_add(steps, 1U, &cost.steps)) {
            check_fail(checker, "A0-CHECK-0013",
                "semantic value width is unbounded or overflows U32");
            return cost;
        }
        cost.live = condition.live;
        if (yes.live > cost.live) {
            cost.live = yes.live;
        }
        if (no.live > cost.live) {
            cost.live = no.live;
        }
        cost.depth = condition.depth;
        if (yes.depth > cost.depth) {
            cost.depth = yes.depth;
        }
        if (no.depth > cost.depth) {
            cost.depth = no.depth;
        }
        cost.depth += 1U;
        cost.workspace = condition.workspace;
        if (yes.workspace > cost.workspace) {
            cost.workspace = yes.workspace;
        }
        if (no.workspace > cost.workspace) {
            cost.workspace = no.workspace;
        }
        return cost;
    }
    check_fail(checker, "A0-CHECK-0010",
        "kernel path lacks terminal accept or reject");
    return cost;
}

/*
 * `check_order` from the typed-core model, section 8.7. Rejection indices
 * strictly increase along every sequentially reachable continuation, so the
 * declared `rejects:` order is the order premises are actually checked rather
 * than an inventory the body may contradict. Mutually exclusive branches may
 * each begin at an unrelated index because only one of them runs.
 */
static void
check_rejection_order(struct checker *checker, uint32_t expression_index,
    uint32_t floor)
{
    const struct seki_expression *expression;
    const struct seki_expr_info *info;
    if (checker->failed ||
        (size_t)expression_index >= checker->kernel->expression_count) {
        return;
    }
    expression = &checker->kernel->expressions[expression_index];
    info = &checker->kernel_elaboration->expressions[expression_index];
    switch (expression->kind) {
    case SEKI_EXPR_ACCEPT:
        break;
    case SEKI_EXPR_REJECT:
        if (info->c < floor) {
            check_fail(checker, "A0-CHECK-0023",
                "rejection precedence must increase along each path");
        }
        break;
    case SEKI_EXPR_REQUIRE:
        if (info->c < floor) {
            check_fail(checker, "A0-CHECK-0023",
                "rejection precedence must increase along each path");
            return;
        }
        if (info->c == UINT32_MAX) {
            check_fail(checker, "A0-CHECK-0013",
                "semantic value width is unbounded or overflows U32");
            return;
        }
        check_rejection_order(checker, expression->value.require.continuation,
            info->c + 1U);
        break;
    case SEKI_EXPR_LET:
        check_rejection_order(checker, expression->value.let.body, floor);
        break;
    case SEKI_EXPR_IF:
        check_rejection_order(checker, expression->value.conditional.if_true,
            floor);
        check_rejection_order(checker, expression->value.conditional.if_false,
            floor);
        break;
    default:
        break;
    }
}

static void
check_kernel(struct checker *checker, size_t kernel_index)
{
    const struct seki_kernel_decl *kernel = checker->kernel;
    struct seki_kernel_elab *elaboration =
        &checker->elaboration->kernels[kernel_index];
    struct environment environment;
    struct cost cost;
    uint32_t base = 0U;
    size_t index;

    checker->kernel_elaboration = elaboration;
    memset(elaboration, 0, sizeof *elaboration);
    elaboration->result_type = SEKI_TYPE_INVALID;
    elaboration->accepted_type = SEKI_TYPE_INVALID;
    elaboration->rejection_type = SEKI_TYPE_INVALID;
    elaboration->parameter_count = kernel->parameter_count;
    elaboration->expression_count = kernel->expression_count;
    for (index = 0U; index < kernel->expression_count; index += 1U) {
        elaboration->expressions[index].type = SEKI_TYPE_INVALID;
    }

    if (kernel->result.kind != SEKI_TYPE_APPLIED ||
        !seki_name_is(&kernel->result.name, "Decision") ||
        kernel->result.argument_count != 2U ||
        kernel->result.arguments[0].kind != SEKI_TYPE_ARG_TYPE_NAME ||
        kernel->result.arguments[1].kind != SEKI_TYPE_ARG_TYPE_NAME) {
        check_fail(checker, "A0-CHECK-0011",
            "kernel result must be Decision[A, R]");
        return;
    }
    elaboration->result_type = resolve(checker, &kernel->result);
    if (checker->failed) {
        return;
    }
    elaboration->accepted_type =
        checker->elaboration->types.entries[elaboration->result_type].a;
    elaboration->rejection_type =
        checker->elaboration->types.entries[elaboration->result_type].b;

    memset(&environment, 0, sizeof environment);
    if (kernel->parameter_count > SEKI_ENV_CAPACITY) {
        check_fail(checker, "A0-CHECK-0016",
            "kernel environment exceeds fixed capacity");
        return;
    }
    /* Parameters occupy the outermost slots: the last declared parameter is
     * environment slot zero. */
    for (index = 0U; index < kernel->parameter_count; index += 1U) {
        const size_t slot = kernel->parameter_count - 1U - index;
        const uint32_t type = resolve(checker,
            &kernel->parameters[index].type);
        if (checker->failed) {
            return;
        }
        elaboration->parameter_types[index] = type;
        environment.slots[slot] = type;
        environment.names[slot] = kernel->parameters[index].label;
        if (!seki_checked_add(base, width_of(checker, type), &base)) {
            check_fail(checker, "A0-CHECK-0013",
                "semantic value width is unbounded or overflows U32");
            return;
        }
    }
    environment.count = kernel->parameter_count;

    check_kernel_tail(checker, kernel->body_root, &environment);
    if (checker->failed) {
        return;
    }
    check_rejection_order(checker, kernel->body_root, 0U);
    if (checker->failed) {
        return;
    }
    cost = cost_of_kernel_tail(checker, kernel->body_root, &environment, base,
        elaboration->result_type);
    if (checker->failed) {
        return;
    }
    /* The root callable frame is charged one step and one frame of depth. */
    if (!seki_checked_add(cost.steps, 1U, &cost.steps) ||
        !seki_checked_add(cost.depth, 1U, &cost.depth)) {
        check_fail(checker, "A0-CHECK-0013",
            "semantic value width is unbounded or overflows U32");
        return;
    }
    elaboration->exact.steps = cost.steps;
    elaboration->exact.live_bits = cost.live;
    elaboration->exact.control_depth = cost.depth;
    elaboration->exact.workspace_bits = cost.workspace;

    if (kernel->bounds.steps < cost.steps ||
        kernel->bounds.live_bits < cost.live ||
        kernel->bounds.control_depth < cost.depth ||
        kernel->bounds.workspace_bits < cost.workspace) {
        check_fail(checker, "A0-CHECK-0017",
            "declared resource ceiling is below the derived exact bound");
    }
}

int
seki_check_module(const struct seki_module_prefix *module,
    struct seki_elaboration *elaboration, struct seki_check_error *error)
{
    struct checker checker;
    size_t index;
    if (module == NULL || elaboration == NULL || error == NULL) {
        return 0;
    }
    error->code = "A0-CHECK-0000";
    error->message = "invalid checker state";
    memset(elaboration, 0, sizeof *elaboration);
    seki_type_table_init(&elaboration->types);
    elaboration->kernel_count = module->kernel_count;
    checker.module = module;
    checker.kernel = NULL;
    checker.elaboration = elaboration;
    checker.kernel_elaboration = NULL;
    checker.error = error;
    checker.failed = 0;

    resolve_declarations(&checker);
    for (index = 0U; index < module->kernel_count && !checker.failed;
        index += 1U) {
        checker.kernel = &module->kernels[index];
        check_kernel(&checker, index);
    }
    return !checker.failed;
}
