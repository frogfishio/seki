/-
KCore program logic: total-correctness triples over the inductive semantics
`Exec` (KCore/BigStep.lean), with one proof rule per statement form, each
proved sound once.

    Valid P L env pre s post  :≡  ∀ m l, pre m l → ∃ r, Exec P L env m l s r ∧ post r

Because `Exec` never produces `oof`, a valid triple also proves termination.
A postcondition that is false on `stuck` proves the statement never gets
stuck (T4). Atomic statements need no dedicated rules: their obligation is
`post (atomic …)`, which is discharged by computing the shared step function.
-/
import KCore.BigStep

namespace KCore

variable {P : Program} {L : Layout} {env : Env}

def Valid (P : Program) (L : Layout) (env : Env) (pre : Machine → Locals → Prop) (s : Stmt)
    (post : Res → Prop) : Prop :=
  ∀ m l, pre m l → ∃ r, Exec P L env m l s r ∧ post r

/-- The continuation of a statement inside a sequence: normal completion must
    establish `mid`; an abrupt result (return, failure, stuck) must satisfy
    the final postcondition directly. -/
def seqPost (mid : Machine → Locals → Prop) (post : Res → Prop) : Res → Prop
  | .normal m l => mid m l
  | r => r.abrupt ∧ post r

/-! ## Structural rules -/

theorem Valid.conseq {pre pre' : Machine → Locals → Prop} {s : Stmt} {post post' : Res → Prop}
    (h : Valid P L env pre s post) (hpre : ∀ m l, pre' m l → pre m l)
    (hpost : ∀ r, post r → post' r) : Valid P L env pre' s post' := by
  intro m l hp
  obtain ⟨r, hr, hq⟩ := h m l (hpre m l hp)
  exact ⟨r, hr, hpost r hq⟩

theorem Valid.atomic {pre : Machine → Locals → Prop} {s : Stmt} {post : Res → Prop}
    (hs : s.isAtomic = true) (h : ∀ m l, pre m l → post (atomic P L env m l s)) :
    Valid P L env pre s post :=
  fun m l hp => ⟨_, .atom hs, h m l hp⟩

theorem Valid.seq {pre mid : Machine → Locals → Prop} {a b : Stmt} {post : Res → Prop}
    (ha : Valid P L env pre a (seqPost mid post)) (hb : Valid P L env mid b post) :
    Valid P L env pre (.seq a b) post := by
  intro m l hp
  obtain ⟨r, hr, hq⟩ := ha m l hp
  cases r with
  | normal m' l' =>
    obtain ⟨r', hr', hq'⟩ := hb m' l' hq
    exact ⟨r', .seqNormal hr hr', hq'⟩
  | oof => exact absurd rfl hr.ne_oof
  | _ => exact ⟨_, .seqAbrupt hr hq.1, hq.2⟩

theorem Valid.ite {pre : Machine → Locals → Prop} {c : Expr} {a b : Stmt} {post : Res → Prop}
    (hc : ∀ m l, pre m l → ∃ bv, evalExpr l c = .ok (.bool bv))
    (ha : Valid P L env (fun m l => pre m l ∧ evalExpr l c = .ok (.bool true)) a post)
    (hb : Valid P L env (fun m l => pre m l ∧ evalExpr l c = .ok (.bool false)) b post) :
    Valid P L env pre (.ite c a b) post := by
  intro m l hp
  obtain ⟨bv, hbv⟩ := hc m l hp
  cases bv with
  | true => obtain ⟨r, hr, hq⟩ := ha m l ⟨hp, hbv⟩; exact ⟨r, .iteTrue hbv hr, hq⟩
  | false => obtain ⟨r, hr, hq⟩ := hb m l ⟨hp, hbv⟩; exact ⟨r, .iteFalse hbv hr, hq⟩

/-- Total-correctness loop rule: an invariant `inv`, a natural-number
    variant `measure` that strictly decreases on every normal iteration, a
    boolean condition, the exit obligation, and the body obligation. -/
theorem Valid.while {inv : Machine → Locals → Prop} {measure : Machine → Locals → Nat}
    {c : Expr} {body : Stmt} {post : Res → Prop}
    (hc : ∀ m l, inv m l → ∃ bv, evalExpr l c = .ok (.bool bv))
    (hexit : ∀ m l, inv m l → evalExpr l c = .ok (.bool false) → post (.normal m l))
    (hbody : ∀ k, Valid P L env
      (fun m l => inv m l ∧ evalExpr l c = .ok (.bool true) ∧ measure m l = k) body
      (seqPost (fun m' l' => inv m' l' ∧ measure m' l' < k) post)) :
    Valid P L env inv (.while c body) post := by
  intro m l hp
  -- strong induction on the variant
  suffices ∀ k m l, measure m l = k → inv m l →
      ∃ r, Exec P L env m l (.while c body) r ∧ post r from this _ m l rfl hp
  intro k
  induction k using Nat.strongRecOn with
  | _ k ih =>
    intro m l hk hi
    obtain ⟨bv, hbv⟩ := hc m l hi
    cases bv with
    | false => exact ⟨_, .whileFalse hbv, hexit m l hi hbv⟩
    | true =>
      obtain ⟨r, hr, hq⟩ := hbody k m l ⟨hi, hbv, hk⟩
      cases r with
      | normal m' l' =>
        obtain ⟨hi', hlt⟩ := hq
        obtain ⟨r', hr', hq'⟩ := ih _ hlt m' l' rfl hi'
        exact ⟨r', .whileNormal hbv hr hr', hq'⟩
      | oof => exact absurd rfl hr.ne_oof
      | _ => exact ⟨_, .whileAbrupt hbv hr hq.1, hq.2⟩

/-- Call rule: the caller supplies, for every admissible state, evaluated
    arguments, the resolved callee, well-typed arguments and a valid triple
    for the callee body from its entry locals. A callee return must conform
    to the declared result (else the call is stuck); failure and stuck
    results propagate unchanged. -/
theorem Valid.call {pre : Machine → Locals → Prop} {x f : String} {args : List Expr}
    {post : Res → Prop}
    (h : ∀ m l, pre m l → ∃ vs g, evalExprs l args = .ok vs ∧ P.fun? f = some g ∧
      P.argsOk g vs = true ∧
      Valid P L env (fun m₀ l₀ => m₀ = m ∧ l₀ = Locals.ofList (g.paramNames.zip vs)) g.body
        (fun r => match r with
          | .ret m' v => P.conforms? v g.result = true ∧ post (.normal m' (l.set x v))
          | .normal _ _ => False
          | .oof => False
          | r => post r)) :
    Valid P L env pre (.call x f args) post := by
  intro m l hp
  obtain ⟨vs, g, hvs, hg, hok, hbody⟩ := h m l hp
  obtain ⟨r, hr, hq⟩ := hbody m _ ⟨rfl, rfl⟩
  cases r with
  | ret m' v => exact ⟨_, .callRet hvs hg hok hr hq.1, hq.2⟩
  | normal _ _ => exact absurd hq id
  | oof => exact absurd hq id
  | fail m' f' => exact ⟨_, .callPropagate hvs hg hok hr trivial, hq⟩
  | stuck m' w => exact ⟨_, .callPropagate hvs hg hok hr trivial, hq⟩

/-! ## From triples to transactions -/

/-- A valid triple for a statement yields the evaluator's result for all
    sufficiently large fuel. -/
theorem Valid.exec {pre : Machine → Locals → Prop} {s : Stmt} {post : Res → Prop}
    (h : Valid P L env pre s post) {m : Machine} {l : Locals} (hp : pre m l) :
    ∃ r n₀, post r ∧ r ≠ .oof ∧ ∀ n, n₀ ≤ n → exec P L env n m l s = r := by
  obtain ⟨r, hr, hq⟩ := h m l hp
  obtain ⟨n₀, hn⟩ := hr.to_exec
  exact ⟨r, n₀, hq, hr.ne_oof, fun n hle => exec_mono hle hn hr.ne_oof⟩

end KCore
