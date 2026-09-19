#ifndef SEKI_ALPHA_C_BACKEND_H
#define SEKI_ALPHA_C_BACKEND_H

#include <stddef.h>
#include <stdint.h>

#define SEKI_C_SOURCE_CAPACITY 4096U

struct seki_backend_error {
    const char *code;
    const char *message;
    size_t offset;
};

struct seki_core_inspection {
    uint32_t profile_version;
    uint8_t threshold;
};

int seki_core_to_c(const unsigned char *core, size_t core_length,
    char *c_source, size_t c_capacity, size_t *c_length,
    struct seki_backend_error *error);

int seki_inspect_core(const unsigned char *core, size_t core_length,
    struct seki_core_inspection *inspection,
    struct seki_backend_error *error);

#endif
