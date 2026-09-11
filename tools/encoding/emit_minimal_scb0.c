/* Experimental SCB-0 minimal-module fixture emitter. Not a compiler. */
#include <stdint.h>
#include <stdio.h>
#include <string.h>

struct buffer {
    unsigned char bytes[256];
    size_t length;
};

static void
put_u8(struct buffer *buffer, uint8_t value)
{
    buffer->bytes[buffer->length++] = value;
}

static void
put_u32(struct buffer *buffer, uint32_t value)
{
    put_u8(buffer, (uint8_t)(value >> 24));
    put_u8(buffer, (uint8_t)(value >> 16));
    put_u8(buffer, (uint8_t)(value >> 8));
    put_u8(buffer, (uint8_t)value);
}

static void
put_raw(struct buffer *buffer, const unsigned char *bytes, size_t length)
{
    memcpy(buffer->bytes + buffer->length, bytes, length);
    buffer->length += length;
}

static void
put_name(struct buffer *buffer, const char *name)
{
    const size_t length = strlen(name);
    put_u32(buffer, (uint32_t)length);
    put_raw(buffer, (const unsigned char *)name, length);
}

static void
put_empty_sequence(struct buffer *buffer)
{
    put_u32(buffer, UINT32_C(0));
}

static struct buffer
minimal_module_payload(void)
{
    struct buffer payload = {{0}, 0};
    unsigned int index;

    put_u32(&payload, UINT32_C(0));       /* typed-core schema version */
                                            /* LanguageId: zero octets */
    put_u32(&payload, UINT32_C(1));       /* module path component count */
    put_name(&payload, "a");
    put_u32(&payload, UINT32_C(1));       /* module version */
    put_name(&payload, "c11_bounded");
    put_u32(&payload, UINT32_C(1));       /* profile version */

    for (index = 0; index < 5; ++index) { /* imports through kernels */
        put_empty_sequence(&payload);
    }
    for (index = 0; index < 4; ++index) { /* four export vectors */
        put_empty_sequence(&payload);
    }
    put_empty_sequence(&payload);         /* theorem requirements */
    put_empty_sequence(&payload);         /* claim ceiling */

    put_u32(&payload, UINT32_C(0));       /* maximum input bytes */
    put_u32(&payload, UINT32_C(1024));    /* maximum typed-core bytes */
    for (index = 0; index < 9; ++index) { /* remaining module bounds */
        put_u32(&payload, UINT32_C(0));
    }

    put_u32(&payload, UINT32_C(0));       /* derivation schema version */
    put_empty_sequence(&payload);         /* type dependency order */
    put_empty_sequence(&payload);         /* function dependency order */
    return payload;
}

int
main(void)
{
    static const unsigned char magic[] = {'S', 'E', 'K', 'I'};
    const struct buffer payload = minimal_module_payload();
    struct buffer module = {{0}, 0};

    put_raw(&module, magic, sizeof magic);
    put_u32(&module, UINT32_C(0));        /* SCB schema version */
    put_u8(&module, UINT8_C(0));          /* module object kind */
    put_u32(&module, (uint32_t)payload.length);
    put_raw(&module, payload.bytes, payload.length);

    if (fwrite(module.bytes, 1, module.length, stdout) != module.length) {
        return 1;
    }
    return 0;
}

