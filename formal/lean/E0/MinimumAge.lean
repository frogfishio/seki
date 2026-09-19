/-
  E0-VS1 experimental semantic nucleus.

  This file has no proof authority. It is intentionally independent of the
  eventual SCB-0 decoder. E0-03 may claim the program theorem only after a
  decoder theorem binds the exact typed-core bytes to `minimumAgeProgram`.
-/

namespace Seki.E0

abbrev U8 := Fin 256

def u8LessThan (left right : U8) : Bool :=
  if left.val < right.val then true else false

structure Applicant where
  age : U8
  deriving DecidableEq, Repr

inductive Rejection where
  | underage
  deriving DecidableEq, Repr

inductive Decision (accepted : Type) (rejection : Type) where
  | accept (value : accepted)
  | reject (reason : rejection)
  deriving DecidableEq, Repr

namespace Requirement

def MinimumAgePolicy
    (run : Applicant → Decision Unit Rejection) : Prop :=
  ∀ applicant,
    if applicant.age.val < 18 then
      run applicant = .reject .underage
    else
      run applicant = .accept ()

def NoMinorApproved
    (run : Applicant → Decision Unit Rejection) : Prop :=
  ∀ applicant,
    applicant.age.val < 18 →
      run applicant ≠ .accept ()

def AdultApproved
    (run : Applicant → Decision Unit Rejection) : Prop :=
  ∀ applicant,
    18 ≤ applicant.age.val →
      run applicant = .accept ()

theorem minimumAgePolicy_implies_noMinorApproved
    {run : Applicant → Decision Unit Rejection}
    (policy : MinimumAgePolicy run) : NoMinorApproved run := by
  intro applicant underage approved
  have required := policy applicant
  simp [underage] at required
  rw [required] at approved
  cases approved

theorem minimumAgePolicy_implies_adultApproved
    {run : Applicant → Decision Unit Rejection}
    (policy : MinimumAgePolicy run) : AdultApproved run := by
  intro applicant adult
  have required := policy applicant
  have notUnderage : ¬ applicant.age.val < 18 := Nat.not_lt.mpr adult
  simpa [notUnderage] using required

end Requirement

/-
  This is the minimum typed expression language needed by E0-VS1. It is not a
  proposed replacement for the full typed-core definition.
-/
inductive Ty where
  | applicant
  | u8
  | bool
  | unit
  | decision

def Ty.denote : Ty → Type
  | .applicant => Applicant
  | .u8 => U8
  | .bool => Bool
  | .unit => Unit
  | .decision => Decision Unit Rejection

inductive Expr : Ty → Type where
  | applicant : Expr .applicant
  | age (owner : Expr .applicant) : Expr .u8
  | u8 (value : U8) : Expr .u8
  | lessThan (left right : Expr .u8) : Expr .bool
  | unit : Expr .unit
  | ifThenElse (condition : Expr .bool)
      (whenTrue whenFalse : Expr result) : Expr result
  | accept (value : Expr .unit) : Expr .decision
  | rejectUnderage : Expr .decision

def Expr.eval : Expr ty → Applicant → ty.denote
  | .applicant, input => input
  | .age owner, input => (eval owner input).age
  | .u8 value, _ => value
  | .lessThan left right, input =>
      u8LessThan (eval left input) (eval right input)
  | .unit, _ => ()
  | .ifThenElse condition whenTrue whenFalse, input =>
      match eval condition input with
      | true => eval whenTrue input
      | false => eval whenFalse input
  | .accept value, input => .accept (eval value input)
  | .rejectUnderage, _ => .reject .underage

def minimumAgeProgram : Expr .decision :=
  .ifThenElse
    (.lessThan (.age .applicant) (.u8 ⟨18, by decide⟩))
    .rejectUnderage
    (.accept .unit)

theorem minimumAgeProgram_policy :
    Requirement.MinimumAgePolicy minimumAgeProgram.eval := by
  intro applicant
  simp only [minimumAgeProgram, Expr.eval, u8LessThan]
  by_cases underage : applicant.age.val < 18 <;>
    simp [underage]

theorem minimumAgeProgram_noMinorApproved :
    Requirement.NoMinorApproved minimumAgeProgram.eval :=
  Requirement.minimumAgePolicy_implies_noMinorApproved
    minimumAgeProgram_policy

theorem minimumAgeProgram_adultApproved :
    Requirement.AdultApproved minimumAgeProgram.eval :=
  Requirement.minimumAgePolicy_implies_adultApproved
    minimumAgeProgram_policy

end Seki.E0
