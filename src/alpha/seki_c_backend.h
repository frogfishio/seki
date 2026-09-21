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
    /*
     * The first integer literal the kernel body evaluates, with its SCB-0
     * integer type tag. It is a reporting aid, not a semantic summary: a
     * kernel with several literals has more than one.
     */
    uint64_t first_literal;
    uint8_t first_literal_type;
    int has_literal;
};

/*
 * Projects the typed core to C. With `external_header` nonzero the translation
 * unit includes the module's public header instead of declaring its own types,
 * so the two together compile exactly as the self-contained form does.
 */
int seki_core_to_c(const unsigned char *core, size_t core_length,
    char *c_source, size_t c_capacity, size_t *c_length, int external_header,
    struct seki_backend_error *error);

/* The declarations a consumer integrates against, with an include guard. */
int seki_core_to_header(const unsigned char *core, size_t core_length,
    char *header, size_t capacity, size_t *length,
    struct seki_backend_error *error);

int seki_inspect_core(const unsigned char *core, size_t core_length,
    struct seki_core_inspection *inspection,
    struct seki_backend_error *error);

#endif
