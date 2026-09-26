/-
Language-level KCore theorems (docs/engineering/KCORE_SEMANTICS.md §6).

T3  non-fabrication: an operational failure is witnessed by the most recent
    event, which failed and is of the matching kind.
T5  release: after an `operational` or `stuck` outcome, no block allocated by
    the transaction is live.
These are proved once for the language; no program can violate them.
-/
import KCore.Semantics

namespace KCore

/-! ## T3 — operational failure is never fabricated -/

theorem exec_fail_witnessed {P : Program} {L : Layout} {env : Env} :
    ∀ (n : Nat) (m : Machine) (l : Locals) (s : Stmt) (m' : Machine) (f : Failure),
      exec P L env n m l s = .fail m' f →
      ∃ ev, m'.trace.head? = some ⟨ev, false⟩ ∧ f.witnessedBy ev := by
  intro n
  induction n with
  | zero => intro m l s m' f h; simp [exec] at h
  | succ n ih =>
    intro m l s m' f h
    cases s <;> simp only [exec, atomic] at h
    all_goals first
      | (repeat' split at h) <;>
          first
            | exact ih _ _ _ _ _ h
            | (simp_all [Machine.record, Failure.witnessedBy]; done)
            | (cases h; simp_all [Machine.record, Failure.witnessedBy]; done)
            | skip

theorem run_operational_witnessed {P : Program} {L : Layout} {env : Env} {fuel : Nat}
    {inputs : Array Block} {entry : String} {args : List Val}
    {f : Failure} {h : Heap} {tr : List EventRec}
    (hr : run P L env fuel inputs entry args = .operational f h tr) :
    ∃ ev, tr.head? = some ⟨ev, false⟩ ∧ f.witnessedBy ev := by
  unfold run at hr
  dsimp only at hr
  split at hr
  · simp at hr
  · split at hr
    · simp at hr
    · split at hr
      all_goals first
        | (split at hr <;> (try split at hr) <;> simp at hr; done)
        | (simp at hr; done)
        | (rename_i hx
           simp only [Outcome.operational.injEq] at hr
           obtain ⟨rfl, -, rfl⟩ := hr
           exact exec_fail_witnessed _ _ _ _ _ _ hx)

/-! ## T5 — the transaction's blocks are released on failure

`OwnInv init h`: blocks with id ≥ `init` are exactly the transaction's
allocations. Among them, the live ones are exactly the owned ones. -/

def OwnInv (init : Nat) (h : Heap) : Prop :=
  init ≤ h.blocks.size ∧ h.owned.Nodup ∧
  (∀ b, b ∈ h.owned → init ≤ b ∧ ∃ blk, h.blocks[b]? = some blk ∧ blk.live = true) ∧
  (∀ b blk, init ≤ b → h.blocks[b]? = some blk → blk.live = true → b ∈ h.owned)

/-- A heap step that preserves size, ownership and every block's liveness
    preserves the invariant. -/
theorem OwnInv.of_live_eq {init : Nat} {h h' : Heap} (hi : OwnInv init h)
    (hsize : h'.blocks.size = h.blocks.size) (howned : h'.owned = h.owned)
    (hlive : ∀ j : Nat, (h'.blocks[j]?).map Block.live = (h.blocks[j]?).map Block.live) :
    OwnInv init h' := by
  obtain ⟨hs, hnd, hown, hlv⟩ := hi
  refine ⟨hsize ▸ hs, howned ▸ hnd, ?_, ?_⟩
  · intro b hb
    rw [howned] at hb
    obtain ⟨hib, blk, hblk, hl⟩ := hown b hb
    have := hlive b
    rw [hblk] at this
    cases h'b : h'.blocks[b]? with
    | none => simp [h'b] at this
    | some blk' => simp [h'b] at this; exact ⟨hib, blk', rfl, this.trans hl⟩
  · intro b blk' hib h'b hl
    have := hlive b
    rw [h'b] at this
    cases hb : h.blocks[b]? with
    | none => simp [hb] at this
    | some blk => simp [hb] at this; rw [howned]; exact hlv b blk hib hb (this ▸ hl)

theorem Heap.store?_live {h h' : Heap} {t : Ty} {b o : Nat} {v : Val}
    (hs : h.store? t b o v = .ok h') :
    h'.blocks.size = h.blocks.size ∧ h'.owned = h.owned ∧
    ∀ j : Nat, (h'.blocks[j]?).map Block.live = (h.blocks[j]?).map Block.live := by
  unfold Heap.store? at hs
  cases hb : h.blocks[b]? with
  | none => simp [hb] at hs
  | some blk =>
    simp only [hb] at hs
    repeat' split at hs
    all_goals try (simp at hs; done)
    · simp only [Except.ok.injEq] at hs
      subst hs
      refine ⟨by simp [Array.set!_eq_setIfInBounds], rfl, fun j => ?_⟩
      simp only [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds]
      by_cases hj : b = j
      · subst hj
        obtain ⟨hlt, hget⟩ := Array.getElem?_eq_some_iff.mp hb
        simp [hlt, hget]
      · simp [hj]

theorem OwnInv.free {init : Nat} {h h' : Heap} {b : Nat} (hi : OwnInv init h)
    (hf : h.free? b = .ok h') : OwnInv init h' := by
  unfold Heap.free? at hf
  cases hb : h.blocks[b]? with
  | none => simp [hb] at hf
  | some blk =>
    simp only [hb] at hf
    split at hf
    · rename_i hcond
      obtain ⟨_, hmem⟩ := hcond
      simp only [Except.ok.injEq] at hf
      subst hf
      obtain ⟨hs, hnd, hown, hlv⟩ := hi
      have hbsz := (Array.getElem?_eq_some_iff.mp hb).1
      refine ⟨by simpa [Array.set!_eq_setIfInBounds] using hs, hnd.erase b, ?_, ?_⟩
      · intro c hc
        rw [List.Nodup.mem_erase_iff hnd] at hc
        obtain ⟨hne, hc⟩ := hc
        obtain ⟨hic, blk', hblk', hl⟩ := hown c hc
        refine ⟨hic, blk', ?_, hl⟩
        simp [Array.set!_eq_setIfInBounds, Ne.symm hne, hblk']
      · intro c blk' hic hc hl
        rw [List.Nodup.mem_erase_iff hnd]
        simp only [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds] at hc
        by_cases hbc : b = c
        · subst hbc; simp [hbsz] at hc; subst hc; simp at hl
        · simp [hbc] at hc; exact ⟨Ne.symm hbc, hlv c blk' hic hc hl⟩
    · simp at hf

theorem OwnInv.alloc {init : Nat} {h : Heap} {t : Ty} {n : Nat} {z : Val}
    (hi : OwnInv init h) : OwnInv init (h.alloc t n z).1 := by
  obtain ⟨hs, hnd, hown, hlv⟩ := hi
  simp only [Heap.alloc]
  refine ⟨by simp; omega, ?_, ?_, ?_⟩
  · refine List.nodup_cons.mpr ⟨fun hm => ?_, hnd⟩
    obtain ⟨-, blk, hblk, -⟩ := hown _ hm
    simp at hblk
  · intro c hc
    simp only [List.mem_cons] at hc
    rcases hc with rfl | hc
    · exact ⟨hs, { ty := t, cells := Array.replicate n z, live := true }, by simp, rfl⟩
    · obtain ⟨hic, blk, hblk, hl⟩ := hown c hc
      have hlt := (Array.getElem?_eq_some_iff.mp hblk).1
      exact ⟨hic, blk, by simp [Array.getElem?_push, Nat.ne_of_lt hlt, hblk], hl⟩
  · intro c blk hic hc hl
    simp only [Array.getElem?_push] at hc
    split at hc
    · rename_i heq; subst heq; exact List.mem_cons_self
    · exact List.mem_cons_of_mem _ (hlv c blk hic hc hl)

def Res.machine? : Res → Option Machine
  | .normal m _ | .ret m _ | .fail m _ | .stuck m _ => some m
  | .oof => none

theorem Res.machine?_of_normal {r : Res} {m : Machine} {l : Locals}
    (h : r = .normal m l) : r.machine? = some m := by simp [h, Res.machine?]

theorem Res.machine?_of_ret {r : Res} {m : Machine} {v : Val}
    (h : r = .ret m v) : r.machine? = some m := by simp [h, Res.machine?]

theorem exec_inv {P : Program} {L : Layout} {env : Env} {init : Nat} :
    ∀ (n : Nat) (m : Machine) (l : Locals) (s : Stmt) (m' : Machine),
      OwnInv init m.heap → (exec P L env n m l s).machine? = some m' → OwnInv init m'.heap := by
  intro n
  induction n with
  | zero => intro m l s m' _ h; simp [exec, Res.machine?] at h
  | succ n ih =>
    intro m l s m' hi h
    cases s <;> simp only [exec, atomic] at h
    all_goals (repeat' split at h)
    all_goals first
      -- unchanged machine
      | (simp only [Res.machine?, Option.some.injEq] at h; subst h; assumption)
      -- event recorded, heap unchanged
      | (simp only [Res.machine?, Option.some.injEq] at h; subst h;
         simpa [Machine.record] using hi)
      -- pass-through of a sub-evaluation (if, call failure/stuck, loop/seq exit)
      | exact ih _ _ _ _ hi h
      -- chained sub-evaluations (seq, while)
      | exact ih _ _ _ _ (ih _ _ _ _ hi (Res.machine?_of_normal ‹_›)) h
      -- call returning or falling off the end
      | (simp only [Res.machine?, Option.some.injEq] at h; subst h;
         exact ih _ _ _ _ hi (Res.machine?_of_ret ‹_›))
      | (simp only [Res.machine?, Option.some.injEq] at h; subst h;
         exact ih _ _ _ _ hi (Res.machine?_of_normal ‹_›))
      -- heap operations
      | (simp only [Res.machine?, Option.some.injEq] at h; subst h; exact OwnInv.free hi ‹_›)
      | (simp only [Res.machine?, Option.some.injEq] at h; subst h;
         exact OwnInv.of_live_eq hi (Heap.store?_live ‹_›).1 (Heap.store?_live ‹_›).2.1
           (Heap.store?_live ‹_›).2.2)
      | (simp only [Res.machine?, Option.some.injEq] at h; subst h; dsimp only;
         exact OwnInv.alloc hi)

theorem OwnInv.releaseAll_dead {init : Nat} {h : Heap} (hi : OwnInv init h) :
    ∀ b blk, init ≤ b → h.releaseAll.blocks[b]? = some blk → blk.live = false := by
  obtain ⟨-, -, -, hlv⟩ := hi
  intro b blk hib hb
  simp only [Heap.releaseAll, Array.getElem?_mapIdx] at hb
  cases hob : h.blocks[b]? with
  | none => simp [hob] at hb
  | some blk0 =>
    simp only [hob, Option.map_some, Option.some.injEq] at hb
    split at hb
    · subst hb; rfl
    · rename_i hnot; subst hb
      cases hl : blk0.live
      · rfl
      · exact absurd (hlv b blk0 hib hob hl) hnot

theorem Res.machine?_of_fail {r : Res} {m : Machine} {f : Failure}
    (h : r = .fail m f) : r.machine? = some m := by simp [h, Res.machine?]

theorem Res.machine?_of_stuck {r : Res} {m : Machine} {w : Fault}
    (h : r = .stuck m w) : r.machine? = some m := by simp [h, Res.machine?]

theorem OwnInv.initial (inputs : Array Block) :
    OwnInv inputs.size { blocks := inputs, owned := [] } := by
  refine ⟨Nat.le_refl _, List.nodup_nil, by simp, ?_⟩
  intro b blk hib hb
  have := (Array.getElem?_eq_some_iff.mp hb).1
  simp at this; omega

/-- **T5.** After an `operational` or `stuck` outcome, no block allocated by
    the transaction (id ≥ number of host input blocks) is live. -/
theorem run_nonok_released {P : Program} {L : Layout} {env : Env} {fuel : Nat}
    {inputs : Array Block} {entry : String} {args : List Val} {h : Heap}
    (hr : (∃ f tr, run P L env fuel inputs entry args = .operational f h tr) ∨
          (∃ why, run P L env fuel inputs entry args = .stuck h why)) :
    ∀ b blk, inputs.size ≤ b → h.blocks[b]? = some blk → blk.live = false := by
  have h0 := OwnInv.initial inputs
  have noTx : ∀ b blk, inputs.size ≤ b →
      ({ blocks := inputs, owned := [] } : Heap).blocks[b]? = some blk → blk.live = false := by
    intro b blk hib hb
    have := (Array.getElem?_eq_some_iff.mp hb).1
    simp at this; omega
  unfold run at hr
  dsimp only at hr
  split at hr
  · rcases hr with ⟨_, _, hr⟩ | ⟨_, hr⟩ <;> simp at hr; obtain ⟨rfl, -⟩ := hr; exact noTx
  · split at hr
    · rcases hr with ⟨_, _, hr⟩ | ⟨_, hr⟩ <;> simp at hr; obtain ⟨rfl, -⟩ := hr; exact noTx
    · split at hr
      -- entry returned: typing check, leak check, then `ok`
      · have hinv := exec_inv _ _ _ _ _ h0 (Res.machine?_of_ret ‹_›)
        split at hr
        · rcases hr with ⟨_, _, hr⟩ | ⟨_, hr⟩ <;> simp at hr
          obtain ⟨rfl, -⟩ := hr; exact OwnInv.releaseAll_dead hinv
        · split at hr
          · rcases hr with ⟨_, _, hr⟩ | ⟨_, hr⟩ <;> simp at hr
            obtain ⟨rfl, -⟩ := hr; exact OwnInv.releaseAll_dead hinv
          · rcases hr with ⟨_, _, hr⟩ | ⟨_, hr⟩ <;> simp at hr
      all_goals rcases hr with ⟨_, _, hr⟩ | ⟨_, hr⟩ <;> simp at hr
      all_goals first
        | (obtain ⟨-, rfl, -⟩ := hr
           exact OwnInv.releaseAll_dead (exec_inv _ _ _ _ _ h0 (Res.machine?_of_fail ‹_›)))
        | (obtain ⟨rfl, -⟩ := hr
           exact OwnInv.releaseAll_dead (exec_inv _ _ _ _ _ h0 (Res.machine?_of_stuck ‹_›)))
        | (obtain ⟨rfl, -⟩ := hr
           exact OwnInv.releaseAll_dead (exec_inv _ _ _ _ _ h0 (Res.machine?_of_normal ‹_›)))

/-! ## T1 support: an environment that grants every event causes no failure -/

/-- Under an environment that grants every event, execution never produces an
    operational failure. Combined with a total-correctness triple, this gives
    T1 (progress to `ok` under sufficient resources). -/
theorem exec_no_fail_allOk {P : Program} {L : Layout} :
    ∀ (n : Nat) (m : Machine) (l : Locals) (s : Stmt) (m' : Machine) (f : Failure),
      exec P L (fun _ _ => true) n m l s ≠ .fail m' f := by
  intro n
  induction n with
  | zero => intro m l s m' f h; simp [exec] at h
  | succ n ih =>
    intro m l s m' f h
    cases s <;> simp only [exec, atomic] at h
    all_goals (repeat' split at h)
    all_goals first
      | (simp at h; done)
      | exact ih _ _ _ _ _ h
      | (simp_all; done)

end KCore
