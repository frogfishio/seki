/*
 * KCore C11 support component (KCORE_C11_SUBSET §4, AR-1 §5).
 *
 * Hand-written and reviewed; part of the trusted boundary of the C target.
 * Emitted code reaches the C library only through these functions.
 *
 * Event model. KCore's environment decides every fallible event: event k
 * (k = number of events so far in the transaction) is an allocation of
 * `count` elements or a cancellation checkpoint (KCORE_SEMANTICS §5).
 * `kc_ctx.decide` is that environment. Returning false refuses the event:
 * the allocation fails, or the checkpoint cancels. A granted allocation can
 * still fail in `malloc`, which is the same observable outcome as a refusal.
 *
 * Transaction ownership (§5a). Every allocation is registered with the
 * context; `kc_rt_free` unregisters and frees one block; on operational
 * failure the entry function calls `kc_rt_release_all`, which frees every
 * block still registered.
 */
#ifndef KC_RT_H
#define KC_RT_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define KC_OK UINT32_C(0)
#define KC_ALLOCATION_FAILED UINT32_C(1)
#define KC_CANCELLED UINT32_C(2)
/* Unreachable for verified programs (KCore T4); reported, never relied on. */
#define KC_STUCK UINT32_C(3)

#define KC_EV_ALLOC UINT32_C(0)
#define KC_EV_CANCEL UINT32_C(1)

typedef bool (*kc_decide_fn)(void *user, uint64_t k, uint32_t event, uint64_t count);

typedef struct kc_ctx {
  kc_decide_fn decide; /* NULL: grant every event */
  void *user;
  uint64_t events;     /* events decided so far (KCore trace length) */
  void **owned;        /* transaction-owned live blocks */
  uint64_t owned_len;
  uint64_t owned_cap;
} kc_ctx;

/* A context with no owned blocks and no events. */
void kc_rt_init(kc_ctx *c, kc_decide_fn decide, void *user);

void *kc_rt_alloc(kc_ctx *c, uint64_t n, uint64_t size);
void kc_rt_free(kc_ctx *c, void *p);
bool kc_rt_cancelled(kc_ctx *c);
void kc_rt_release_all(kc_ctx *c);
/* Frees the registry itself; the owned set must be empty. */
void kc_rt_dispose(kc_ctx *c);

#endif
