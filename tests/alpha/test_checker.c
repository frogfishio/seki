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

static int
check_source(const char *source, const char *expected_code)
{
    struct seki_module_prefix module;
    struct seki_parse_error parse_error;
    struct seki_check_error check_error;
    if (!seki_parse_module((const unsigned char *)source,
        strlen(source), &module, &parse_error)) {
        return 0;
    }
    if (expected_code == NULL) {
        return seki_check_module(&module, &check_error);
    }
    return !seki_check_module(&module, &check_error) &&
        strcmp(check_error.code, expected_code) == 0;
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
    return 0;
}
