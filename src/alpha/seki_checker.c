#include "seki_checker.h"

#include <stddef.h>
#include <stdint.h>

enum inferred_kind {
    INFER_INVALID,
    INFER_UNIT,
    INFER_BOOL,
    INFER_UNSIGNED,
    INFER_NATURAL,
    INFER_NAMED
};

struct inferred_type {
    enum inferred_kind kind;
    uint32_t width;
    uint32_t natural;
    struct seki_name name;
};

struct checker {
    const struct seki_module_prefix *module;
    const struct seki_kernel_decl *kernel;
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

static const struct seki_type_decl *
find_type(const struct seki_module_prefix *module, const struct seki_name *name)
{
    size_t index;
    for (index = 0U; index < module->declaration_count; index += 1U) {
        if (seki_name_equal(&module->declarations[index].name, name)) {
            return &module->declarations[index];
        }
    }
    return NULL;
}

static struct inferred_type
infer_type_ref(const struct seki_type_ref *type)
{
    struct inferred_type inferred = {INFER_INVALID, 0U, 0U, {NULL, 0U}};
    if (type->kind != SEKI_TYPE_NAMED) {
        return inferred;
    }
    if (seki_name_is(&type->name, "Unit")) {
        inferred.kind = INFER_UNIT;
    } else if (seki_name_is(&type->name, "Bool")) {
        inferred.kind = INFER_BOOL;
    } else if (seki_name_is(&type->name, "U8")) {
        inferred.kind = INFER_UNSIGNED;
        inferred.width = 8U;
    } else if (seki_name_is(&type->name, "U16")) {
        inferred.kind = INFER_UNSIGNED;
        inferred.width = 16U;
    } else if (seki_name_is(&type->name, "U32")) {
        inferred.kind = INFER_UNSIGNED;
        inferred.width = 32U;
    } else if (seki_name_is(&type->name, "U64")) {
        inferred.kind = INFER_UNSIGNED;
        inferred.width = 64U;
    } else {
        inferred.kind = INFER_NAMED;
        inferred.name = type->name;
    }
    return inferred;
}

static const struct seki_type_ref *
find_parameter_type(const struct seki_kernel_decl *kernel,
    const struct seki_name *name)
{
    size_t index;
    for (index = 0U; index < kernel->parameter_count; index += 1U) {
        if (seki_name_equal(&kernel->parameters[index].label, name)) {
            return &kernel->parameters[index].type;
        }
    }
    return NULL;
}

static const struct seki_type_ref *
find_record_field(const struct checker *checker,
    const struct seki_name *owner, const struct seki_name *field)
{
    const struct seki_type_decl *declaration =
        find_type(checker->module, owner);
    size_t index;
    if (declaration == NULL || declaration->kind != SEKI_DECL_RECORD) {
        return NULL;
    }
    for (index = 0U; index < declaration->value.record.field_count;
        index += 1U) {
        if (seki_name_equal(&declaration->value.record.fields[index].name,
            field)) {
            return &declaration->value.record.fields[index].type;
        }
    }
    return NULL;
}

static int
natural_fits(uint32_t value, uint32_t width)
{
    if (width >= 32U) {
        return 1;
    }
    return value < (UINT32_C(1) << width);
}

static int
types_comparable(const struct inferred_type *left,
    const struct inferred_type *right)
{
    if (left->kind == INFER_UNSIGNED && right->kind == INFER_NATURAL) {
        return natural_fits(right->natural, left->width);
    }
    if (left->kind == INFER_NATURAL && right->kind == INFER_UNSIGNED) {
        return natural_fits(left->natural, right->width);
    }
    if (left->kind != right->kind) {
        return 0;
    }
    if (left->kind == INFER_UNSIGNED) {
        return left->width == right->width;
    }
    if (left->kind == INFER_NAMED) {
        return seki_name_equal(&left->name, &right->name);
    }
    return left->kind != INFER_INVALID;
}

static int
type_is_numeric(const struct inferred_type *type)
{
    return type->kind == INFER_UNSIGNED || type->kind == INFER_NATURAL;
}

static struct inferred_type infer_expression(struct checker *checker,
    uint32_t expression_index);

static struct inferred_type
infer_expression(struct checker *checker, uint32_t expression_index)
{
    struct inferred_type inferred = {INFER_INVALID, 0U, 0U, {NULL, 0U}};
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
        const struct seki_type_ref *type = find_parameter_type(checker->kernel,
            &expression->value.name);
        if (type == NULL) {
            check_fail(checker, "A0-CHECK-0002", "unknown value name");
        } else {
            inferred = infer_type_ref(type);
        }
        break;
    }
    case SEKI_EXPR_BOOL:
        inferred.kind = INFER_BOOL;
        break;
    case SEKI_EXPR_UNIT:
        inferred.kind = INFER_UNIT;
        break;
    case SEKI_EXPR_NATURAL:
        inferred.kind = INFER_NATURAL;
        inferred.natural = expression->value.natural;
        break;
    case SEKI_EXPR_FIELD: {
        const struct inferred_type receiver = infer_expression(checker,
            expression->value.field.receiver);
        const struct seki_type_ref *field_type = NULL;
        if (receiver.kind == INFER_NAMED) {
            field_type = find_record_field(checker, &receiver.name,
                &expression->value.field.field);
        }
        if (field_type == NULL) {
            check_fail(checker, "A0-CHECK-0003",
                "field does not belong to receiver record");
        } else {
            inferred = infer_type_ref(field_type);
        }
        break;
    }
    case SEKI_EXPR_COMPARE: {
        const struct inferred_type left = infer_expression(checker,
            expression->value.compare.left);
        const struct inferred_type right = infer_expression(checker,
            expression->value.compare.right);
        if (!checker->failed && !types_comparable(&left, &right)) {
            check_fail(checker, "A0-CHECK-0004",
                "comparison operands are incompatible");
        } else if (!checker->failed &&
            expression->value.compare.operator <= SEKI_COMPARE_GREATER_EQUAL &&
            (!type_is_numeric(&left) || !type_is_numeric(&right))) {
            check_fail(checker, "A0-CHECK-0004",
                "ordered comparison requires numeric operands");
        } else {
            inferred.kind = INFER_BOOL;
        }
        break;
    }
    default:
        check_fail(checker, "A0-CHECK-0005",
            "kernel control used as a value expression");
        break;
    }
    return inferred;
}

static int
type_matches_argument(const struct inferred_type *type,
    const struct seki_type_arg *argument)
{
    if (argument->kind != SEKI_TYPE_ARG_TYPE_NAME) {
        return 0;
    }
    if (seki_name_is(&argument->name, "Unit")) {
        return type->kind == INFER_UNIT;
    }
    if (seki_name_is(&argument->name, "Bool")) {
        return type->kind == INFER_BOOL;
    }
    return type->kind == INFER_NAMED &&
        seki_name_equal(&type->name, &argument->name);
}

static int
variant_has_item(const struct seki_module_prefix *module,
    const struct seki_variant_ref *reference)
{
    const struct seki_type_decl *declaration =
        find_type(module, &reference->owner);
    size_t index;
    if (declaration == NULL || declaration->kind != SEKI_DECL_VARIANT) {
        return 0;
    }
    for (index = 0U; index < declaration->value.variant.case_count;
        index += 1U) {
        if (seki_name_equal(&declaration->value.variant.cases[index].name,
            &reference->item)) {
            return 1;
        }
    }
    return 0;
}

static int
kernel_declares_rejection(const struct seki_kernel_decl *kernel,
    const struct seki_variant_ref *reference)
{
    size_t index;
    for (index = 0U; index < kernel->rejection_count; index += 1U) {
        if (seki_name_equal(&kernel->rejections[index].owner,
            &reference->owner) &&
            seki_name_equal(&kernel->rejections[index].item,
                &reference->item)) {
            return 1;
        }
    }
    return 0;
}

static void
check_kernel_tail(struct checker *checker, uint32_t expression_index)
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
    if (expression->kind == SEKI_EXPR_ACCEPT) {
        const struct inferred_type value = infer_expression(checker,
            expression->value.accept.value);
        if (!checker->failed && !type_matches_argument(&value,
            &checker->kernel->result.arguments[0])) {
            check_fail(checker, "A0-CHECK-0006",
                "accepted value does not match Decision result");
        }
    } else if (expression->kind == SEKI_EXPR_REJECT) {
        const struct seki_variant_ref *reference =
            &expression->value.rejection;
        if (!seki_name_equal(&reference->owner,
            &checker->kernel->result.arguments[1].name) ||
            !variant_has_item(checker->module, reference)) {
            check_fail(checker, "A0-CHECK-0007",
                "rejection does not belong to Decision result");
        } else if (!kernel_declares_rejection(checker->kernel, reference)) {
            check_fail(checker, "A0-CHECK-0008",
                "rejection is absent from ordered inventory");
        }
    } else if (expression->kind == SEKI_EXPR_IF) {
        const struct inferred_type condition = infer_expression(checker,
            expression->value.conditional.condition);
        if (!checker->failed && condition.kind != INFER_BOOL) {
            check_fail(checker, "A0-CHECK-0009",
                "kernel condition must have type Bool");
        }
        check_kernel_tail(checker, expression->value.conditional.if_true);
        check_kernel_tail(checker, expression->value.conditional.if_false);
    } else {
        check_fail(checker, "A0-CHECK-0010",
            "kernel path lacks terminal accept or reject");
    }
}

static void
check_kernel(struct checker *checker)
{
    if (checker->kernel->result.kind != SEKI_TYPE_APPLIED ||
        !seki_name_is(&checker->kernel->result.name, "Decision") ||
        checker->kernel->result.argument_count != 2U ||
        checker->kernel->result.arguments[0].kind !=
            SEKI_TYPE_ARG_TYPE_NAME ||
        checker->kernel->result.arguments[1].kind !=
            SEKI_TYPE_ARG_TYPE_NAME) {
        check_fail(checker, "A0-CHECK-0011",
            "kernel result must be Decision[A, R]");
        return;
    }
    check_kernel_tail(checker, checker->kernel->body_root);
}

int
seki_check_module(const struct seki_module_prefix *module,
    struct seki_check_error *error)
{
    struct checker checker;
    size_t index;
    if (module == NULL || error == NULL) {
        return 0;
    }
    error->code = "A0-CHECK-0000";
    error->message = "invalid checker state";
    checker.module = module;
    checker.kernel = NULL;
    checker.error = error;
    checker.failed = 0;
    for (index = 0U; index < module->kernel_count && !checker.failed;
        index += 1U) {
        checker.kernel = &module->kernels[index];
        check_kernel(&checker);
    }
    return !checker.failed;
}
