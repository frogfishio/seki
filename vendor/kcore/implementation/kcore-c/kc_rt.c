/* KCore C11 support component; see kc_rt.h. */
#include "kc_rt.h"

#include <stdlib.h>

void kc_rt_init(kc_ctx *c, kc_decide_fn decide, void *user) {
  c->decide = decide;
  c->user = user;
  c->events = 0;
  c->owned = NULL;
  c->owned_len = 0;
  c->owned_cap = 0;
}

static bool decide(kc_ctx *c, uint32_t event, uint64_t count) {
  uint64_t k = c->events;
  c->events = k + 1;
  return c->decide == NULL ? true : c->decide(c->user, k, event, count);
}

/* Room for one more owned block; false if the registry cannot grow. */
static bool reserve(kc_ctx *c) {
  if (c->owned_len < c->owned_cap) return true;
  uint64_t cap = c->owned_cap == 0 ? 16 : c->owned_cap * 2;
  if (cap > SIZE_MAX / sizeof(void *)) return false;
  void **p = realloc(c->owned, (size_t)cap * sizeof(void *));
  if (p == NULL) return false;
  c->owned = p;
  c->owned_cap = cap;
  return true;
}

void *kc_rt_alloc(kc_ctx *c, uint64_t n, uint64_t size) {
  if (!decide(c, KC_EV_ALLOC, n)) return NULL;
  /* Representability is proved in KCore (count <= SIZE_MAX / size); checked
     again here so that a violated premise cannot become a short buffer. */
  if (n == 0 || size == 0 || n > SIZE_MAX / size) return NULL;
  if (!reserve(c)) return NULL;
  void *p = malloc((size_t)(n * size));
  if (p == NULL) return NULL;
  c->owned[c->owned_len] = p;
  c->owned_len = c->owned_len + 1;
  return p;
}

void kc_rt_free(kc_ctx *c, void *p) {
  for (uint64_t i = c->owned_len; i > 0; i--) {
    if (c->owned[i - 1] == p) {
      c->owned[i - 1] = c->owned[c->owned_len - 1];
      c->owned_len = c->owned_len - 1;
      free(p);
      return;
    }
  }
  /* Freeing a block the transaction does not own is excluded by KCore T4. */
  abort();
}

bool kc_rt_cancelled(kc_ctx *c) { return !decide(c, KC_EV_CANCEL, 0); }

void kc_rt_release_all(kc_ctx *c) {
  for (uint64_t i = 0; i < c->owned_len; i++) free(c->owned[i]);
  c->owned_len = 0;
}

void kc_rt_dispose(kc_ctx *c) {
  if (c->owned_len != 0) abort();
  free(c->owned);
  c->owned = NULL;
  c->owned_cap = 0;
}
