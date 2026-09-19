/* Temporary A0 bridge around the immutable E0 frontend regression oracle. */
#include "e0_adapter.h"

int seki_e0_frontend_hidden_main(int argc, char **argv);
#define main seki_e0_frontend_hidden_main
#include "../e0/sekic_e0.c"
#undef main

int
seki_e0_source_to_core(const unsigned char *source, size_t source_length,
    unsigned char *core, size_t core_capacity, size_t *core_length,
    struct seki_e0_diagnostic *diagnostic)
{
    size_t error_line = 1U;
    size_t error_column = 1U;
    const char *reason = "unknown failure";
    struct module module;
    struct buffer output;

    if (source == NULL || core == NULL || core_length == NULL ||
        diagnostic == NULL) {
        return 0;
    }
    diagnostic->code = "A0-INTERNAL-0001";
    diagnostic->message = "invalid E0 adapter argument";
    diagnostic->line = 0U;
    diagnostic->column = 0U;
    diagnostic->offset = 0U;
    if (!parse_source(source, source_length, &module,
        &error_line, &error_column, &reason)) {
        diagnostic->code = "A0-SOURCE-0001";
        diagnostic->message = reason;
        diagnostic->line = error_line;
        diagnostic->column = error_column;
        return 0;
    }
    if (!encode_module(&module, &output) || output.length > core_capacity) {
        diagnostic->code = "A0-INTERNAL-0002";
        diagnostic->message = "candidate typed-core output exceeds capacity";
        return 0;
    }
    memcpy(core, output.bytes, output.length);
    *core_length = output.length;
    return 1;
}

