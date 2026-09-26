/-
Inductive big-step semantics of KCore (KCORE_SEMANTICS.md §6) and its
agreement with the fuel-indexed evaluator:

    Exec P L env m l s r  ↔  ∃ n, exec P L env n m l s = r     (for r ≠ oof)

The relation is the object that per-program proofs (T1, T2, T4, T6) reason
about. The evaluator is what runs and what printed C is differentially
tested against. Atomic statements share one definition (`atomic`).
-/
import KCore.Fuel

namespace KCore

/-- Results that end a block early: `seq` and loops pass them through. -/
def Res.abrupt : Res → Prop
  | .ret _ _ | .fail _ _ | .stuck _ _ => True
  | _ => False

/-- Results a callee may pass through to its caller unchanged. -/
def Res.propagates : Res → Prop
  | .fail _ _ | .stuck _ _ => True
  | _ => False

inductive Exec (P : Program) (L : Layout) (env : Env) : Machine → Locals → Stmt → Res → Prop where
  | atom {m l s} : s.isAtomic = true → Exec P L env m l s (atomic P L env m l s)
  | seqNormal {m l a b m' l' r} :
      Exec P L env m l a (.normal m' l') → Exec P L env m' l' b r → Exec P L env m l (.seq a b) r
  | seqAbrupt {m l a b r} :
      Exec P L env m l a r → r.abrupt → Exec P L env m l (.seq a b) r
  | iteTrue {m l c a b r} :
      evalExpr l c = .ok (.bool true) → Exec P L env m l a r → Exec P L env m l (.ite c a b) r
  | iteFalse {m l c a b r} :
      evalExpr l c = .ok (.bool false) → Exec P L env m l b r → Exec P L env m l (.ite c a b) r
  | iteShape {m l c a b v} :
      evalExpr l c = .ok v → (∀ bv, v ≠ .bool bv) → Exec P L env m l (.ite c a b) (.stuck m .typing)
  | iteFault {m l c a b f} :
      evalExpr l c = .error f → Exec P L env m l (.ite c a b) (.stuck m f)
  | whileFalse {m l c body} :
      evalExpr l c = .ok (.bool false) → Exec P L env m l (.while c body) (.normal m l)
  | whileNormal {m l c body m' l' r} :
      evalExpr l c = .ok (.bool true) → Exec P L env m l body (.normal m' l') →
      Exec P L env m' l' (.while c body) r → Exec P L env m l (.while c body) r
  | whileAbrupt {m l c body r} :
      evalExpr l c = .ok (.bool true) → Exec P L env m l body r → r.abrupt →
      Exec P L env m l (.while c body) r
  | whileShape {m l c body v} :
      evalExpr l c = .ok v → (∀ bv, v ≠ .bool bv) → Exec P L env m l (.while c body) (.stuck m .typing)
  | whileFault {m l c body f} :
      evalExpr l c = .error f → Exec P L env m l (.while c body) (.stuck m f)
  | callRet {m l x f args vs fd m' v} :
      evalExprs l args = .ok vs → P.fun? f = some fd → P.argsOk fd vs = true →
      Exec P L env m (Locals.ofList (fd.paramNames.zip vs)) fd.body (.ret m' v) →
      P.conforms? v fd.result = true →
      Exec P L env m l (.call x f args) (.normal m' (l.set x v))
  | callBadResult {m l x f args vs fd m' v} :
      evalExprs l args = .ok vs → P.fun? f = some fd → P.argsOk fd vs = true →
      Exec P L env m (Locals.ofList (fd.paramNames.zip vs)) fd.body (.ret m' v) →
      P.conforms? v fd.result = false →
      Exec P L env m l (.call x f args) (.stuck m' .typing)
  | callFellOff {m l x f args vs fd m' l'} :
      evalExprs l args = .ok vs → P.fun? f = some fd → P.argsOk fd vs = true →
      Exec P L env m (Locals.ofList (fd.paramNames.zip vs)) fd.body (.normal m' l') →
      Exec P L env m l (.call x f args) (.stuck m' .typing)
  | callPropagate {m l x f args vs fd r} :
      evalExprs l args = .ok vs → P.fun? f = some fd → P.argsOk fd vs = true →
      Exec P L env m (Locals.ofList (fd.paramNames.zip vs)) fd.body r → r.propagates →
      Exec P L env m l (.call x f args) r
  | callBadArgs {m l x f args vs fd} :
      evalExprs l args = .ok vs → P.fun? f = some fd → P.argsOk fd vs = false →
      Exec P L env m l (.call x f args) (.stuck m .typing)
  | callUnresolved {m l x f args vs} :
      evalExprs l args = .ok vs → P.fun? f = none →
      Exec P L env m l (.call x f args) (.stuck m .typing)
  | callArgFault {m l x f args e} :
      evalExprs l args = .error e → Exec P L env m l (.call x f args) (.stuck m e)

theorem atomic_ne_oof {P : Program} {L : Layout} {env : Env} {m : Machine} {l : Locals} {s : Stmt} :
    atomic P L env m l s ≠ .oof := by
  cases s <;> simp only [atomic] <;> (repeat' split) <;> simp

/-- The relation never produces `oof`: fuel is not part of the semantics. -/
theorem Exec.ne_oof {P : Program} {L : Layout} {env : Env} {m : Machine} {l : Locals} {s : Stmt} {r : Res}
    (h : Exec P L env m l s r) : r ≠ .oof := by
  induction h with
  | atom => exact atomic_ne_oof
  | whileFalse => simp
  | iteShape | iteFault | whileShape | whileFault | callBadArgs | callUnresolved
  | callFellOff | callBadResult | callArgFault => simp
  | callRet => simp
  | seqAbrupt _ ha _ | whileAbrupt _ _ ha _ =>
      intro hr; subst hr; simp [Res.abrupt] at ha
  | callPropagate _ _ _ _ hp _ => intro hr; subst hr; simp [Res.propagates] at hp
  | seqNormal _ _ _ ih | iteTrue _ _ ih | iteFalse _ _ ih | whileNormal _ _ _ _ ih => exact ih

/-- **Completeness of the evaluator:** every derivation is reached with enough
    fuel. -/
theorem Exec.to_exec {P : Program} {L : Layout} {env : Env} {m : Machine} {l : Locals} {s : Stmt} {r : Res}
    (h : Exec P L env m l s r) : ∃ n, exec P L env n m l s = r := by
  induction h with
  | @atom m l s hs =>
      refine ⟨1, ?_⟩
      cases s <;> simp_all [Stmt.isAtomic, exec]
  | @seqNormal m l a b m' l' r ha hb iha ihb =>
      obtain ⟨n₁, h₁⟩ := iha; obtain ⟨n₂, h₂⟩ := ihb
      refine ⟨max n₁ n₂ + 1, ?_⟩
      rw [exec_seq_eq, exec_mono (Nat.le_max_left _ _) h₁ (by simp)]
      exact exec_mono (Nat.le_max_right _ _) h₂ hb.ne_oof
  | @seqAbrupt m l a b r ha hab iha =>
      obtain ⟨n, hn⟩ := iha
      refine ⟨n + 1, ?_⟩
      rw [exec_seq_eq, hn]
      cases r <;> simp_all [Res.abrupt]
  | iteTrue hc _ ih =>
      obtain ⟨n, hn⟩ := ih; exact ⟨n + 1, by rw [exec_ite_eq, hc]; exact hn⟩
  | iteFalse hc _ ih =>
      obtain ⟨n, hn⟩ := ih; exact ⟨n + 1, by rw [exec_ite_eq, hc]; exact hn⟩
  | iteShape hc hv =>
      refine ⟨1, ?_⟩
      rw [exec_ite_eq, hc]
      split
      · rename_i h; cases h; exact absurd rfl (hv true)
      · rename_i h; cases h; exact absurd rfl (hv false)
      · rfl
      · rename_i h; cases h
  | iteFault hc => exact ⟨1, by rw [exec_ite_eq, hc]⟩
  | whileFalse hc => exact ⟨1, by rw [exec_while_eq, hc]⟩
  | @whileNormal m l c body m' l' r hc hb hw ihb ihw =>
      obtain ⟨n₁, h₁⟩ := ihb; obtain ⟨n₂, h₂⟩ := ihw
      refine ⟨max n₁ n₂ + 1, ?_⟩
      rw [exec_while_eq, hc]
      simp only
      rw [exec_mono (Nat.le_max_left _ _) h₁ (by simp)]
      exact exec_mono (Nat.le_max_right _ _) h₂ hw.ne_oof
  | @whileAbrupt m l c body r hc hb hab ih =>
      obtain ⟨n, hn⟩ := ih
      refine ⟨n + 1, ?_⟩
      rw [exec_while_eq, hc]
      simp only
      rw [hn]
      cases r <;> simp_all [Res.abrupt]
  | whileShape hc hv =>
      refine ⟨1, ?_⟩
      rw [exec_while_eq, hc]
      split
      · rename_i h; cases h; exact absurd rfl (hv false)
      · rename_i h; cases h; exact absurd rfl (hv true)
      · rfl
      · rename_i h; cases h
  | whileFault hc => exact ⟨1, by rw [exec_while_eq, hc]⟩
  | callRet hvs hfd hok _ hres ih =>
      obtain ⟨n, hn⟩ := ih
      exact ⟨n + 1, by rw [exec_call_eq, hvs, hfd]; simp only; rw [if_pos hok, hn]; simp [hres]⟩
  | callBadResult hvs hfd hok _ hres ih =>
      obtain ⟨n, hn⟩ := ih
      exact ⟨n + 1, by rw [exec_call_eq, hvs, hfd]; simp only; rw [if_pos hok, hn]; simp [hres]⟩
  | callFellOff hvs hfd hok _ ih =>
      obtain ⟨n, hn⟩ := ih
      exact ⟨n + 1, by rw [exec_call_eq, hvs, hfd]; simp only; rw [if_pos hok, hn]⟩
  | @callPropagate m l x f args vs fd r hvs hfd hok hb hp ih =>
      obtain ⟨n, hn⟩ := ih
      refine ⟨n + 1, ?_⟩
      rw [exec_call_eq, hvs, hfd]; simp only; rw [if_pos hok, hn]
      cases r <;> simp_all [Res.propagates]
  | callBadArgs hvs hfd hok =>
      exact ⟨1, by rw [exec_call_eq, hvs, hfd]; simp only; rw [if_neg (by simp [hok])]⟩
  | callUnresolved hvs hfd => exact ⟨1, by rw [exec_call_eq, hvs, hfd]⟩
  | callArgFault hvs => exact ⟨1, by rw [exec_call_eq, hvs]⟩

/-- **Soundness of the evaluator:** every non-`oof` result is derivable. -/
theorem exec_to_Exec {P : Program} {L : Layout} {env : Env} :
    ∀ (n : Nat) (m : Machine) (l : Locals) (s : Stmt) (r : Res),
      exec P L env n m l s = r → r ≠ .oof → Exec P L env m l s r := by
  intro n
  induction n with
  | zero => intro m l s r h hr; simp [exec] at h; exact absurd h.symm hr
  | succ n ih =>
    intro m l s r h hr
    cases s with
    | seq a b =>
      rw [exec_seq_eq] at h
      cases ha : exec P L env n m l a with
      | normal m' l' =>
          rw [ha] at h; exact .seqNormal (ih _ _ _ _ ha (by simp)) (ih _ _ _ _ h hr)
      | oof => rw [ha] at h; exact absurd h.symm hr
      | ret m' v => rw [ha] at h; subst h; exact .seqAbrupt (ih _ _ _ _ ha (by simp)) trivial
      | fail m' f => rw [ha] at h; subst h; exact .seqAbrupt (ih _ _ _ _ ha (by simp)) trivial
      | stuck m' w => rw [ha] at h; subst h; exact .seqAbrupt (ih _ _ _ _ ha (by simp)) trivial
    | ite c a b =>
      rw [exec_ite_eq] at h
      split at h
      · exact .iteTrue ‹_› (ih _ _ _ _ h hr)
      · exact .iteFalse ‹_› (ih _ _ _ _ h hr)
      · subst h
        refine .iteShape ‹evalExpr _ _ = .ok _› (fun bv hbv => ?_)
        subst hbv; cases bv <;> simp_all
      · subst h; exact .iteFault ‹_›
    | «while» c body =>
      rw [exec_while_eq] at h
      split at h
      · subst h; exact .whileFalse ‹_›
      · rename_i hc
        cases hb : exec P L env n m l body with
        | normal m' l' =>
            rw [hb] at h
            exact .whileNormal hc (ih _ _ _ _ hb (by simp)) (ih _ _ _ _ h hr)
        | oof => rw [hb] at h; exact absurd h.symm hr
        | ret m' v => rw [hb] at h; subst h; exact .whileAbrupt hc (ih _ _ _ _ hb (by simp)) trivial
        | fail m' f => rw [hb] at h; subst h; exact .whileAbrupt hc (ih _ _ _ _ hb (by simp)) trivial
        | stuck m' w => rw [hb] at h; subst h; exact .whileAbrupt hc (ih _ _ _ _ hb (by simp)) trivial
      · subst h
        refine .whileShape ‹evalExpr _ _ = .ok _› (fun bv hbv => ?_)
        subst hbv; cases bv <;> simp_all
      · subst h; exact .whileFault ‹_›
    | call x f args =>
      rw [exec_call_eq] at h
      split at h
      · subst h; exact .callArgFault ‹_›
      · subst h; exact .callUnresolved ‹_› ‹_›
      · rename_i vs fd hvs hfd
        split at h
        · rename_i hok
          cases hb : exec P L env n m (Locals.ofList (fd.paramNames.zip vs)) fd.body with
          | ret m' v =>
              rw [hb] at h
              cases hres : P.conforms? v fd.result
              · simp [hres] at h; subst h
                exact .callBadResult hvs hfd hok (ih _ _ _ _ hb (by simp)) hres
              · simp [hres] at h; subst h
                exact .callRet hvs hfd hok (ih _ _ _ _ hb (by simp)) hres
          | normal m' l' => rw [hb] at h; subst h; exact .callFellOff hvs hfd hok (ih _ _ _ _ hb (by simp))
          | fail m' f' => rw [hb] at h; subst h; exact .callPropagate hvs hfd hok (ih _ _ _ _ hb (by simp)) trivial
          | stuck m' w => rw [hb] at h; subst h; exact .callPropagate hvs hfd hok (ih _ _ _ _ hb (by simp)) trivial
          | oof => rw [hb] at h; exact absurd h.symm hr
        · rename_i hnok; subst h; exact .callBadArgs hvs hfd (by simpa using hnok)
    | _ =>
      simp only [exec] at h
      subst h
      exact .atom rfl

/-- **Agreement.** The relation and the evaluator define the same semantics. -/
theorem Exec_iff_exec {P : Program} {L : Layout} {env : Env} {m : Machine} {l : Locals} {s : Stmt} {r : Res} :
    Exec P L env m l s r ↔ (r ≠ .oof ∧ ∃ n, exec P L env n m l s = r) :=
  ⟨fun h => ⟨h.ne_oof, h.to_exec⟩, fun ⟨hr, n, hn⟩ => exec_to_Exec n m l s r hn hr⟩

/-- The relation is deterministic. -/
theorem Exec.det {P : Program} {L : Layout} {env : Env} {m : Machine} {l : Locals} {s : Stmt} {r₁ r₂ : Res}
    (h₁ : Exec P L env m l s r₁) (h₂ : Exec P L env m l s r₂) : r₁ = r₂ := by
  obtain ⟨n₁, e₁⟩ := h₁.to_exec
  obtain ⟨n₂, e₂⟩ := h₂.to_exec
  exact exec_det e₁ e₂ h₁.ne_oof h₂.ne_oof

end KCore
