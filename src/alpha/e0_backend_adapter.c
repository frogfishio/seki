/* Temporary A0 bridge around the immutable E0 backend regression oracle. */
#include "e0_adapter.h"

int seki_e0_backend_hidden_main(int argc, char **argv);
#define main seki_e0_backend_hidden_main
#include "../e0/seki_e0_c_backend.c"
#undef main

int
seki_e0_inspect_core(const unsigned char *core, size_t core_length,
    struct seki_e0_inspection *inspection,
    struct seki_e0_diagnostic *diagnostic)
{
    size_t error_offset = 0U;
    const char *reason = "unknown failure";
    struct rc_module module;

    if (core == NULL || inspection == NULL || diagnostic == NULL) {
        return 0;
    }
    diagnostic->code = "A0-INTERNAL-0001";
    diagnostic->message = "invalid E0 adapter argument";
    diagnostic->line = 0U;
    diagnostic->column = 0U;
    diagnostic->offset = 0U;
    if (!decode_module(core, core_length, &module, &error_offset, &reason)) {
        diagnostic->code = "A0-CORE-0001";
        diagnostic->message = reason;
        diagnostic->offset = error_offset;
        return 0;
    }
    inspection->profile_version = module.profile_version;
    inspection->threshold = module.kernel.condition.literal;
    return 1;
}

int
seki_e0_core_to_c(const unsigned char *core, size_t core_length,
    char *c_source, size_t c_capacity, size_t *c_length,
    struct seki_e0_diagnostic *diagnostic)
{
    size_t error_offset = 0U;
    const char *reason = "unknown failure";
    struct rc_module module;
    struct text_buffer output;

    if (core == NULL || c_source == NULL || c_length == NULL ||
        diagnostic == NULL) {
        return 0;
    }
    diagnostic->code = "A0-INTERNAL-0001";
    diagnostic->message = "invalid E0 adapter argument";
    diagnostic->line = 0U;
    diagnostic->column = 0U;
    diagnostic->offset = 0U;
    if (!decode_module(core, core_length, &module, &error_offset, &reason)) {
        diagnostic->code = "A0-CORE-0001";
        diagnostic->message = reason;
        diagnostic->offset = error_offset;
        return 0;
    }
    if (!print_module(&module, &output) || output.length > c_capacity) {
        diagnostic->code = "A0-INTERNAL-0003";
        diagnostic->message = "restricted-C output exceeds capacity";
        return 0;
    }
    memcpy(c_source, output.bytes, output.length);
    *c_length = output.length;
    return 1;
}

