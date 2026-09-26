#ifndef SEKI_ALPHA_CORE_H
#define SEKI_ALPHA_CORE_H

#include <stddef.h>

#include "seki_checker.h"
#include "seki_parser.h"

#define SEKI_CORE_CAPACITY 65536U

struct seki_core_error {
    const char *code;
    const char *message;
};

/*
 * Constructs the candidate typed core from a checked module.
 *
 * The emitter never re-resolves a surface name: every type, local slot, field
 * position, variant tag, and precedence index comes from the elaboration the
 * checker produced. It borrows the elaboration mutably because canonical type
 * values are interned on demand while encoding.
 */
int seki_emit_core(const struct seki_module_prefix *module,
    struct seki_elaboration *elaboration, unsigned char *output,
    size_t capacity, size_t *output_length, struct seki_core_error *error);

#endif
