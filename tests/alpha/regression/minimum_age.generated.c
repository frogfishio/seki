#include <stdint.h>

typedef struct {
    uint8_t seki_f_age;
} seki_a0_minimum_age_applicant;

typedef struct {
    uint32_t abi_revision;
    uint32_t disposition;   /* 1 accepted, 2 rejected */
    uint32_t rejection_tag; /* 0 when accepted */
    uint32_t premise_tag;   /* 0 when inapplicable */
} seki_a0_minimum_age_decision;

static void
seki_a0_minimum_age_zero(uint8_t *bytes, uint32_t length)
{
    uint32_t index;
    for (index = UINT32_C(0); index < length; ++index) {
        bytes[index] = UINT8_C(0);
    }
}

seki_a0_minimum_age_decision seki_a0_minimum_age_decide(seki_a0_minimum_age_applicant seki_p_applicant);

seki_a0_minimum_age_decision
seki_a0_minimum_age_decide(seki_a0_minimum_age_applicant seki_p_applicant)
{
    seki_a0_minimum_age_decision result;
    seki_a0_minimum_age_zero((uint8_t *)&result, (uint32_t)sizeof result);
    result.abi_revision = UINT32_C(1);
    if (seki_p_applicant.seki_f_age < UINT8_C(18)) {
        result.disposition = UINT32_C(2);
        result.rejection_tag = UINT32_C(1);
    } else {
        result.disposition = UINT32_C(1);
    }
    return result;
}
