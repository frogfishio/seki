/-
Spike (ADR 0023, order of work step 1): the quickstart `gate` kernel lowered to
KCore by hand, and proved.

    module example::gate @ 1
    export nominal AccountId := Digest[sha256, 32].
    export record Request { account: AccountId, boundAccount: AccountId,
                            age: U8, tier: U16 }.
    export variant Denial [ UnknownAccount @ 1. Underage @ 2.
                            TierTooLow(limit: U16, actual: U16) @ 5. ].
    export kernel authorise request: Request -> Decision[Unit, Denial]
    rejects: Denial::UnknownAccount, Denial::Underage, Denial::TierTooLow [
      account := request account.
      require account == (request boundAccount) else: Denial::UnknownAccount.
      require (request age) >= 18 else: Denial::Underage.
      require (request tier) >= 100
        else: Denial::TierTooLow(limit: 100, actual: (request tier)).
      accept unit ].

Three things are here:

1. `Spec`: what the Seki kernel means, written as a Lean function. In the real
   pipeline this is `Seki.eval` applied to the decoded typed core; here it is
   transcribed by hand, because that evaluator does not exist yet.
2. `prog`: the KCore program a lowering would produce, also written by hand.
3. `gate_run`: for every admitted request and every KCore environment, the
   KCore run returns exactly the encoded meaning of the Seki kernel, with no
   event, no allocation and nothing left owned. A Seki kernel cannot fail.

Representation choices, each of which a real lowering must make and prove:

* `Digest[sha256, 32]` becomes a struct of 32 `u8` fields. KCore structs hold
  scalars only; there are no arrays inside structs.
* Octet identity becomes the branch-free expression
  `(a0 ^ b0) | (a1 ^ b1) | … | (a31 ^ b31)`, compared with zero once.
* The decision is union-free: `abi_revision`, `disposition`, `rejection_tag`,
  `premise_tag`, then every payload field of every case. Here that is
  `TierTooLow.limit` and `TierTooLow.actual`. `abi_revision` is 3.
* Canonical field order is by name, as in Seki's typed core:
  `account, age, boundAccount, tier`.
-/
import KCore.Kit

namespace SekiSpike.Gate
open KCore
open KCore.Examples (seqs)

/-! ## 1. What the Seki kernel means -/

namespace Spec

structure Request where
  account : List Nat
  age : Nat
  boundAccount : List Nat
  tier : Nat

/-- An admitted request: every field is a value of its declared Seki type. -/
def Request.Admitted (r : Request) : Prop :=
  r.account.length = 32 ∧ (∀ x ∈ r.account, x < 256) ∧
  r.boundAccount.length = 32 ∧ (∀ x ∈ r.boundAccount, x < 256) ∧
  r.age < 256 ∧ r.tier < 65536

inductive Denial where
  | unknownAccount
  | underage
  | tierTooLow (limit actual : Nat)

/-- The authored stable tag of each case (`@ N` in the source). -/
def Denial.tag : Denial → Nat
  | .unknownAccount => 1
  | .underage => 2
  | .tierTooLow _ _ => 5

inductive Decision where
  | accept
  /-- A rejection and the one-based position of the `require` that produced it. -/
  | reject (d : Denial) (premise : Nat)

/-- The kernel: premises in declared rejection order, first failure wins. -/
def authorise (r : Request) : Decision :=
  if r.account ≠ r.boundAccount then .reject .unknownAccount 1
  else if r.age < 18 then .reject .underage 2
  else if r.tier < 100 then .reject (.tierTooLow 100 r.tier) 3
  else .accept

end Spec

/-! ## 2. The KCore program -/

def U8 : Ty := .int .u8
def U16 : Ty := .int .u16
def U32 : Ty := .int .u32
def DigestT : Ty := .struct "Digest"
def RequestT : Ty := .struct "Request"
def DecisionT : Ty := .struct "Decision"

def digestDef : StructDef := { name := "Digest", fields := List.replicate 32 U8 }
/-- Canonical field order: account, age, boundAccount, tier. -/
def requestDef : StructDef := { name := "Request", fields := [DigestT, U8, DigestT, U16] }
/-- abi_revision, disposition, rejection_tag, premise_tag,
    TierTooLow.limit, TierTooLow.actual. -/
def decisionDef : StructDef :=
  { name := "Decision", fields := [U32, U32, U32, U32, U16, U16] }

def V (x : String) : Expr := .var x
def n8 (n : Nat) : Expr := .lit (.int .u8 n)
def n16 (n : Nat) : Expr := .lit (.int .u16 n)
def n32 (n : Nat) : Expr := .lit (.int .u32 n)

/-- `OR` over the first `n` octets of `a XOR b`: zero exactly when they agree. -/
def octDiff (a b : Expr) : Nat → Expr
  | 0 => n8 0
  | n + 1 => .bin .bor (octDiff a b n) (.bin .bxor (.field a n) (.field b n))

def rejection (tag premise : Nat) (limit actual : Expr) : Expr :=
  .mk "Decision" [n32 3, n32 2, n32 tag, n32 premise, limit, actual]

def authoriseFun : FunDef where
  name := "authorise"
  params := [("request", RequestT)]
  result := DecisionT
  locals := [("account", DigestT)]
  body := seqs [
    .assign "account" (.field (V "request") 0),
    .ite (.bin .ne (octDiff (V "account") (.field (V "request") 2) 32) (n8 0))
      (.ret (rejection 1 1 (n16 0) (n16 0))) .skip,
    .ite (.bin .lt (.field (V "request") 1) (n8 18))
      (.ret (rejection 2 2 (n16 0) (n16 0))) .skip,
    .ite (.bin .lt (.field (V "request") 3) (n16 100))
      (.ret (rejection 5 3 (n16 100) (.field (V "request") 3))) .skip,
    .ret (.mk "Decision" [n32 3, n32 1, n32 0, n32 0, n16 0, n16 0])]

def prog : Program := { structs := [digestDef, requestDef, decisionDef], funs := [authoriseFun] }
def L : Layout := Layout.naturalC11 prog

#guard prog.wf
#guard prog.entryWf "authorise"
#guard L.valid prog

/-! ## 3. The encoding of Seki values as KCore values -/

def digestVal (bs : List Nat) : Val := .struct "Digest" (bs.map (.int .u8 ·))

def reqVal (r : Spec.Request) : Val :=
  .struct "Request" [digestVal r.account, .int .u8 r.age, digestVal r.boundAccount,
    .int .u16 r.tier]

def decisionVal : Spec.Decision → Val
  | .accept => .struct "Decision"
      [.int .u32 3, .int .u32 1, .int .u32 0, .int .u32 0, .int .u16 0, .int .u16 0]
  | .reject d p =>
      let (limit, actual) := match d with
        | .tierTooLow limit actual => (limit, actual)
        | _ => (0, 0)
      .struct "Decision" [.int .u32 3, .int .u32 2, .int .u32 d.tag, .int .u32 p,
        .int .u16 limit, .int .u16 actual]

/-! ## 4. Octet identity -/

theorem xor_eq_zero {a b : Nat} : a ^^^ b = 0 ↔ a = b := by
  constructor
  · intro h; apply Nat.eq_of_testBit_eq; intro i
    have := congrArg (fun x => x.testBit i) h
    simp only [Nat.testBit_xor, Nat.zero_testBit] at this
    cases ha : a.testBit i <;> cases hb : b.testBit i <;> simp_all
  · rintro rfl; simp

theorem lor_eq_zero {a b : Nat} : a ||| b = 0 ↔ a = 0 ∧ b = 0 := by
  constructor
  · intro h
    have hb : ∀ i, a.testBit i = false ∧ b.testBit i = false := fun i => by
      have := congrArg (fun x => x.testBit i) h
      simpa [Nat.testBit_or] using this
    exact ⟨Nat.eq_of_testBit_eq fun i => by simp [(hb i).1],
           Nat.eq_of_testBit_eq fun i => by simp [(hb i).2]⟩
  · rintro ⟨rfl, rfl⟩; rfl

/-- The value `octDiff` computes. -/
def diffN (xs ys : List Nat) : Nat → Nat
  | 0 => 0
  | n + 1 => diffN xs ys n ||| (xs.getD n 0 ^^^ ys.getD n 0)

theorem diffN_eq_zero {xs ys : List Nat} :
    ∀ n, diffN xs ys n = 0 ↔ ∀ i < n, xs.getD i 0 = ys.getD i 0
  | 0 => by simp [diffN]
  | n + 1 => by
      rw [diffN, lor_eq_zero, xor_eq_zero, diffN_eq_zero n]
      constructor
      · rintro ⟨h, h'⟩ i hi
        rcases Nat.lt_succ_iff_lt_or_eq.mp hi with hi | rfl
        · exact h i hi
        · exact h'
      · intro h; exact ⟨fun i hi => h i (Nat.lt_succ_of_lt hi), h n (Nat.lt_succ_self n)⟩

theorem diffN_lt {xs ys : List Nat} (hx : ∀ x ∈ xs, x < 256) (hy : ∀ y ∈ ys, y < 256) :
    ∀ n, diffN xs ys n < 256
  | 0 => by simp [diffN]
  | n + 1 => by
      have hxn : xs.getD n 0 < 256 := by
        rw [List.getD_eq_getElem?_getD]
        cases h : xs[n]? with
        | none => simp
        | some v => simpa using hx v (List.mem_of_getElem? h)
      have hyn : ys.getD n 0 < 256 := by
        rw [List.getD_eq_getElem?_getD]
        cases h : ys[n]? with
        | none => simp
        | some v => simpa using hy v (List.mem_of_getElem? h)
      have h1 := diffN_lt hx hy n
      have h2 : xs.getD n 0 ^^^ ys.getD n 0 < 2 ^ 8 := Nat.xor_lt_two_pow hxn hyn
      exact Nat.or_lt_two_pow h1 h2

/-- Two 32-octet digests are equal exactly when `diffN` over 32 octets is zero. -/
theorem diffN_32_eq_zero {xs ys : List Nat} (hx : xs.length = 32) (hy : ys.length = 32) :
    diffN xs ys 32 = 0 ↔ xs = ys := by
  rw [diffN_eq_zero]
  constructor
  · intro h
    apply List.ext_getElem (hx.trans hy.symm)
    intro i hi hi'
    have := h i (hx ▸ hi)
    simpa [List.getD_eq_getElem?_getD, hi, hi'] using this
  · rintro rfl i _; rfl

theorem evalExpr_octDiff {l : Locals} {a b : Expr} {xs ys : List Nat}
    (ha : evalExpr l a = .ok (digestVal xs)) (hb : evalExpr l b = .ok (digestVal ys)) :
    ∀ n, n ≤ xs.length → n ≤ ys.length →
      evalExpr l (octDiff a b n) = .ok (.int .u8 (diffN xs ys n))
  | 0, _, _ => by
      rw [octDiff, n8, evalExpr_lit_int (by simp [IntTy.bound, IntTy.bits])]; rfl
  | n + 1, hx, hy => by
      have ih := evalExpr_octDiff ha hb n (Nat.le_of_succ_le hx) (Nat.le_of_succ_le hy)
      have fx : (xs.map (Val.int .u8 ·))[n]? = some (.int .u8 (xs.getD n 0)) := by
        simp [List.getElem?_map, List.getD_eq_getElem?_getD,
          List.getElem?_eq_getElem (Nat.lt_of_succ_le hx)]
      have fy : (ys.map (Val.int .u8 ·))[n]? = some (.int .u8 (ys.getD n 0)) := by
        simp [List.getElem?_map, List.getD_eq_getElem?_getD,
          List.getElem?_eq_getElem (Nat.lt_of_succ_le hy)]
      simp only [octDiff, diffN, evalExpr_bin, evalExpr_field, ih, ha, hb, digestVal,
        ebind_ok, fieldF_struct, fx, fy, optVal_some, evalBin_bxor, evalBin_bor]

/-! ## 5. Conformance of admitted requests -/

theorem conformsAll_bytes {xs : List Nat} (hx : ∀ x ∈ xs, x < 256) :
    conformsAll prog (xs.map (Val.int .u8 ·)) (List.replicate xs.length (.int .u8)) = true := by
  induction xs with
  | nil => simp [conformsAll]
  | cons x xs ih =>
      simp only [List.map_cons, List.length_cons, List.replicate_succ, conformsAll, conforms]
      have h1 := hx x (by simp)
      have h2 := ih (fun y hy => hx y (by simp [hy]))
      simp [IntTy.bound, IntTy.bits, h1, h2]

theorem struct_digest : prog.struct? "Digest" = some digestDef := by rfl
theorem struct_request : prog.struct? "Request" = some requestDef := by rfl
theorem struct_decision : prog.struct? "Decision" = some decisionDef := by rfl

theorem conforms_digest {xs : List Nat} (hl : xs.length = 32) (hx : ∀ x ∈ xs, x < 256) :
    conforms prog (digestVal xs) DigestT = true := by
  have := conformsAll_bytes hx
  rw [hl] at this
  simp only [digestVal, DigestT, conforms, struct_digest, digestDef, U8, this]
  rfl

theorem ptrsIn_bytes (xs : List Nat) :
    ptrsInInputsAll #[] (xs.map (Val.int .u8 ·)) = true := by
  induction xs with
  | nil => simp [ptrsInInputsAll]
  | cons x xs ih => simp [ptrsInInputsAll, ptrsInInputs, ih]

theorem conforms_request {r : Spec.Request} (hr : r.Admitted) :
    conforms prog (reqVal r) RequestT = true := by
  obtain ⟨hla, hxa, hlb, hxb, hage, htier⟩ := hr
  have ha := conforms_digest hla hxa
  have hb := conforms_digest hlb hxb
  simp only [reqVal, RequestT, conforms, struct_request, requestDef, conformsAll, ha, hb,
    U8, U16, IntTy.bound, IntTy.bits]
  simp [hage, htier]

theorem conforms_authorise {r : Spec.Request} (hr : r.Admitted) :
    conforms prog (decisionVal (Spec.authorise r)) DecisionT = true := by
  have htier := hr.2.2.2.2.2
  unfold Spec.authorise
  by_cases h1 : r.account ≠ r.boundAccount
  · rw [if_pos h1]
    simp [decisionVal, DecisionT, conforms, struct_decision, decisionDef, conformsAll,
      U32, U16, IntTy.bound, IntTy.bits, Spec.Denial.tag]
  rw [if_neg h1]
  by_cases h2 : r.age < 18
  · rw [if_pos h2]
    simp [decisionVal, DecisionT, conforms, struct_decision, decisionDef, conformsAll,
      U32, U16, IntTy.bound, IntTy.bits, Spec.Denial.tag]
  rw [if_neg h2]
  by_cases h3 : r.tier < 100
  · rw [if_pos h3]
    simp [decisionVal, DecisionT, conforms, struct_decision, decisionDef, conformsAll,
      U32, U16, IntTy.bound, IntTy.bits, Spec.Denial.tag, htier]
  · rw [if_neg h3]
    simp [decisionVal, DecisionT, conforms, struct_decision, decisionDef, conformsAll,
      U32, U16, IntTy.bound, IntTy.bits]

/-! ## 6. The theorem -/

/-- The locals on entry, and after the binding `account := request account`. -/
def l0 (r : Spec.Request) : Locals := Locals.ofList [("request", reqVal r)]
def l1 (r : Spec.Request) : Locals := (l0 r).set "account" (digestVal r.account)

theorem l0_request (r : Spec.Request) : l0 r "request" = some (reqVal r) := by
  simp [l0, Locals.ofList, Locals.set]
theorem l1_request (r : Spec.Request) : l1 r "request" = some (reqVal r) := by
  simp [l1, l0, Locals.ofList, Locals.set]
theorem l1_account (r : Spec.Request) : l1 r "account" = some (digestVal r.account) := by
  simp [l1, Locals.set]

section fields
variable {l : Locals} {r : Spec.Request} (h : l "request" = some (reqVal r))
include h

theorem e_account : evalExpr l (.field (V "request") 0) = .ok (digestVal r.account) := by
  rw [evalExpr_field, V, evalExpr_var, h]
  simp only [reqVal, ebind_ok, fieldF_struct, List.getElem?_cons_zero, optVal_some]
theorem e_age : evalExpr l (.field (V "request") 1) = .ok (.int .u8 r.age) := by
  rw [evalExpr_field, V, evalExpr_var, h]
  simp only [reqVal, ebind_ok, fieldF_struct, List.getElem?_cons_succ, List.getElem?_cons_zero,
    optVal_some]
theorem e_bound : evalExpr l (.field (V "request") 2) = .ok (digestVal r.boundAccount) := by
  rw [evalExpr_field, V, evalExpr_var, h]
  simp only [reqVal, ebind_ok, fieldF_struct, List.getElem?_cons_succ, List.getElem?_cons_zero,
    optVal_some]
theorem e_tier : evalExpr l (.field (V "request") 3) = .ok (.int .u16 r.tier) := by
  rw [evalExpr_field, V, evalExpr_var, h]
  simp only [reqVal, ebind_ok, fieldF_struct, List.getElem?_cons_succ, List.getElem?_cons_zero,
    optVal_some]
end fields

theorem e_lit8 {l : Locals} {n : Nat} (h : n < 256) : evalExpr l (n8 n) = .ok (.int .u8 n) :=
  evalExpr_lit_int (by simpa [IntTy.bound, IntTy.bits] using h)
theorem e_lit16 {l : Locals} {n : Nat} (h : n < 65536) : evalExpr l (n16 n) = .ok (.int .u16 n) :=
  evalExpr_lit_int (by simpa [IntTy.bound, IntTy.bits] using h)
theorem e_lit32 {l : Locals} {n : Nat} (h : n < 4294967296) :
    evalExpr l (n32 n) = .ok (.int .u32 n) :=
  evalExpr_lit_int (by simpa [IntTy.bound, IntTy.bits] using h)

theorem e_rejection {l : Locals} {tag premise : Nat} {lim act : Expr} {a b : Nat}
    (ht : tag < 4294967296) (hp : premise < 4294967296)
    (hl : evalExpr l lim = .ok (.int .u16 a)) (ha : evalExpr l act = .ok (.int .u16 b)) :
    evalExpr l (rejection tag premise lim act) = .ok (.struct "Decision"
      [.int .u32 3, .int .u32 2, .int .u32 tag, .int .u32 premise, .int .u16 a, .int .u16 b]) := by
  simp only [rejection, evalExpr_mk, evalExprs_cons, evalExprs_nil, e_lit32 (by omega : 3 < _),
    e_lit32 (by omega : 2 < _), e_lit32 ht, e_lit32 hp, hl, ha, ebind_ok]

theorem gate_body (r : Spec.Request) (hr : r.Admitted) (env : Env) (m : Machine) (n : Nat) :
    exec prog L env (n + 10) m (l0 r) authoriseFun.body =
      .ret m (decisionVal (Spec.authorise r)) := by
  obtain ⟨hla, hxa, hlb, hxb, hage, htier⟩ := hr
  have hdiff := evalExpr_octDiff (l := l1 r) (a := V "account") (b := .field (V "request") 2)
    (xs := r.account) (ys := r.boundAccount)
    (by rw [V, evalExpr_var, l1_account]) (e_bound (l1_request r)) 32 (by omega) (by omega)
  have hcases := diffN_32_eq_zero hla hlb
  have hc1 : evalExpr (l1 r) (.bin .ne (octDiff (V "account") (.field (V "request") 2) 32) (n8 0)) =
      .ok (.bool (diffN r.account r.boundAccount 32 != 0)) := by
    rw [evalExpr_bin, hdiff, ebind_ok, e_lit8 (by omega), ebind_ok, evalBin_ne]
  have hc2 : evalExpr (l1 r) (.bin .lt (.field (V "request") 1) (n8 18)) =
      .ok (.bool (decide (r.age < 18))) := by
    rw [evalExpr_bin, e_age (l1_request r), ebind_ok, e_lit8 (by omega), ebind_ok, evalBin_lt]
  have hc3 : evalExpr (l1 r) (.bin .lt (.field (V "request") 3) (n16 100)) =
      .ok (.bool (decide (r.tier < 100))) := by
    rw [evalExpr_bin, e_tier (l1_request r), ebind_ok, e_lit16 (by omega), ebind_ok, evalBin_lt]
  have hv1 := e_rejection (l := l1 r) (tag := 1) (premise := 1) (by omega) (by omega)
    (e_lit16 (n := 0) (by omega)) (e_lit16 (n := 0) (by omega))
  have hv2 := e_rejection (l := l1 r) (tag := 2) (premise := 2) (by omega) (by omega)
    (e_lit16 (n := 0) (by omega)) (e_lit16 (n := 0) (by omega))
  have hv3 := e_rejection (l := l1 r) (tag := 5) (premise := 3) (by omega) (by omega)
    (e_lit16 (n := 100) (by omega)) (e_tier (l1_request r))
  have hv4 : evalExpr (l1 r) (.mk "Decision" [n32 3, n32 1, n32 0, n32 0, n16 0, n16 0]) =
      .ok (decisionVal .accept) := by
    simp only [evalExpr_mk, evalExprs_cons, evalExprs_nil, e_lit32 (by omega : 3 < _),
      e_lit32 (by omega : 1 < _), e_lit32 (by omega : 0 < _), e_lit16 (by omega : 0 < _),
      ebind_ok, decisionVal]
  have hassign : atomic prog L env m (l0 r) (.assign "account" (.field (V "request") 0)) =
      .normal m (l1 r) := by
    simp only [atomic, e_account (l0_request r), l1]
  simp only [authoriseFun, seqs, exec, hassign, hc1]
  unfold Spec.authorise
  by_cases h1 : r.account = r.boundAccount
  · have hz : diffN r.account r.boundAccount 32 = 0 := hcases.mpr h1
    simp only [hz, bne_self_eq_false, atomic_skip, hc2]
    rw [if_neg (fun h => h h1)]
    by_cases h2 : r.age < 18
    · rw [if_pos h2]
      simp only [h2, decide_true, atomic, hv2, decisionVal, Spec.Denial.tag]
    · rw [if_neg h2]
      simp only [h2, decide_false, hc3]
      by_cases h3 : r.tier < 100
      · rw [if_pos h3]
        simp only [h3, decide_true, atomic, hv3, decisionVal, Spec.Denial.tag]
      · rw [if_neg h3]
        simp only [h3, decide_false, atomic, hv4]
  · have hz : diffN r.account r.boundAccount 32 ≠ 0 := fun h => h1 (hcases.mp h)
    have hb : (diffN r.account r.boundAccount 32 != 0) = true := by simp [hz]
    simp only [hb, atomic, hv1]
    rw [if_pos h1]
    simp only [decisionVal, Spec.Denial.tag]


theorem fun_authorise : prog.fun? "authorise" = some authoriseFun := by rfl
theorem pointerFree_decision : prog.pointerFree? DecisionT = true := by decide

theorem inputOk_request {r : Spec.Request} (hr : r.Admitted) :
    prog.inputOk #[] authoriseFun [reqVal r] = true := by
  have hc := conforms_request hr
  simp only [reqVal, digestVal] at hc
  simp only [Program.inputOk, Program.argsOk, Program.conforms?, authoriseFun]
  simp [hc, reqVal, digestVal, ptrsInInputs, ptrsInInputsAll, ptrsIn_bytes]

/-- **The spike theorem.** For every admitted request and every environment,
    with enough fuel, the KCore run returns exactly the encoded meaning of the
    Seki kernel. The heap is the empty input heap, unchanged; the trace is
    empty, so no event occurred; nothing is owned. There is no environment
    under which it fails. -/
theorem gate_run (r : Spec.Request) (hr : r.Admitted) (env : Env) :
    ∀ fuel, 10 ≤ fuel →
      run prog L env fuel #[] "authorise" [reqVal r] =
        .ok (decisionVal (Spec.authorise r)) { blocks := #[], owned := [] } [] := by
  intro fuel hfuel
  obtain ⟨n, rfl⟩ : ∃ n, fuel = n + 10 := ⟨fuel - 10, by omega⟩
  have hbody := gate_body r hr env { heap := { blocks := #[], owned := [] }, trace := [] } n
  have hconf := conforms_authorise hr
  simp only [run, fun_authorise, inputOk_request hr, Bool.not_true]
  have hl : Locals.ofList (authoriseFun.paramNames.zip [reqVal r]) = l0 r := by rfl
  rw [hl, hbody]
  simp [Program.conforms?, authoriseFun, hconf, pointerFree_decision]

end SekiSpike.Gate
