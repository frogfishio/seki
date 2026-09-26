/-
Totality: an admitted kernel, applied to an argument of its parameter type,
always reaches a decision.

    theorem totality : Admit.module m = true → k ∈ m.kernels →
      HasTypes m.types args k.params → ∃ o, k.eval args = some o

`HasType ds v t` says value `v` is a value of type `t` under declarations
`ds`: integers within their width, octet strings of their declared length,
records with every field typed, and variants at a declared case with the
case's payload. The theorem rests on one lemma per level: every admitted
expression evaluates to a value of its claimed type (`expr_sound`), and every
admitted kernel expression evaluates to a decision (`kexpr_total`).

This is the property the lowering to KCore relies on: a Seki kernel has no
failure mode of its own.
-/
import Seki.Eval
import Seki.Admit

namespace Seki

open Admit (body?)

mutual
inductive HasType (ds : List Decl) : Value → Ty → Prop
  | unit : HasType ds .unit .unit
  | bool (b : Bool) : HasType ds (.bool b) .bool
  | int (w : IntTy) (n : Nat) : n < 2 ^ w.bits → HasType ds (.int w n) (.int w)
  | bytes (bs : List Nat) (n : Nat) : bs.length = n → (∀ b ∈ bs, b < 256) →
      HasType ds (.bytes bs) (.bytes n)
  | digest (bs : List Nat) (n : Nat) : bs.length = n → (∀ b ∈ bs, b < 256) →
      HasType ds (.bytes bs) (.digest n)
  | alias (i : Nat) (r : Ty) (v : Value) : body? ds i = some (.alias r) →
      HasType ds v r → HasType ds v (.declared i)
  | nominal (i : Nat) (r : Ty) (v : Value) : body? ds i = some (.nominal r) →
      HasType ds v r → HasType ds v (.declared i)
  | record (i : Nat) (fs : List Field) (vs : List Value) : body? ds i = some (.record fs) →
      HasTypes ds vs (fs.map (·.ty)) → HasType ds (.record vs) (.declared i)
  | variant (i : Nat) (cs : List Case) (c : Case) : body? ds i = some (.variant cs) →
      c ∈ cs → c.payload = none → HasType ds (.variant c.tag none) (.declared i)
  | variantPayload (i : Nat) (cs : List Case) (c : Case) (fs : List Field) (vs : List Value) :
      body? ds i = some (.variant cs) → c ∈ cs → c.payload = some fs →
      HasTypes ds vs (fs.map (·.ty)) → HasType ds (.variant c.tag (some vs)) (.declared i)

inductive HasTypes (ds : List Decl) : List Value → List Ty → Prop
  | nil : HasTypes ds [] []
  | cons {v : Value} {t : Ty} {vs : List Value} {ts : List Ty} :
      HasType ds v t → HasTypes ds vs ts → HasTypes ds (v :: vs) (t :: ts)
end

variable {ds : List Decl}

/-! ## Lists of typed values -/

theorem HasTypes.get :
    ∀ {i : Nat} {vs : List Value} {ts : List Ty} {t : Ty},
      HasTypes ds vs ts → ts[i]? = some t → ∃ v, vs[i]? = some v ∧ HasType ds v t
  | i, vs, ts, t, h, hi => by
      induction i generalizing vs ts with
      | zero =>
          cases h with
          | nil => simp at hi
          | cons hv _ => simp at hi; subst hi; exact ⟨_, rfl, hv⟩
      | succ i ih =>
          cases h with
          | nil => simp at hi
          | cons _ hr => simpa using ih _ _ hr (by simpa using hi)

theorem HasTypes.length_eq :
    ∀ {vs : List Value} {ts : List Ty}, HasTypes ds vs ts → vs.length = ts.length
  | vs, ts, h => by
      induction vs generalizing ts with
      | nil => cases h; rfl
      | cons v vs ih => cases h with
        | cons _ hr => simp [ih _ hr]

/-! ## Inversion for the types operators act on -/

theorem HasType.bool_inv {v : Value} (h : HasType ds v .bool) : ∃ b, v = .bool b := by
  cases h; exact ⟨_, rfl⟩

/-- A value whose type resolves to an integer type is an integer of that width. -/
theorem HasType.repr_int :
    ∀ (fuel : Nat) {v : Value} {t : Ty} {w : IntTy},
      HasType ds v t → Admit.repr ds fuel t = .int w → ∃ n, v = .int w n
  | 0, v, t, w, h, hr => by
      simp [Admit.repr] at hr; subst hr; cases h; exact ⟨_, rfl⟩
  | fuel + 1, v, t, w, h, hr => by
      cases t with
      | declared i =>
          simp only [Admit.repr] at hr
          cases hb : body? ds i with
          | none => rw [hb] at hr; simp at hr
          | some b =>
              rw [hb] at hr
              cases b with
              | alias r =>
                  simp at hr
                  cases h with
                  | alias _ r' _ hb' hv =>
                      rw [hb] at hb'; cases hb'; exact HasType.repr_int fuel hv hr
                  | nominal _ _ _ hb' => rw [hb] at hb'; cases hb'
                  | record _ _ _ hb' => rw [hb] at hb'; cases hb'
                  | variant _ _ _ hb' => rw [hb] at hb'; cases hb'
                  | variantPayload _ _ _ _ _ hb' => rw [hb] at hb'; cases hb'
              | nominal r =>
                  simp at hr
                  cases h with
                  | nominal _ r' _ hb' hv =>
                      rw [hb] at hb'; cases hb'; exact HasType.repr_int fuel hv hr
                  | alias _ _ _ hb' => rw [hb] at hb'; cases hb'
                  | record _ _ _ hb' => rw [hb] at hb'; cases hb'
                  | variant _ _ _ hb' => rw [hb] at hb'; cases hb'
                  | variantPayload _ _ _ _ _ hb' => rw [hb] at hb'; cases hb'
              | record _ => simp at hr
              | variant _ => simp at hr
      | int w' => simp [Admit.repr] at hr; subst hr; cases h; exact ⟨_, rfl⟩
      | _ => simp [Admit.repr] at hr

theorem isInt_iff {t : Ty} : Admit.isInt t = true ↔ ∃ w, t = .int w := by
  cases t <;> simp [Admit.isInt]

theorem HasType.record_inv {v : Value} {r : Nat} {flds : List Field}
    (h : HasType ds v (.declared r)) (hb : body? ds r = some (.record flds)) :
    ∃ vs, v = .record vs ∧ HasTypes ds vs (flds.map (·.ty)) := by
  cases h with
  | record _ _ _ hb' hvs => rw [hb] at hb'; cases hb'; exact ⟨_, rfl, hvs⟩
  | alias _ _ _ hb' => rw [hb] at hb'; cases hb'
  | nominal _ _ _ hb' => rw [hb] at hb'; cases hb'
  | variant _ _ _ hb' => rw [hb] at hb'; cases hb'
  | variantPayload _ _ _ _ _ hb' => rw [hb] at hb'; cases hb'

/-! ## Expressions evaluate to values of their claimed type -/

mutual
theorem expr_sound {tenv : List Ty} {env : List Value} (henv : HasTypes ds env tenv) :
    ∀ (e : Expr), Admit.okExpr ds tenv e = true →
      ∃ v, evalExpr env e = some v ∧ HasType ds v e.ty
  | .mk t term, h => by
      simp only [Admit.okExpr] at h
      obtain ⟨v, hv, ht⟩ := term_sound henv t term h
      exact ⟨v, by simp only [evalExpr]; exact hv, ht⟩

theorem term_sound {tenv : List Ty} {env : List Value} (henv : HasTypes ds env tenv) (t : Ty) :
    ∀ (term : Term), Admit.okTerm ds tenv t term = true →
      ∃ v, evalTerm env term = some v ∧ HasType ds v t
  | .unit, h => by
      simp only [Admit.okTerm, beq_iff_eq] at h; subst h
      exact ⟨.unit, by simp only [evalTerm], .unit⟩
  | .bool b, h => by
      simp only [Admit.okTerm, beq_iff_eq] at h; subst h
      exact ⟨.bool b, by simp only [evalTerm], .bool b⟩
  | .int w n, h => by
      simp only [Admit.okTerm, Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq] at h
      obtain ⟨rfl, hn⟩ := h
      exact ⟨.int w n, by simp only [evalTerm], .int w n hn⟩
  | .local i, h => by
      simp only [Admit.okTerm, beq_iff_eq] at h
      obtain ⟨v, hv, ht⟩ := henv.get h
      exact ⟨v, by simp only [evalTerm]; exact hv, ht⟩
  | .record r fs, h => by
      simp only [Admit.okTerm, Bool.and_eq_true, beq_iff_eq] at h
      obtain ⟨rfl, h⟩ := h
      split at h
      · rename_i flds hb
        obtain ⟨vs, hvs, hts⟩ := inits_sound henv flds 0 fs h
        exact ⟨.record vs, by simp only [evalTerm, hvs, Option.map_some],
          .record r flds vs hb hts⟩
      · cases h
  | .project e r f, h => by
      simp only [Admit.okTerm, Bool.and_eq_true, beq_iff_eq] at h
      obtain ⟨⟨he, hty⟩, h⟩ := h
      split at h
      · rename_i flds hb
        obtain ⟨v, hv, ht⟩ := expr_sound henv e he
        rw [hty] at ht
        obtain ⟨vs, rfl, hvs⟩ := ht.record_inv hb
        have hf : (flds.map (·.ty))[f]? = some t := by simpa using h
        obtain ⟨x, hx, htx⟩ := hvs.get hf
        exact ⟨x, by simp only [evalTerm, hv]; exact hx, htx⟩
      · cases h
  | .variant r tag fs, h => by
      simp only [Admit.okTerm, Bool.and_eq_true, beq_iff_eq] at h
      obtain ⟨rfl, h⟩ := h
      split at h
      · rename_i cs hb
        split at h
        · rename_i ctag name hc
          obtain ⟨vs, hvs, hts⟩ := named_sound henv [] fs h
          have hvs0 : vs = [] := by cases hts; rfl
          subst hvs0
          have hmem := List.mem_of_find?_eq_some hc
          have htag : ctag = tag := by simpa using List.find?_some hc
          subst htag
          refine ⟨.variant ctag none, ?_, ?_⟩
          · simp only [evalTerm, hvs, Option.map_some, List.isEmpty_nil, if_true]
          · exact HasType.variant r cs ⟨ctag, name, none⟩ hb hmem rfl
        · rename_i ctag name flds hc
          simp only [Bool.and_eq_true, Bool.not_eq_true', List.isEmpty_eq_false_iff] at h
          obtain ⟨hne, h⟩ := h
          obtain ⟨vs, hvs, hts⟩ := named_sound henv flds fs h
          have hlen := hts.length_eq
          have hvne : vs.isEmpty = false := by
            cases vs with
            | nil => simp at hlen; exact absurd (List.eq_nil_of_length_eq_zero hlen.symm) hne
            | cons _ _ => rfl
          have hmem := List.mem_of_find?_eq_some hc
          have htag : ctag = tag := by simpa using List.find?_some hc
          subst htag
          refine ⟨.variant ctag (some vs), ?_, ?_⟩
          · simp only [evalTerm, hvs, Option.map_some, hvne, Bool.false_eq_true, if_false]
          · exact HasType.variantPayload r cs ⟨ctag, name, some flds⟩ flds vs hb hmem rfl hts
        · cases h
      · cases h
  | .eq a b, h => by
      simp only [Admit.okTerm, Bool.and_eq_true, beq_iff_eq] at h
      obtain ⟨⟨⟨rfl, ha⟩, hb⟩, _⟩ := h
      obtain ⟨va, hva, _⟩ := expr_sound henv a ha
      obtain ⟨vb, hvb, _⟩ := expr_sound henv b hb
      exact ⟨.bool (va.beq vb), by simp only [evalTerm, hva, hvb], .bool _⟩
  | .ne a b, h => by
      simp only [Admit.okTerm, Bool.and_eq_true, beq_iff_eq] at h
      obtain ⟨⟨⟨rfl, ha⟩, hb⟩, _⟩ := h
      obtain ⟨va, hva, _⟩ := expr_sound henv a ha
      obtain ⟨vb, hvb, _⟩ := expr_sound henv b hb
      exact ⟨.bool (!va.beq vb), by simp only [evalTerm, hva, hvb], .bool _⟩
  | .andThen a b, h => by
      simp only [Admit.okTerm, Bool.and_eq_true, beq_iff_eq] at h
      obtain ⟨⟨⟨⟨rfl, ha⟩, hb⟩, hta⟩, htb⟩ := h
      obtain ⟨va, hva, tva⟩ := expr_sound henv a ha
      rw [hta] at tva
      obtain ⟨x, rfl⟩ := tva.bool_inv
      cases x with
      | false => exact ⟨_, by simp only [evalTerm, hva], .bool false⟩
      | true =>
          obtain ⟨vb, hvb, tvb⟩ := expr_sound henv b hb
          rw [htb] at tvb
          obtain ⟨y, rfl⟩ := tvb.bool_inv
          exact ⟨_, by simp only [evalTerm, hva, hvb], .bool y⟩
  | .orElse a b, h => by
      simp only [Admit.okTerm, Bool.and_eq_true, beq_iff_eq] at h
      obtain ⟨⟨⟨⟨rfl, ha⟩, hb⟩, hta⟩, htb⟩ := h
      obtain ⟨va, hva, tva⟩ := expr_sound henv a ha
      rw [hta] at tva
      obtain ⟨x, rfl⟩ := tva.bool_inv
      cases x with
      | true => exact ⟨_, by simp only [evalTerm, hva], .bool true⟩
      | false =>
          obtain ⟨vb, hvb, tvb⟩ := expr_sound henv b hb
          rw [htb] at tvb
          obtain ⟨y, rfl⟩ := tvb.bool_inv
          exact ⟨_, by simp only [evalTerm, hva, hvb], .bool y⟩
  | .cmp op a b, h => by
      simp only [Admit.okTerm, Bool.and_eq_true, beq_iff_eq] at h
      obtain ⟨⟨⟨⟨rfl, ha⟩, hb⟩, hab⟩, hint⟩ := h
      obtain ⟨w, hw⟩ := isInt_iff.mp hint
      obtain ⟨va, hva, tva⟩ := expr_sound henv a ha
      obtain ⟨vb, hvb, tvb⟩ := expr_sound henv b hb
      rw [← hab] at tvb
      obtain ⟨x, rfl⟩ := HasType.repr_int _ tva hw
      obtain ⟨y, rfl⟩ := HasType.repr_int _ tvb hw
      exact ⟨.bool (cmp op x y), by simp only [evalTerm, hva, hvb, beq_self_eq_true, if_true], .bool _⟩

theorem inits_sound {tenv : List Ty} {env : List Value} (henv : HasTypes ds env tenv) :
    ∀ (flds : List Field) (i : Nat) (fs : Inits), Admit.okInits ds tenv flds i fs = true →
      ∃ vs, evalInits env fs = some vs ∧ HasTypes ds vs (flds.map (·.ty))
  | [], _, .nil, _ => ⟨[], by simp only [evalInits], .nil⟩
  | f :: flds, i, .cons j e rest, h => by
      simp only [Admit.okInits, Bool.and_eq_true, beq_iff_eq] at h
      obtain ⟨⟨⟨_, he⟩, hty⟩, hrest⟩ := h
      obtain ⟨v, hv, tv⟩ := expr_sound henv e he
      obtain ⟨vs, hvs, tvs⟩ := inits_sound henv flds (i + 1) rest hrest
      rw [hty] at tv
      exact ⟨v :: vs, by simp only [evalInits, hv, hvs], .cons tv tvs⟩
  | [], _, .cons _ _ _, h => by simp [Admit.okInits] at h
  | _ :: _, _, .nil, h => by simp [Admit.okInits] at h

theorem named_sound {tenv : List Ty} {env : List Value} (henv : HasTypes ds env tenv) :
    ∀ (flds : List Field) (fs : NamedInits), Admit.okNamed ds tenv flds fs = true →
      ∃ vs, evalNamed env fs = some vs ∧ HasTypes ds vs (flds.map (·.ty))
  | [], .nil, _ => ⟨[], by simp only [evalNamed], .nil⟩
  | f :: flds, .cons n e rest, h => by
      simp only [Admit.okNamed, Bool.and_eq_true, beq_iff_eq] at h
      obtain ⟨⟨⟨_, he⟩, hty⟩, hrest⟩ := h
      obtain ⟨v, hv, tv⟩ := expr_sound henv e he
      obtain ⟨vs, hvs, tvs⟩ := named_sound henv flds rest hrest
      rw [hty] at tv
      exact ⟨v :: vs, by simp only [evalNamed, hv, hvs], .cons tv tvs⟩
  | [], .cons _ _ _, h => by simp [Admit.okNamed] at h
  | _ :: _, .nil, h => by simp [Admit.okNamed] at h
end

/-! ## Kernel expressions reach a decision -/

/-- A value of a declared variant whose cases carry no payload is one of its
    cases, without payload. -/
theorem HasType.variant_inv {v : Value} {r : Nat} {cs : List Case}
    (h : HasType ds v (.declared r)) (hb : body? ds r = some (.variant cs))
    (hnone : cs.all (·.payload.isNone) = true) :
    ∃ c ∈ cs, v = .variant c.tag none := by
  cases h with
  | variant _ _ c hb' hc _ => rw [hb] at hb'; cases hb'; exact ⟨c, hc, rfl⟩
  | variantPayload _ _ c fs _ hb' hc hp _ =>
      rw [hb] at hb'; cases hb'
      have := List.all_eq_true.mp hnone c hc
      simp [hp] at this
  | alias _ _ _ hb' => rw [hb] at hb'; cases hb'
  | nominal _ _ _ hb' => rw [hb] at hb'; cases hb'
  | record _ _ _ hb' => rw [hb] at hb'; cases hb'

theorem okReason_expr {tenv : List Ty} {R : Ty} {rejects : List (Nat × Nat)} {floor : Nat}
    {r : Expr} {p : Nat} (h : Admit.okReason ds tenv R rejects floor r p = true) :
    Admit.okExpr ds tenv r = true := by
  simp only [Admit.okReason, Bool.and_eq_true] at h
  exact h.1.1.1

mutual
theorem kexpr_total {A R : Ty} {rejects : List (Nat × Nat)} :
    ∀ {tenv : List Ty} {env : List Value}, HasTypes ds env tenv →
      ∀ (floor : Nat) (k : KExpr), Admit.okK ds tenv A R rejects floor k = true →
        ∃ o, evalK env k = some o
  | tenv, env, henv, floor, .accept e, h => by
      simp only [Admit.okK, Bool.and_eq_true] at h
      obtain ⟨v, hv, _⟩ := expr_sound henv e h.1
      exact ⟨.accept v, by simp only [evalK, hv, Option.map_some]⟩
  | tenv, env, henv, floor, .reject r p, h => by
      simp only [Admit.okK] at h
      obtain ⟨v, hv, _⟩ := expr_sound henv r (okReason_expr h)
      exact ⟨.reject v p false, by simp only [evalK, hv, Option.map_some]⟩
  | tenv, env, henv, floor, .require c r p k, h => by
      simp only [Admit.okK, Bool.and_eq_true, beq_iff_eq] at h
      obtain ⟨⟨⟨hc, hty⟩, hr⟩, hk⟩ := h
      obtain ⟨vc, hvc, tvc⟩ := expr_sound henv c hc
      rw [hty] at tvc
      obtain ⟨b, rfl⟩ := tvc.bool_inv
      cases b with
      | true =>
          obtain ⟨o, ho⟩ := kexpr_total henv (p + 1) k hk
          exact ⟨o, by simp only [evalK, hvc]; exact ho⟩
      | false =>
          obtain ⟨v, hv, _⟩ := expr_sound henv r (okReason_expr hr)
          exact ⟨.reject v p true, by simp only [evalK, hvc, hv, Option.map_some]⟩
  | tenv, env, henv, floor, .let_ v k, h => by
      simp only [Admit.okK, Bool.and_eq_true] at h
      obtain ⟨hv, hk⟩ := h
      obtain ⟨x, hx, tx⟩ := expr_sound henv v hv
      obtain ⟨o, ho⟩ := kexpr_total (HasTypes.cons tx henv) floor k hk
      exact ⟨o, by simp only [evalK, hx]; exact ho⟩
  | tenv, env, henv, floor, .ite c a b, h => by
      simp only [Admit.okK, Bool.and_eq_true, beq_iff_eq] at h
      obtain ⟨⟨⟨hc, hty⟩, ha⟩, hb⟩ := h
      obtain ⟨vc, hvc, tvc⟩ := expr_sound henv c hc
      rw [hty] at tvc
      obtain ⟨x, rfl⟩ := tvc.bool_inv
      cases x with
      | true =>
          obtain ⟨o, ho⟩ := kexpr_total henv floor a ha
          exact ⟨o, by simp only [evalK, hvc]; exact ho⟩
      | false =>
          obtain ⟨o, ho⟩ := kexpr_total henv floor b hb
          exact ⟨o, by simp only [evalK, hvc]; exact ho⟩
  | tenv, env, henv, floor, .match_ s as, h => by
      simp only [Admit.okK, Bool.and_eq_true] at h
      obtain ⟨hs, h⟩ := h
      obtain ⟨sv, hsv, tsv⟩ := expr_sound henv s hs
      split at h
      · rename_i v hty
        rw [hty] at tsv
        split at h
        · rename_i cs hb
          simp only [Bool.and_eq_true] at h
          obtain ⟨hnone, harms⟩ := h
          obtain ⟨c, hc, rfl⟩ := tsv.variant_inv hb hnone
          obtain ⟨o, ho⟩ := arms_total henv floor v (cs.map (·.tag)) as harms c.tag
            (List.mem_map_of_mem hc)
          exact ⟨o, by simp only [evalK, hsv]; exact ho⟩
        · cases h
      · cases h

theorem arms_total {A R : Ty} {rejects : List (Nat × Nat)} :
    ∀ {tenv : List Ty} {env : List Value}, HasTypes ds env tenv →
      ∀ (floor v : Nat) (tags : List Nat) (as : Arms),
        Admit.okArms ds tenv A R rejects floor v tags as = true →
        ∀ tag, tag ∈ tags → ∃ o, evalArms env tag none as = some o
  | tenv, env, henv, floor, v, [], .nil, _, tag, hmem => by simp at hmem
  | tenv, env, henv, floor, v, t :: ts, .cons r tg k rest, h, tag, hmem => by
      simp only [Admit.okArms, Bool.and_eq_true, beq_iff_eq] at h
      obtain ⟨⟨⟨_, htg⟩, hk⟩, hrest⟩ := h
      subst htg
      by_cases heq : tg = tag
      · subst heq
        obtain ⟨o, ho⟩ := kexpr_total henv floor k hk
        exact ⟨o, by simp only [evalArms, beq_self_eq_true, if_true]; exact ho⟩
      · have hts : tag ∈ ts := by
          rcases List.mem_cons.mp hmem with h' | h'
          · exact absurd h'.symm heq
          · exact h'
        obtain ⟨o, ho⟩ := arms_total henv floor v ts rest hrest tag hts
        exact ⟨o, by simp only [evalArms, beq_iff_eq, heq, if_false]; exact ho⟩
  | tenv, env, henv, floor, v, [], .cons _ _ _ _, h, _, _ => by simp [Admit.okArms] at h
  | tenv, env, henv, floor, v, _ :: _, .nil, h, _, _ => by simp [Admit.okArms] at h
end

/-! ## Totality -/

/-- **An admitted kernel, applied to an argument of its parameter type, always
    reaches a decision.** It has no failure mode of its own. -/
theorem totality {m : Module} (h : Admit.module m = true) {k : Kernel} (hk : k ∈ m.kernels)
    {args : List Value} (ha : HasTypes m.types args k.params) :
    ∃ o, k.eval args = some o := by
  simp only [Admit.module, Bool.and_eq_true] at h
  have hok := List.all_eq_true.mp h.2 k hk
  unfold Admit.okKernel at hok
  split at hok
  · rename_i pt A rv hparams hresult
    split at hok
    · rename_i cs hb
      simp only [Bool.and_eq_true] at hok
      rw [hparams] at ha
      cases ha with
      | cons ta tnil =>
          cases tnil
          exact kexpr_total (HasTypes.cons ta .nil) 0 k.body hok.2
    · cases hok
  · cases hok

end Seki
