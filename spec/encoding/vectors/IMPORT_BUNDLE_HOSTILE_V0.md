# Experimental import-bundle hostile vectors

- Status: executable bootstrap vectors; not frozen admission evidence
- Runner: `tools/encoding/check_import_bundle.mjs`

| Mutation | Expected reason |
| --- | --- |
| bundle envelope exceeds the profile byte ceiling | `0008 bundle_total_bytes_ceiling_exceeded` |
| change valid dependency bytes without updating import | `0405 imported_digest_mismatch` |
| substitute the consumer's claimed import digest | `0405 imported_digest_mismatch` |
| remove the dependency envelope | `0401 missing_dependency_module` |
| reverse canonical module order | `0104 nonincreasing_table_key` |
| duplicate the dependency module | `0400 duplicate_module_identity` |
| designate the dependency as root while retaining consumer | `0402 unused_dependency_module` |
| change dependency profile and correctly rebind its digest | `0403 imported_profile_mismatch` |
| replace least function order `[0,1]` with `[1,1]` | `0d04 function_dependency_order_invalid` |
| use nonexistent import-table index 1 | `0406 undeclared_direct_import` |
| use unexported imported type index 1 | `0408 imported_declaration_not_exported` |
| call unexported imported function index 1 | `0408 imported_declaration_not_exported` |
| add a dependency-to-consumer identity edge | `0404 import_cycle` |
| construct a ten-module chain of dependency depth nine | `040c import_depth_ceiling_exceeded` |
| construct a thirteen-module DAG with 78 import edges | `040b import_edge_ceiling_exceeded` |

Cycle detection intentionally precedes digest equality. A digest-bearing import
cycle otherwise requires a cryptographic fixed point before the cycle tag can be
observed; malformed ordinary cycle fixtures would always report digest mismatch.
