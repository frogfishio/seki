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

#define SEKI_A0_VERSION "0.0.0-alpha.6"
#define SEKI_A0_SOURCE_CAPACITY 65536U

/*
 * The parsed module and its elaboration are large fixed-capacity workspaces.
 * The host owns one instance for the whole process and lends it to the
 * compiler core, so no component below `main` carries them on its own frame
 * and the core imposes no allocation policy of its own.
 */
struct seki_workspace {
    struct seki_module_prefix module;
    struct seki_elaboration elaboration;
};

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
        "  sekic build --core OUTPUT.scb0 --c OUTPUT.c --header OUTPUT.h "
        "INPUT.seki\n"
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
compile_source(struct seki_workspace *workspace, const char *path,
    unsigned char *core, size_t *core_length)
{
    unsigned char source[SEKI_A0_SOURCE_CAPACITY];
    size_t source_length = 0U;
    struct seki_parse_error parse_error;
    struct seki_check_error check_error;
    struct seki_core_error core_error;

    if (!read_bounded(path, source, sizeof source, &source_length)) {
        (void)fprintf(stderr,
            "A0-IO-0001:%s: cannot read source within %u-byte limit\n",
            path, (unsigned)sizeof source);
        return EXIT_IO;
    }
    if (!seki_parse_module(source, source_length, &workspace->module,
        &parse_error)) {
        (void)fprintf(stderr, "%s:%s:%zu:%zu: %s\n", parse_error.code,
            path, parse_error.line, parse_error.column, parse_error.message);
        return EXIT_DATA;
    }
    if (!seki_check_module(&workspace->module, &workspace->elaboration,
        &check_error)) {
        (void)fprintf(stderr, "%s:%s: %s\n", check_error.code, path,
            check_error.message);
        return EXIT_DATA;
    }
    if (!seki_emit_core(&workspace->module, &workspace->elaboration, core,
        SEKI_CORE_CAPACITY, core_length, &core_error)) {
        (void)fprintf(stderr, "%s:%s: %s\n", core_error.code, path,
            core_error.message);
        return EXIT_DATA;
    }
    return EXIT_OK;
}

static int
check_command(struct seki_workspace *workspace, const char *input_path)
{
    unsigned char core[SEKI_CORE_CAPACITY];
    size_t core_length = 0U;

    return compile_source(workspace, input_path, core, &core_length);
}

static int
build_command(struct seki_workspace *workspace, const char *input_path,
    const char *core_path, const char *c_path, const char *header_path)
{
    unsigned char core[SEKI_CORE_CAPACITY];
    char c_source[SEKI_C_SOURCE_CAPACITY];
    char header[SEKI_C_SOURCE_CAPACITY];
    size_t core_length = 0U;
    size_t c_length = 0U;
    size_t header_length = 0U;
    struct seki_backend_error backend_error;
    int status;

    if (header_path != NULL && (strcmp(header_path, core_path) == 0 ||
        strcmp(header_path, c_path) == 0 || path_exists(header_path))) {
        (void)fprintf(stderr,
            "A0-IO-0002: output paths must be distinct and not already exist\n");
        return EXIT_IO;
    }
    if (strcmp(core_path, c_path) == 0 || path_exists(core_path) ||
        path_exists(c_path)) {
        (void)fprintf(stderr,
            "A0-IO-0002: output paths must be distinct and not already exist\n");
        return EXIT_IO;
    }
    status = compile_source(workspace, input_path, core, &core_length);
    if (status != EXIT_OK) {
        return status;
    }
    if (header_path != NULL && !seki_core_to_header(core, core_length, header,
        sizeof header, &header_length, &backend_error)) {
        print_backend_error(input_path, &backend_error);
        return EXIT_DATA;
    }
    if (!seki_core_to_c(core, core_length, c_source, sizeof c_source,
        &c_length, header_path != NULL, &backend_error)) {
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
    if (header_path != NULL &&
        !write_new_file(header_path, header, header_length)) {
        (void)remove(core_path);
        (void)remove(c_path);
        (void)fprintf(stderr, "A0-IO-0005:%s: cannot create header output\n",
            header_path);
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
    /*
     * The two boundaries are deliberately reported separately: `check`
     * validates source and typed-core construction, while `build` additionally
     * requires the narrower restricted-C projection. A module can satisfy the
     * first and not yet the second.
     */
    {
        static const char *const integer_names[] = {"u8", "u16", "u32", "u64"};
        (void)printf(
            "frontend=alpha-decision\n"
            "backend=alpha-decision\n"
            "profile=c11_bounded@%u\n",
            (unsigned)inspection.profile_version);
        if (inspection.has_literal && inspection.first_literal_type >= 2U &&
            inspection.first_literal_type <= 5U) {
            (void)printf("first_literal=%llu:%s\n",
                (unsigned long long)inspection.first_literal,
                integer_names[inspection.first_literal_type - 2U]);
        }
        (void)printf("authority=none\n");
    }
    return EXIT_OK;
}

int
main(int argc, char **argv)
{
    static struct seki_workspace host_workspace;
    struct seki_workspace *const workspace = &host_workspace;

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
        return check_command(workspace, argv[2]);
    }
    if (argc == 7 && command_is(argv[1], "build") &&
        command_is(argv[2], "--core") && command_is(argv[4], "--c")) {
        return build_command(workspace, argv[6], argv[3], argv[5], NULL);
    }
    if (argc == 9 && command_is(argv[1], "build") &&
        command_is(argv[2], "--core") && command_is(argv[4], "--c") &&
        command_is(argv[6], "--header")) {
        return build_command(workspace, argv[8], argv[3], argv[5], argv[7]);
    }
    if (argc == 3 && command_is(argv[1], "inspect")) {
        return inspect_command(argv[2]);
    }
    print_usage(stderr);
    return EXIT_USAGE;
}
