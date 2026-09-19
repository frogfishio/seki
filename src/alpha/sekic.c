/*
 * Seki A0 command-line shell.
 *
 * This is provisional bootstrap software with no implementation, proof, or
 * production authority. Compiler commands remain fail-closed until their
 * reusable implementations are connected deliberately.
 */
#include <stdio.h>
#include <string.h>

#define SEKI_A0_VERSION "0.0.0-alpha.1"

enum exit_status {
    EXIT_OK = 0,
    EXIT_USAGE = 64,
    EXIT_UNAVAILABLE = 69
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
unavailable(const char *command)
{
    (void)fprintf(stderr,
        "A0-CLI-0002: %s is not connected in this bootstrap revision\n",
        command);
    return EXIT_UNAVAILABLE;
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
    if (argc >= 2 && command_is(argv[1], "check")) {
        if (argc != 3) {
            print_usage(stderr);
            return EXIT_USAGE;
        }
        return unavailable("check");
    }
    if (argc >= 2 && command_is(argv[1], "build")) {
        if (argc != 7 || !command_is(argv[2], "--core") ||
            !command_is(argv[4], "--c")) {
            print_usage(stderr);
            return EXIT_USAGE;
        }
        return unavailable("build");
    }
    if (argc >= 2 && command_is(argv[1], "inspect")) {
        if (argc != 3) {
            print_usage(stderr);
            return EXIT_USAGE;
        }
        return unavailable("inspect");
    }
    print_usage(stderr);
    return EXIT_USAGE;
}

