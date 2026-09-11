# Experimental SCB-0 structural hostile vectors

- Status: executable bootstrap vectors; not frozen admission evidence
- Runner: `tools/encoding/check_decoder_mutations.mjs`

The independent cursor decoder reopens both positive module vectors, then applies
one targeted mutation at a time:

| Mutation | Expected reason |
| --- | --- |
| bad magic | `0001 bad_magic` |
| unsupported SCB version | `0002 unsupported_scb_version` |
| bundle kind supplied to module decoder | `0003 wrong_object_kind` |
| final byte removed | `0005 truncated_value` |
| trailing zero byte | `0006 trailing_bytes` |
| typed-core schema changed | `0200 wrong_typed_core_schema` |
| unknown type-declaration tag | `0100 unknown_discriminant` |
| second type key changed to sort before the first | `0104 nonincreasing_table_key` |
| decreasing type key plus unknown body tag | `0104 nonincreasing_table_key` |
| variant payload option tag changed to 2 | `0102 invalid_option_tag` |
| theorem set member duplicated | `0105 duplicate_set_member` |
| publication Boolean changed to 2 | `0101 invalid_boolean_tag` |
| least type dependency order replaced by another first index | `0d02 type_dependency_order_invalid` |

Three competing-failure cases establish that envelope failure precedes a deeper
tag failure, that the earlier structural path wins within the canonical-form
layer, and that a bad table key is selected before its later malformed value.

These vectors test structural reopening and the type-dependency schedule only.
The decoder does not yet validate a nonempty function schedule or claim static
typing, exact resource recomputation, import admission, or semantic evaluation.
