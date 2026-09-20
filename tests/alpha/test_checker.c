#include <stdint.h>
#include <string.h>

#include "seki_checker.h"
#include "seki_parser.h"

#define TEST_PREFIX \
    "module a @ 1 profile: p @ 1 claims: c requires: r. " \
    "export record Applicant { age: U8 }. " \
    "export variant Rejection [ Underage @ 1. Other @ 2. ]. "

#define KERNEL_PREFIX \
    "export kernel decide applicant: Applicant " \
    "-> Decision[Unit, Rejection] arithmetic: checked " \
    "bounded steps: 32 liveBits: 256 controlDepth: 16 workspaceBits: 0 "

static struct seki_module_prefix module;
static struct seki_elaboration elaboration;

static int
check_source(const char *source, const char *expected_code)
{
    struct seki_parse_error parse_error;
    struct seki_check_error check_error;
    if (!seki_parse_module((const unsigned char *)source,
        strlen(source), &module, &parse_error)) {
        return 0;
    }
    if (expected_code == NULL) {
        return seki_check_module(&module, &elaboration, &check_error);
    }
    return !seki_check_module(&module, &elaboration, &check_error) &&
        strcmp(check_error.code, expected_code) == 0;
}

/* The derived exact bounds are the checker's own conclusion, so a positive
 * case pins them rather than only asserting that checking succeeded. */
static int
exact_bounds_are(uint32_t steps, uint32_t live, uint32_t depth,
    uint32_t workspace)
{
    const struct seki_resource_bounds *exact = &elaboration.kernels[0].exact;
    return exact->steps == steps && exact->live_bits == live &&
        exact->control_depth == depth && exact->workspace_bits == workspace;
}

int
main(void)
{
    static const char valid[] = TEST_PREFIX KERNEL_PREFIX
        "rejects: Rejection::Underage publication: none [ "
        "(applicant age) < 18 "
        "ifTrue: [ reject Rejection::Underage ] "
        "ifFalse: [ accept unit ] ].";
    static const char unknown_field[] = TEST_PREFIX KERNEL_PREFIX
        "rejects: Rejection::Underage publication: none [ "
        "(applicant missing) < 18 "
        "ifTrue: [ reject Rejection::Underage ] "
        "ifFalse: [ accept unit ] ].";
    static const char wide_literal[] = TEST_PREFIX KERNEL_PREFIX
        "rejects: Rejection::Underage publication: none [ "
        "(applicant age) < 256 "
        "ifTrue: [ reject Rejection::Underage ] "
        "ifFalse: [ accept unit ] ].";
    static const char wrong_accept[] = TEST_PREFIX KERNEL_PREFIX
        "rejects: Rejection::Underage publication: none [ accept 1 ].";
    static const char undeclared_rejection[] = TEST_PREFIX KERNEL_PREFIX
        "rejects: Rejection::Underage publication: none [ "
        "reject Rejection::Other ].";
    static const char non_boolean_condition[] = TEST_PREFIX KERNEL_PREFIX
        "rejects: Rejection::Underage publication: none [ "
        "1 ifTrue: [ reject Rejection::Underage ] "
        "ifFalse: [ accept unit ] ].";
    /* Exactly the derived ceiling, which must be admitted. */
    static const char exact_ceiling[] = TEST_PREFIX
        "export kernel decide applicant: Applicant "
        "-> Decision[Unit, Rejection] arithmetic: checked "
        "bounded steps: 8 liveBits: 25 controlDepth: 5 workspaceBits: 0 "
        "rejects: Rejection::Underage publication: none [ "
        "(applicant age) < 18 "
        "ifTrue: [ reject Rejection::Underage ] "
        "ifFalse: [ accept unit ] ].";
    /* One logical step below the derived exact bound. */
    static const char low_ceiling[] = TEST_PREFIX
        "export kernel decide applicant: Applicant "
        "-> Decision[Unit, Rejection] arithmetic: checked "
        "bounded steps: 7 liveBits: 25 controlDepth: 5 workspaceBits: 0 "
        "rejects: Rejection::Underage publication: none [ "
        "(applicant age) < 18 "
        "ifTrue: [ reject Rejection::Underage ] "
        "ifFalse: [ accept unit ] ].";
    static const char unknown_type[] =
        "module a @ 1 profile: p @ 1 claims: c requires: r. "
        "export record Applicant { age: Missing }. "
        "export variant Rejection [ Underage @ 1. ]. " KERNEL_PREFIX
        "rejects: Rejection::Underage publication: none [ "
        "accept unit ].";

    if (!check_source(valid, NULL)) {
        return 1;
    }
    if (!check_source(unknown_field, "A0-CHECK-0003")) {
        return 2;
    }
    if (!check_source(wide_literal, "A0-CHECK-0004")) {
        return 3;
    }
    if (!check_source(wrong_accept, "A0-CHECK-0006")) {
        return 4;
    }
    if (!check_source(undeclared_rejection, "A0-CHECK-0008")) {
        return 5;
    }
    if (!check_source(non_boolean_condition, "A0-CHECK-0009")) {
        return 6;
    }
    if (!check_source(valid, NULL) || !exact_bounds_are(8U, 25U, 5U, 0U)) {
        return 7;
    }
    if (!check_source(exact_ceiling, NULL)) {
        return 8;
    }
    if (!check_source(low_ceiling, "A0-CHECK-0017")) {
        return 9;
    }
    if (!check_source(unknown_type, "A0-CHECK-0012")) {
        return 10;
    }
    return 0;
}
