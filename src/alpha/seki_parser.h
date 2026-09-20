#ifndef SEKI_ALPHA_PARSER_H
#define SEKI_ALPHA_PARSER_H

#include <stddef.h>
#include <stdint.h>

#define SEKI_HEADER_MAX_PATH_COMPONENTS 8U
#define SEKI_HEADER_MAX_CLAIMS 16U
#define SEKI_HEADER_MAX_REQUIREMENTS 16U
#define SEKI_MODULE_MAX_DECLARATIONS 32U
#define SEKI_RECORD_MAX_FIELDS 32U
#define SEKI_VARIANT_MAX_CASES 32U
#define SEKI_VARIANT_MAX_PAYLOAD_FIELDS 8U
#define SEKI_TYPE_MAX_ARGUMENTS 4U
#define SEKI_MODULE_MAX_KERNELS 16U
#define SEKI_CALLABLE_MAX_PARAMETERS 16U
#define SEKI_KERNEL_MAX_REJECTIONS 32U
#define SEKI_KERNEL_MAX_EXPRESSIONS 256U

/*
 * Syntactic nesting ceiling, matching `maximum_nesting` in the
 * `c11_bounded @ 1` profile. Recursive descent is bounded by this rather than
 * by the host stack: a source nested more deeply than admission would accept
 * is rejected while parsing instead of exhausting the stack.
 */
#define SEKI_MAX_NESTING 256U

struct seki_name {
    const unsigned char *bytes;
    size_t length;
};

struct seki_module_header {
    struct seki_name path[SEKI_HEADER_MAX_PATH_COMPONENTS];
    size_t path_count;
    uint32_t module_version;
    struct seki_name profile;
    uint32_t profile_version;
    struct seki_name claims[SEKI_HEADER_MAX_CLAIMS];
    size_t claim_count;
    struct seki_name requirements[SEKI_HEADER_MAX_REQUIREMENTS];
    size_t requirement_count;
};

struct seki_parse_error {
    const char *code;
    const char *message;
    size_t line;
    size_t column;
};

enum seki_type_ref_kind {
    SEKI_TYPE_NAMED,
    SEKI_TYPE_BYTES,
    SEKI_TYPE_DIGEST,
    SEKI_TYPE_APPLIED
};

enum seki_type_arg_kind {
    SEKI_TYPE_ARG_TYPE_NAME,
    SEKI_TYPE_ARG_VALUE_NAME,
    SEKI_TYPE_ARG_NUMBER
};

struct seki_type_arg {
    enum seki_type_arg_kind kind;
    struct seki_name name;
    uint32_t number;
};

struct seki_type_ref {
    enum seki_type_ref_kind kind;
    struct seki_name name;
    struct seki_name algorithm;
    uint32_t length;
    struct seki_type_arg arguments[SEKI_TYPE_MAX_ARGUMENTS];
    size_t argument_count;
};

struct seki_field_decl {
    struct seki_name name;
    struct seki_type_ref type;
};

struct seki_record_decl {
    struct seki_field_decl fields[SEKI_RECORD_MAX_FIELDS];
    size_t field_count;
};

struct seki_variant_case {
    struct seki_name name;
    uint32_t tag;
    struct seki_field_decl payload[SEKI_VARIANT_MAX_PAYLOAD_FIELDS];
    size_t payload_count;
};

struct seki_variant_decl {
    struct seki_variant_case cases[SEKI_VARIANT_MAX_CASES];
    size_t case_count;
};

enum seki_type_decl_kind {
    SEKI_DECL_ALIAS,
    SEKI_DECL_NOMINAL,
    SEKI_DECL_RECORD,
    SEKI_DECL_VARIANT
};

struct seki_type_decl {
    enum seki_type_decl_kind kind;
    struct seki_name name;
    union {
        struct seki_type_ref target;
        struct seki_record_decl record;
        struct seki_variant_decl variant;
    } value;
};

struct seki_parameter_decl {
    struct seki_name label;
    struct seki_type_ref type;
};

struct seki_resource_bounds {
    uint32_t steps;
    uint32_t live_bits;
    uint32_t control_depth;
    uint32_t workspace_bits;
};

struct seki_variant_ref {
    struct seki_name owner;
    struct seki_name item;
};

enum seki_expression_kind {
    SEKI_EXPR_VALUE_NAME,
    SEKI_EXPR_BOOL,
    SEKI_EXPR_UNIT,
    SEKI_EXPR_NATURAL,
    SEKI_EXPR_FIELD,
    SEKI_EXPR_COMPARE,
    SEKI_EXPR_AND,
    SEKI_EXPR_OR,
    SEKI_EXPR_ACCEPT,
    SEKI_EXPR_REJECT,
    SEKI_EXPR_IF
};

enum seki_compare_operator {
    SEKI_COMPARE_LESS,
    SEKI_COMPARE_LESS_EQUAL,
    SEKI_COMPARE_GREATER,
    SEKI_COMPARE_GREATER_EQUAL,
    SEKI_COMPARE_EQUAL,
    SEKI_COMPARE_NOT_EQUAL
};

struct seki_expression {
    enum seki_expression_kind kind;
    union {
        struct seki_name name;
        int boolean;
        uint32_t natural;
        struct {
            uint32_t receiver;
            struct seki_name field;
        } field;
        struct {
            enum seki_compare_operator operator;
            uint32_t left;
            uint32_t right;
        } compare;
        struct {
            uint32_t left;
            uint32_t right;
        } logical;
        struct {
            uint32_t value;
        } accept;
        struct seki_variant_ref rejection;
        struct {
            uint32_t condition;
            uint32_t if_true;
            uint32_t if_false;
        } conditional;
    } value;
};

struct seki_kernel_decl {
    struct seki_name name;
    struct seki_parameter_decl parameters[SEKI_CALLABLE_MAX_PARAMETERS];
    size_t parameter_count;
    struct seki_type_ref result;
    struct seki_name arithmetic_policy;
    struct seki_resource_bounds bounds;
    struct seki_variant_ref rejections[SEKI_KERNEL_MAX_REJECTIONS];
    size_t rejection_count;
    int publication_eligible;
    struct seki_expression expressions[SEKI_KERNEL_MAX_EXPRESSIONS];
    size_t expression_count;
    uint32_t body_root;
};

struct seki_module_prefix {
    struct seki_module_header header;
    struct seki_type_decl declarations[SEKI_MODULE_MAX_DECLARATIONS];
    size_t declaration_count;
    struct seki_kernel_decl kernels[SEKI_MODULE_MAX_KERNELS];
    size_t kernel_count;
};

int seki_parse_module_header(const unsigned char *source, size_t length,
    struct seki_module_header *header, struct seki_parse_error *error);

int seki_parse_module(const unsigned char *source, size_t length,
    struct seki_module_prefix *module, struct seki_parse_error *error);

int seki_name_equal(const struct seki_name *left,
    const struct seki_name *right);

int seki_name_is(const struct seki_name *name, const char *text);

#endif
