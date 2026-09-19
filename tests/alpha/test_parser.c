#include <stddef.h>
#include <string.h>

#include "seki_parser.h"

static int
accepts_header(const char *source, struct seki_module_header *header)
{
    struct seki_parse_error error;
    return seki_parse_module_header((const unsigned char *)source,
        strlen(source), header, &error);
}

static int
rejects_header(const char *source, const char *code)
{
    struct seki_module_header header;
    struct seki_parse_error error;
    return !seki_parse_module_header((const unsigned char *)source,
        strlen(source), &header, &error) && strcmp(error.code, code) == 0;
}

int
main(void)
{
    static const char valid[] =
        "module acme::risk @ 7\n"
        "profile: c11_bounded @ 2\n"
        "claims: semantic_evaluation, restricted_c_source\n"
        "requires: totality, determinism.\n"
        "export record Input { age: U8 }.";
    struct seki_module_header header;

    if (!accepts_header(valid, &header)) {
        return 1;
    }
    if (header.path_count != 2U || !seki_name_is(&header.path[0], "acme") ||
        !seki_name_is(&header.path[1], "risk") ||
        header.module_version != 7U || !seki_name_is(&header.profile,
            "c11_bounded") || header.profile_version != 2U ||
        header.claim_count != 2U || header.requirement_count != 2U) {
        return 2;
    }
    if (!rejects_header(
        "module Acme @ 1 profile: p @ 1 claims: c requires: r.",
        "A0-PARSE-0003")) {
        return 3;
    }
    if (!rejects_header(
        "module acme @ 1 profile: p @ 1 claims: c, c requires: r.",
        "A0-PARSE-0007")) {
        return 4;
    }
    if (!rejects_header(
        "module a::b::c::d::e::f::g::h::i @ 1 profile: p @ 1 "
        "claims: c requires: r.", "A0-PARSE-0008")) {
        return 5;
    }
    if (!rejects_header(
        "module acme @ 1 profile: p @ 1 claims: c requires: .",
        "A0-PARSE-0003")) {
        return 6;
    }
    return 0;
}

