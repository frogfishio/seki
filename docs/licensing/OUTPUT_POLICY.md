# Generated-output policy

Status: policy accepted; runtime-exception legal text pending

## Customer ownership and choice

Running Seki's tools does not transfer ownership of a customer's input or
output to the Seki project and does not, by itself, impose Seki's GPL license on
generated artifacts. The customer chooses the terms for its Seki modules and
generated C, headers, proofs, manifests, and certificates.

## Seki-owned material in output

An output can require separate permission if it copies copyrightable Seki
runtime, header, or template material. Seki will follow the GCC model by
granting an explicit additional permission for that material so generated
kernels can be embedded and conveyed under the customer's chosen terms.

The exact Seki exception must be reviewed and adopted before affected material
is distributed. The existing GCC Runtime Library Exception is not copied or
modified because its terms specifically define GCC and its license text says
that changing it is not allowed.

Until the Seki exception is adopted, the generator must either:

1. emit artifacts containing no copyrightable Seki-owned material; or
2. mark the output unqualified and prevent its distribution as a release
   artifact.

Every future delivery manifest must distinguish customer-derived output from
Seki-owned runtime or template material and report the license of the latter.

