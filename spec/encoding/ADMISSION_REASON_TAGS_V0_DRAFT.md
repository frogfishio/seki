# Seki admission-reason tags v0 draft

- Status: provisional registry; non-normative; vector freeze pending
- Encoding: two octets, `layer` then `reason`

## 1. Tag structure

An `AdmissionReason` is one big-endian structured `U16` written as two `U8`
components:

```text
AdmissionReason ::= { layer: U8, reason: U8 }
tag = (layer << 8) | reason
```

The high octet is the fixed admission-precedence layer from
`ADMISSION_RULES_V0_DRAFT.md`. The low octet identifies one failure in that
layer. Unassigned layer/reason pairs are invalid and must not be emitted.

This structure makes the precedence visible without coupling diagnostics to
English wording. Human messages are untrusted presentation selected by tag and
structural path.

If several failures exist, admission selects the lowest layer, then the least
canonical structural path, then the lowest reason octet applicable at that exact
path. Implementations may report additional findings separately.

## 2. Registry

### Layer `00` — envelope

```text
0000 input_bytes_ceiling_exceeded
0001 bad_magic
0002 unsupported_scb_version
0003 wrong_object_kind
0004 payload_length_mismatch
0005 truncated_value
0006 trailing_bytes
0007 bundle_module_count_ceiling_exceeded
0008 bundle_total_bytes_ceiling_exceeded
```

### Layer `01` — canonical form

```text
0100 unknown_discriminant
0101 invalid_boolean_tag
0102 invalid_option_tag
0103 duplicate_table_key
0104 nonincreasing_table_key
0105 duplicate_set_member
0106 nonincreasing_set_member
```

### Layer `02` — identity

```text
0200 wrong_typed_core_schema
0201 wrong_language_identity
0202 invalid_module_identity
0203 unsupported_semantic_profile
0204 wrong_designated_root
```

### Layer `03` — shape and profile size

```text
0300 invalid_ascii_name
0301 invalid_module_path
0302 sequence_count_ceiling_exceeded
0303 byte_length_ceiling_exceeded
0304 declaration_count_ceiling_exceeded
0305 expression_count_ceiling_exceeded
0306 nesting_ceiling_exceeded
0307 invalid_fixed_length
0308 invalid_natural_parameter
```

### Layer `04` — imports

```text
0400 duplicate_module_identity
0401 missing_dependency_module
0402 unused_dependency_module
0403 imported_digest_mismatch
0404 imported_profile_mismatch
0405 undeclared_direct_import
0406 transitive_reference_not_visible
0407 import_cycle
0408 imported_declaration_not_exported
0409 imported_declaration_wrong_kind
040a imported_signature_mismatch
040b bundle_module_count_mismatch
040c bundle_import_edge_ceiling_exceeded
040d bundle_dependency_depth_ceiling_exceeded
```

### Layer `05` — declarations

```text
0500 function_key_collision
0501 duplicate_variant_case_name
0502 invalid_variant_stable_tag
0503 invalid_export_reference
0504 invalid_declaration_body
```

### Layer `06` — type formation

```text
0600 zero_index_bound
0601 invalid_digest_type_length
0602 recursive_type
0603 empty_variant
0604 forbidden_variant_payload_type
0605 invalid_nominal_representation
0606 unsupported_type
0607 type_parameter_ceiling_exceeded
```

### Layer `07` — references

```text
0700 declaration_reference_out_of_range
0701 declaration_reference_wrong_kind
0702 local_reference_out_of_scope
0703 field_reference_out_of_range
0704 field_owner_mismatch
0705 variant_case_not_found
0706 constructor_owner_mismatch
0707 function_reference_out_of_range
```

### Layer `08` — static typing

```text
0800 claimed_type_mismatch
0801 operand_type_mismatch
0802 argument_count_mismatch
0803 argument_type_mismatch
0804 result_type_mismatch
0805 record_field_mismatch
0806 variant_payload_mismatch
0807 branch_type_mismatch
0808 match_not_exhaustive
0809 match_binder_mismatch
080a comparison_not_supported
080b arithmetic_type_mismatch
080c shift_count_not_u32
080d unsigned_negation
080e collection_signature_mismatch
```

### Layer `09` — totality

```text
0900 recursive_call
0901 indirect_call
0902 kernel_call_forbidden
0903 escaping_block
0904 unsupported_intrinsic
0905 unbounded_control
0906 ambient_effect
```

### Layer `0a` — module and kernel rules

```text
0a00 invalid_theorem_requirement
0a01 claim_exceeds_ceiling
0a02 invalid_kernel_decision_type
0a03 invalid_kernel_rejection_type
0a04 incomplete_rejection_order
0a05 duplicate_rejection_constructor
0a06 rejection_index_out_of_range
0a07 rejection_reason_index_mismatch
0a08 rejection_precedence_violation
0a09 kernel_control_in_value_position
0a0a invalid_publication_declaration
```

### Layer `0b` — bounds

```text
0b00 bound_arithmetic_overflow
0b01 logical_steps_mismatch
0b02 live_value_bits_mismatch
0b03 control_depth_mismatch
0b04 workspace_bits_mismatch
0b05 callable_ceiling_exceeded
0b06 module_ceiling_exceeded
0b07 profile_ceiling_exceeded
0b08 call_depth_ceiling_exceeded
```

### Layer `0c` — backend/profile

```text
0c00 construct_unavailable_in_profile
0c01 representation_unavailable_in_profile
0c02 proof_projection_unavailable_in_profile
0c03 backend_projection_unavailable_in_profile
```

### Layer `0d` — witness closure

```text
0d00 unsupported_derivation_schema
0d01 type_dependency_order_incomplete
0d02 type_dependency_order_invalid
0d03 function_dependency_order_incomplete
0d04 function_dependency_order_invalid
0d05 derivation_conclusion_mismatch
```

## 3. Registry rules

- Existing assigned pairs are never reused within v0.
- New reasons may use an unassigned low octet only before the byte/vector freeze.
- After freeze, adding or splitting a reason requires a new admission-result
  schema version.
- A wording change does not change the tag.
- The tag identifies why admission failed, not a process error such as allocation
  failure, cancellation, or host I/O failure.
- Certificate and CLI formats must bind their own version before carrying this
  pair; raw two-byte values are not self-identifying artifacts.

## 4. Vector obligations

Every assigned pair requires one minimal hostile input whose authoritative result
is that pair and one test showing that a lower-precedence competing failure wins.
Every layer also requires equal-path reason tie tests where two checks could apply.
