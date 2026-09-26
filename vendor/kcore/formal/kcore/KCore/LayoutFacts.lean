/-
Consequences of `Layout.valid` (KCore-D3): alignment closure.

A valid target layout gives every struct an alignment that is a multiple of
the alignment of every field it contains, directly or through nested structs
held by value. The C11 printer relies on this when it places a struct inside
another struct or inside an allocated block.
-/
import KCore.WellFormed

namespace KCore

/-- `Contains P t u`: a value of type `t` contains, by value, a field of
    type `u` (directly, or through nested structs). -/
inductive Contains (P : Program) : Ty → Ty → Prop where
  | field {n : String} {sd : StructDef} {f : Ty} :
      P.struct? n = some sd → f ∈ sd.fields → Contains P (.struct n) f
  | trans {t u v : Ty} : Contains P t u → Contains P u v → Contains P t v

theorem Program.struct?_mem {P : Program} {n : String} {sd : StructDef}
    (h : P.struct? n = some sd) : sd ∈ P.structs ∧ sd.name = n := by
  unfold Program.struct? at h
  exact ⟨List.mem_of_find?_eq_some h, by simpa using List.find?_some h⟩

/-- The per-field facts `Layout.valid` records for a struct field. -/
theorem Layout.valid_field {L : Layout} {P : Program} (hv : L.valid P = true) {n : String}
    {sd : StructDef} {f : Ty} (hsd : P.struct? n = some sd) (hf : f ∈ sd.fields) :
    L.sizeOf f > 0 ∧ L.alignOf f > 0 ∧ L.sizeOf f % L.alignOf f = 0 ∧
      L.alignOf (.struct n) % L.alignOf f = 0 := by
  obtain ⟨hmem, rfl⟩ := Program.struct?_mem hsd
  simp only [Layout.valid, decide_eq_true_eq, List.all_eq_true] at hv
  have hs := (hv.2.2.2 sd hmem).2.2.1 f hf
  exact ⟨hs.1.1, hs.1.2.1, hs.1.2.2, hs.2⟩

/-- **Alignment closure.** Under a valid layout, the alignment of an
    aggregate is a multiple of the alignment of every recursively contained
    field, and that alignment is positive. -/
theorem Layout.valid_contains_align {L : Layout} {P : Program} (hv : L.valid P = true)
    {t u : Ty} (h : Contains P t u) :
    L.alignOf u > 0 ∧ L.alignOf u ∣ L.alignOf t := by
  induction h with
  | field hsd hf =>
    obtain ⟨-, hpos, -, hdiv⟩ := Layout.valid_field hv hsd hf
    exact ⟨hpos, Nat.dvd_of_mod_eq_zero hdiv⟩
  | trans _ _ ih₁ ih₂ => exact ⟨ih₂.1, Nat.dvd_trans ih₂.2 ih₁.2⟩

end KCore
