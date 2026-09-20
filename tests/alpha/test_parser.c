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

static int
rejects_module(const char *source, const char *code)
{
    struct seki_module_prefix module;
    struct seki_parse_error error;
    return !seki_parse_module((const unsigned char *)source,
        strlen(source), &module, &error) && strcmp(error.code, code) == 0;
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
    struct seki_module_prefix module;
    struct seki_parse_error error;

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
    if (!seki_parse_module((const unsigned char *)valid,
        strlen(valid), &module, &error) || module.declaration_count != 1U ||
        module.declarations[0].kind != SEKI_DECL_RECORD ||
        !seki_name_is(&module.declarations[0].name, "Input") ||
        module.declarations[0].value.record.field_count != 1U ||
        !seki_name_is(&module.declarations[0].value.record.fields[0].name,
            "age") || !seki_name_is(
                &module.declarations[0].value.record.fields[0].type.name,
                "U8")) {
        return 7;
    }
    {
        static const char declarations[] =
            "module acme @ 1 profile: p @ 1 claims: c requires: r. "
            "export type Digest256 := Digest[sha256, 32]. "
            "export nominal Epoch := U64. "
            "export record Receipt { hash: Digest[sha256, 32], raw: Bytes[8] }. "
            "export variant Result [ Ok(value: U32) @ 1. Bad @ 2. ]. "
            "export kernel decide receipt: Receipt "
            "-> Decision[Unit, Result] arithmetic: checked "
            "bounded steps: 8 liveBits: 64 controlDepth: 4 workspaceBits: 0 "
            "rejects: Result::Bad publication: none "
            "[ (receipt raw) == (receipt raw) "
            "ifTrue: [ accept unit ] ifFalse: [ reject Result::Bad ] ].";
        if (!seki_parse_module((const unsigned char *)declarations,
            strlen(declarations), &module, &error) ||
            module.declaration_count != 4U ||
            module.declarations[0].kind != SEKI_DECL_ALIAS ||
            module.declarations[0].value.target.kind != SEKI_TYPE_DIGEST ||
            module.declarations[0].value.target.length != 32U ||
            module.declarations[1].kind != SEKI_DECL_NOMINAL ||
            !seki_name_is(&module.declarations[1].value.target.name, "U64") ||
            module.declarations[2].value.record.field_count != 2U ||
            module.declarations[2].value.record.fields[0].type.kind !=
                SEKI_TYPE_DIGEST ||
            module.declarations[2].value.record.fields[0].type.length != 32U ||
            module.declarations[3].value.variant.case_count != 2U ||
            module.declarations[3].value.variant.cases[0].payload_count != 1U ||
            module.kernel_count != 1U ||
            !seki_name_is(&module.kernels[0].name, "decide") ||
            module.kernels[0].parameter_count != 1U ||
            module.kernels[0].result.kind != SEKI_TYPE_APPLIED ||
            module.kernels[0].result.argument_count != 2U ||
            module.kernels[0].bounds.steps != 8U ||
            module.kernels[0].rejection_count != 1U ||
            module.kernels[0].publication_eligible != 0 ||
            module.kernels[0].expression_count != 9U ||
            module.kernels[0].expressions[
                module.kernels[0].body_root].kind != SEKI_EXPR_IF ||
            module.kernels[0].expressions[
                module.kernels[0].expressions[
                    module.kernels[0].body_root].value.conditional.condition
                ].kind != SEKI_EXPR_COMPARE) {
            return 8;
        }
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
    {
        static const char duplicate_field[] =
            "module a @ 1 profile: p @ 1 claims: c requires: r. "
            "export record R { x: U8, x: U16 }.";
        if (seki_parse_module((const unsigned char *)duplicate_field,
            strlen(duplicate_field), &module, &error) ||
            strcmp(error.code, "A0-PARSE-0011") != 0) {
            return 9;
        }
    }
    {
        static const char duplicate_case[] =
            "module a @ 1 profile: p @ 1 claims: c requires: r. "
            "export variant V [ A @ 1. B @ 1. ].";
        if (seki_parse_module((const unsigned char *)duplicate_case,
            strlen(duplicate_case), &module, &error) ||
            strcmp(error.code, "A0-PARSE-0015") != 0) {
            return 10;
        }
    }
    if (!rejects_module(
        "module a @ 1 profile: p @ 1 claims: c requires: r. "
        "export variant R [ Bad @ 1. ]. "
        "export kernel k -> Decision[Unit, R] arithmetic: magical "
        "bounded steps: 1 liveBits: 1 controlDepth: 1 workspaceBits: 0 "
        "rejects: R::Bad publication: none [ reject R::Bad ].",
        "A0-PARSE-0025")) {
        return 11;
    }
    if (!rejects_module(
        "module a @ 1 profile: p @ 1 claims: c requires: r. "
        "export variant R [ Bad @ 1. ]. "
        "export kernel k -> Decision[Unit, R] arithmetic: checked "
        "bounded steps: 1 liveBits: 1 controlDepth: 1 workspaceBits: 0 "
        "rejects: R::Bad publication: none [ accept ].",
        "A0-PARSE-0031")) {
        return 12;
    }
    if (!rejects_module(
        "module a @ 1 profile: p @ 1 claims: c requires: r. trailing",
        "A0-PARSE-0034")) {
        return 13;
    }
    /*
     * Stack-exhaustion regressions, both found by source mutation fuzzing
     * under AddressSanitizer.
     *
     * Deeply nested parentheses consume no expression-arena slot per level, so
     * before the nesting ceiling existed they recursed until the host stack was
     * gone.
     */
    {
        static char deep[8192];
        const size_t depth = 2000U;
        size_t index;
        size_t at = 0U;
        static const char head[] =
            "module a @ 1 profile: p @ 1 claims: c requires: r. "
            "export variant R [ Bad @ 1. ]. "
            "export kernel k -> Decision[Unit, R] arithmetic: checked "
            "bounded steps: 1 liveBits: 1 controlDepth: 1 workspaceBits: 0 "
            "rejects: R::Bad publication: none [ accept ";
        memcpy(deep, head, sizeof head - 1U);
        at = sizeof head - 1U;
        for (index = 0U; index < depth && at < sizeof deep - 1U; index += 1U) {
            deep[at++] = '(';
        }
        deep[at] = '\0';
        if (!rejects_module(deep, "A0-PARSE-0035")) {
            return 14;
        }
    }
    /*
     * A lexer failure leaves the parser's current token stale. A stale `ifTrue`
     * used to drive the conditional production forever; the original lexer
     * diagnostic must survive instead.
     */
    if (!rejects_module(
        "module a @ 1 profile: p @ 1 claims: c requires: r. "
        "export record D { v: U8 }. "
        "export variant R [ Bad @ 1. ]. "
        "export kernel k d: D -> Decision[Unit, R] arithmetic: checked "
        "bounded steps: 1 liveBits: 1 controlDepth: 1 workspaceBits: 0 "
        "rejects: R::Bad publication: none [ (d v) < 18 "
        "ifTrue\x01 [ reject R::Bad ] ifFalse: [ accept unit ] ].",
        "A0-LEX-0003")) {
        return 15;
    }
    return 0;
}
