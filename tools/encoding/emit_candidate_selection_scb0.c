/* Experimental SCB-0 candidate-selection fixture emitter. Not a compiler. */
#include <stdint.h>
#include <stdio.h>
#include <string.h>

struct buffer {
    unsigned char bytes[4096];
    size_t length;
    int failed;
};

typedef void (*type_emitter)(struct buffer *);

static void
put_raw(struct buffer *buffer, const unsigned char *bytes, size_t length)
{
    if (length > sizeof buffer->bytes - buffer->length) {
        buffer->failed = 1;
        return;
    }
    memcpy(buffer->bytes + buffer->length, bytes, length);
    buffer->length += length;
}

static void
put_u8(struct buffer *buffer, uint8_t value)
{
    put_raw(buffer, &value, 1);
}

static void
put_u32(struct buffer *buffer, uint32_t value)
{
    const unsigned char bytes[4] = {
        (unsigned char)(value >> 24), (unsigned char)(value >> 16),
        (unsigned char)(value >> 8), (unsigned char)value
    };
    put_raw(buffer, bytes, sizeof bytes);
}

static void
put_name(struct buffer *buffer, const char *value)
{
    const size_t length = strlen(value);
    put_u32(buffer, (uint32_t)length);
    put_raw(buffer, (const unsigned char *)value, length);
}

static void
put_local_type_ref(struct buffer *buffer, uint32_t index)
{
    put_u8(buffer, UINT8_C(0));
    put_u32(buffer, index);
}

static void
put_variant_ref(struct buffer *buffer, uint32_t tag)
{
    put_local_type_ref(buffer, UINT32_C(4));
    put_u32(buffer, tag);
}

static void
put_field_ref(struct buffer *buffer, uint32_t owner, uint32_t index)
{
    put_u8(buffer, UINT8_C(0));
    put_local_type_ref(buffer, owner);
    put_u32(buffer, index);
}

static void type_unit(struct buffer *b) { put_u8(b, UINT8_C(0)); }
static void type_bool(struct buffer *b) { put_u8(b, UINT8_C(1)); }
static void type_u64(struct buffer *b) { put_u8(b, UINT8_C(5)); }

static void
put_declared_type(struct buffer *buffer, uint32_t index)
{
    put_u8(buffer, UINT8_C(21));
    put_local_type_ref(buffer, index);
}

static void type_candidate(struct buffer *b) { put_declared_type(b, 0); }
static void type_candidate_id(struct buffer *b) { put_declared_type(b, 1); }
static void type_epoch(struct buffer *b) { put_declared_type(b, 2); }
static void type_input(struct buffer *b) { put_declared_type(b, 3); }
static void type_rejection(struct buffer *b) { put_declared_type(b, 4); }

static void
type_candidate_array(struct buffer *buffer)
{
    put_u8(buffer, UINT8_C(18));
    type_candidate(buffer);
    put_u32(buffer, UINT32_C(32));
}

static void
type_option_candidate(struct buffer *buffer)
{
    put_u8(buffer, UINT8_C(15));
    type_candidate(buffer);
}

static void
type_selection(struct buffer *buffer)
{
    put_u8(buffer, UINT8_C(16));
    type_option_candidate(buffer);
    type_unit(buffer);
}

static void
type_kernel_result(struct buffer *buffer)
{
    put_u8(buffer, UINT8_C(19));
    type_candidate(buffer);
    type_rejection(buffer);
}

static void
expr_local(struct buffer *buffer, type_emitter type, uint32_t index)
{
    type(buffer);
    put_u8(buffer, UINT8_C(4));
    put_u32(buffer, index);
}

static void
expr_project_local(struct buffer *buffer, type_emitter result_type,
    type_emitter record_type, uint32_t local_index, uint32_t owner,
    uint32_t field_index)
{
    result_type(buffer);
    put_u8(buffer, UINT8_C(7));
    expr_local(buffer, record_type, local_index);
    put_field_ref(buffer, owner, field_index);
}

static void
expr_equal_projects(struct buffer *buffer,
    type_emitter left_type, type_emitter left_record_type,
    uint32_t left_local, uint32_t left_owner, uint32_t left_field,
    type_emitter right_type, type_emitter right_record_type,
    uint32_t right_local, uint32_t right_owner, uint32_t right_field)
{
    type_bool(buffer);
    put_u8(buffer, UINT8_C(14));
    expr_project_local(buffer, left_type, left_record_type, left_local,
        left_owner, left_field);
    expr_project_local(buffer, right_type, right_record_type, right_local,
        right_owner, right_field);
}

static void
expr_rejection(struct buffer *buffer, uint32_t tag)
{
    type_rejection(buffer);
    put_u8(buffer, UINT8_C(8));
    put_variant_ref(buffer, tag);
    put_u32(buffer, UINT32_C(0));
}

static void
expr_predicate(struct buffer *buffer)
{
    expr_equal_projects(buffer,
        type_candidate_id, type_candidate, 0, 0, 2,
        type_candidate_id, type_input, 1, 3, 2);
}

static void
expr_selection(struct buffer *buffer)
{
    type_selection(buffer);
    put_u8(buffer, UINT8_C(29));
    expr_project_local(buffer, type_candidate_array, type_input, 0, 3, 0);
    put_u32(buffer, UINT32_C(1));
    type_candidate(buffer);
    type_bool(buffer);
    expr_predicate(buffer);
}

static void
constructor_result(struct buffer *buffer, uint32_t tag)
{
    put_u8(buffer, UINT8_C(2));
    type_option_candidate(buffer);
    type_unit(buffer);
    put_u32(buffer, tag);
}

static void
constructor_option(struct buffer *buffer, uint32_t tag)
{
    put_u8(buffer, UINT8_C(1));
    type_candidate(buffer);
    put_u32(buffer, tag);
}

static void
kernel_reject(struct buffer *buffer, uint32_t tag, uint32_t precedence)
{
    put_u8(buffer, UINT8_C(1));
    expr_rejection(buffer, tag);
    put_u32(buffer, precedence);
}

static void
kernel_accept(struct buffer *buffer)
{
    put_u8(buffer, UINT8_C(0));
    expr_local(buffer, type_candidate, 0);
}

static void
kernel_some_arm(struct buffer *buffer)
{
    put_u8(buffer, UINT8_C(2));
    expr_equal_projects(buffer,
        type_epoch, type_candidate, 0, 0, 1,
        type_epoch, type_input, 3, 3, 1);
    expr_rejection(buffer, 3);
    put_u32(buffer, UINT32_C(2));

    put_u8(buffer, UINT8_C(2));
    expr_project_local(buffer, type_bool, type_candidate, 0, 0, 0);
    expr_rejection(buffer, 4);
    put_u32(buffer, UINT32_C(3));
    kernel_accept(buffer);
}

static void
kernel_option_match(struct buffer *buffer)
{
    put_u8(buffer, UINT8_C(5));
    expr_local(buffer, type_option_candidate, 0);
    put_u32(buffer, UINT32_C(2));
    constructor_option(buffer, 0);
    kernel_reject(buffer, 1, 0);
    constructor_option(buffer, 1);
    kernel_some_arm(buffer);
}

static void
kernel_result_match(struct buffer *buffer)
{
    put_u8(buffer, UINT8_C(5));
    expr_local(buffer, type_selection, 0);
    put_u32(buffer, UINT32_C(2));
    constructor_result(buffer, 0);
    kernel_option_match(buffer);
    constructor_result(buffer, 1);
    kernel_reject(buffer, 2, 1);
}

static void
kernel_expression(struct buffer *buffer)
{
    put_u8(buffer, UINT8_C(3));
    expr_selection(buffer);
    kernel_result_match(buffer);
}

static void
put_resource_bounds(struct buffer *buffer, uint32_t steps, uint32_t live,
    uint32_t depth, uint32_t workspace)
{
    put_u32(buffer, steps);
    put_u32(buffer, live);
    put_u32(buffer, depth);
    put_u32(buffer, workspace);
}

static void
put_record_field(struct buffer *buffer, const char *field_name,
    type_emitter field_type)
{
    put_name(buffer, field_name);
    field_type(buffer);
}

static void
put_type_declarations(struct buffer *buffer)
{
    put_u32(buffer, UINT32_C(5));

    put_name(buffer, "Candidate");
    put_u8(buffer, UINT8_C(2));
    put_u32(buffer, UINT32_C(3));
    put_record_field(buffer, "enabled", type_bool);
    put_record_field(buffer, "epoch", type_epoch);
    put_record_field(buffer, "id", type_candidate_id);

    put_name(buffer, "CandidateId");
    put_u8(buffer, UINT8_C(1));
    put_u8(buffer, UINT8_C(12));
    put_u8(buffer, UINT8_C(0));
    put_u32(buffer, UINT32_C(0));
    put_u32(buffer, UINT32_C(16));

    put_name(buffer, "Epoch");
    put_u8(buffer, UINT8_C(1));
    type_u64(buffer);

    put_name(buffer, "Input");
    put_u8(buffer, UINT8_C(2));
    put_u32(buffer, UINT32_C(3));
    put_record_field(buffer, "candidates", type_candidate_array);
    put_record_field(buffer, "currentEpoch", type_epoch);
    put_record_field(buffer, "wanted", type_candidate_id);

    put_name(buffer, "Rejection");
    put_u8(buffer, UINT8_C(3));
    put_u32(buffer, UINT32_C(4));
    put_u32(buffer, UINT32_C(1)); put_name(buffer, "Missing"); put_u8(buffer, 0);
    put_u32(buffer, UINT32_C(2)); put_name(buffer, "Duplicate"); put_u8(buffer, 0);
    put_u32(buffer, UINT32_C(3)); put_name(buffer, "Stale"); put_u8(buffer, 0);
    put_u32(buffer, UINT32_C(4)); put_name(buffer, "Disabled"); put_u8(buffer, 0);
}

static void
put_kernel(struct buffer *buffer)
{
    put_name(buffer, "select");
    put_u32(buffer, UINT32_C(1));
    put_name(buffer, "input");

    put_u32(buffer, UINT32_C(1));
    type_input(buffer);
    type_kernel_result(buffer);
    put_u32(buffer, UINT32_C(4));
    put_variant_ref(buffer, 1); put_variant_ref(buffer, 2);
    put_variant_ref(buffer, 3); put_variant_ref(buffer, 4);
    kernel_expression(buffer);
    put_resource_bounds(buffer, 2048, 32768, 64, 4096);
    put_resource_bounds(buffer, 212, 19361, 8, 201);
    put_u8(buffer, UINT8_C(0));
}

static void
put_module_bounds(struct buffer *buffer)
{
    put_u32(buffer, UINT32_C(1048576));
    put_u32(buffer, UINT32_C(32));
    put_u32(buffer, UINT32_C(4096));
    put_u32(buffer, UINT32_C(65536));
    put_u32(buffer, UINT32_C(256));
    put_u32(buffer, UINT32_C(32));
    put_resource_bounds(buffer, 16777216, 8388608, 256, 8388608);
}

static struct buffer
module_payload(void)
{
    struct buffer buffer = {{0}, 0, 0};
    uint32_t index;

    put_u32(&buffer, UINT32_C(0));
    put_u32(&buffer, UINT32_C(3));
    put_name(&buffer, "seki");
    put_name(&buffer, "examples");
    put_name(&buffer, "candidate_selection");
    put_u32(&buffer, UINT32_C(1));
    put_name(&buffer, "c11_bounded");
    put_u32(&buffer, UINT32_C(1));

    put_u32(&buffer, UINT32_C(0));
    put_u32(&buffer, UINT32_C(1));
    put_name(&buffer, "CandidateIdentity");
    put_type_declarations(&buffer);
    put_u32(&buffer, UINT32_C(0));
    put_u32(&buffer, UINT32_C(1));
    put_kernel(&buffer);

    put_u32(&buffer, UINT32_C(1)); put_u32(&buffer, UINT32_C(0));
    put_u32(&buffer, UINT32_C(5));
    for (index = 0; index < 5; ++index) put_u32(&buffer, index);
    put_u32(&buffer, UINT32_C(0));
    put_u32(&buffer, UINT32_C(1)); put_u32(&buffer, UINT32_C(0));
    put_u32(&buffer, UINT32_C(5));
    for (index = 0; index < 5; ++index) put_u8(&buffer, (uint8_t)index);
    put_u32(&buffer, UINT32_C(1)); put_u8(&buffer, UINT8_C(0));
    put_module_bounds(&buffer);

    put_u32(&buffer, UINT32_C(0));
    put_u32(&buffer, UINT32_C(5));
    put_u32(&buffer, UINT32_C(1)); put_u32(&buffer, UINT32_C(2));
    put_u32(&buffer, UINT32_C(0)); put_u32(&buffer, UINT32_C(3));
    put_u32(&buffer, UINT32_C(4));
    put_u32(&buffer, UINT32_C(0));
    return buffer;
}

int
main(void)
{
    static const unsigned char magic[] = {'S', 'E', 'K', 'I'};
    const struct buffer payload = module_payload();
    struct buffer module = {{0}, 0, 0};

    if (payload.failed) return 1;
    put_raw(&module, magic, sizeof magic);
    put_u32(&module, UINT32_C(0));
    put_u8(&module, UINT8_C(0));
    put_u32(&module, (uint32_t)payload.length);
    put_raw(&module, payload.bytes, payload.length);
    if (module.failed) return 1;
    if (fwrite(module.bytes, 1, module.length, stdout) != module.length) return 1;
    return 0;
}
