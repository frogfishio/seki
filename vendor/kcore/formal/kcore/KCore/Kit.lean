/-
Reusable proof kit for verified KCore programs.

  * `steps`: straight-line symbolic execution. A list of atomic statements
    executed in sequence has exactly the result `steps ss m l`, so a whole
    straight-line segment is discharged by computing one term
    (`Valid.straight`) instead of one intermediate assertion per statement.
  * `Arr`: a live integer block described by its length and a cell function,
    with load, pointer-arithmetic, store, allocation and free lemmas, and
    frame lemmas: an operation on one block leaves every other block's
    description unchanged.
-/
import KCore.Logic
import KCore.Examples

namespace KCore

open KCore.Examples (seqs)

variable {P : Program} {L : Layout} {env : Env}

/-! ## Straight-line segments -/

/-- Execute atomic statements in order, stopping at the first abrupt result. -/
def steps (P : Program) (L : Layout) (env : Env) : List Stmt → Machine → Locals → Res
  | [], m, l => .normal m l
  | s :: ss, m, l =>
      match atomic P L env m l s with
      | .normal m' l' => steps P L env ss m' l'
      | r => r

theorem exec_steps : ∀ (ss : List Stmt) (m : Machine) (l : Locals),
    (∀ s ∈ ss, s.isAtomic = true) → Exec P L env m l (seqs ss) (steps P L env ss m l)
  | [], m, l, _ => Exec.atom (s := .skip) rfl
  | [s], m, l, h => by
      have ha := Exec.atom (P := P) (L := L) (env := env) (m := m) (l := l) (h s (by simp))
      show Exec P L env m l s (steps P L env [s] m l)
      simp only [steps]
      cases hr : atomic P L env m l s <;> rw [hr] at ha <;> exact ha
  | s :: s' :: ss, m, l, h => by
      have ha := Exec.atom (P := P) (L := L) (env := env) (m := m) (l := l) (h s (by simp))
      show Exec P L env m l (.seq s (seqs (s' :: ss))) (steps P L env (s :: s' :: ss) m l)
      simp only [steps]
      cases hr : atomic P L env m l s with
      | normal m' l' =>
        rw [hr] at ha
        exact .seqNormal ha (exec_steps (s' :: ss) m' l' (fun x hx => h x (by simp [hx])))
      | oof => exact absurd hr atomic_ne_oof
      | ret m' v => rw [hr] at ha; exact .seqAbrupt ha trivial
      | fail m' f => rw [hr] at ha; exact .seqAbrupt ha trivial
      | stuck m' w => rw [hr] at ha; exact .seqAbrupt ha trivial

/-- Straight-line rule: the postcondition of the computed result. -/
theorem Valid.straight {pre : Machine → Locals → Prop} {ss : List Stmt} {post : Res → Prop}
    (hs : ∀ s ∈ ss, s.isAtomic = true) (h : ∀ m l, pre m l → post (steps P L env ss m l)) :
    Valid P L env pre (seqs ss) post :=
  fun m l hp => ⟨_, exec_steps ss m l hs, h m l hp⟩

theorem Locals.set_same {l : Locals} {x : String} {v : Val} : (l.set x v) x = some v := by
  simp [Locals.set]
theorem Locals.set_other {l : Locals} {x y : String} {v : Val} (h : y ≠ x) :
    (l.set x v) y = l y := by
  simp [Locals.set, h]

/-- Continuation of `steps` after one atomic result. -/
def stepsK (P : Program) (L : Layout) (env : Env) (ss : List Stmt) : Res → Res
  | .normal m l => steps P L env ss m l
  | r => r

/- Propositional unfolding of `steps` (see the note on `rfl` theorems at
   `ebind_ok`). -/
theorem steps_nil' {m : Machine} {l : Locals} : steps P L env [] m l = .normal m l := Eq.trans rfl rfl
theorem steps_cons' {s : Stmt} {ss : List Stmt} {m : Machine} {l : Locals} :
    steps P L env (s :: ss) m l = stepsK P L env ss (atomic P L env m l s) := by
  cases h : atomic P L env m l s <;> simp only [steps, stepsK, h]
theorem stepsK_normal {ss : List Stmt} {m : Machine} {l : Locals} :
    stepsK P L env ss (.normal m l) = steps P L env ss m l := Eq.trans rfl rfl
theorem stepsK_ret {ss : List Stmt} {m : Machine} {v : Val} :
    stepsK P L env ss (.ret m v) = .ret m v := Eq.trans rfl rfl
theorem stepsK_fail {ss : List Stmt} {m : Machine} {f : Failure} :
    stepsK P L env ss (.fail m f) = .fail m f := Eq.trans rfl rfl
theorem stepsK_stuck {ss : List Stmt} {m : Machine} {f : Fault} :
    stepsK P L env ss (.stuck m f) = .stuck m f := Eq.trans rfl rfl

/-- A straight-line prefix computed by `steps`, followed by any statements. -/
theorem Valid.steps_seq {pre mid : Machine → Locals → Prop} {post : Res → Prop} :
    ∀ (as rest : List Stmt), rest ≠ [] → (∀ s ∈ as, s.isAtomic = true) →
    (∀ m l, pre m l → seqPost mid post (steps P L env as m l)) →
    Valid P L env mid (seqs rest) post → Valid P L env pre (seqs (as ++ rest)) post
  | [], rest, _, _, h, hr => fun m l hp => by
      have := h m l hp
      simp only [steps, seqPost] at this
      exact hr m l this
  | a :: as, rest, hne, hat, h, hr => by
      have ha : a.isAtomic = true := hat a (by simp)
      have tail : as ++ rest ≠ [] := by simp [hne]
      have hs : seqs (a :: as ++ rest) = .seq a (seqs (as ++ rest)) := by
        cases hx : as ++ rest with
        | nil => exact absurd hx tail
        | cons y ys => simp only [List.cons_append, hx]; rfl
      rw [hs]
      intro m l hp
      have hm := h m l hp
      cases hr0 : KCore.atomic P L env m l a with
      | normal m' l' =>
        have ih := Valid.steps_seq (pre := fun m0 l0 => m0 = m' ∧ l0 = l') as rest hne
          (fun s hs => hat s (by simp [hs]))
          (fun m0 l0 ⟨e1, e2⟩ => by subst e1 e2; simpa [steps, hr0] using hm) hr
        obtain ⟨r, hr1, hq⟩ := ih m' l' ⟨rfl, rfl⟩
        have ex : Exec P L env m l a (.normal m' l') := hr0 ▸ Exec.atom ha
        exact ⟨r, .seqNormal ex hr1, hq⟩
      | oof => exact absurd hr0 atomic_ne_oof
      | ret m' v =>
        simp only [steps, hr0, seqPost] at hm
        have ex : Exec P L env m l a (.ret m' v) := hr0 ▸ Exec.atom ha
        exact ⟨_, .seqAbrupt ex trivial, hm.2⟩
      | fail m' f =>
        simp only [steps, hr0, seqPost] at hm
        have ex : Exec P L env m l a (.fail m' f) := hr0 ▸ Exec.atom ha
        exact ⟨_, .seqAbrupt ex trivial, hm.2⟩
      | stuck m' f =>
        simp only [steps, hr0, seqPost] at hm
        have ex : Exec P L env m l a (.stuck m' f) := hr0 ▸ Exec.atom ha
        exact ⟨_, .seqAbrupt ex trivial, hm.2⟩

/-- `fd`, entered in `m` with arguments `vs`, returns `v` and leaves the
    machine unchanged. -/
def Returns (P : Program) (L : Layout) (env : Env) (fd : FunDef) (m : Machine) (vs : List Val)
    (v : Val) : Prop :=
  Valid P L env (fun m0 l0 => m0 = m ∧ l0 = Locals.ofList (fd.paramNames.zip vs)) fd.body
    (fun r => r = .ret m v)

/-- A call to a function specified by `Returns`. -/
theorem Valid.callRet {pre : Machine → Locals → Prop} {x f : String} {args : List Expr}
    {g : FunDef} {post : Res → Prop} (hg : P.fun? f = some g)
    (h : ∀ m l, pre m l → ∃ vs v, evalExprs l args = .ok vs ∧ P.argsOk g vs = true ∧
      P.conforms? v g.result = true ∧ Returns P L env g m vs v ∧ post (.normal m (l.set x v))) :
    Valid P L env pre (.call x f args) post := by
  apply Valid.call
  intro m l hp
  obtain ⟨vs, v, hvs, hok, hc, hret, hpost⟩ := h m l hp
  refine ⟨vs, g, hvs, hg, hok, (hret.conseq (fun _ _ h => h) ?_)⟩
  intro r hr
  subst hr
  exact ⟨hc, hpost⟩

/-- Existential precondition: fix the witness. -/
theorem Valid.exists_pre {α : Sort _} {pre : α → Machine → Locals → Prop} {s : Stmt}
    {post : Res → Prop} (h : ∀ a, Valid P L env (pre a) s post) :
    Valid P L env (fun m l => ∃ a, pre a m l) s post :=
  fun m l ⟨a, hp⟩ => h a m l hp

/-- Pure conjunct of a precondition: assume it. -/
theorem Valid.pure_pre {φ : Prop} {pre : Machine → Locals → Prop} {s : Stmt} {post : Res → Prop}
    (h : φ → Valid P L env pre s post) : Valid P L env (fun m l => φ ∧ pre m l) s post :=
  fun m l ⟨hφ, hp⟩ => h hφ m l hp

theorem stepsK_ite {ss : List Stmt} {c : Prop} [Decidable c] {a b : Res} :
    stepsK P L env ss (if c then a else b) = if c then stepsK P L env ss a else stepsK P L env ss b := by
  split <;> rfl

theorem seqPost_ite {mid : Machine → Locals → Prop} {post : Res → Prop} {c : Prop} [Decidable c]
    {a b : Res} :
    seqPost mid post (if c then a else b) = if c then seqPost mid post a else seqPost mid post b := by
  split <;> rfl

section seqpost
variable {mid : Machine → Locals → Prop} {post : Res → Prop} {m : Machine}
theorem seqPost_normal {l : Locals} : seqPost mid post (.normal m l) = mid m l := Eq.trans rfl rfl
theorem seqPost_ret {v : Val} : seqPost mid post (.ret m v) = post (.ret m v) := by
  simp [seqPost, Res.abrupt]
theorem seqPost_fail {f : Failure} : seqPost mid post (.fail m f) = post (.fail m f) := by
  simp [seqPost, Res.abrupt]
theorem seqPost_stuck {f : Fault} : seqPost mid post (.stuck m f) = post (.stuck m f) := by
  simp [seqPost, Res.abrupt]
end seqpost

theorem steps_cons_normal {s : Stmt} {ss : List Stmt} {m m' : Machine} {l l' : Locals}
    (h : atomic P L env m l s = .normal m' l') :
    steps P L env (s :: ss) m l = steps P L env ss m' l' := by
  simp [steps, h]

theorem steps_append : ∀ (a b : List Stmt) (m : Machine) (l : Locals),
    steps P L env (a ++ b) m l =
      match steps P L env a m l with
      | .normal m' l' => steps P L env b m' l'
      | r => r
  | [], b, m, l => rfl
  | s :: a, b, m, l => by
      simp only [List.cons_append, steps]
      cases atomic P L env m l s <;> simp [steps_append a b]

/-! ## Operator evaluation

One lemma per operator, with the operator's side condition as a hypothesis.
Symbolic execution rewrites with these instead of unfolding `evalBin`, so an
undischarged side condition leaves a visible `evalBin` term rather than a
case split. -/

section ops
variable {w : IntTy} {a b : Nat}

theorem evalBin_add (h : a + b < w.bound) :
    evalBin .add (.int w a) (.int w b) = .ok (.int w (a + b)) := by simp [evalBin, mkInt, h]
theorem evalBin_sub (h : b ≤ a) :
    evalBin .sub (.int w a) (.int w b) = .ok (.int w (a - b)) := by simp [evalBin, h]
theorem evalBin_mul (h : a * b < w.bound) :
    evalBin .mul (.int w a) (.int w b) = .ok (.int w (a * b)) := by simp [evalBin, mkInt, h]
theorem evalBin_div (h : b ≠ 0) :
    evalBin .div (.int w a) (.int w b) = .ok (.int w (a / b)) := by simp [evalBin, h]
theorem evalBin_wadd :
    evalBin .wadd (.int w a) (.int w b) = .ok (.int w ((a + b) % w.bound)) := by simp [evalBin]
theorem evalBin_band : evalBin .band (.int w a) (.int w b) = .ok (.int w (a &&& b)) := by
  simp [evalBin]
theorem evalBin_bor : evalBin .bor (.int w a) (.int w b) = .ok (.int w (a ||| b)) := by
  simp [evalBin]
theorem evalBin_bxor : evalBin .bxor (.int w a) (.int w b) = .ok (.int w (a ^^^ b)) := by
  simp [evalBin]
theorem evalBin_shr (h : b < w.bits) :
    evalBin .shr (.int w a) (.int w b) = .ok (.int w (a >>> b)) := by simp [evalBin, h]
theorem evalBin_wshl (h : b < w.bits) :
    evalBin .wshl (.int w a) (.int w b) = .ok (.int w ((a <<< b) % w.bound)) := by
  simp [evalBin, h]
theorem evalBin_lt : evalBin .lt (.int w a) (.int w b) = .ok (.bool (decide (a < b))) := by
  simp [evalBin]
theorem evalUn_bnot : evalUn .bnot (.int w a) = .ok (.int w (w.bound - 1 - a)) := Eq.trans rfl rfl
theorem evalBin_eq : evalBin .eq (.int w a) (.int w b) = .ok (.bool (a == b)) := by simp [evalBin]
theorem evalBin_ne : evalBin .ne (.int w a) (.int w b) = .ok (.bool (a != b)) := by simp [evalBin]
theorem evalBin_le : evalBin .le (.int w a) (.int w b) = .ok (.bool (decide (a ≤ b))) := by
  simp [evalBin]
theorem evalBin_wsub :
    evalBin .wsub (.int w a) (.int w b) = .ok (.int w ((a + w.bound - b) % w.bound)) := by
  simp [evalBin]
theorem evalBin_beq {p q : Bool} : evalBin .eq (.bool p) (.bool q) = .ok (.bool (p == q)) := by
  simp [evalBin]
theorem evalBin_bne {p q : Bool} : evalBin .ne (.bool p) (.bool q) = .ok (.bool (p != q)) := by
  simp [evalBin]
theorem evalBin_land {p q : Bool} : evalBin .land (.bool p) (.bool q) = .ok (.bool (p && q)) := by
  simp [evalBin]
theorem evalBin_lor {p q : Bool} : evalBin .lor (.bool p) (.bool q) = .ok (.bool (p || q)) := by
  simp [evalBin]
theorem evalUn_lnot {p : Bool} : evalUn .lnot (.bool p) = .ok (.bool (!p)) := by simp [evalUn]
theorem evalUn_zext {to : IntTy} (h : w.bits ≤ to.bits) :
    evalUn (.zext to) (.int w a) = .ok (.int to a) := by simp [evalUn, h]
theorem evalUn_trunc {to : IntTy} (h : to.bits ≤ w.bits) :
    evalUn (.trunc to) (.int w a) = .ok (.int to (a % to.bound)) := by simp [evalUn, h]
theorem conforms_int {P : Program} (h : a < w.bound) : conforms P (.int w a) (.int w) = true := by
  simp [conforms, h]
theorem evalExpr_lit_int {l : Locals} (h : a < w.bound) :
    evalExpr l (.lit (.int w a)) = .ok (.int w a) := by simp [evalExpr, Val.isLiteral, h]

/- Structural evaluation lemmas. Symbolic execution uses these instead of
   unfolding `evalExpr`, so a literal is only ever evaluated through
   `evalExpr_lit_int`, whose range condition goes to the discharger.

   Every lemma used for symbolic execution is deliberately *not* an `rfl`
   theorem (`Eq.trans rfl rfl`, or a tactic proof). `simp` applies `rfl`
   theorems as definitional rewrites and leaves the equality to the kernel,
   whose unfolding order can then expand `evalBin` and a product such as
   `x * 16777216` in unary. Propositional rewrites leave no such check. -/
theorem ebind_ok {ε α β : Type} {a : α} {f : α → Except ε β} :
    (Except.ok a : Except ε α).bind f = f a := Eq.trans rfl rfl
theorem ebind_error {ε α β : Type} {e : ε} {f : α → Except ε β} :
    (Except.error e : Except ε α).bind f = .error e := Eq.trans rfl rfl
theorem evalExpr_var {l : Locals} {x : String} :
    evalExpr l (.var x) = (match l x with | some v => .ok v | none => .error .typing) := by
  cases h : l x <;> simp [evalExpr, h]
theorem evalExpr_bin {l : Locals} {op : BinOp} {e₁ e₂ : Expr} :
    evalExpr l (.bin op e₁ e₂) =
      (evalExpr l e₁).bind (fun a => (evalExpr l e₂).bind (fun b => evalBin op a b)) := by
  simp only [evalExpr]; exact Eq.trans rfl rfl
theorem evalExpr_un {l : Locals} {op : UnOp} {e : Expr} :
    evalExpr l (.un op e) = (evalExpr l e).bind (fun a => evalUn op a) := by
  simp only [evalExpr]; exact Eq.trans rfl rfl
theorem evalExpr_lit_bool {l : Locals} {b : Bool} : evalExpr l (.lit (.bool b)) = .ok (.bool b) := by
  simp [evalExpr, Val.isLiteral]
/-- Field selection, as a named function so that its reduction is
    propositional. -/
def fieldF (i : Nat) : Val → Eval Val
  | .struct _ fs => match fs[i]? with
      | some v => .ok v
      | none => .error .typing
  | _ => .error .typing
theorem evalExpr_field {l : Locals} {e : Expr} {i : Nat} :
    evalExpr l (.field e i) = (evalExpr l e).bind (fieldF i) := by
  simp only [evalExpr]; cases evalExpr l e <;> exact Eq.trans rfl rfl
def optVal : Option Val → Eval Val
  | some v => .ok v
  | none => .error .typing
theorem fieldF_struct {n : String} {fs : List Val} {i : Nat} :
    fieldF i (.struct n fs) = optVal fs[i]? := by
  cases h : fs[i]? <;> simp [fieldF, optVal, h]
theorem optVal_some {v : Val} : optVal (some v) = .ok v := Eq.trans rfl rfl
theorem evalExpr_mk {l : Locals} {n : String} {es : List Expr} :
    evalExpr l (.mk n es) = (evalExprs l es).bind (fun vs => .ok (.struct n vs)) := by
  simp only [evalExpr]; exact Eq.trans rfl rfl
theorem evalExprs_nil {l : Locals} : evalExprs l [] = .ok [] := by simp [evalExprs]
theorem evalExprs_cons {l : Locals} {e : Expr} {es : List Expr} :
    evalExprs l (e :: es) =
      (evalExpr l e).bind (fun v => (evalExprs l es).bind (fun vs => .ok (v :: vs))) := by
  simp only [evalExprs]; exact Eq.trans rfl rfl

end ops

/-! ## Propositional statement semantics

`atomic` computes by nested `match`. When `simp` reduces those matches it
does so definitionally, and the kernel must then re-establish each step by
unfolding; its unfolding order can evaluate the program's checked arithmetic
in unary (minutes for a single `x * 16777216`). Symbolic execution therefore
rewrites `atomic` into small continuation functions whose reduction lemmas
are propositional. -/

section kont
variable {P : Program} {L : Layout} {env : Env} {m : Machine} {l : Locals} {x : String}

def assignK (m : Machine) (l : Locals) (x : String) : Eval Val → Res
  | .ok v => .normal m (l.set x v)
  | .error f => .stuck m f

def loadK2 (m : Machine) (l : Locals) (x : String) : Eval Val → Res
  | .ok v => .normal m (l.set x v)
  | .error f => .stuck m f

def loadK (m : Machine) (l : Locals) (x : String) : Eval Val → Res
  | .ok (.ptr t (.loc b o)) => loadK2 m l x (m.heap.load? t b o)
  | .ok (.ptr _ .null) => .stuck m .bounds
  | .ok _ => .stuck m .typing
  | .error f => .stuck m f

def heapK (m : Machine) (l : Locals) : Eval Heap → Res
  | .ok h => .normal { m with heap := h } l
  | .error f => .stuck m f

def storeK (P : Program) (m : Machine) (l : Locals) : Eval Val → Eval Val → Res
  | .error f, _ => .stuck m f
  | _, .error f => .stuck m f
  | .ok (.ptr t (.loc b o)), .ok v =>
      if P.conforms? v t then heapK m l (m.heap.store? t b o v) else .stuck m .typing
  | .ok (.ptr _ .null), .ok _ => .stuck m .bounds
  | .ok _, .ok _ => .stuck m .typing

def ptrAddK2 (m : Machine) (l : Locals) (x : String) (t : Ty) (b : Nat) : Eval Nat → Res
  | .ok o' => .normal m (l.set x (.ptr t (.loc b o')))
  | .error f => .stuck m f

def ptrAddK (m : Machine) (l : Locals) (x : String) : Eval Val → Eval Val → Res
  | .error f, _ => .stuck m f
  | _, .error f => .stuck m f
  | .ok (.ptr t (.loc b o)), .ok (.int .u64 k) => ptrAddK2 m l x t b (m.heap.ptrAdd? b o k)
  | .ok (.ptr _ .null), .ok (.int .u64 _) => .stuck m .bounds
  | .ok _, .ok _ => .stuck m .typing

def freeK (m : Machine) (l : Locals) : Eval Val → Res
  | .ok (.ptr _ (.loc b 0)) => heapK m l (m.heap.free? b)
  | .ok (.ptr _ _) => .stuck m .bounds
  | .ok _ => .stuck m .typing
  | .error f => .stuck m f

def retK (m : Machine) : Eval Val → Res
  | .ok v => .ret m v
  | .error f => .stuck m f

/-- Allocation after the count has been evaluated and found admissible. -/
def allocOk (env : Env) (m : Machine) (l : Locals) (x : String) (t : Ty) (k : Nat)
    (z : Val) : Res :=
  if env m.trace.length (.alloc t k) then
    .normal { m.record (.alloc t k) true with heap := (m.heap.alloc t k z).1 }
      (l.set x (.ptr t (.loc m.heap.blocks.size 0)))
  else .fail (m.record (.alloc t k) false) .allocationFailed

theorem atomic_skip : atomic P L env m l .skip = .normal m l := Eq.trans rfl rfl
theorem atomic_assign {e : Expr} : atomic P L env m l (.assign x e) = assignK m l x (evalExpr l e) := by
  cases h : evalExpr l e <;> simp [atomic, assignK, h]
theorem atomic_load {pe : Expr} : atomic P L env m l (.load x pe) = loadK m l x (evalExpr l pe) := by
  unfold atomic loadK loadK2; exact Eq.trans rfl rfl
theorem atomic_store {pe ve : Expr} :
    atomic P L env m l (.store pe ve) = storeK P m l (evalExpr l pe) (evalExpr l ve) := by
  unfold atomic storeK heapK; exact Eq.trans rfl rfl
theorem atomic_ptrAdd {pe ke : Expr} :
    atomic P L env m l (.ptrAdd x pe ke) = ptrAddK m l x (evalExpr l pe) (evalExpr l ke) := by
  unfold atomic ptrAddK ptrAddK2; exact Eq.trans rfl rfl
theorem atomic_free {pe : Expr} : atomic P L env m l (.free pe) = freeK m l (evalExpr l pe) := by
  unfold atomic freeK heapK; exact Eq.trans rfl rfl
theorem atomic_ret {e : Expr} : atomic P L env m l (.ret e) = retK m (evalExpr l e) := by
  unfold atomic retK; exact Eq.trans rfl rfl
theorem atomic_checkpoint :
    atomic P L env m l .checkpoint =
      if env m.trace.length .cancel then .normal (m.record .cancel true) l
      else .fail (m.record .cancel false) .cancelled := by
  unfold atomic; cases env m.trace.length .cancel <;> exact Eq.trans rfl rfl
def allocK (P : Program) (L : Layout) (env : Env) (m : Machine) (l : Locals) (x : String)
    (t : Ty) : Eval Val → Res
  | .ok (.int .u64 k) =>
      if k = 0 ∨ L.maxCount t < k then .stuck m .alloc else
      match P.zero? t with
      | none => .stuck m .typing
      | some z =>
          let ev := Event.alloc t k
          let ok := env m.trace.length ev
          let m' := m.record ev ok
          if ok then
            let (h, b) := m'.heap.alloc t k z
            .normal { m' with heap := h } (l.set x (.ptr t (.loc b 0)))
          else .fail m' .allocationFailed
  | .ok _ => .stuck m .typing
  | .error f => .stuck m f

theorem atomic_alloc {t : Ty} {ce : Expr} :
    atomic P L env m l (.alloc x t ce) = allocK P L env m l x t (evalExpr l ce) := by
  unfold atomic allocK; exact Eq.trans rfl rfl

/-- Allocation of an integer block with an admissible count. -/
theorem allocK_int {w : IntTy} {k : Nat} (h0 : 0 < k) (hmax : k ≤ L.maxCount (.int w)) :
    allocK P L env m l x (.int w) (.ok (.int .u64 k)) = allocOk env m l x (.int w) k (.int w 0) := by
  have : ¬ (k = 0 ∨ L.maxCount (.int w) < k) := by omega
  simp only [allocK, this, if_false, allocOk]
  simp [Program.zero?, zeroOf, Machine.record]
  cases env m.trace.length (.alloc (.int w) k) <;> simp [Heap.alloc]

/-- Allocation of a block of any type with a typed zero, with an admissible count. -/
theorem allocK_ok {t : Ty} {k : Nat} {z : Val} (h0 : 0 < k) (hmax : k ≤ L.maxCount t)
    (hz : P.zero? t = some z) :
    allocK P L env m l x t (.ok (.int .u64 k)) = allocOk env m l x t k z := by
  have : ¬ (k = 0 ∨ L.maxCount t < k) := by omega
  simp only [allocK, this, if_false, hz, allocOk]
  cases env m.trace.length (.alloc t k) <;> simp [Machine.record, Heap.alloc]

theorem assignK_ok {v : Val} : assignK m l x (.ok v) = .normal m (l.set x v) := Eq.trans rfl rfl
theorem loadK_ok {t : Ty} {b o : Nat} :
    loadK m l x (.ok (.ptr t (.loc b o))) = loadK2 m l x (m.heap.load? t b o) := Eq.trans rfl rfl
theorem loadK2_ok {v : Val} : loadK2 m l x (.ok v) = .normal m (l.set x v) := Eq.trans rfl rfl
theorem heapK_ok {h : Heap} : heapK m l (.ok h) = .normal { m with heap := h } l := Eq.trans rfl rfl
theorem storeK_int {w : IntTy} {b o a : Nat} (h : a < w.bound) :
    storeK P m l (.ok (.ptr (.int w) (.loc b o))) (.ok (.int w a)) =
      heapK m l (m.heap.store? (.int w) b o (.int w a)) := by
  simp [storeK, Program.conforms?, conforms, h]
theorem ptrAddK_ok {t : Ty} {b o k : Nat} :
    ptrAddK m l x (.ok (.ptr t (.loc b o))) (.ok (.int .u64 k)) = ptrAddK2 m l x t b (m.heap.ptrAdd? b o k) :=
  Eq.trans rfl rfl
theorem ptrAddK2_ok {t : Ty} {b o' : Nat} :
    ptrAddK2 m l x t b (.ok o') = .normal m (l.set x (.ptr t (.loc b o'))) := Eq.trans rfl rfl
theorem freeK_ok {t : Ty} {b : Nat} : freeK m l (.ok (.ptr t (.loc b 0))) = heapK m l (m.heap.free? b) := by
  simp [freeK]
theorem retK_ok {v : Val} : retK m (.ok v) = .ret m v := Eq.trans rfl rfl

theorem Machine.record_heap {ev : Event} {ok : Bool} : (m.record ev ok).heap = m.heap := Eq.trans rfl rfl

end kont

theorem IntTy.bound_u8 : IntTy.bound .u8 = 256 := by decide
theorem IntTy.bound_u16 : IntTy.bound .u16 = 65536 := by decide
theorem IntTy.bound_u32 : IntTy.bound .u32 = 4294967296 := by decide
theorem IntTy.bound_u64 : IntTy.bound .u64 = 18446744073709551616 := by decide
theorem IntTy.bits_u8 : IntTy.bits .u8 = 8 := by decide
theorem IntTy.bits_u16 : IntTy.bits .u16 = 16 := by decide
theorem IntTy.bits_u32 : IntTy.bits .u32 = 32 := by decide
theorem IntTy.bits_u64 : IntTy.bits .u64 = 64 := by decide

/-- Discharger for symbolic execution side conditions: linear arithmetic
    over the local context, after normalizing integer widths to numerals.
    Never `decide`: deciding a comparison with a free variable against 2⁶⁴
    unfolds `Nat.ble` in unary and does not terminate in practice. -/
macro "kdisch" : tactic => `(tactic| first
  | omega
  | (simp only [IntTy.bound_u8, IntTy.bound_u16, IntTy.bound_u32, IntTy.bound_u64, IntTy.bits_u8,
      IntTy.bits_u16, IntTy.bits_u32, IntTy.bits_u64, ne_eq] <;> omega)
  | (simp only [ne_eq, String.reduceEq, not_false_eq_true]))

/-- Symbolic execution: computes `steps`/`atomic` with the operator lemmas,
    discharging their side conditions with `kdisch`. -/
syntax "kstep" " [" Lean.Parser.Tactic.simpArg,* "]" (" at " ident)? : tactic
macro_rules
  | `(tactic| kstep [$ts,*]) => `(tactic| simp (disch := kdisch) [steps_nil', steps_cons', stepsK_normal, stepsK_ret,
      stepsK_fail, stepsK_stuck, stepsK_ite, seqPost_ite, seqPost_normal, seqPost_ret,
      seqPost_fail, seqPost_stuck, allocOk, atomic_skip, atomic_assign, atomic_load, atomic_store,
      atomic_ptrAdd, atomic_free, atomic_ret, atomic_checkpoint, atomic_alloc, allocK_int, assignK_ok,
      loadK_ok, loadK2_ok, heapK_ok, storeK_int, ptrAddK_ok, ptrAddK2_ok, freeK_ok, retK_ok,
      Machine.record_heap, IntTy.bound_u8, IntTy.bound_u16, IntTy.bound_u32, IntTy.bound_u64,
      IntTy.bits_u8, IntTy.bits_u16, IntTy.bits_u32, IntTy.bits_u64, evalExpr_var, evalExpr_lit_bool,
      evalBin_eq, evalBin_ne, evalBin_le, evalBin_wsub, evalBin_beq, evalBin_bne, evalBin_land,
      evalBin_lor, evalUn_lnot, evalExpr_field, fieldF_struct, optVal_some,
      List.getElem?_cons_zero, List.getElem?_cons_succ,
      evalExpr_bin, evalExpr_un, evalExpr_mk, evalExprs_nil, evalExprs_cons, evalExpr_lit_int,
      ebind_ok, ebind_error, Locals.set_same, Locals.set_other,
      evalBin_add, evalBin_sub, evalBin_mul, evalBin_div, evalBin_wadd, evalBin_band, evalBin_bor,
      evalBin_bxor, evalBin_shr, evalBin_wshl, evalBin_lt, evalUn_bnot, evalUn_zext, evalUn_trunc,
      $ts,*])
  | `(tactic| kstep [$ts,*] at $h:ident) => `(tactic| simp (disch := kdisch) [steps_nil', steps_cons', stepsK_normal, stepsK_ret,
      stepsK_fail, stepsK_stuck, stepsK_ite, seqPost_ite, seqPost_normal, seqPost_ret,
      seqPost_fail, seqPost_stuck, allocOk, atomic_skip, atomic_assign, atomic_load, atomic_store,
      atomic_ptrAdd, atomic_free, atomic_ret, atomic_checkpoint, atomic_alloc, allocK_int, assignK_ok,
      loadK_ok, loadK2_ok, heapK_ok, storeK_int, ptrAddK_ok, ptrAddK2_ok, freeK_ok, retK_ok,
      Machine.record_heap, IntTy.bound_u8, IntTy.bound_u16, IntTy.bound_u32, IntTy.bound_u64,
      IntTy.bits_u8, IntTy.bits_u16, IntTy.bits_u32, IntTy.bits_u64, evalExpr_var, evalExpr_lit_bool,
      evalBin_eq, evalBin_ne, evalBin_le, evalBin_wsub, evalBin_beq, evalBin_bne, evalBin_land,
      evalBin_lor, evalUn_lnot, evalExpr_field, fieldF_struct, optVal_some,
      List.getElem?_cons_zero, List.getElem?_cons_succ,
      evalExpr_bin, evalExpr_un, evalExpr_mk, evalExprs_nil, evalExprs_cons, evalExpr_lit_int,
      ebind_ok, ebind_error, Locals.set_same, Locals.set_other,
      evalBin_add, evalBin_sub, evalBin_mul, evalBin_div, evalBin_wadd, evalBin_band, evalBin_bor,
      evalBin_bxor, evalBin_shr, evalBin_wshl, evalBin_lt, evalUn_bnot, evalUn_zext, evalUn_trunc,
      $ts,*] at $h:ident)

/-! ## Integer arrays -/

/-- Block `b` is a live `w`-integer block of length `n` whose cell `j` holds `f j`. -/
def Arr (h : Heap) (b : Nat) (w : IntTy) (n : Nat) (f : Nat → Nat) : Prop :=
  ∃ blk, h.blocks[b]? = some blk ∧ blk.ty = .int w ∧ blk.live = true ∧ blk.cells.size = n ∧
    ∀ j, j < n → blk.cells[j]? = some (.int w (f j))

/-- Function update at one index. -/
def upd (f : Nat → Nat) (i x : Nat) : Nat → Nat := fun j => if j = i then x else f j

/-- The heap after a successful in-bounds store (as computed by `store?`). -/
def Heap.setCell (h : Heap) (b i : Nat) (v : Val) : Heap :=
  match h.blocks[b]? with
  | some blk => { h with blocks := h.blocks.set! b { blk with cells := blk.cells.set! i v } }
  | none => h

section arr
variable {h : Heap} {b : Nat} {w : IntTy} {n : Nat} {f : Nat → Nat}

theorem Arr.lt (ha : Arr h b w n f) : b < h.blocks.size := by
  obtain ⟨blk, hb, -⟩ := ha
  exact (Array.getElem?_eq_some_iff.mp hb).1

theorem Arr.congr (ha : Arr h b w n f) {g : Nat → Nat} (hg : ∀ j, j < n → f j = g j) :
    Arr h b w n g := by
  obtain ⟨blk, hb, ht, hl, hs, hc⟩ := ha
  exact ⟨blk, hb, ht, hl, hs, fun j hj => by rw [← hg j hj]; exact hc j hj⟩

/-- Frame: a heap that agrees on block `b` has the same description of it. -/
theorem Arr.frame (ha : Arr h b w n f) {h' : Heap} (he : h'.blocks[b]? = h.blocks[b]?) :
    Arr h' b w n f := by
  obtain ⟨blk, hb, rest⟩ := ha
  exact ⟨blk, he.trans hb, rest⟩

theorem Arr.load (ha : Arr h b w n f) {j : Nat} (hj : j < n) :
    h.load? (.int w) b j = .ok (.int w (f j)) := by
  obtain ⟨blk, hb, ht, hl, -, hc⟩ := ha
  simp [Heap.load?, hb, ht, hl, hc j hj]

theorem Arr.ptrAdd (ha : Arr h b w n f) {o k : Nat} (hk : o + k ≤ n) :
    h.ptrAdd? b o k = .ok (o + k) := by
  obtain ⟨blk, hb, -, hl, hs, -⟩ := ha
  simp [Heap.ptrAdd?, hb, hl, hs, hk]

theorem Arr.store (ha : Arr h b w n f) {i x : Nat} (hi : i < n) :
    h.store? (.int w) b i (.int w x) = .ok (h.setCell b i (.int w x)) := by
  obtain ⟨blk, hb, ht, hl, hs, -⟩ := ha
  simp [Heap.store?, Heap.setCell, hb, ht, hl, hs, hi, Val.ty]

theorem Arr.setCell (ha : Arr h b w n f) {i x : Nat} (hi : i < n) :
    Arr (h.setCell b i (.int w x)) b w n (upd f i x) := by
  obtain ⟨blk, hb, ht, hl, hs, hc⟩ := ha
  obtain ⟨hbl, hget⟩ := Array.getElem?_eq_some_iff.mp hb
  refine ⟨{ blk with cells := blk.cells.set! i (.int w x) }, ?_, ht, hl, ?_, fun j hj => ?_⟩
  · simp [Heap.setCell, Array.set!_eq_setIfInBounds, hbl, hget]
  · simp [Array.set!_eq_setIfInBounds, hs]
  · simp only [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds, upd]
    by_cases hij : i = j
    · subst hij; simp [hs, hi]
    · simp [hij, Ne.symm hij, hc j hj]

end arr

theorem Heap.setCell_other {h : Heap} {b b' i : Nat} {v : Val} (hne : b' ≠ b) :
    (h.setCell b i v).blocks[b']? = h.blocks[b']? := by
  unfold Heap.setCell
  split
  · simp [Array.set!_eq_setIfInBounds, Ne.symm hne]
  · rfl

@[simp] theorem Heap.setCell_owned {h : Heap} {b i : Nat} {v : Val} :
    (h.setCell b i v).owned = h.owned := by
  unfold Heap.setCell; split <;> rfl

@[simp] theorem Heap.setCell_size {h : Heap} {b i : Nat} {v : Val} :
    (h.setCell b i v).blocks.size = h.blocks.size := by
  unfold Heap.setCell; split <;> simp [Array.set!_eq_setIfInBounds]

/-! ### Arrays of arbitrary values (e.g. struct records) -/

/-- Block `b` is a live block of element type `t` and length `n` whose cell
    `j` holds `f j`. -/
def ArrV (h : Heap) (b : Nat) (t : Ty) (n : Nat) (f : Nat → Val) : Prop :=
  ∃ blk, h.blocks[b]? = some blk ∧ blk.ty = t ∧ blk.live = true ∧ blk.cells.size = n ∧
    ∀ j, j < n → blk.cells[j]? = some (f j)

def updV (f : Nat → Val) (i : Nat) (v : Val) : Nat → Val := fun j => if j = i then v else f j

section arrv
variable {h : Heap} {b : Nat} {t : Ty} {n : Nat} {f : Nat → Val}

theorem ArrV.frame (ha : ArrV h b t n f) {h' : Heap} (he : h'.blocks[b]? = h.blocks[b]?) :
    ArrV h' b t n f := by
  obtain ⟨blk, hb, rest⟩ := ha
  exact ⟨blk, he.trans hb, rest⟩

theorem ArrV.congr (ha : ArrV h b t n f) {g : Nat → Val} (hg : ∀ j, j < n → f j = g j) :
    ArrV h b t n g := by
  obtain ⟨blk, hb, ht, hl, hs, hc⟩ := ha
  exact ⟨blk, hb, ht, hl, hs, fun j hj => by rw [← hg j hj]; exact hc j hj⟩

theorem ArrV.load (ha : ArrV h b t n f) {j : Nat} (hj : j < n) : h.load? t b j = .ok (f j) := by
  obtain ⟨blk, hb, ht, hl, -, hc⟩ := ha
  simp [Heap.load?, hb, ht, hl, hc j hj]

theorem ArrV.ptrAdd (ha : ArrV h b t n f) {o k : Nat} (hk : o + k ≤ n) :
    h.ptrAdd? b o k = .ok (o + k) := by
  obtain ⟨blk, hb, -, hl, hs, -⟩ := ha
  simp [Heap.ptrAdd?, hb, hl, hs, hk]

theorem ArrV.store (ha : ArrV h b t n f) {i : Nat} {v : Val} (hi : i < n) (hv : v.ty = t) :
    h.store? t b i v = .ok (h.setCell b i v) := by
  obtain ⟨blk, hb, ht, hl, hs, -⟩ := ha
  simp [Heap.store?, Heap.setCell, hb, ht, hl, hs, hi, hv]

theorem ArrV.setCell (ha : ArrV h b t n f) {i : Nat} {v : Val} (hi : i < n) :
    ArrV (h.setCell b i v) b t n (updV f i v) := by
  obtain ⟨blk, hb, ht, hl, hs, hc⟩ := ha
  obtain ⟨hbl, hget⟩ := Array.getElem?_eq_some_iff.mp hb
  refine ⟨{ blk with cells := blk.cells.set! i v }, ?_, ht, hl, ?_, fun j hj => ?_⟩
  · simp [Heap.setCell, Array.set!_eq_setIfInBounds, hbl, hget]
  · simp [Array.set!_eq_setIfInBounds, hs]
  · simp only [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds, updV]
    by_cases hij : i = j
    · subst hij; simp [hs, hi]
    · simp [hij, Ne.symm hij, hc j hj]

end arrv

/-- A store of any conforming value (`storeK_int` specialized to integers). -/
theorem storeK_val {P : Program} {m : Machine} {l : Locals} {t : Ty} {b o : Nat} {v : Val}
    (h : P.conforms? v t = true) :
    storeK P m l (.ok (.ptr t (.loc b o))) (.ok v) = heapK m l (m.heap.store? t b o v) := by
  simp [storeK, h]

/-! ### Allocation and free -/

theorem Heap.alloc_arr {h : Heap} {w : IntTy} {n : Nat} :
    Arr (h.alloc (.int w) n (.int w 0)).1 h.blocks.size w n (fun _ => 0) :=
  ⟨{ ty := .int w, cells := Array.replicate n (.int w 0), live := true },
    by simp [Heap.alloc], rfl, rfl, by simp, fun j hj => by simp [hj]⟩

@[simp] theorem Heap.alloc_snd {h : Heap} {t : Ty} {n : Nat} {z : Val} :
    (h.alloc t n z).2 = h.blocks.size := rfl

@[simp] theorem Heap.alloc_owned {h : Heap} {t : Ty} {n : Nat} {z : Val} :
    (h.alloc t n z).1.owned = h.blocks.size :: h.owned := rfl

@[simp] theorem Heap.alloc_size {h : Heap} {t : Ty} {n : Nat} {z : Val} :
    (h.alloc t n z).1.blocks.size = h.blocks.size + 1 := by
  simp [Heap.alloc]

theorem Heap.alloc_old {h : Heap} {t : Ty} {n : Nat} {z : Val} {b : Nat} (hb : b < h.blocks.size) :
    (h.alloc t n z).1.blocks[b]? = h.blocks[b]? := by
  simp [Heap.alloc, Array.getElem?_push, Nat.ne_of_lt hb]

theorem Heap.alloc_arrV {h : Heap} {t : Ty} {n : Nat} {z : Val} :
    ArrV (h.alloc t n z).1 h.blocks.size t n (fun _ => z) :=
  ⟨{ ty := t, cells := Array.replicate n z, live := true },
    by simp [Heap.alloc], rfl, rfl, by simp, fun j hj => by simp [hj]⟩

/-- The heap after a successful free (as computed by `free?`). -/
def Heap.kill (h : Heap) (b : Nat) : Heap :=
  match h.blocks[b]? with
  | some blk => { blocks := h.blocks.set! b { blk with live := false }, owned := h.owned.erase b }
  | none => h

theorem Arr.free {h : Heap} {b : Nat} {w : IntTy} {n : Nat} {f : Nat → Nat}
    (ha : Arr h b w n f) (hown : b ∈ h.owned) : h.free? b = .ok (h.kill b) := by
  obtain ⟨blk, hb, -, hl, -⟩ := ha
  simp [Heap.free?, Heap.kill, hb, hl, hown]

theorem Arr.kill_owned {h : Heap} {b : Nat} {w : IntTy} {n : Nat} {f : Nat → Nat}
    (ha : Arr h b w n f) : (h.kill b).owned = h.owned.erase b := by
  obtain ⟨blk, hb, -⟩ := ha
  simp [Heap.kill, hb]

theorem ArrV.free {h : Heap} {b : Nat} {t : Ty} {n : Nat} {f : Nat → Val}
    (ha : ArrV h b t n f) (hown : b ∈ h.owned) : h.free? b = .ok (h.kill b) := by
  obtain ⟨blk, hb, -, hl, -⟩ := ha
  simp [Heap.free?, Heap.kill, hb, hl, hown]

theorem ArrV.kill_owned {h : Heap} {b : Nat} {t : Ty} {n : Nat} {f : Nat → Val}
    (ha : ArrV h b t n f) : (h.kill b).owned = h.owned.erase b := by
  obtain ⟨blk, hb, -⟩ := ha
  simp [Heap.kill, hb]

theorem Heap.kill_size {h : Heap} {b : Nat} : (h.kill b).blocks.size = h.blocks.size := by
  unfold Heap.kill; split <;> simp [Array.set!_eq_setIfInBounds]

/-- The killed block is dead. -/
theorem Heap.kill_dead {h : Heap} {b : Nat} {blk : Block} (hb : (h.kill b).blocks[b]? = some blk) :
    blk.live = false := by
  unfold Heap.kill at hb
  split at hb
  · rename_i blk0 hb0
    have hlt : b < h.blocks.size := (Array.getElem?_eq_some_iff.mp hb0).1
    simp [Array.set!_eq_setIfInBounds, hlt] at hb
    rw [← hb]
  · rename_i hn; rw [hn] at hb; cases hb

/-- `releaseAll` kills exactly the owned blocks. -/
theorem Heap.releaseAll_get {h : Heap} {b : Nat} :
    h.releaseAll.blocks[b]? =
      (h.blocks[b]?).map (fun blk => if b ∈ h.owned then { blk with live := false } else blk) := by
  simp [Heap.releaseAll, Array.getElem?_mapIdx]

theorem Heap.kill_other {h : Heap} {b b' : Nat} (hne : b' ≠ b) :
    (h.kill b).blocks[b']? = h.blocks[b']? := by
  unfold Heap.kill
  split
  · simp [Array.set!_eq_setIfInBounds, Ne.symm hne]
  · rfl

end KCore

namespace KCore
/-- Resolve local lookups through `Locals.set` chains. -/
syntax "klook" " [" Lean.Parser.Tactic.simpArg,* "]" : tactic
macro_rules
  | `(tactic| klook [$ts,*]) => `(tactic| simp (disch := kdisch) [Locals.set_same, Locals.set_other, $ts,*])
end KCore
