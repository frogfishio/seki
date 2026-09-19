# Generated-output policy

Status: policy and Seki Generated Output Exception 1.0 adopted

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

The project-owned exception is
[`SEKI_OUTPUT_EXCEPTION`](../../SEKI_OUTPUT_EXCEPTION). It is an original GPLv3
section 7 additional permission implementing this policy; the GCC Runtime
Library Exception was not copied or modified because its terms specifically
define GCC and its license text says that changing it is not allowed.

Every future delivery manifest must distinguish customer-derived output from
Seki-owned runtime or template material and report the license and exception
identity of the latter. Standalone compiler, runtime, and library artifacts are
not generated output and retain their applicable licenses.
