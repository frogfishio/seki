#ifndef SEKI_ALPHA_PARSER_H
#define SEKI_ALPHA_PARSER_H

#include <stddef.h>
#include <stdint.h>

#define SEKI_HEADER_MAX_PATH_COMPONENTS 8U
#define SEKI_HEADER_MAX_CLAIMS 16U
#define SEKI_HEADER_MAX_REQUIREMENTS 16U

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

int seki_parse_module_header(const unsigned char *source, size_t length,
    struct seki_module_header *header, struct seki_parse_error *error);

int seki_name_equal(const struct seki_name *left,
    const struct seki_name *right);

int seki_name_is(const struct seki_name *name, const char *text);

#endif

