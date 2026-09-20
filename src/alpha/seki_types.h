#ifndef SEKI_ALPHA_TYPES_H
#define SEKI_ALPHA_TYPES_H

#include <stddef.h>
#include <stdint.h>

#include "seki_parser.h"

/*
 * Resolved alpha value types.
 *
 * A resolved type is interned once per module, so two identical types share one
 * identifier and exact normalized identity is an integer comparison. The `kind`
 * field deliberately carries the SCB-0 `Type` discriminant rather than a private
 * enumeration: the core emitter writes it directly, and a divergence between
 * this table and the schema ledger becomes a compile-time constant mismatch
 * instead of a silent encoding bug.
 */
#define SEKI_TYPE_TABLE_CAPACITY 128U
#define SEKI_TYPE_INVALID UINT32_MAX

enum seki_type_kind {
    SEKI_T_UNIT = 0U,
    SEKI_T_BOOL = 1U,
    SEKI_T_U8 = 2U,
    SEKI_T_U16 = 3U,
    SEKI_T_U32 = 4U,
    SEKI_T_U64 = 5U,
    SEKI_T_BYTES = 11U,
    SEKI_T_DIGEST = 13U,
    SEKI_T_DECISION = 19U,
    SEKI_T_DECLARED = 21U
};

struct seki_type {
    uint32_t kind;
    /*
     * `a` carries the byte length for Bytes/Digest, the module declaration
     * index for Declared, and the accepted type identifier for Decision.
     * `b` carries the rejection type identifier for Decision and is zero
     * elsewhere.
     */
    uint32_t a;
    uint32_t b;
};

struct seki_type_table {
    struct seki_type entries[SEKI_TYPE_TABLE_CAPACITY];
    size_t count;
};

void seki_type_table_init(struct seki_type_table *table);

/* Returns SEKI_TYPE_INVALID when the fixed table capacity is exhausted. */
uint32_t seki_type_intern(struct seki_type_table *table, uint32_t kind,
    uint32_t a, uint32_t b);

/*
 * Resolves one surface type reference against the module's declarations.
 * Returns SEKI_TYPE_INVALID for unknown names and forms outside the alpha
 * subset; the caller owns the diagnostic.
 */
uint32_t seki_type_resolve(const struct seki_module_prefix *module,
    struct seki_type_table *table, const struct seki_type_ref *reference);

/* Expands aliases and nominals to the underlying representation identifier. */
uint32_t seki_type_expand(const struct seki_module_prefix *module,
    struct seki_type_table *table, uint32_t type);

/*
 * Canonical semantic width from the resource-cost algebra. Returns zero on
 * checked-arithmetic overflow or an unresolvable declaration, which the caller
 * reports as a bound failure rather than emitting an inadmissible module.
 */
int seki_type_value_bits(const struct seki_module_prefix *module,
    struct seki_type_table *table, uint32_t type, uint32_t *bits);

int seki_checked_add(uint32_t left, uint32_t right, uint32_t *result);
int seki_checked_mul(uint32_t left, uint32_t right, uint32_t *result);
uint32_t seki_tag_bits(uint32_t tag);

#endif
