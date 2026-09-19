#ifndef SEKI_ALPHA_E0_ADAPTER_H
#define SEKI_ALPHA_E0_ADAPTER_H

#include <stddef.h>
#include <stdint.h>

#define SEKI_E0_CORE_CAPACITY 2048U
#define SEKI_E0_C_CAPACITY 4096U

struct seki_e0_diagnostic {
    const char *code;
    const char *message;
    size_t line;
    size_t column;
    size_t offset;
};

struct seki_e0_inspection {
    uint32_t profile_version;
    uint8_t threshold;
};

int seki_e0_source_to_core(const unsigned char *source, size_t source_length,
    unsigned char *core, size_t core_capacity, size_t *core_length,
    struct seki_e0_diagnostic *diagnostic);

int seki_e0_core_to_c(const unsigned char *core, size_t core_length,
    char *c_source, size_t c_capacity, size_t *c_length,
    struct seki_e0_diagnostic *diagnostic);

int seki_e0_inspect_core(const unsigned char *core, size_t core_length,
    struct seki_e0_inspection *inspection,
    struct seki_e0_diagnostic *diagnostic);

#endif

