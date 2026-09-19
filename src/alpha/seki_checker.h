#ifndef SEKI_ALPHA_CHECKER_H
#define SEKI_ALPHA_CHECKER_H

#include "seki_parser.h"

struct seki_check_error {
    const char *code;
    const char *message;
};

int seki_check_module(const struct seki_module_prefix *module,
    struct seki_check_error *error);

#endif
