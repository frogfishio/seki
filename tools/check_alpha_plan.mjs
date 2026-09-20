import fs from "node:fs";

const alpha = JSON.parse(fs.readFileSync("alpha/ALPHA_PLAN.json", "utf8"));
const status = JSON.parse(fs.readFileSync("PROJECT_STATUS.json", "utf8"));
const scope = fs.readFileSync("docs/alpha/A0_SCOPE.md", "utf8");
const adr = fs.readFileSync(
  "docs/decisions/0021-build-usable-alpha-before-f0-review.md", "utf8");

const expect = (condition, message) => {
  if (!condition) throw new Error(`Seki alpha plan: ${message}`);
};

expect(alpha.schema === "io.frogfish.seki/alpha-plan@1", "unknown schema");
expect(alpha.track === "A0" && alpha.status === "active", "A0 is not active");
expect(alpha.current_work_package === status.active_work_package,
  "alpha and project active work packages disagree");
expect(alpha.claim_class === "provisional-bootstrap-alpha",
  "alpha claim class drift");
expect(alpha.f0_may_remain_open === true && status.global_f0 === "open",
  "A0 must not silently close F0");
expect(alpha.f1_authorized === false && status.f1_implementation_authorized === false,
  "A0 must not authorize F1");
expect(alpha.language_frozen === false && alpha.encoding_frozen === false,
  "A0 must not freeze provisional interfaces");
expect(alpha.authority_granted === false, "A0 granted authority");
expect(alpha.development_assurance_model === "internal-self-attestation",
  "development assurance model drift");
expect(alpha.cli_version === "0.0.0-alpha.6", "alpha CLI version drift");
expect(alpha.connected_commands.join(",") === "check,build,inspect",
  "connected alpha commands drift");
expect(alpha.compiler_core === "alpha-decision-frontend+backend",
  "unexpected provisional compiler core");
expect(alpha.general_compiler_core_ready === false,
  "A0-02 cannot close while the general core remains incomplete");
expect(alpha.e0_frontend_adapter_active === false,
  "E0 frontend remained active after alpha core integration");
expect(alpha.e0_backend_adapter_active === false,
  "E0 backend remained active after alpha backend integration");
expect(alpha.general_lexer_ready === true,
  "general alpha lexer progress record lost");
expect(alpha.general_header_parser_ready === true,
  "general module-header parser progress record lost");
expect(alpha.complete_module_parse_required === true,
  "live compiler no longer requires a complete module parse");
expect(alpha.general_alias_nominal_parser_ready === true,
  "general alias/nominal parser progress record lost");
expect(alpha.general_record_variant_parser_ready === true,
  "general record/variant parser progress record lost");
expect(alpha.general_kernel_envelope_parser_ready === true,
  "general kernel-envelope parser progress record lost");
expect(alpha.general_expression_parser_ready === false,
  "expression parser claimed ready before implementation");
expect(alpha.u8_decision_tail_ast_ready === true,
  "U8-decision kernel-tail AST progress record lost");
expect(alpha.u8_decision_semantic_checker_ready === true,
  "U8-decision semantic checker progress record lost");
expect(alpha.u8_decision_core_emitter_ready === true,
  "U8-decision core emitter progress record lost");
expect(alpha.u8_decision_independent_core_decoder_ready === true,
  "U8-decision independent core decoder progress record lost");
expect(alpha.u8_decision_c_backend_ready === true,
  "U8-decision C backend progress record lost");
expect(alpha.u8_decision_identity_independent === true,
  "U8-decision slice regained program-identity assumptions");
expect(alpha.u8_decision_multiple_fields === true,
  "U8-decision multi-field progress record lost");
expect(alpha.u8_decision_multiple_rejections === true,
  "U8-decision rejection-inventory progress record lost");
expect(alpha.u8_decision_independent_semantic_recheck === true,
  "U8-decision lost independent semantic rechecking");
expect(alpha.shared_elaboration_ready === true,
  "checker and emitter no longer share one elaboration");
expect(alpha.general_core_traversal_ready === true,
  "typed-core construction regained a fixed program shape");
expect(alpha.general_resource_derivation_ready === true,
  "exact resource bounds are no longer derived from the cost algebra");
expect(alpha.canonical_table_ordering_ready === true,
  "canonical table ordering progress record lost");
expect(alpha.general_comparison_operators_ready === true,
  "comparison lowering narrowed back to one operator");
expect(alpha.syntax_nesting_bounded === true,
  "recursive descent is no longer bounded by the profile nesting ceiling");
expect(alpha.restricted_c_ast_ready === true,
  "C projection regained a fixed linear byte expectation");
expect(alpha.nested_kernel_control_ready === true,
  "nested kernel control progress record lost");
expect(alpha.unsigned_field_widths_ready === true,
  "record fields narrowed back to a single unsigned width");
expect(alpha.multiple_declarations_ready === true,
  "C projection returned to a fixed one-record one-variant module");
expect(alpha.general_declaration_parser_ready === false,
  "declaration parser claimed ready before functions and domains exist");
expect(status.development_assurance_model === "internal-self-attestation",
  "project status lost internal assurance model");
expect(status.internal_certification_status === "not-ready",
  "unfinished A0 cannot be internally certified");
expect(status.field_validation_status === "deferred-until-release-candidate",
  "field validation started before the release candidate");
expect(status.go_live_eligible === false, "unfinished A0 became live-eligible");
expect(alpha.required_examples.join(",") ===
  "minimum-age,grit-stage1-publication", "required example drift");

const packages = alpha.work_packages;
expect(Array.isArray(packages) && packages.length === 6,
  "unexpected work-package ledger");
expect(packages.map((item) => item.id).join(",") ===
  "A0-01,A0-02,A0-03,A0-04,A0-05,A0-06",
  "work-package order drift");
expect(packages.filter((item) => item.state === "active").length === 1,
  "exactly one alpha work package must be active");
expect(packages.find((item) => item.state === "active")?.id ===
  alpha.current_work_package, "active package ledger mismatch");

for (const forbidden of [
  "implementation_authority", "proof_authority", "native_binary_authority",
  "product_authority", "production_authority"
]) expect(status[forbidden] === false, `${forbidden} granted during A0`);

expect(scope.includes("A0 completion does not close F0 or make Seki live-eligible"),
  "scope lost its gate boundary");
expect(adr.includes("The solution is not to weaken F0"),
  "decision rationale drift");

console.log(
  `seki_alpha_plan=verified status=${alpha.status} ` +
  `work_package=${alpha.current_work_package} authority=false`
);
