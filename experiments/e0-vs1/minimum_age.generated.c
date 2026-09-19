#include <stdint.h>

typedef struct {
    uint8_t age;
} seki_e0_applicant;

typedef struct {
    uint8_t tag;
    uint8_t reason;
} seki_e0_decision;

seki_e0_decision seki_e0_decide(seki_e0_applicant applicant);

seki_e0_decision
seki_e0_decide(seki_e0_applicant applicant)
{
    seki_e0_decision result;
    if (applicant.age < UINT8_C(18)) {
        result.tag = UINT8_C(1);
        result.reason = UINT8_C(1);
    } else {
        result.tag = UINT8_C(0);
        result.reason = UINT8_C(0);
    }
    return result;
}
