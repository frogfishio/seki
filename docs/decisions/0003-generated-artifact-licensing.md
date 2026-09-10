# ADR 0003: Customer-controlled generated artifacts

- Status: accepted; exact runtime-exception text pending legal review
- Date: 2026-09-11

## Context

Seki itself is GPL-3.0-or-later. The compiler is intended to emit C, headers,
formal definitions, proof material, manifests, and certificates for embedding
in other systems. Some outputs may mechanically express a customer's Seki
module; others may contain copyrightable Seki runtime or template material.

The license of a compiler does not by itself settle the license of every
output, and copied or linked runtime material may have separate consequences.
The project must make this boundary explicit rather than leave customers to
infer it.

## Decision

Running `sekic` does not change the ownership or licensing of its inputs or
outputs. Customers control the licensing of their Seki modules and of generated
C, headers, formal definitions, proof material, manifests, and certificates.
They may use and convey those artifacts under terms of their choice.

This follows GCC's division between a GPL-covered compiler and customer-owned
compiled programs. Where output contains Seki-owned runtime, header, or
template material that would otherwise impose GPL conditions, that material
will carry an explicit additional permission modeled on the purpose of the GCC
Runtime Library Exception.

## Required implementation

- Design generators to minimize copied Seki-owned material.
- Mark every runtime, header, and template file with its applicable license.
- Make each delivery manifest report copied and linked licensed material.
- Put an explicit output notice in generated artifacts without asserting
  ownership over customer material.
- Adopt legally reviewed exception text before distributing any Seki-owned
  runtime or template material as part of customer output.

The GCC Runtime Library Exception cannot simply be renamed or edited: its
published text defines GCC and forbids modification. Seki therefore needs its
own reviewed additional permission implementing the same customer-freedom
policy. Until that instrument is adopted, qualified output must contain no
Seki-owned runtime or template material whose inclusion would restrict the
customer's chosen terms.

