#ifndef SEKI_ALPHA_CHECKER_H
#define SEKI_ALPHA_CHECKER_H

#include "seki_parser.h"
#include "seki_types.h"

struct seki_check_error {
    const char *code;
    const char *message;
};

/*
 * Per-expression elaboration output.
 *
 * The checker is the only component that resolves a surface name. Everything
 * downstream reads the resolution recorded here rather than repeating the
 * lookup, so the typed-core emitter cannot disagree with the checker about what
 * a program means.
 *
 * `type` is the interned claimed type of the expression, or SEKI_TYPE_INVALID
 * for kernel-control nodes, which carry a decision rather than a value. The
 * remaining fields are per-kind resolutions:
 *
 *   SEKI_EXPR_VALUE_NAME  a = environment slot index
 *   SEKI_EXPR_FIELD       a = owner declaration index, b = field index
 *   SEKI_EXPR_REJECT      a = variant declaration index, b = stable tag,
 *                         c = declared precedence index
 */
struct seki_expr_info {
    uint32_t type;
    uint32_t a;
    uint32_t b;
    uint32_t c;
};

struct seki_kernel_elab {
    uint32_t parameter_types[SEKI_CALLABLE_MAX_PARAMETERS];
    size_t parameter_count;
    uint32_t result_type;
    uint32_t accepted_type;
    uint32_t rejection_type;
    struct seki_expr_info expressions[SEKI_KERNEL_MAX_EXPRESSIONS];
    size_t expression_count;
    /* Exact derived bounds from the resource-cost algebra. Admission requires
     * equality with these, so they are derived once here and only transcribed
     * downstream. */
    struct seki_resource_bounds exact;
};

/*
 * Caller-owned elaboration workspace. The checker borrows it for the duration
 * of one module and does not retain it; the host owns its storage so the
 * compiler core imposes no allocation policy of its own.
 */
struct seki_elaboration {
    struct seki_type_table types;
    struct seki_kernel_elab kernels[SEKI_MODULE_MAX_KERNELS];
    size_t kernel_count;
};

int seki_check_module(const struct seki_module_prefix *module,
    struct seki_elaboration *elaboration, struct seki_check_error *error);

#endif
