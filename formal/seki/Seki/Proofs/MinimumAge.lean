/-
The E0 minimum-age requirement, proved of the kernel's exact typed-core bytes,
with the Lean kernel as the only thing trusted.

1. The requirement is stated by the policy owner, knowing nothing of Seki:
   a function from an age to a verdict is acceptable when it approves exactly
   the adults.
2. The kernel is the exact bytes of `experiments/e0-vs1/minimum_age.scb0.hex`,
   decoded by the general SCB-0 decoder, not transcribed by hand. The bytes
   are a list literal generated from that file (`MinimumAgeBytes.lean`),
   because the kernel reduces numerals quickly and strings very slowly; the
   check regenerates it and requires it to be identical.
3. Its meaning is `Seki.eval` of what the bytes decode to.
4. The bridge reads a decision in the requirement's vocabulary through the
   kernel's published tag dictionary: acceptance of `Unit` is approval, and
   rejection with tag 1 is `Underage`. Anything else is no verdict, which the
   requirement does not accept.

The proof is `decide +kernel` over all 256 values of `U8`: the Lean kernel
itself decodes the bytes and evaluates the kernel for every age. Nothing is
decided by compiled code, so Lean's compiler and runtime are not trusted.
-/
import Seki.Decode
import Seki.Eval
import Seki.Proofs.MinimumAgeBytes

namespace Seki.Proofs.MinimumAge
open Seki

/-! ## The requirement (the policy owner's; independent of Seki) -/

namespace Requirement

inductive Verdict where
  | approve
  | underage
deriving DecidableEq

/-- Every applicant of a representable age gets a verdict, and it is
    `underage` exactly when the applicant is under 18. -/
def MinimumAgePolicy (run : Nat → Option Verdict) : Prop :=
  ∀ age, age < 256 → run age = some (if age < 18 then .underage else .approve)

/-- The two consequences a reviewer cares about, derived rather than assumed. -/
def NoMinorApproved (run : Nat → Option Verdict) : Prop :=
  ∀ age, age < 18 → run age ≠ some .approve

def AdultApproved (run : Nat → Option Verdict) : Prop :=
  ∀ age, 18 ≤ age → age < 256 → run age = some .approve

theorem noMinorApproved {run} (h : MinimumAgePolicy run) : NoMinorApproved run := by
  intro age hage
  rw [h age (by omega)]
  simp [hage]

theorem adultApproved {run} (h : MinimumAgePolicy run) : AdultApproved run := by
  intro age hage hbound
  rw [h age hbound]
  simp [Nat.not_lt.mpr hage]

/-- Falsifiable: a kernel that approves everyone does not satisfy it. -/
theorem approveAll_fails : ¬ MinimumAgePolicy (fun _ => some .approve) := by
  intro h
  have := h 0 (by decide)
  simp at this

end Requirement

/-! ## The kernel: exact bytes, decoded -/

/-- The kernel the bytes decode to, if they decode. -/
def kernel : Option Kernel :=
  match Decode.envelope exactBytes with
  | .ok m => m.kernels.head?
  | .error _ => none

/-! ## The bridge: a decision in the requirement's vocabulary -/

def interpret : Outcome → Option Requirement.Verdict
  | .accept .unit => some .approve
  | .reject (.variant 1 none) _ _ => some .underage
  | _ => none

/-- The kernel's meaning, as the requirement sees it: the applicant record has
    one field, `age : U8`. -/
def run (age : Nat) : Option Requirement.Verdict :=
  match kernel with
  | some k =>
      match k.eval [.record [.int .u8 age]] with
      | some o => interpret o
      | none => none
  | none => none

/-! ## The proofs -/

theorem bytes_decode : kernel.isSome = true := by decide +kernel

theorem policy : Requirement.MinimumAgePolicy run := by
  unfold Requirement.MinimumAgePolicy
  decide +kernel

theorem noMinorApproved : Requirement.NoMinorApproved run :=
  Requirement.noMinorApproved policy

theorem adultApproved : Requirement.AdultApproved run :=
  Requirement.adultApproved policy

end Seki.Proofs.MinimumAge
