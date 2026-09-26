/* Differential test for the spike: every vector's expected decision comes from
   the Lean statement of the kernel (SekiSpike.Gate.Spec.authorise), not from
   KCore and not from the C. */
#include "seki_a0_gate.h"

#include <stdio.h>
#include <string.h>

static int hexbytes(const char *s, uint8_t *out) {
  for (int i = 0; i < 32; i++) {
    unsigned v;
    if (sscanf(s + 2 * i, "%2x", &v) != 1) return 0;
    out[i] = (uint8_t)v;
  }
  return 1;
}

int main(int argc, char **argv) {
  FILE *f = fopen(argc > 1 ? argv[1] : "vectors.txt", "r");
  if (f == NULL) { perror("vectors"); return 2; }
  char a[65], b[65];
  unsigned age, tier, disp, tag, prem, lim, act;
  unsigned long cases = 0, accepted = 0;
  while (fscanf(f, "%64s %64s %u %u %u %u %u %u %u",
                a, b, &age, &tier, &disp, &tag, &prem, &lim, &act) == 9) {
    seki_a0_gate_request r;
    memset(&r, 0, sizeof r);
    if (!hexbytes(a, r.seki_f_account) || !hexbytes(b, r.seki_f_boundAccount)) return 2;
    r.seki_f_age = (uint8_t)age;
    r.seki_f_tier = (uint16_t)tier;
    seki_a0_gate_decision d = seki_a0_gate_authorise(r);
    /* The decision has no padding and no union (asserted in the header), so
       comparing it byte for byte is sound. */
    seki_a0_gate_decision want = {3, disp, tag, prem, (uint16_t)lim, (uint16_t)act};
    if (memcmp(&d, &want, sizeof d) != 0) {
      fprintf(stderr, "MISMATCH case %lu: got %u/%u/%u/%u/%u/%u want %u/%u/%u/%u/%u/%u\n",
              cases, d.abi_revision, d.disposition, d.rejection_tag, d.premise_tag,
              d.tiertoolow_limit, d.tiertoolow_actual, 3U, disp, tag, prem, lim, act);
      return 1;
    }
    cases++;
    if (disp == 1U) accepted++;
  }
  fclose(f);
  printf("gate_differential=verified cases=%lu accepted=%lu rejected=%lu\n",
         cases, accepted, cases - accepted);
  return 0;
}
