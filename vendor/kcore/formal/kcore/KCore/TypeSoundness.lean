/-
Type soundness for KCore (KCore-D2 follow-up).

Main result (`run_no_typing_fault`): for a well-formed program, a well-formed
entry and well-formed inputs, `run` never ends `stuck … .typing`. Every
remaining way to be stuck is an arithmetic, bounds, liveness, allocation or
leak fault. Those are exactly the per-program obligations the proof tooling
has to discharge.
-/
import KCore.WellFormed
import KCore.Fuel

namespace KCore

/-! ## Invariants -/

/- Pointer validity: every pointer inside a value names an existing block of
   exactly its target type, with offset within `[0, len]`. Liveness is *not*
   required; using a freed block is a liveness fault, not a typing fault. -/
mutual
def PtrOk (h : Heap) : Val → Prop
  | .ptr t (.loc b o) => ∃ blk, h.blocks[b]? = some blk ∧ blk.ty = t ∧ o ≤ blk.cells.size
  | .struct _ fs => PtrOkAll h fs
  | _ => True

def PtrOkAll (h : Heap) : List Val → Prop
  | [] => True
  | v :: vs => PtrOk h v ∧ PtrOkAll h vs
end

/-- Result of evaluating a well-typed expression: a conforming, pointer-valid
    value, or a fault that is not a typing fault. -/
def ExprOk (P : Program) (h : Heap) (t : Ty) : Eval Val → Prop
  | .ok v => conforms P v t = true ∧ PtrOk h v
  | .error f => f ≠ .typing

/-! ## Operators -/

theorem IntTy.bound_pos (w : IntTy) : 0 < w.bound := by
  unfold IntTy.bound; exact Nat.two_pow_pos _

theorem IntTy.bound_mono {w to : IntTy} (h : w.bits ≤ to.bits) : w.bound ≤ to.bound := by
  unfold IntTy.bound; exact Nat.pow_le_pow_right (by decide) h

theorem evalBin_int {P : Program} {h : Heap} {op : BinOp} {t : Ty} {w : IntTy} {a b : Nat}
    (ha : a < w.bound) (hb : b < w.bound) (ht : binTy op (.int w) (.int w) = some t) :
    ExprOk P h t (evalBin op (.int w a) (.int w b)) := by
  have hpos := IntTy.bound_pos w
  cases op <;> simp [binTy] at ht <;> subst ht <;> simp only [evalBin, mkInt, ne_eq,
    not_true_eq_false, ↓reduceIte]
  all_goals (repeat' split)
  all_goals simp_all [ExprOk, conforms, PtrOk]
  all_goals first
    | omega
    | exact Nat.mod_lt _ hpos
    | (unfold IntTy.bound at *; exact Nat.and_lt_two_pow _ hb)
    | (unfold IntTy.bound at *; exact Nat.or_lt_two_pow ha hb)
    | (unfold IntTy.bound at *; exact Nat.xor_lt_two_pow ha hb)
    | exact Nat.lt_of_le_of_lt (Nat.shiftRight_le _ _) ha
    | exact Nat.lt_of_le_of_lt (Nat.div_le_self _ _) ha
    | exact Nat.lt_of_le_of_lt (Nat.mod_le _ _) ha

theorem evalBin_bool {P : Program} {h : Heap} {op : BinOp} {t : Ty} {a b : Bool}
    (ht : binTy op .bool .bool = some t) :
    ExprOk P h t (evalBin op (.bool a) (.bool b)) := by
  cases op <;> simp [binTy] at ht <;> subst ht <;> simp [evalBin, ExprOk, conforms, PtrOk]

theorem evalBin_ptr {P : Program} {h : Heap} {op : BinOp} {t s : Ty} {p q : Ptr}
    (ht : binTy op (.ptr s) (.ptr s) = some t) :
    ExprOk P h t (evalBin op (.ptr s p) (.ptr s q)) := by
  cases op <;> simp [binTy] at ht <;> subst ht <;> simp only [evalBin, ne_eq,
    not_true_eq_false, ↓reduceIte]
  all_goals (repeat' split)
  all_goals simp_all [ExprOk, conforms, PtrOk]

theorem evalBin_sound {P : Program} {h : Heap} {op : BinOp} {t₁ t₂ t : Ty} {v₁ v₂ : Val}
    (ht : binTy op t₁ t₂ = some t) (h₁ : conforms P v₁ t₁ = true) (h₂ : conforms P v₂ t₂ = true) :
    ExprOk P h t (evalBin op v₁ v₂) := by
  cases v₁ with
  | int w₁ a =>
    cases t₁ <;> simp [conforms] at h₁
    obtain ⟨rfl, ha⟩ := h₁
    cases v₂ <;> cases t₂ <;> simp [conforms] at h₂ <;> simp [binTy] at ht
    rename_i w₂ b w₂'
    obtain ⟨rfl, hb⟩ := h₂
    by_cases hw : w₁ = w₂
    · subst hw; exact evalBin_int ha hb (by simpa [binTy] using ht)
    · simp [binTy, hw] at ht
  | bool a =>
    cases t₁ <;> simp [conforms] at h₁
    cases v₂ <;> cases t₂ <;> simp [conforms] at h₂ <;> simp [binTy] at ht
    exact evalBin_bool (by simpa [binTy] using ht)
  | ptr s₁ p =>
    cases t₁ <;> simp [conforms] at h₁
    subst h₁
    cases v₂ <;> cases t₂ <;> simp [conforms] at h₂ <;> simp [binTy] at ht
    rename_i s₂ q s₂'
    subst h₂
    by_cases hs : s₁ = s₂
    · subst hs; exact evalBin_ptr (by simpa [binTy] using ht)
    · simp [binTy, hs] at ht
  | struct n fs =>
    cases t₁ <;> simp [conforms] at h₁ <;> simp [binTy] at ht

theorem evalUn_sound {P : Program} {h : Heap} {op : UnOp} {t₁ t : Ty} {v : Val}
    (ht : unTy op t₁ = some t) (h₁ : conforms P v t₁ = true) :
    ExprOk P h t (evalUn op v) := by
  cases op with
  | lnot =>
    cases t₁ <;> simp [unTy] at ht; subst ht
    cases v <;> simp [conforms] at h₁; simp [evalUn, ExprOk, conforms, PtrOk]
  | bnot =>
    cases t₁ <;> simp [unTy] at ht; subst ht
    cases v <;> simp [conforms] at h₁
    obtain ⟨rfl, ha⟩ := h₁
    have := IntTy.bound_pos ‹IntTy›
    simp [evalUn, ExprOk, conforms, PtrOk]; omega
  | zext to =>
    cases t₁ <;> simp [unTy] at ht
    rename_i w
    obtain ⟨hle, rfl⟩ := ht
    cases v <;> simp [conforms] at h₁
    obtain ⟨rfl, ha⟩ := h₁
    simp [evalUn, hle, ExprOk, conforms, PtrOk]
    exact Nat.lt_of_lt_of_le ha (IntTy.bound_mono hle)
  | trunc to =>
    cases t₁ <;> simp [unTy] at ht
    rename_i w
    obtain ⟨hle, rfl⟩ := ht
    cases v <;> simp [conforms] at h₁
    obtain ⟨rfl, ha⟩ := h₁
    simp [evalUn, hle, ExprOk, conforms, PtrOk]
    exact Nat.mod_lt _ (IntTy.bound_pos _)

/-! ## Expressions -/

/-- Every definitely assigned variable holds a value that conforms to its
    declared type and whose pointers are valid in the heap. -/
def LocalsOk (P : Program) (Γ : TyEnv) (A : List String) (h : Heap) (l : Locals) : Prop :=
  ∀ x ∈ A, ∃ t v, Γ.lookup x = some t ∧ l x = some v ∧ conforms P v t = true ∧ PtrOk h v

def ExprsOk (P : Program) (h : Heap) (ts : List Ty) : Eval (List Val) → Prop
  | .ok vs => conformsAll P vs ts = true ∧ PtrOkAll h vs
  | .error f => f ≠ .typing

theorem conformsAll_get {P : Program} {h : Heap} :
    ∀ {vs : List Val} {ts : List Ty} {i : Nat} {t : Ty},
      conformsAll P vs ts = true → PtrOkAll h vs → ts[i]? = some t →
      ∃ v, vs[i]? = some v ∧ conforms P v t = true ∧ PtrOk h v
  | [], [], _, _, _, _, hi => by simp at hi
  | [], _ :: _, _, _, hc, _, _ => by simp [conformsAll] at hc
  | _ :: _, [], _, _, hc, _, _ => by simp [conformsAll] at hc
  | v :: vs, t :: ts, 0, t', hc, hp, hi => by
      simp [conformsAll] at hc; simp at hi; subst hi
      exact ⟨v, rfl, hc.1, hp.1⟩
  | v :: vs, t :: ts, i + 1, t', hc, hp, hi => by
      simp [conformsAll] at hc; simp at hi
      exact conformsAll_get (vs := vs) (ts := ts) hc.2 hp.2 hi

theorem litTy_sound {P : Program} {h : Heap} {v : Val} {t : Ty} (ht : litTy v = some t) :
    v.isLiteral = true ∧ conforms P v t = true ∧ PtrOk h v := by
  cases v with
  | int w n =>
    simp only [litTy] at ht; split at ht <;> simp at ht; subst ht
    simp_all [Val.isLiteral, conforms, PtrOk]
  | bool b => simp [litTy] at ht; subst ht; simp [Val.isLiteral, conforms, PtrOk]
  | ptr s p =>
    cases p <;> simp [litTy] at ht; subst ht; simp [Val.isLiteral, conforms, PtrOk]
  | struct n fs => simp [litTy] at ht

mutual
theorem evalExpr_sound {P : Program} {Γ : TyEnv} {A : List String} {h : Heap} {l : Locals}
    (hl : LocalsOk P Γ A h l) :
    ∀ (e : Expr) (t : Ty), typeOf P Γ e = some t → usedIn A e = true →
      ExprOk P h t (evalExpr l e)
  | .var x, t, ht, hu => by
      simp [usedIn, exprVars] at hu
      obtain ⟨t', v, hΓ, hv, hc, hp⟩ := hl x hu
      simp [typeOf] at ht
      rw [hΓ] at ht; cases ht
      simp [evalExpr, hv, ExprOk, hc, hp]
  | .lit v, t, ht, _ => by
      simp [typeOf] at ht
      obtain ⟨hlit, hc, hp⟩ := litTy_sound (h := h) (P := P) ht
      simp [evalExpr, hlit, ExprOk, hc, hp]
  | .bin op a b, t, ht, hu => by
      simp [usedIn, exprVars, List.all_append] at hu
      simp only [typeOf] at ht
      cases hta : typeOf P Γ a with
      | none => simp [hta] at ht
      | some ta =>
        cases htb : typeOf P Γ b with
        | none => simp [hta, htb] at ht
        | some tb =>
          simp [hta, htb] at ht
          have iha := evalExpr_sound hl a ta hta (by simp [usedIn]; exact hu.1)
          have ihb := evalExpr_sound hl b tb htb (by simp [usedIn]; exact hu.2)
          simp only [evalExpr]
          cases hea : evalExpr l a with
          | error f => simp only [hea, ExprOk] at iha; simp [bind, Except.bind, ExprOk, iha]
          | ok va =>
            cases heb : evalExpr l b with
            | error f => simp only [heb, ExprOk] at ihb; simp [bind, Except.bind, ExprOk, ihb]
            | ok vb =>
              simp only [hea, ExprOk] at iha; simp only [heb, ExprOk] at ihb
              simp only [bind, Except.bind]
              exact evalBin_sound ht iha.1 ihb.1
  | .un op a, t, ht, hu => by
      simp [usedIn, exprVars] at hu
      simp only [typeOf] at ht
      cases hta : typeOf P Γ a with
      | none => simp [hta] at ht
      | some ta =>
        simp [hta] at ht
        have iha := evalExpr_sound hl a ta hta (by simp [usedIn]; exact hu)
        simp only [evalExpr]
        cases hea : evalExpr l a with
        | error f => simp only [hea, ExprOk] at iha; simp [bind, Except.bind, ExprOk, iha]
        | ok va =>
          simp only [hea, ExprOk] at iha
          simp only [bind, Except.bind]
          exact evalUn_sound ht iha.1
  | .field e i, t, ht, hu => by
      simp [usedIn, exprVars] at hu
      simp only [typeOf] at ht
      cases hte : typeOf P Γ e with
      | none => simp [hte] at ht
      | some te =>
        simp [hte] at ht
        cases te with
        | struct n =>
          simp at ht
          cases hsd : P.struct? n with
          | none => simp [hsd] at ht
          | some sd =>
            simp [hsd] at ht
            have ihe := evalExpr_sound hl e (.struct n) hte (by simp [usedIn]; exact hu)
            simp only [evalExpr]
            cases hee : evalExpr l e with
            | error f => simp only [hee, ExprOk] at ihe; simp [bind, Except.bind, ExprOk, ihe]
            | ok ve =>
              simp only [hee, ExprOk] at ihe
              obtain ⟨hc, hp⟩ := ihe
              cases ve with
              | struct n' fs =>
                simp [conforms] at hc
                obtain ⟨rfl, hc⟩ := hc
                rw [hsd] at hc
                simp [PtrOk] at hp
                obtain ⟨v, hv, hcv, hpv⟩ := conformsAll_get hc hp ht
                simp [bind, Except.bind, hv, ExprOk, hcv, hpv]
              | _ => simp [conforms] at hc
        | _ => simp at ht
  | .mk n es, t, ht, hu => by
      simp [usedIn, exprVars] at hu
      simp only [typeOf] at ht
      cases hsd : P.struct? n with
      | none => simp [hsd] at ht
      | some sd =>
        cases hts : typesOf P Γ es with
        | none => simp [hsd, hts] at ht
        | some ts =>
          simp [hsd, hts] at ht
          obtain ⟨hts', rfl⟩ := ht
          have ihs := evalExprs_sound hl es ts hts (by simpa using hu)
          simp only [evalExpr]
          cases hes : evalExprs l es with
          | error f => simp only [hes, ExprsOk] at ihs; simp [bind, Except.bind, ExprOk, ihs]
          | ok vs =>
            simp only [hes, ExprsOk] at ihs
            subst hts'
            simp [bind, Except.bind, pure, Except.pure, ExprOk, conforms, hsd, ihs.1, PtrOk, ihs.2]

theorem evalExprs_sound {P : Program} {Γ : TyEnv} {A : List String} {h : Heap} {l : Locals}
    (hl : LocalsOk P Γ A h l) :
    ∀ (es : List Expr) (ts : List Ty), typesOf P Γ es = some ts →
      (exprsVars es).all (· ∈ A) = true → ExprsOk P h ts (evalExprs l es)
  | [], ts, ht, _ => by
      simp [typesOf] at ht; subst ht
      simp [evalExprs, ExprsOk, conformsAll, PtrOkAll]
  | e :: es, ts, ht, hu => by
      simp [exprsVars, List.all_append] at hu
      simp only [typesOf] at ht
      cases hte : typeOf P Γ e with
      | none => simp [hte] at ht
      | some te =>
        cases htes : typesOf P Γ es with
        | none => simp [hte, htes] at ht
        | some tes =>
          simp [hte, htes] at ht; subst ht
          have ihe := evalExpr_sound hl e te hte (by simp [usedIn]; exact hu.1)
          have ihs := evalExprs_sound hl es tes htes (by simpa using hu.2)
          simp only [evalExprs]
          cases hee : evalExpr l e with
          | error f => simp only [hee, ExprOk] at ihe; simp [bind, Except.bind, ExprsOk, ihe]
          | ok ve =>
            cases hes : evalExprs l es with
            | error f => simp only [hes, ExprsOk] at ihs; simp [bind, Except.bind, ExprsOk, ihs]
            | ok vs =>
              simp only [hee, ExprOk] at ihe; simp only [hes, ExprsOk] at ihs
              simp [bind, Except.bind, pure, Except.pure, ExprsOk, conformsAll, ihe.1, ihs.1,
                PtrOkAll, ihe.2, ihs.2]
end

/-! ## Heap invariants -/

/-- Every block has a pointer-free element type and every cell conforms. -/
def HeapOk (P : Program) (h : Heap) : Prop :=
  ∀ (b : Nat) (blk : Block), h.blocks[b]? = some blk →
    P.pointerFree? blk.ty = true ∧
    ∀ (i : Nat) (c : Val), blk.cells[i]? = some c → conforms P c blk.ty = true

/-- The heap only grows; existing blocks keep their type and length. -/
def HeapExt (h h' : Heap) : Prop :=
  ∀ (b : Nat) (blk : Block), h.blocks[b]? = some blk →
    ∃ blk', h'.blocks[b]? = some blk' ∧ blk'.ty = blk.ty ∧ blk'.cells.size = blk.cells.size

theorem HeapExt.refl (h : Heap) : HeapExt h h := fun _ blk hb => ⟨blk, hb, rfl, rfl⟩

theorem HeapExt.trans {h₁ h₂ h₃ : Heap} (a : HeapExt h₁ h₂) (b : HeapExt h₂ h₃) : HeapExt h₁ h₃ := by
  intro i blk hi
  obtain ⟨blk₂, h2, t2, s2⟩ := a i blk hi
  obtain ⟨blk₃, h3, t3, s3⟩ := b i blk₂ h2
  exact ⟨blk₃, h3, t3.trans t2, s3.trans s2⟩

mutual
theorem PtrOk.mono {h h' : Heap} (he : HeapExt h h') : ∀ {v : Val}, PtrOk h v → PtrOk h' v
  | .int _ _, _ => by simp [PtrOk]
  | .bool _, _ => by simp [PtrOk]
  | .ptr _ .null, _ => by simp [PtrOk]
  | .ptr t (.loc b o), hp => by
      simp only [PtrOk] at hp ⊢
      obtain ⟨blk, hb, ht, ho⟩ := hp
      obtain ⟨blk', hb', ht', hs'⟩ := he b blk hb
      exact ⟨blk', hb', ht'.trans ht, hs' ▸ ho⟩
  | .struct _ fs, hp => by simp only [PtrOk] at hp ⊢; exact PtrOkAll.mono he hp

theorem PtrOkAll.mono {h h' : Heap} (he : HeapExt h h') : ∀ {vs : List Val}, PtrOkAll h vs → PtrOkAll h' vs
  | [], _ => by simp [PtrOkAll]
  | _ :: _, hp => by
      simp only [PtrOkAll] at hp ⊢
      exact ⟨PtrOk.mono he hp.1, PtrOkAll.mono he hp.2⟩
end

theorem LocalsOk.mono_heap {P : Program} {Γ : TyEnv} {A : List String} {h h' : Heap} {l : Locals}
    (hl : LocalsOk P Γ A h l) (he : HeapExt h h') : LocalsOk P Γ A h' l := by
  intro x hx
  obtain ⟨t, v, h1, h2, h3, h4⟩ := hl x hx
  exact ⟨t, v, h1, h2, h3, PtrOk.mono he h4⟩

theorem LocalsOk.mono_set {P : Program} {Γ : TyEnv} {A B : List String} {h : Heap} {l : Locals}
    (hl : LocalsOk P Γ A h l) (hsub : ∀ x ∈ B, x ∈ A) : LocalsOk P Γ B h l :=
  fun x hx => hl x (hsub x hx)

theorem LocalsOk.set {P : Program} {Γ : TyEnv} {A : List String} {h : Heap} {l : Locals}
    {x : String} {t : Ty} {v : Val}
    (hl : LocalsOk P Γ A h l) (hΓ : Γ.lookup x = some t) (hc : conforms P v t = true)
    (hp : PtrOk h v) : LocalsOk P Γ (x :: A) h (l.set x v) := by
  intro y hy
  by_cases hyx : y = x
  · subst hyx; exact ⟨t, v, hΓ, by simp [Locals.set], hc, hp⟩
  · simp [hyx] at hy
    obtain ⟨t', v', h1, h2, h3, h4⟩ := hl y hy
    exact ⟨t', v', h1, by simp [Locals.set, hyx, h2], h3, h4⟩

theorem conforms_ty {P : Program} {v : Val} {t : Ty} (h : conforms P v t = true) : v.ty = t := by
  cases v <;> cases t <;> simp_all [conforms, Val.ty]

/- A value conforming to a pointer-free type contains no pointer. -/
mutual
theorem ptrOk_of_pointerFree {P : Program} {h : Heap} :
    ∀ (d : Nat) (v : Val) (t : Ty), pointerFree P d t = true → conforms P v t = true → PtrOk h v
  | _, .int _ _, _, _, _ => by simp [PtrOk]
  | _, .bool _, _, _, _ => by simp [PtrOk]
  | _, .ptr _ _, t, hpf, hc => by cases t <;> simp_all [conforms, pointerFree]
  | 0, .struct _ _, t, hpf, hc => by cases t <;> simp_all [conforms, pointerFree]
  | d + 1, .struct n fs, t, hpf, hc => by
      cases t with
      | struct n' =>
        simp [conforms] at hc
        obtain ⟨rfl, hc⟩ := hc
        simp only [pointerFree] at hpf
        cases hsd : P.struct? n with
        | none => simp [hsd] at hpf
        | some sd =>
          simp only [hsd] at hpf
          simp [hsd] at hc
          simp only [PtrOk]
          exact ptrOkAll_of_pointerFree d fs sd.fields hpf hc
      | _ => simp [conforms] at hc

theorem ptrOkAll_of_pointerFree {P : Program} {h : Heap} :
    ∀ (d : Nat) (vs : List Val) (ts : List Ty), pointerFreeAll P d ts = true →
      conformsAll P vs ts = true → PtrOkAll h vs
  | _, [], _, _, _ => by simp [PtrOkAll]
  | _, _ :: _, [], _, hc => by simp [conformsAll] at hc
  | d, v :: vs, t :: ts, hpf, hc => by
      simp only [pointerFreeAll_cons, Bool.and_eq_true] at hpf; simp [conformsAll] at hc
      simp only [PtrOkAll]
      exact ⟨ptrOk_of_pointerFree d v t hpf.1 hc.1, ptrOkAll_of_pointerFree d vs ts hpf.2 hc.2⟩
end

/- Typed zero values conform, and every pointer-free type has one. -/
mutual
theorem zeroOf_conforms {P : Program} :
    ∀ (d : Nat) (t : Ty) (z : Val), zeroOf P d t = some z → conforms P z t = true
  | _, .int w, z, hz => by
      simp [zeroOf] at hz; subst hz; simp [conforms, IntTy.bound_pos]
  | _, .bool, z, hz => by simp [zeroOf] at hz; subst hz; simp [conforms]
  | _, .ptr _, _, hz => by simp [zeroOf] at hz
  | 0, .struct _, _, hz => by simp [zeroOf] at hz
  | d + 1, .struct n, z, hz => by
      simp only [zeroOf] at hz
      cases hsd : P.struct? n with
      | none => simp [hsd] at hz
      | some sd =>
        cases hzs : zerosOf P d sd.fields with
        | none => simp [hsd, hzs] at hz
        | some zs =>
          simp [hsd, hzs] at hz; subst hz
          simp [conforms, hsd, zerosOf_conforms d sd.fields zs hzs]

theorem zerosOf_conforms {P : Program} :
    ∀ (d : Nat) (ts : List Ty) (zs : List Val), zerosOf P d ts = some zs → conformsAll P zs ts = true
  | _, [], zs, hz => by simp [zerosOf] at hz; subst hz; simp [conformsAll]
  | d, t :: ts, zs, hz => by
      simp only [zerosOf] at hz
      cases h1 : zeroOf P d t with
      | none => simp [h1] at hz
      | some z =>
        cases h2 : zerosOf P d ts with
        | none => simp [h1, h2] at hz
        | some zs' =>
          simp [h1, h2] at hz; subst hz
          simp [conformsAll, zeroOf_conforms d t z h1, zerosOf_conforms d ts zs' h2]
end

mutual
theorem zeroOf_of_pointerFree {P : Program} :
    ∀ (d : Nat) (t : Ty), pointerFree P d t = true → ∃ z, zeroOf P d t = some z
  | _, .int _, _ => by simp [zeroOf]
  | _, .bool, _ => by simp [zeroOf]
  | _, .ptr _, h => by simp [pointerFree] at h
  | 0, .struct _, h => by simp [pointerFree] at h
  | d + 1, .struct n, h => by
      simp only [pointerFree] at h
      cases hsd : P.struct? n with
      | none => simp [hsd] at h
      | some sd =>
        simp only [hsd] at h
        obtain ⟨zs, hzs⟩ := zerosOf_of_pointerFree d sd.fields h
        exact ⟨.struct n zs, by simp [zeroOf, hsd, hzs]⟩

theorem zerosOf_of_pointerFree {P : Program} :
    ∀ (d : Nat) (ts : List Ty), pointerFreeAll P d ts = true → ∃ zs, zerosOf P d ts = some zs
  | _, [], _ => ⟨[], by simp [zerosOf]⟩
  | d, t :: ts, h => by
      simp only [pointerFreeAll_cons, Bool.and_eq_true] at h
      obtain ⟨z, hz⟩ := zeroOf_of_pointerFree d t h.1
      obtain ⟨zs, hzs⟩ := zerosOf_of_pointerFree d ts h.2
      exact ⟨z :: zs, by simp [zerosOf, hz, hzs]⟩
end

/-! ## Heap operations preserve the invariants -/

theorem store?_ok {P : Program} {h h' : Heap} {t : Ty} {b o : Nat} {v : Val}
    (hi : HeapOk P h) (hc : conforms P v t = true) (hs : h.store? t b o v = .ok h') :
    HeapOk P h' ∧ HeapExt h h' := by
  unfold Heap.store? at hs
  cases hb : h.blocks[b]? with
  | none => simp [hb] at hs
  | some blk =>
    simp only [hb] at hs
    repeat' split at hs
    all_goals try (simp at hs; done)
    rename_i hlive hty hlt
    simp only [Except.ok.injEq] at hs; subst hs
    have hbsz := (Array.getElem?_eq_some_iff.mp hb).1
    have hbt : blk.ty = t := by simp at hty; exact hty.1
    constructor
    · intro c blk' hc'
      simp only [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds] at hc'
      by_cases hbc : b = c
      · subst hbc; simp [hbsz] at hc'; subst hc'
        obtain ⟨hpf, hcells⟩ := hi b blk hb
        refine ⟨hpf, fun i c hic => ?_⟩
        simp only [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds] at hic
        by_cases hoi : o = i
        · subst hoi; simp [hlt] at hic; subst hic; rw [hbt]; exact hc
        · simp [hoi] at hic; exact hcells i c hic
      · simp [hbc] at hc'; exact hi c blk' hc'
    · intro c blk' hc'
      by_cases hbc : b = c
      · subst hbc; rw [hb] at hc'; cases hc'
        exact ⟨{ blk with cells := blk.cells.set! o v },
          by simp [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds, hbsz], rfl,
          by simp [Array.set!_eq_setIfInBounds]⟩
      · exact ⟨blk', by simp [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds, hbc, hc'],
          rfl, rfl⟩

theorem free?_ok {P : Program} {h h' : Heap} {b : Nat}
    (hi : HeapOk P h) (hf : h.free? b = .ok h') : HeapOk P h' ∧ HeapExt h h' := by
  unfold Heap.free? at hf
  cases hb : h.blocks[b]? with
  | none => simp [hb] at hf
  | some blk =>
    simp only [hb] at hf
    split at hf
    · simp only [Except.ok.injEq] at hf; subst hf
      have hbsz := (Array.getElem?_eq_some_iff.mp hb).1
      constructor
      · intro c blk' hc'
        simp only [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds] at hc'
        by_cases hbc : b = c
        · subst hbc; simp [hbsz] at hc'; subst hc'
          exact hi b blk hb
        · simp [hbc] at hc'; exact hi c blk' hc'
      · intro c blk' hc'
        by_cases hbc : b = c
        · subst hbc; rw [hb] at hc'; cases hc'
          exact ⟨{ blk with live := false },
            by simp [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds, hbsz], rfl, rfl⟩
        · exact ⟨blk', by simp [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds, hbc, hc'],
            rfl, rfl⟩
    · simp at hf

theorem alloc_ok {P : Program} {h : Heap} {t : Ty} {n : Nat} {z : Val}
    (hi : HeapOk P h) (hpf : P.pointerFree? t = true) (hz : conforms P z t = true) :
    HeapOk P (h.alloc t n z).1 ∧ HeapExt h (h.alloc t n z).1 := by
  simp only [Heap.alloc]
  constructor
  · intro c blk hc
    simp only [Array.getElem?_push] at hc
    split at hc
    · simp at hc; subst hc
      refine ⟨hpf, fun i c hic => ?_⟩
      simp only [Array.getElem?_replicate] at hic
      split at hic <;> simp at hic; subst hic; exact hz
    · exact hi c blk hc
  · intro c blk hc
    have hlt := (Array.getElem?_eq_some_iff.mp hc).1
    exact ⟨blk, by simp [Array.getElem?_push, Nat.ne_of_lt hlt, hc], rfl, rfl⟩

/-- Reading a heap cell of pointer-free type yields a conforming,
    pointer-free value. -/
theorem load?_ok {P : Program} {h : Heap} {t : Ty} {b o : Nat} {v : Val}
    (hi : HeapOk P h) (hl : h.load? t b o = .ok v) : conforms P v t = true ∧ PtrOk h v := by
  unfold Heap.load? at hl
  cases hb : h.blocks[b]? with
  | none => simp [hb] at hl
  | some blk =>
    simp only [hb] at hl
    by_cases hlv : blk.live = false
    · simp [hlv] at hl
    · by_cases hty : blk.ty = t
      · cases hcell : blk.cells[o]? with
        | none => simp [hlv, hty, hcell] at hl
        | some c =>
          simp [hlv, hty, hcell] at hl; subst hl
          obtain ⟨hpf, hcells⟩ := hi b blk hb
          have hcv := hcells o c hcell
          rw [hty] at hcv hpf
          exact ⟨hcv, ptrOk_of_pointerFree _ _ _ hpf hcv⟩
      · simp [hlv, hty] at hl

/-! ## Heap operations never fail with a typing fault on valid pointers -/

theorem load?_fault {h : Heap} {t : Ty} {b o : Nat} {f : Fault}
    (hp : PtrOk h (.ptr t (.loc b o))) (hl : h.load? t b o = .error f) : f ≠ .typing := by
  simp only [PtrOk] at hp
  obtain ⟨blk, hb, hty, -⟩ := hp
  unfold Heap.load? at hl
  simp only [hb, hty] at hl
  by_cases hlv : blk.live = false
  · simp [hlv] at hl; subst hl; simp
  · cases hc : blk.cells[o]? <;> simp [hlv, hc] at hl; subst hl; simp

theorem store?_fault {h : Heap} {t : Ty} {b o : Nat} {v : Val} {f : Fault}
    (hp : PtrOk h (.ptr t (.loc b o))) (hvt : v.ty = t) (hs : h.store? t b o v = .error f) :
    f ≠ .typing := by
  simp only [PtrOk] at hp
  obtain ⟨blk, hb, hty, -⟩ := hp
  unfold Heap.store? at hs
  simp only [hb, hty, hvt] at hs
  by_cases hlv : blk.live = false
  · simp [hlv] at hs; subst hs; simp
  · by_cases hlt : o < blk.cells.size <;> simp [hlv, hlt] at hs; subst hs; simp

theorem ptrAdd?_fault {h : Heap} {t : Ty} {b o k : Nat} {f : Fault}
    (hp : PtrOk h (.ptr t (.loc b o))) (ha : h.ptrAdd? b o k = .error f) : f ≠ .typing := by
  simp only [PtrOk] at hp
  obtain ⟨blk, hb, -, -⟩ := hp
  unfold Heap.ptrAdd? at ha
  simp only [hb] at ha
  by_cases hlv : blk.live = false
  · simp [hlv] at ha; subst ha; simp
  · by_cases hle : o + k ≤ blk.cells.size <;> simp [hlv, hle] at ha; subst ha; simp

theorem ptrAdd?_ok {h : Heap} {t : Ty} {b o k o' : Nat}
    (hp : PtrOk h (.ptr t (.loc b o))) (ha : h.ptrAdd? b o k = .ok o') :
    PtrOk h (.ptr t (.loc b o')) := by
  simp only [PtrOk] at hp ⊢
  obtain ⟨blk, hb, hty, -⟩ := hp
  unfold Heap.ptrAdd? at ha
  simp only [hb] at ha
  by_cases hlv : blk.live = false
  · simp [hlv] at ha
  · by_cases hle : o + k ≤ blk.cells.size <;> simp [hlv, hle] at ha
    subst ha; exact ⟨blk, hb, hty, hle⟩

theorem free?_fault {h : Heap} {t : Ty} {b : Nat} {f : Fault}
    (hp : PtrOk h (.ptr t (.loc b 0))) (hf : h.free? b = .error f) : f ≠ .typing := by
  simp only [PtrOk] at hp
  obtain ⟨blk, hb, -, -⟩ := hp
  unfold Heap.free? at hf
  simp only [hb] at hf
  split at hf <;> simp at hf; subst hf; simp

/-! ## Definite return and assignment monotonicity -/

/-- A statement that definitely returns never completes normally. -/
theorem exec_returns_not_normal {P : Program} {L : Layout} {env : Env} :
    ∀ (n : Nat) (m : Machine) (l : Locals) (s : Stmt) (m' : Machine) (l' : Locals),
      s.returns = true → exec P L env n m l s ≠ .normal m' l' := by
  intro n
  induction n with
  | zero => intro m l s m' l' _; simp [exec]
  | succ n ih =>
    intro m l s m' l' hr
    cases s with
    | ret e =>
        simp only [exec, atomic]
        cases evalExpr l e <;> simp
    | seq a b =>
        rw [exec_seq_eq]
        simp only [Stmt.returns, Bool.or_eq_true] at hr
        cases ha : exec P L env n m l a with
        | normal m₁ l₁ =>
            rcases hr with hr | hr
            · exact absurd ha (ih _ _ _ _ _ hr)
            · exact ih _ _ _ _ _ hr
        | _ => simp
    | ite c a b =>
        rw [exec_ite_eq]
        simp only [Stmt.returns, Bool.and_eq_true] at hr
        split
        · exact ih _ _ _ _ _ hr.1
        · exact ih _ _ _ _ _ hr.2
        · simp
        · simp
    | _ => simp [Stmt.returns] at hr

theorem TyEnv.lookup_mem {Γ : TyEnv} {x : String} {t : Ty} (h : Γ.lookup x = some t) :
    x ∈ Γ.map (·.1) := by
  simp only [TyEnv.lookup, Option.map_eq_some_iff] at h
  obtain ⟨p, hp, rfl⟩ := h
  have hmem := List.mem_of_find?_eq_some hp
  have hname := List.find?_some hp
  simp at hname
  exact List.mem_map.mpr ⟨p, hmem, hname⟩

/-- The definitely assigned set only grows, and stays within the declared
    variables. -/
theorem checkStmt_sets {P : Program} {fd : FunDef} :
    ∀ (s : Stmt) (A A' : List String), checkStmt P fd A s = some A' →
      (∀ x ∈ A, x ∈ fd.vars.map (·.1)) →
      (∀ x ∈ A, x ∈ A') ∧ (∀ x ∈ A', x ∈ fd.vars.map (·.1))
  | .skip, A, A', h, hA => by
      simp [checkStmt] at h; subst h; exact ⟨fun _ hx => hx, hA⟩
  | .checkpoint, A, A', h, hA => by
      simp [checkStmt] at h; subst h; exact ⟨fun _ hx => hx, hA⟩
  | .assign x e, A, A', h, hA => by
      simp only [checkStmt] at h
      cases hte : typeOf P fd.vars e <;> simp [hte] at h
      obtain ⟨⟨hx, -⟩, rfl⟩ := h
      refine ⟨fun y hy => List.mem_cons_of_mem _ hy, fun y hy => ?_⟩
      simp at hy; rcases hy with rfl | hy
      · exact TyEnv.lookup_mem hx
      · exact hA y hy
  | .load x p, A, A', h, hA => by
      simp only [checkStmt] at h
      cases hp : typeOf P fd.vars p with
      | none => simp [hp] at h
      | some tp =>
        cases tp <;> simp [hp] at h
        obtain ⟨⟨hx, -⟩, rfl⟩ := h
        refine ⟨fun y hy => List.mem_cons_of_mem _ hy, fun y hy => ?_⟩
        simp at hy; rcases hy with rfl | hy
        · exact TyEnv.lookup_mem hx
        · exact hA y hy
  | .store p v, A, A', h, hA => by
      simp only [checkStmt] at h
      cases hp : typeOf P fd.vars p <;> cases hv : typeOf P fd.vars v <;> simp [hp, hv] at h
      rename_i tp tv
      cases tp <;> simp at h
      obtain ⟨-, rfl⟩ := h; exact ⟨fun _ hy => hy, hA⟩
  | .ptrAdd x p k, A, A', h, hA => by
      simp only [checkStmt] at h
      cases hp : typeOf P fd.vars p <;> cases hk : typeOf P fd.vars k <;> simp [hp, hk] at h
      rename_i tp tk
      cases tp <;> cases tk <;> (try (simp at h; done))
      rename_i _ w; cases w <;> (try (simp at h; done))
      simp at h
      obtain ⟨⟨hx, -⟩, rfl⟩ := h
      refine ⟨fun y hy => List.mem_cons_of_mem _ hy, fun y hy => ?_⟩
      simp at hy; rcases hy with rfl | hy
      · exact TyEnv.lookup_mem hx
      · exact hA y hy
  | .alloc x t c, A, A', h, hA => by
      simp only [checkStmt] at h
      cases hc : typeOf P fd.vars c with
      | none => simp [hc] at h
      | some tc =>
        cases tc <;> simp [hc] at h
        rename_i w; cases w <;> simp at h
        obtain ⟨⟨hx, -⟩, rfl⟩ := h
        refine ⟨fun y hy => List.mem_cons_of_mem _ hy, fun y hy => ?_⟩
        simp at hy; rcases hy with rfl | hy
        · exact TyEnv.lookup_mem hx
        · exact hA y hy
  | .free p, A, A', h, hA => by
      simp only [checkStmt] at h
      cases hp : typeOf P fd.vars p with
      | none => simp [hp] at h
      | some tp => cases tp <;> simp [hp] at h; obtain ⟨-, rfl⟩ := h; exact ⟨fun _ hy => hy, hA⟩
  | .call x f args, A, A', h, hA => by
      simp only [checkStmt] at h
      cases hg : P.fun? f <;> simp [hg] at h
      cases hts : typesOf P fd.vars args <;> simp [hts] at h
      obtain ⟨⟨-, hx, -⟩, rfl⟩ := h
      refine ⟨fun y hy => List.mem_cons_of_mem _ hy, fun y hy => ?_⟩
      simp at hy; rcases hy with rfl | hy
      · exact TyEnv.lookup_mem hx
      · exact hA y hy
  | .ret e, A, A', h, hA => by
      simp only [checkStmt] at h
      cases hte : typeOf P fd.vars e <;> simp [hte] at h
      obtain ⟨-, rfl⟩ := h; exact ⟨hA, fun _ hy => hy⟩
  | .ite c a b, A, A', h, hA => by
      simp only [checkStmt] at h
      split at h
      · simp at h
      · cases ha : checkStmt P fd A a with
        | none => simp [ha] at h
        | some A₁ =>
          cases hb : checkStmt P fd A b with
          | none => simp [ha, hb] at h
          | some A₂ =>
            simp [ha, hb] at h
            obtain ⟨m₁, s₁⟩ := checkStmt_sets a A A₁ ha hA
            obtain ⟨m₂, s₂⟩ := checkStmt_sets b A A₂ hb hA
            split at h
            · cases h; exact ⟨m₂, s₂⟩
            · split at h
              · cases h; exact ⟨m₁, s₁⟩
              · cases h
                exact ⟨fun y hy => List.mem_filter.mpr ⟨m₁ y hy, by simpa using m₂ y hy⟩,
                  fun y hy => s₁ y (List.mem_filter.mp hy).1⟩
  | .while c body, A, A', h, hA => by
      simp only [checkStmt] at h
      split at h
      · simp at h
      · cases hb : checkStmt P fd A body <;> simp [hb] at h
        subst h; exact ⟨fun _ hy => hy, hA⟩
  | .seq a b, A, A', h, hA => by
      simp only [checkStmt] at h
      cases ha : checkStmt P fd A a with
      | none => simp [ha] at h
      | some A₁ =>
        simp [ha] at h
        obtain ⟨m₁, s₁⟩ := checkStmt_sets a A A₁ ha hA
        obtain ⟨m₂, s₂⟩ := checkStmt_sets b A₁ A' h s₁
        exact ⟨fun y hy => m₂ y (m₁ y hy), s₂⟩

/-! ## Calls: binding arguments to parameters -/

theorem TyEnv.lookup_cons {x y : String} {t : Ty} {Γ : TyEnv} :
    TyEnv.lookup ((x, t) :: Γ) y = if x = y then some t else TyEnv.lookup Γ y := by
  by_cases h : x = y
  · subst h; simp [TyEnv.lookup]
  · have : (x == y) = false := by simp [h]
    simp [TyEnv.lookup, List.find?, this, h]

theorem argsOk_of_conforms {P : Program} {g : FunDef} :
    ∀ {vs : List Val}, conformsAll P vs (g.params.map (·.2)) = true → P.argsOk g vs = true := by
  intro vs h
  simp only [Program.argsOk, Bool.and_eq_true, beq_iff_eq]
  suffices ∀ (ps : List (String × Ty)) (vs : List Val), conformsAll P vs (ps.map (·.2)) = true →
      ps.length = vs.length ∧ (ps.zip vs).all (fun pv => P.conforms? pv.2 pv.1.2) = true from
    this g.params vs h
  intro ps
  induction ps with
  | nil => intro vs h; cases vs <;> simp_all [conformsAll]
  | cons p ps ih =>
    intro vs h
    cases vs with
    | nil => simp [conformsAll] at h
    | cons v vs =>
      simp [conformsAll] at h
      obtain ⟨h1, h2⟩ := ih vs h.2
      simp [h1, Program.conforms?, h.1]
      simpa using h2

theorem localsOk_params {P : Program} {h : Heap} :
    ∀ (ps rest : List (String × Ty)) (vs : List Val),
      (ps.map (·.1)).Nodup → conformsAll P vs (ps.map (·.2)) = true → PtrOkAll h vs →
      LocalsOk P (ps ++ rest) (ps.map (·.1)) h (Locals.ofList ((ps.map (·.1)).zip vs))
  | [], _, _, _, _, _ => by intro x hx; simp at hx
  | (x, t) :: ps, rest, [], _, hc, _ => by simp [conformsAll] at hc
  | (x, t) :: ps, rest, v :: vs, hnd, hc, hp => by
      simp [conformsAll] at hc
      simp only [PtrOkAll] at hp
      simp only [List.map_cons, List.nodup_cons] at hnd
      have ih := localsOk_params ps rest vs hnd.2 hc.2 hp.2
      intro y hy
      simp only [List.map_cons, List.mem_cons] at hy
      by_cases hyx : y = x
      · subst hyx
        exact ⟨t, v, by simp [TyEnv.lookup_cons], by simp [Locals.ofList, Locals.set], hc.1, hp.1⟩
      · rcases hy with hy | hy
        · exact absurd hy hyx
        · obtain ⟨t', v', h1, h2, h3, h4⟩ := ih y hy
          refine ⟨t', v', ?_, ?_, h3, h4⟩
          · simp only [List.cons_append, TyEnv.lookup_cons]; simp [Ne.symm hyx, h1]
          · simp [Locals.ofList, Locals.set, hyx, h2]

theorem FunDef.params_nodup {fd : FunDef} (h : (fd.vars.map (·.1)).Nodup) :
    (fd.params.map (·.1)).Nodup := by
  simp only [FunDef.vars, List.map_append] at h
  exact (List.nodup_append.mp h).1

/-! ## Statements -/

/-- What a well-typed statement guarantees about its result, relative to the
    heap `h0` it started from. -/
def ResOk (P : Program) (fd : FunDef) (A : List String) (h0 : Heap) : Res → Prop
  | .normal m l => HeapOk P m.heap ∧ HeapExt h0 m.heap ∧ LocalsOk P fd.vars A m.heap l
  | .ret m v => HeapOk P m.heap ∧ HeapExt h0 m.heap ∧ conforms P v fd.result = true ∧ PtrOk m.heap v
  | .fail m _ => HeapOk P m.heap ∧ HeapExt h0 m.heap
  | .stuck _ f => f ≠ .typing
  | .oof => True

theorem ResOk.weaken {P : Program} {fd : FunDef} {A B : List String} {h0 : Heap} {r : Res}
    (hsub : ∀ x ∈ B, x ∈ A) (h : ResOk P fd A h0 r) : ResOk P fd B h0 r := by
  cases r <;> simp only [ResOk] at h ⊢
  case normal => exact ⟨h.1, h.2.1, h.2.2.mono_set hsub⟩
  all_goals exact h

theorem ResOk.nonNormal {P : Program} {fd : FunDef} {A B : List String} {h0 : Heap} {r : Res}
    (hn : ∀ m l, r ≠ .normal m l) (h : ResOk P fd A h0 r) : ResOk P fd B h0 r := by
  cases r <;> simp only [ResOk] at h ⊢
  case normal m l => exact absurd rfl (hn m l)
  all_goals exact h

theorem ResOk.ext {P : Program} {fd : FunDef} {A : List String} {h0 h1 : Heap} {r : Res}
    (he : HeapExt h0 h1) (h : ResOk P fd A h1 r) : ResOk P fd A h0 r := by
  cases r <;> simp only [ResOk] at h ⊢
  case normal => exact ⟨h.1, he.trans h.2.1, h.2.2⟩
  case ret => exact ⟨h.1, he.trans h.2.1, h.2.2⟩
  case fail => exact ⟨h.1, he.trans h.2⟩
  all_goals exact h

theorem LocalsOk.names {P : Program} {Γ : TyEnv} {A : List String} {h : Heap} {l : Locals}
    (hl : LocalsOk P Γ A h l) : ∀ x ∈ A, x ∈ Γ.map (·.1) := by
  intro x hx
  obtain ⟨t, _, h1, _⟩ := hl x hx
  exact TyEnv.lookup_mem h1

theorem Program.wf_fun {P : Program} (hP : P.wf = true) {f : String} {g : FunDef}
    (hg : P.fun? f = some g) : FunDef.wf P g = true := by
  simp only [Program.wf, decide_eq_true_eq, Bool.and_eq_true] at hP
  have hmem := List.mem_of_find?_eq_some hg
  exact (List.all_eq_true.mp hP.2.2.2.2.2) g hmem

/-- **Statement soundness.** A well-typed statement, started from a
    well-formed heap and well-typed locals, produces a result satisfying
    `ResOk`. In particular it is never stuck with a typing fault. -/
theorem exec_sound {P : Program} {L : Layout} {env : Env} (hP : P.wf = true) :
    ∀ (n : Nat) (m : Machine) (l : Locals) (s : Stmt) (fd : FunDef) (A A' : List String),
      checkStmt P fd A s = some A' → HeapOk P m.heap → LocalsOk P fd.vars A m.heap l →
      ResOk P fd A' m.heap (exec P L env n m l s) := by
  intro n
  induction n with
  | zero => intro m l s fd A A' _ _ _; simp [exec, ResOk]
  | succ n ih =>
    intro m l s fd A A' hcs hm hl
    cases s with
    | skip =>
      simp [checkStmt] at hcs; subst hcs
      simp only [exec, atomic, ResOk]; exact ⟨hm, HeapExt.refl _, hl⟩
    | checkpoint =>
      simp [checkStmt] at hcs; subst hcs
      simp only [exec, atomic]
      split <;> simp only [ResOk, Machine.record]
      · exact ⟨hm, HeapExt.refl _, hl⟩
      · exact ⟨hm, HeapExt.refl _⟩
    | assign x e =>
      simp only [checkStmt] at hcs
      cases hte : typeOf P fd.vars e with
      | none => simp [hte] at hcs
      | some t =>
        simp [hte] at hcs
        obtain ⟨⟨hx, hu⟩, rfl⟩ := hcs
        have he := evalExpr_sound hl e t hte hu
        simp only [exec, atomic]
        cases hev : evalExpr l e with
        | error f => rw [hev] at he; exact he
        | ok v =>
          rw [hev] at he; simp only [ExprOk] at he
          exact ⟨hm, HeapExt.refl _, hl.set hx he.1 he.2⟩
    | ret e =>
      simp only [checkStmt] at hcs
      cases hte : typeOf P fd.vars e with
      | none => simp [hte] at hcs
      | some t =>
        simp [hte] at hcs
        obtain ⟨⟨rfl, hu⟩, rfl⟩ := hcs
        have he := evalExpr_sound hl e fd.result hte hu
        simp only [exec, atomic]
        cases hev : evalExpr l e with
        | error f => rw [hev] at he; exact he
        | ok v =>
          rw [hev] at he; simp only [ExprOk] at he
          exact ⟨hm, HeapExt.refl _, he.1, he.2⟩
    | load x p =>
      simp only [checkStmt] at hcs
      cases htp : typeOf P fd.vars p with
      | none => simp [htp] at hcs
      | some tp =>
        cases tp with
        | ptr t =>
          simp [htp] at hcs
          obtain ⟨⟨hx, hpf, hu⟩, rfl⟩ := hcs
          have he := evalExpr_sound hl p (.ptr t) htp hu
          simp only [exec, atomic]
          cases hev : evalExpr l p with
          | error f => rw [hev] at he; exact he
          | ok v =>
            rw [hev] at he; simp only [ExprOk] at he
            obtain ⟨hc, hpv⟩ := he
            cases v with
            | ptr t' q =>
              simp [conforms] at hc; subst hc
              cases q with
              | null => simp [ResOk]
              | loc b o =>
                simp only
                cases hld : m.heap.load? t' b o with
                | error f => exact load?_fault hpv hld
                | ok w =>
                  obtain ⟨hcw, hpw⟩ := load?_ok hm hld
                  exact ⟨hm, HeapExt.refl _, hl.set hx hcw hpw⟩
            | _ => simp [conforms] at hc
        | _ => simp [htp] at hcs
    | store p v =>
      simp only [checkStmt] at hcs
      cases htp : typeOf P fd.vars p with
      | none => simp [htp] at hcs
      | some tp =>
        cases htv : typeOf P fd.vars v with
        | none => simp [htp, htv] at hcs
        | some tv =>
          cases tp with
          | ptr t =>
            simp [htp, htv] at hcs
            obtain ⟨⟨rfl, hpf, hup, huv⟩, rfl⟩ := hcs
            have hep := evalExpr_sound hl p (.ptr t) htp hup
            have hev := evalExpr_sound hl v t htv huv
            simp only [exec, atomic]
            cases hp : evalExpr l p with
            | error f => rw [hp] at hep; exact hep
            | ok pv =>
              cases hv : evalExpr l v with
              | error f => rw [hv] at hev; exact hev
              | ok vv =>
                rw [hp] at hep; rw [hv] at hev; simp only [ExprOk] at hep hev
                obtain ⟨hcp, hpp⟩ := hep
                cases pv with
                | ptr t' q =>
                  simp [conforms] at hcp; subst hcp
                  cases q with
                  | null => simp [ResOk]
                  | loc b o =>
                    simp only [Program.conforms?, hev.1, if_true]
                    cases hst : m.heap.store? t' b o vv with
                    | error f => exact store?_fault hpp (conforms_ty hev.1) hst
                    | ok h' =>
                      obtain ⟨hok, hext⟩ := store?_ok hm hev.1 hst
                      exact ⟨hok, hext, hl.mono_heap hext⟩
                | _ => simp [conforms] at hcp
          | _ => simp [htp, htv] at hcs
    | ptrAdd x p k =>
      simp only [checkStmt] at hcs
      cases htp : typeOf P fd.vars p with
      | none => simp [htp] at hcs
      | some tp =>
        cases htk : typeOf P fd.vars k with
        | none => simp [htp, htk] at hcs
        | some tk =>
          cases tp with
          | ptr t =>
            cases tk with
            | int w =>
              cases w <;> simp [htp, htk] at hcs
              obtain ⟨⟨hx, hup, huk⟩, rfl⟩ := hcs
              have hep := evalExpr_sound hl p (.ptr t) htp hup
              have hek := evalExpr_sound hl k (.int .u64) htk huk
              simp only [exec, atomic]
              cases hp : evalExpr l p with
              | error f => rw [hp] at hep; exact hep
              | ok pv =>
                cases hk : evalExpr l k with
                | error f => rw [hk] at hek; exact hek
                | ok kv =>
                  rw [hp] at hep; rw [hk] at hek; simp only [ExprOk] at hep hek
                  obtain ⟨hcp, hpp⟩ := hep
                  cases kv with
                  | int wk kk =>
                    simp [conforms] at hek; obtain ⟨rfl, -⟩ := hek.1
                    cases pv with
                    | ptr t' q =>
                      simp [conforms] at hcp; subst hcp
                      cases q with
                      | null => simp [ResOk]
                      | loc b o =>
                        simp only
                        cases hpa : m.heap.ptrAdd? b o kk with
                        | error f => exact ptrAdd?_fault hpp hpa
                        | ok o' =>
                          exact ⟨hm, HeapExt.refl _, hl.set hx (by simp [conforms])
                            (ptrAdd?_ok hpp hpa)⟩
                    | _ => simp [conforms] at hcp
                  | _ => simp [conforms] at hek
            | _ => simp [htp, htk] at hcs
          | _ => simp [htp, htk] at hcs
    | alloc x t c =>
      simp only [checkStmt] at hcs
      cases htc : typeOf P fd.vars c with
      | none => simp [htc] at hcs
      | some tc =>
        cases tc with
        | int w =>
          cases w <;> simp [htc] at hcs
          obtain ⟨⟨hx, hpf, hu⟩, rfl⟩ := hcs
          have hec := evalExpr_sound hl c (.int .u64) htc hu
          simp only [exec, atomic]
          cases hce : evalExpr l c with
          | error f => rw [hce] at hec; exact hec
          | ok cv =>
            rw [hce] at hec; simp only [ExprOk] at hec
            cases cv with
            | int wc k =>
              simp [conforms] at hec; obtain ⟨rfl, -⟩ := hec.1
              simp only
              split
              · simp [ResOk]
              · obtain ⟨z, hz⟩ := zeroOf_of_pointerFree _ _ hpf
                have hzc := zeroOf_conforms _ _ _ hz
                simp only [Program.zero?, hz]
                split
                · simp only [ResOk, Machine.record]
                  have ⟨hok, hext⟩ := alloc_ok (n := k) hm hpf hzc
                  refine ⟨hok, hext, (hl.mono_heap hext).set hx (by simp [conforms]) ?_⟩
                  simp only [PtrOk, Heap.alloc, Array.getElem?_push, ↓reduceIte]
                  exact ⟨_, rfl, rfl, Nat.zero_le _⟩
                · simp only [ResOk, Machine.record]; exact ⟨hm, HeapExt.refl _⟩
            | _ => simp [conforms] at hec
        | _ => simp [htc] at hcs
    | free p =>
      simp only [checkStmt] at hcs
      cases htp : typeOf P fd.vars p with
      | none => simp [htp] at hcs
      | some tp =>
        cases tp with
        | ptr t =>
          simp [htp] at hcs
          obtain ⟨hu, rfl⟩ := hcs
          have he := evalExpr_sound hl p (.ptr t) htp hu
          simp only [exec, atomic]
          cases hev : evalExpr l p with
          | error f => rw [hev] at he; exact he
          | ok v =>
            rw [hev] at he; simp only [ExprOk] at he
            obtain ⟨hc, hpv⟩ := he
            cases v with
            | ptr t' q =>
              cases q with
              | null => simp [ResOk]
              | loc b o =>
                cases o with
                | zero =>
                  simp only
                  cases hfr : m.heap.free? b with
                  | error f => exact free?_fault hpv hfr
                  | ok h' =>
                    obtain ⟨hok, hext⟩ := free?_ok hm hfr
                    exact ⟨hok, hext, hl.mono_heap hext⟩
                | succ o => simp [ResOk]
            | _ => simp [conforms] at hc
        | _ => simp [htp] at hcs
    | seq a b =>
      simp only [checkStmt] at hcs
      cases hca : checkStmt P fd A a with
      | none => simp [hca] at hcs
      | some A₁ =>
        simp [hca] at hcs
        rw [exec_seq_eq]
        have iha := ih m l a fd A A₁ hca hm hl
        cases hra : exec P L env n m l a with
        | normal m₁ l₁ =>
          rw [hra] at iha; obtain ⟨hm₁, he₁, hl₁⟩ := iha
          exact ResOk.ext he₁ (ih m₁ l₁ b fd A₁ A' hcs hm₁ hl₁)
        | oof => simp [ResOk]
        | _ => rw [hra] at iha; exact ResOk.nonNormal (by simp) iha
    | ite c a b =>
      simp only [checkStmt] at hcs
      split at hcs
      · simp at hcs
      · rename_i hcond
        simp only [not_or, Decidable.not_not, ne_eq] at hcond
        obtain ⟨htc, huc⟩ := hcond
        cases hca : checkStmt P fd A a with
        | none => simp [hca] at hcs
        | some A₁ =>
          cases hcb : checkStmt P fd A b with
          | none => simp [hca, hcb] at hcs
          | some A₂ =>
            simp [hca, hcb] at hcs
            have hec := evalExpr_sound hl c .bool htc huc
            rw [exec_ite_eq]
            -- The result set A' is covered by whichever branch runs normally.
            have branchA : ResOk P fd A' m.heap (exec P L env n m l a) := by
              have r := ih m l a fd A A₁ hca hm hl
              split at hcs
              · cases hcs
                exact ResOk.nonNormal (fun m' l' => exec_returns_not_normal _ _ _ _ _ _ ‹_›) r
              · split at hcs
                · cases hcs; exact r
                · cases hcs; exact r.weaken (fun y hy => (List.mem_filter.mp hy).1)
            have branchB : ResOk P fd A' m.heap (exec P L env n m l b) := by
              have r := ih m l b fd A A₂ hcb hm hl
              split at hcs
              · cases hcs; exact r
              · split at hcs
                · cases hcs
                  exact ResOk.nonNormal (fun m' l' => exec_returns_not_normal _ _ _ _ _ _ ‹_›) r
                · cases hcs; exact r.weaken (fun y hy => by simpa using (List.mem_filter.mp hy).2)
            cases hev : evalExpr l c with
            | error f => rw [hev] at hec; exact hec
            | ok cv =>
              rw [hev] at hec; simp only [ExprOk] at hec
              cases cv with
              | bool bv => cases bv
                           · exact branchB
                           · exact branchA
              | _ => simp [conforms] at hec
    | «while» c body =>
      simp only [checkStmt] at hcs
      split at hcs
      · simp at hcs
      · rename_i hcond
        simp only [not_or, Decidable.not_not, ne_eq] at hcond
        obtain ⟨htc, huc⟩ := hcond
        cases hcb : checkStmt P fd A body with
        | none => simp [hcb] at hcs
        | some Ab =>
          simp [hcb] at hcs; subst hcs
          have hec := evalExpr_sound hl c .bool htc huc
          have hsub := (checkStmt_sets body A Ab hcb hl.names).1
          rw [exec_while_eq]
          cases hev : evalExpr l c with
          | error f => rw [hev] at hec; exact hec
          | ok cv =>
            rw [hev] at hec; simp only [ExprOk] at hec
            cases cv with
            | bool bv =>
              cases bv with
              | false => exact ⟨hm, HeapExt.refl _, hl⟩
              | true =>
                simp only
                have hb := ih m l body fd A Ab hcb hm hl
                cases hrb : exec P L env n m l body with
                | normal m₁ l₁ =>
                  rw [hrb] at hb; obtain ⟨hm₁, he₁, hl₁⟩ := hb
                  have hloop : checkStmt P fd A (.while c body) = some A := by
                    simp [checkStmt, htc, huc, hcb]
                  exact ResOk.ext he₁ (ih m₁ l₁ (.while c body) fd A A hloop hm₁ (hl₁.mono_set hsub))
                | oof => simp [ResOk]
                | _ => rw [hrb] at hb; exact ResOk.nonNormal (by simp) hb
            | _ => simp [conforms] at hec
    | call x f args =>
      simp only [checkStmt] at hcs
      cases hg : P.fun? f with
      | none => simp [hg] at hcs
      | some g =>
        cases hts : typesOf P fd.vars args with
        | none => simp [hg, hts] at hcs
        | some ts =>
          simp [hg, hts] at hcs
          obtain ⟨⟨hts', hx, hu⟩, rfl⟩ := hcs
          have hes := evalExprs_sound hl args ts hts (by simpa using hu)
          have hgwf := Program.wf_fun hP hg
          simp only [FunDef.wf, decide_eq_true_eq, Bool.and_eq_true] at hgwf
          obtain ⟨hnd, -, -, hbody, hret⟩ := hgwf
          rw [exec_call_eq]
          cases hvs : evalExprs l args with
          | error e => rw [hvs] at hes; exact hes
          | ok vs =>
            rw [hvs] at hes; simp only [ExprsOk] at hes
            obtain ⟨hcv, hpv⟩ := hes
            subst hts'
            have hargs : P.argsOk g vs = true := argsOk_of_conforms hcv
            simp only [hg, hargs, if_true]
            cases hb : checkStmt P g g.paramNames g.body with
            | none => simp [hb] at hbody
            | some Ag =>
              have hlg : LocalsOk P g.vars g.paramNames m.heap (Locals.ofList (g.paramNames.zip vs)) :=
                localsOk_params g.params g.locals vs (FunDef.params_nodup hnd) hcv hpv
              have hres := ih m (Locals.ofList (g.paramNames.zip vs)) g.body g g.paramNames Ag hb hm hlg
              cases hr : exec P L env n m (Locals.ofList (g.paramNames.zip vs)) g.body with
              | ret m' v =>
                rw [hr] at hres; obtain ⟨hm', he', hcv', hpv'⟩ := hres
                simp only [Program.conforms?, hcv', if_true]
                exact ⟨hm', he', (hl.mono_heap he').set hx hcv' hpv'⟩
              | normal m' l' => exact absurd hr (exec_returns_not_normal _ _ _ _ _ _ hret)
              | fail m' f' => rw [hr] at hres; exact hres
              | stuck m' w => rw [hr] at hres; exact hres
              | oof => simp [ResOk]

/-! ## Transactions -/

theorem conforms_of_argsOk {P : Program} {g : FunDef} {vs : List Val}
    (h : P.argsOk g vs = true) : conformsAll P vs (g.params.map (·.2)) = true := by
  simp only [Program.argsOk, Bool.and_eq_true, beq_iff_eq] at h
  obtain ⟨hlen, hall⟩ := h
  suffices ∀ (ps : List (String × Ty)) (vs : List Val), ps.length = vs.length →
      (ps.zip vs).all (fun pv => P.conforms? pv.2 pv.1.2) = true →
      conformsAll P vs (ps.map (·.2)) = true from this g.params vs hlen hall
  intro ps
  induction ps with
  | nil => intro vs hl _; cases vs <;> simp_all [conformsAll]
  | cons p ps ih =>
    intro vs hl ha
    cases vs with
    | nil => simp at hl
    | cons v vs =>
      simp at hl ha
      have hrest := ih vs hl (by simpa using ha.2)
      simp only [List.map_cons, conformsAll, Bool.and_eq_true]
      exact ⟨by simpa [Program.conforms?] using ha.1, hrest⟩

mutual
theorem ptrOk_of_inputs {inputs : Array Block} :
    ∀ (v : Val), ptrsInInputs inputs v = true → PtrOk { blocks := inputs, owned := [] } v
  | .int _ _, _ => by simp [PtrOk]
  | .bool _, _ => by simp [PtrOk]
  | .ptr _ .null, _ => by simp [PtrOk]
  | .ptr t (.loc b o), h => by
      simp only [ptrsInInputs] at h
      cases hb : inputs[b]? with
      | none => simp [hb] at h
      | some blk =>
        simp [hb] at h
        exact ⟨blk, hb, h.1, h.2⟩
  | .struct _ fs, h => by
      simp only [ptrsInInputs] at h; simp only [PtrOk]; exact ptrOkAll_of_inputs fs h

theorem ptrOkAll_of_inputs {inputs : Array Block} :
    ∀ (vs : List Val), ptrsInInputsAll inputs vs = true →
      PtrOkAll { blocks := inputs, owned := [] } vs
  | [], _ => by simp [PtrOkAll]
  | v :: vs, h => by
      simp [ptrsInInputsAll] at h; simp only [PtrOkAll]
      exact ⟨ptrOk_of_inputs v h.1, ptrOkAll_of_inputs vs h.2⟩
end

theorem ptrOkAll_of_all {inputs : Array Block} :
    ∀ (vs : List Val), vs.all (ptrsInInputs inputs) = true →
      PtrOkAll { blocks := inputs, owned := [] } vs
  | [], _ => by simp [PtrOkAll]
  | v :: vs, h => by
      simp at h; simp only [PtrOkAll]
      exact ⟨ptrOk_of_inputs v h.1, ptrOkAll_of_all vs (by simpa using h.2)⟩

theorem heapOk_of_inputs {P : Program} {inputs : Array Block}
    (h : inputs.all P.blockOk = true) : HeapOk P { blocks := inputs, owned := [] } := by
  intro b blk hb
  have hmem := Array.mem_of_getElem? hb
  have hok := Array.all_eq_true_iff_forall_mem.mp h blk hmem
  simp only [Program.blockOk, Bool.and_eq_true] at hok
  obtain ⟨⟨-, hpf⟩, hcells⟩ := hok
  refine ⟨hpf, fun i c hc => ?_⟩
  exact Array.all_eq_true_iff_forall_mem.mp hcells c (Array.mem_of_getElem? hc)

/-- **Type soundness.** For a well-formed program, a well-formed entry and
    well-formed inputs, a transaction never ends stuck with a typing fault,
    for every environment, fuel and target layout. Any remaining stuck
    outcome is an arithmetic, bounds, liveness, allocation or leak fault. -/
theorem run_no_typing_fault {P : Program} {L : Layout} {env : Env} {fuel : Nat}
    {inputs : Array Block} {entry : String} {args : List Val} {h : Heap}
    (hP : P.wf = true) (hE : P.entryWf entry = true) (hI : InputWF P inputs entry args = true) :
    run P L env fuel inputs entry args ≠ .stuck h .typing := by
  simp only [InputWF] at hI
  simp only [Program.entryWf] at hE
  cases hfd : P.fun? entry with
  | none => simp [hfd] at hI
  | some fd =>
    simp only [hfd] at hI hE
    have hwf := Program.wf_fun hP hfd
    simp only [FunDef.wf, decide_eq_true_eq, Bool.and_eq_true] at hwf
    obtain ⟨hnd, -, -, hbody, hret⟩ := hwf
    simp only [Program.inputOk, Bool.and_eq_true] at hI
    obtain ⟨⟨hblocks, hargs⟩, hptrs⟩ := hI
    have hm0 := heapOk_of_inputs (P := P) hblocks
    have hl0 : LocalsOk P fd.vars fd.paramNames { blocks := inputs, owned := [] }
        (Locals.ofList (fd.paramNames.zip args)) :=
      localsOk_params fd.params fd.locals args (FunDef.params_nodup hnd)
        (conforms_of_argsOk hargs) (ptrOkAll_of_all args hptrs)
    cases hb : checkStmt P fd fd.paramNames fd.body with
    | none => simp [hb] at hbody
    | some A' =>
      have hres := exec_sound (L := L) (env := env) hP fuel
        { heap := { blocks := inputs, owned := [] }, trace := [] } _ fd.body fd _ A' hb hm0 hl0
      unfold run
      simp only [hfd, Program.inputOk, hblocks, hargs, hptrs, Bool.and_self, Bool.not_true,
        Bool.false_eq_true, ↓reduceIte]
      cases hr : exec P L env fuel { heap := { blocks := inputs, owned := [] }, trace := [] }
          (Locals.ofList (fd.paramNames.zip args)) fd.body with
      | ret m v =>
        rw [hr] at hres; obtain ⟨-, -, hcv, -⟩ := hres
        simp only [Program.conforms?, hcv, hE, Bool.and_self, Bool.not_true, Bool.false_eq_true,
          ↓reduceIte]
        split <;> simp
      | normal m l' => exact absurd hr (exec_returns_not_normal _ _ _ _ _ _ hret)
      | fail m f => simp
      | stuck m w =>
        rw [hr] at hres
        simp only [ResOk] at hres
        simp only [ne_eq, Outcome.stuck.injEq, not_and]
        intro _; exact hres
      | oof => simp

end KCore
