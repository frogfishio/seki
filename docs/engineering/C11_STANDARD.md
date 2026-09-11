# Seki bootstrap C11 engineering standard

- Status: accepted bootstrap engineering profile
- Applies to: handwritten compiler, CLI, checkers, tests, and host orchestration
- Does not define: generated restricted-C profile or proved C semantics

## 1. Objective

Write stable, portable, unsurprising ISO C11. The code should be easy to audit,
fuzz, replace component-by-component, and compile with independent toolchains.
Compactness, macro cleverness, compiler extensions, and framework-like abstraction
are not goals.

Handwritten bootstrap C is initially untrusted. Conformance to this standard is
engineering evidence, not proof authority.

## 2. Dialect and toolchains

- Compile authoritative paths as ISO C11 with extensions disabled.
- Maintain warning-clean builds with supported GCC and Clang versions.
- Treat warnings as errors in CI after toolchain versions are pinned.
- Record compiler identity and flags in build/test manifests.
- Do not make semantics depend on optimization level.
- Development builds include AddressSanitizer and UndefinedBehaviorSanitizer where
  the selected platform supports them.

Initial diagnostic flag baseline:

```text
-std=c11 -pedantic -Wall -Wextra -Werror
-Wconversion -Wsign-conversion -Wshadow -Wstrict-prototypes
-Wmissing-prototypes -Wundef -Wformat=2
```

Toolchain-specific adjustments must be recorded; warnings must not be globally
disabled to admit one site.

## 3. Types and arithmetic

- Use `<stdint.h>` exact-width types at representation boundaries.
- Use `size_t` only for host object sizes and checked indexing, not semantic
  integers or serialized values.
- Convert only after validating range in the source type.
- Check addition and multiplication before computing allocation sizes, offsets,
  or lengths.
- Never rely on signed overflow, invalid shifts, narrowing, or integer promotion.
- Express byte order explicitly.
- Do not use C bit-fields for semantic or wire representation.
- Booleans crossing a serialized boundary must validate their complete encoding.

Reusable checked-arithmetic helpers evaluate every argument exactly once and
return status plus output; they do not hide control flow in unsafe macros.

## 4. Bytes, strings, and slices

Semantic byte input uses explicit immutable slices:

```c
typedef struct seki_bytes_view {
    const uint8_t *data;
    size_t length;
} seki_bytes_view;
```

Mutable buffers separately carry pointer, logical length, and capacity. A pointer
may be null only where the API explicitly permits it; an empty slice has one
documented canonical representation.

C strings are limited to host-facing paths, command-line values, and diagnostics.
No authoritative decoder, digest, identifier, or semantic value relies on NUL
termination, locale, or implicit scanning.

## 5. Ownership and allocation

- Every interface documents borrower, owner, lifetime, and mutation rights.
- Prefer caller-owned bounded workspaces for semantic components.
- Isolate general heap allocation behind one host allocator interface.
- Validate sizes before allocation and preserve the original pointer until a
  resizing operation succeeds.
- Clean up through explicit structured paths; do not use `setjmp`/`longjmp`.
- Do not use variable-length arrays.
- Zeroization is used only for data with an explicit confidentiality requirement;
  it is not treated as a general correctness mechanism.

## 6. Control and state

- No recursion in components intended for later Seki replacement.
- Loops state their finite controlling bound and use overflow-safe termination.
- No hidden initialization, constructor attributes, or ambient mutable globals.
- Immutable lookup tables are permitted when their content is deterministic.
- Concurrency, atomics, signals, and callbacks are outside the initial semantic
  component profile.
- `assert` may detect internal programmer defects in development but cannot be
  required to reject hostile input or preserve release safety.

## 7. Structures and representation

- Never serialize or hash a C structure by copying its object representation.
- Do not depend on padding bytes, union type-punning, host endianness, alignment,
  enum width, or pointer representation.
- Encode and decode every semantic field explicitly.
- Initialize every field before observation.
- Generated representation headers remain separate from handwritten host types.

## 8. Functions and errors

- All functions have prototypes and internal functions use `static`.
- APIs return an explicit status enumeration; outputs use caller-provided pointers.
- A failure path leaves outputs in the documented unchanged or cleared state.
- `errno` may be captured at a host boundary but is not a semantic status.
- Diagnostics are separate from stable machine reasons.
- Functions avoid surprising ownership transfer and multi-purpose flags.
- Macros cannot evaluate an argument more than once.

Suggested shape:

```c
seki_status seki_decode_module(
    seki_bytes_view input,
    seki_workspace *workspace,
    seki_module *output,
    seki_diagnostic *diagnostic);
```

## 9. Determinism

Authoritative output cannot depend on:

- locale or timezone;
- current time, randomness, environment variables, or addresses;
- filesystem enumeration order;
- host hash-table iteration;
- unspecified C operand/argument evaluation order;
- uninitialized storage or padding;
- platform newline conventions; or
- noncanonical path spelling.

Evaluate effectful host operations in separate full expressions. Sort every
semantically unordered collection with an explicit bytewise comparator.

## 10. Source organization

The bootstrap implementation will separate:

```text
src/host/         CLI, files, processes, diagnostics
src/syntax/       lexer and surface parser
src/elaboration/  names, typing proposal, witness construction
src/canonical/    candidate typed-core encoding
src/support/      checked sizes, slices, arenas, diagnostics
```

Pure bounded candidates for later Seki replacement expose no host headers or
ambient state through their public interfaces.

Project symbols use the `seki_` prefix. Public headers are self-contained and
safe to include from C++ with an explicit `extern "C"` boundary where applicable.

## 11. Testing

Every boundary component requires:

- zero, one, maximum, and maximum-plus-one sizes;
- truncated and malformed input;
- duplicate and unknown fields;
- arithmetic boundary and conversion cases;
- deterministic repeated-output tests;
- allocation-failure injection where allocation is permitted;
- GCC and Clang warning-clean builds;
- sanitizer runs; and
- fuzz entry points that preserve reproducible crashing inputs.

Tests must distinguish a stable semantic/admission reason from optional diagnostic
text.

## 12. Review checklist

Before accepting handwritten C, verify:

- all lengths and capacities have visible invariants;
- every arithmetic operation affecting memory has a preceding check;
- every loop has a finite bound and safe terminal condition;
- every ownership transfer is documented;
- every failure preserves output invariants;
- no serialization observes C object representation;
- no authoritative ordering comes from a host container;
- no compiler extension or undefined behavior is required; and
- the component boundary remains suitable for later generated-C replacement.

