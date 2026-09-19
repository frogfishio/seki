#ifndef SEKI_ALPHA_CORE_H
#define SEKI_ALPHA_CORE_H

#include <stddef.h>

#include "seki_parser.h"

#define SEKI_CORE_CAPACITY 2048U

struct seki_core_error {
    const char *code;
    const char *message;
};

int seki_emit_core(const struct seki_module_prefix *module,
    unsigned char *output, size_t capacity, size_t *output_length,
    struct seki_core_error *error);

#endif
