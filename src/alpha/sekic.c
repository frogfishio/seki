/*
 * Seki A0 command-line shell.
 *
 * Provisional bootstrap software with no implementation, proof, or production
 * authority. The connected frontend and backend implement the alpha
 * minimum-age semantic slice. A0-02 remains open until the complete general
 * compiler core replaces that narrow path.
 */
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "seki_c_backend.h"
#include "seki_checker.h"
#include "seki_core.h"
#include "seki_parser.h"

#define SEKI_A0_VERSION "0.0.0-alpha.5"
#define SEKI_A0_SOURCE_CAPACITY 65536U

enum exit_status {
    EXIT_OK = 0,
    EXIT_USAGE = 64,
    EXIT_DATA = 65,
    EXIT_INTERNAL = 70,
    EXIT_IO = 74
};

static void
print_usage(FILE *stream)
{
    (void)fprintf(stream,
        "usage:\n"
        "  sekic --version\n"
        "  sekic check INPUT.seki\n"
        "  sekic build --core OUTPUT.scb0 --c OUTPUT.c INPUT.seki\n"
        "  sekic inspect INPUT.scb0\n");
}

static int
command_is(const char *argument, const char *expected)
{
    return strcmp(argument, expected) == 0;
}

static int
read_bounded(const char *path, unsigned char *bytes, size_t capacity,
    size_t *length)
{
    FILE *file = fopen(path, "rb");
    size_t count;
    int extra;

    if (file == NULL) {
        return 0;
    }
    count = fread(bytes, 1U, capacity, file);
    if (ferror(file)) {
        (void)fclose(file);
        return 0;
    }
    extra = fgetc(file);
    if (extra != EOF || fclose(file) != 0) {
        return 0;
    }
    *length = count;
    return 1;
}

static int
path_exists(const char *path)
{
    FILE *file = fopen(path, "rb");
    if (file == NULL) {
        return 0;
    }
    (void)fclose(file);
    return 1;
}

static int
write_new_file(const char *path, const void *bytes, size_t length)
{
    FILE *file;
    int ok;

    if (path_exists(path)) {
        return 0;
    }
    file = fopen(path, "wb");
    if (file == NULL) {
        return 0;
    }
    ok = fwrite(bytes, 1U, length, file) == length;
    if (fclose(file) != 0) {
        ok = 0;
    }
    if (!ok) {
        (void)remove(path);
    }
    return ok;
}

static void
print_backend_error(const char *path, const struct seki_backend_error *error)
{
    (void)fprintf(stderr, "%s:%s:%zu: %s\n", error->code, path,
        error->offset, error->message);
}

static int
compile_source(const char *path, unsigned char *core, size_t *core_length)
{
    unsigned char source[SEKI_A0_SOURCE_CAPACITY];
    size_t source_length = 0U;
    struct seki_module_prefix module;
    struct seki_parse_error parse_error;
    struct seki_check_error check_error;
    struct seki_core_error core_error;

    if (!read_bounded(path, source, sizeof source, &source_length)) {
        (void)fprintf(stderr,
            "A0-IO-0001:%s: cannot read source within %u-byte limit\n",
            path, (unsigned)sizeof source);
        return EXIT_IO;
    }
    if (!seki_parse_module(source, source_length, &module,
        &parse_error)) {
        (void)fprintf(stderr, "%s:%s:%zu:%zu: %s\n", parse_error.code,
            path, parse_error.line, parse_error.column, parse_error.message);
        return EXIT_DATA;
    }
    if (!seki_check_module(&module, &check_error)) {
        (void)fprintf(stderr, "%s:%s: %s\n", check_error.code, path,
            check_error.message);
        return EXIT_DATA;
    }
    if (!seki_emit_core(&module, core, SEKI_CORE_CAPACITY, core_length,
        &core_error)) {
        (void)fprintf(stderr, "%s:%s: %s\n", core_error.code, path,
            core_error.message);
        return EXIT_DATA;
    }
    return EXIT_OK;
}

static int
check_command(const char *input_path)
{
    unsigned char core[SEKI_CORE_CAPACITY];
    size_t core_length = 0U;

    return compile_source(input_path, core, &core_length);
}

static int
build_command(const char *input_path, const char *core_path,
    const char *c_path)
{
    unsigned char core[SEKI_CORE_CAPACITY];
    char c_source[SEKI_C_SOURCE_CAPACITY];
    size_t core_length = 0U;
    size_t c_length = 0U;
    struct seki_backend_error backend_error;
    int status;

    if (strcmp(core_path, c_path) == 0 || path_exists(core_path) ||
        path_exists(c_path)) {
        (void)fprintf(stderr,
            "A0-IO-0002: output paths must be distinct and not already exist\n");
        return EXIT_IO;
    }
    status = compile_source(input_path, core, &core_length);
    if (status != EXIT_OK) {
        return status;
    }
    if (!seki_core_to_c(core, core_length, c_source, sizeof c_source,
        &c_length, &backend_error)) {
        print_backend_error(input_path, &backend_error);
        return strcmp(backend_error.code, "A0-BACKEND-0002") == 0 ?
            EXIT_INTERNAL : EXIT_DATA;
    }
    if (!write_new_file(core_path, core, core_length)) {
        (void)fprintf(stderr, "A0-IO-0003:%s: cannot create core output\n",
            core_path);
        return EXIT_IO;
    }
    if (!write_new_file(c_path, c_source, c_length)) {
        (void)remove(core_path);
        (void)fprintf(stderr, "A0-IO-0004:%s: cannot create C output\n",
            c_path);
        return EXIT_IO;
    }
    return EXIT_OK;
}

static int
inspect_command(const char *input_path)
{
    unsigned char core[SEKI_CORE_CAPACITY];
    size_t core_length = 0U;
    struct seki_backend_error backend_error;
    struct seki_core_inspection inspection;

    if (!read_bounded(input_path, core, sizeof core, &core_length)) {
        (void)fprintf(stderr,
            "A0-IO-0001:%s: cannot read core within %u-byte limit\n",
            input_path, (unsigned)sizeof core);
        return EXIT_IO;
    }
    if (!seki_inspect_core(core, core_length, &inspection, &backend_error)) {
        print_backend_error(input_path, &backend_error);
        return EXIT_DATA;
    }
    (void)printf(
        "frontend=alpha-u8-decision\n"
        "backend=alpha-u8-decision\n"
        "profile=c11_bounded@%u\n"
        "threshold_u8=%u\n"
        "authority=none\n",
        (unsigned)inspection.profile_version, (unsigned)inspection.threshold);
    return EXIT_OK;
}

int
main(int argc, char **argv)
{
    if (argc == 2 && command_is(argv[1], "--version")) {
        (void)printf("sekic %s (provisional, authority=none)\n",
            SEKI_A0_VERSION);
        return EXIT_OK;
    }
    if (argc == 2 && command_is(argv[1], "--help")) {
        print_usage(stdout);
        return EXIT_OK;
    }
    if (argc == 3 && command_is(argv[1], "check")) {
        return check_command(argv[2]);
    }
    if (argc == 7 && command_is(argv[1], "build") &&
        command_is(argv[2], "--core") && command_is(argv[4], "--c")) {
        return build_command(argv[6], argv[3], argv[5]);
    }
    if (argc == 3 && command_is(argv[1], "inspect")) {
        return inspect_command(argv[2]);
    }
    print_usage(stderr);
    return EXIT_USAGE;
}
