/-
Fuel monotonicity: a result other than `oof` is stable under more fuel.
This is what makes the fuel-indexed evaluator a faithful executable
presentation of one semantics (KCORE_SEMANTICS.md §6).
-/
import KCore.Semantics

namespace KCore

/-! One-step unfolding of the recursive statement forms. -/

theorem exec_seq_eq {P : Program} {L : Layout} {env : Env} {n : Nat} {m : Machine} {l : Locals} {a b : Stmt} :
    exec P L env (n + 1) m l (.seq a b) =
      match exec P L env n m l a with
      | .normal m' l' => exec P L env n m' l' b
      | r => r := rfl

theorem exec_ite_eq {P : Program} {L : Layout} {env : Env} {n : Nat} {m : Machine} {l : Locals}
    {c : Expr} {a b : Stmt} :
    exec P L env (n + 1) m l (.ite c a b) =
      match evalExpr l c with
      | .ok (.bool true) => exec P L env n m l a
      | .ok (.bool false) => exec P L env n m l b
      | .ok _ => .stuck m .typing
      | .error f => .stuck m f := rfl

theorem exec_while_eq {P : Program} {L : Layout} {env : Env} {n : Nat} {m : Machine} {l : Locals}
    {c : Expr} {body : Stmt} :
    exec P L env (n + 1) m l (.while c body) =
      match evalExpr l c with
      | .ok (.bool false) => .normal m l
      | .ok (.bool true) =>
          match exec P L env n m l body with
          | .normal m' l' => exec P L env n m' l' (.while c body)
          | r => r
      | .ok _ => .stuck m .typing
      | .error f => .stuck m f := rfl

theorem exec_call_eq {P : Program} {L : Layout} {env : Env} {n : Nat} {m : Machine} {l : Locals}
    {x f : String} {args : List Expr} :
    exec P L env (n + 1) m l (.call x f args) =
      match evalExprs l args, P.fun? f with
      | .error e, _ => .stuck m e
      | .ok _, none => .stuck m .typing
      | .ok vs, some fd =>
          if P.argsOk fd vs then
            match exec P L env n m (Locals.ofList (fd.paramNames.zip vs)) fd.body with
            | .ret m' v =>
                if P.conforms? v fd.result then .normal m' (l.set x v) else .stuck m' .typing
            | .normal m' _ => .stuck m' .typing
            | r => r
          else .stuck m .typing := rfl

theorem exec_succ {P : Program} {L : Layout} {env : Env} :
    ∀ (n : Nat) (m : Machine) (l : Locals) (s : Stmt) (r : Res),
      exec P L env n m l s = r → r ≠ .oof → exec P L env (n + 1) m l s = r := by
  intro n
  induction n with
  | zero => intro m l s r h hr; simp [exec] at h; exact absurd h.symm hr
  | succ n ih =>
    intro m l s r h hr
    cases s with
    | seq a b =>
      rw [exec_seq_eq] at h ⊢
      cases ha : exec P L env n m l a with
      | normal m' l' =>
          rw [ha] at h; rw [ih _ _ _ _ ha (by simp)]; exact ih _ _ _ _ h hr
      | oof => rw [ha] at h; exact absurd h.symm hr
      | ret m' v => rw [ha] at h; rw [ih _ _ _ _ ha (by simp)]; exact h
      | fail m' f => rw [ha] at h; rw [ih _ _ _ _ ha (by simp)]; exact h
      | stuck m' w => rw [ha] at h; rw [ih _ _ _ _ ha (by simp)]; exact h
    | ite c a b =>
      rw [exec_ite_eq] at h ⊢
      split at h
      · exact ih _ _ _ _ h hr
      · exact ih _ _ _ _ h hr
      · exact h
      · exact h
    | «while» c body =>
      rw [exec_while_eq] at h ⊢
      split at h
      · exact h
      · cases hb : exec P L env n m l body with
        | normal m' l' =>
            rw [hb] at h; rw [ih _ _ _ _ hb (by simp)]; exact ih _ _ _ _ h hr
        | oof => rw [hb] at h; exact absurd h.symm hr
        | ret m' v => rw [hb] at h; rw [ih _ _ _ _ hb (by simp)]; exact h
        | fail m' f => rw [hb] at h; rw [ih _ _ _ _ hb (by simp)]; exact h
        | stuck m' w => rw [hb] at h; rw [ih _ _ _ _ hb (by simp)]; exact h
      · exact h
      · exact h
    | call x f args =>
      rw [exec_call_eq] at h ⊢
      split at h
      · exact h
      · exact h
      · rename_i vs fd hvs hfd
        split at h
        · rename_i hok
          rw [if_pos hok]
          cases hb : exec P L env n m (Locals.ofList (fd.paramNames.zip vs)) fd.body with
          | oof => rw [hb] at h; exact absurd h.symm hr
          | ret m' v => rw [hb] at h; rw [ih _ _ _ _ hb (by simp)]; exact h
          | normal m' l' => rw [hb] at h; rw [ih _ _ _ _ hb (by simp)]; exact h
          | fail m' f' => rw [hb] at h; rw [ih _ _ _ _ hb (by simp)]; exact h
          | stuck m' w => rw [hb] at h; rw [ih _ _ _ _ hb (by simp)]; exact h
        · rename_i hok; rw [if_neg hok]; exact h
    | _ => simp only [exec] at h ⊢; exact h

/-- Any larger fuel gives the same non-`oof` result. -/
theorem exec_mono {P : Program} {L : Layout} {env : Env} {n n' : Nat} {m : Machine} {l : Locals}
    {s : Stmt} {r : Res} (hle : n ≤ n') (h : exec P L env n m l s = r) (hr : r ≠ .oof) :
    exec P L env n' m l s = r := by
  induction hle with
  | refl => exact h
  | step _ ih => exact exec_succ _ _ _ _ _ ih hr

/-- Determinism across fuel: two non-`oof` results of the same statement agree. -/
theorem exec_det {P : Program} {L : Layout} {env : Env} {n₁ n₂ : Nat} {m : Machine} {l : Locals}
    {s : Stmt} {r₁ r₂ : Res} (h₁ : exec P L env n₁ m l s = r₁) (h₂ : exec P L env n₂ m l s = r₂)
    (hr₁ : r₁ ≠ .oof) (hr₂ : r₂ ≠ .oof) : r₁ = r₂ := by
  rcases Nat.le_total n₁ n₂ with hle | hle
  · rw [← exec_mono hle h₁ hr₁]; exact h₂
  · rw [← exec_mono hle h₂ hr₂]; exact h₁.symm

end KCore
