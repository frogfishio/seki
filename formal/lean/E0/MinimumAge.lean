/-
  E0-VS1 experimental semantic nucleus.

  This file has no proof authority. It is intentionally independent of the
  eventual SCB-0 decoder. E0-03 may claim the program theorem only after a
  decoder theorem binds the exact typed-core bytes to `minimumAgeProgram`.
-/

namespace Seki.E0

abbrev U8 := UInt8

def u8LessThan (left right : U8) : Bool :=
  if left.toNat < right.toNat then true else false

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
    if applicant.age.toNat < 18 then
      run applicant = .reject .underage
    else
      run applicant = .accept ()

def NoMinorApproved
    (run : Applicant → Decision Unit Rejection) : Prop :=
  ∀ applicant,
    applicant.age.toNat < 18 →
      run applicant ≠ .accept ()

def AdultApproved
    (run : Applicant → Decision Unit Rejection) : Prop :=
  ∀ applicant,
    18 ≤ applicant.age.toNat →
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
  have notUnderage : ¬ applicant.age.toNat < 18 := Nat.not_lt.mpr adult
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
  deriving DecidableEq

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
    (.lessThan (.age .applicant) (.u8 18))
    .rejectUnderage
    (.accept .unit)

theorem minimumAgeProgram_policy :
    Requirement.MinimumAgePolicy minimumAgeProgram.eval := by
  intro applicant
  simp only [minimumAgeProgram, Expr.eval, u8LessThan]
  by_cases underage : applicant.age.toNat < 18 <;>
    simp [underage]

theorem minimumAgeProgram_noMinorApproved :
    Requirement.NoMinorApproved minimumAgeProgram.eval :=
  Requirement.minimumAgePolicy_implies_noMinorApproved
    minimumAgeProgram_policy

theorem minimumAgeProgram_adultApproved :
    Requirement.AdultApproved minimumAgeProgram.eval :=
  Requirement.minimumAgePolicy_implies_adultApproved
    minimumAgeProgram_policy

def exactSCB0Hex : String :=
  include_str "../../../experiments/e0-vs1/minimum_age.scb0.hex"

namespace SCB0

def hexNibble : Char → Option Nat
  | '0' => some 0 | '1' => some 1 | '2' => some 2 | '3' => some 3
  | '4' => some 4 | '5' => some 5 | '6' => some 6 | '7' => some 7
  | '8' => some 8 | '9' => some 9 | 'a' => some 10 | 'b' => some 11
  | 'c' => some 12 | 'd' => some 13 | 'e' => some 14 | 'f' => some 15
  | 'A' => some 10 | 'B' => some 11 | 'C' => some 12 | 'D' => some 13
  | 'E' => some 14 | 'F' => some 15
  | _ => none

def decodeHexChars : List Char → Option (List UInt8)
  | [] => some []
  | '\n' :: rest => decodeHexChars rest
  | '\r' :: rest => decodeHexChars rest
  | high :: low :: rest => do
      let highValue ← hexNibble high
      let lowValue ← hexNibble low
      let tail ← decodeHexChars rest
      pure (UInt8.ofNat (highValue * 16 + lowValue) :: tail)
  | _ => none

def decodeHex (value : String) : Option (List UInt8) :=
  decodeHexChars value.toList

abbrev Parser (α : Type) := StateT (List UInt8) Option α

def failParser : Parser α := fun _ => none

def readByte : Parser UInt8 := fun input =>
  match input with
  | [] => none
  | byte :: rest => some (byte, rest)

def readU32 : Parser Nat := do
  let a ← readByte
  let b ← readByte
  let c ← readByte
  let d ← readByte
  pure (a.toNat * 16777216 + b.toNat * 65536 + c.toNat * 256 + d.toNat)

def expectByte (expected : Nat) : Parser Unit := do
  let actual ← readByte
  if actual.toNat = expected then pure () else failParser

def expectU32 (expected : Nat) : Parser Unit := do
  let actual ← readU32
  if actual = expected then pure () else failParser

def expectBytes : List UInt8 → Parser Unit
  | [] => pure ()
  | expected :: rest => do
      let actual ← readByte
      if actual = expected then expectBytes rest else failParser

def expectName (expected : String) : Parser Unit := do
  expectU32 expected.toUTF8.size
  expectBytes expected.toUTF8.toList

def expectLocalTypeRef (index : Nat) : Parser Unit := do
  expectByte 0
  expectU32 index

def expectUnitType : Parser Unit := expectByte 0
def expectBoolType : Parser Unit := expectByte 1
def expectU8Type : Parser Unit := expectByte 2

def expectDeclaredType (index : Nat) : Parser Unit := do
  expectByte 21
  expectLocalTypeRef index

def expectApplicantType : Parser Unit := expectDeclaredType 0
def expectRejectionType : Parser Unit := expectDeclaredType 1

def expectDecisionType : Parser Unit := do
  expectByte 19
  expectUnitType
  expectRejectionType

def parseApplicantExpr : Parser (Expr .applicant) := do
  expectApplicantType
  expectByte 4
  expectU32 0
  pure .applicant

def parseU8Expr : Parser (Expr .u8) := do
  expectU8Type
  let tag ← readByte
  if tag.toNat = 7 then
    let owner ← parseApplicantExpr
    expectByte 0
    expectLocalTypeRef 0
    expectU32 0
    pure (.age owner)
  else if tag.toNat = 2 then
    expectByte 0
    let value ← readByte
    pure (.u8 value)
  else
    failParser

def parseBoolExpr : Parser (Expr .bool) := do
  expectBoolType
  expectByte 19
  expectByte 0
  let left ← parseU8Expr
  let right ← parseU8Expr
  pure (.lessThan left right)

def parseUnitExpr : Parser (Expr .unit) := do
  expectUnitType
  expectByte 0
  pure .unit

def parseUnderageExpr : Parser Unit := do
  expectRejectionType
  expectByte 8
  expectLocalTypeRef 1
  expectU32 1
  expectU32 0

def parseReject : Parser (Expr .decision) := do
  expectByte 1
  parseUnderageExpr
  expectU32 0
  pure .rejectUnderage

def parseAccept : Parser (Expr .decision) := do
  expectByte 0
  let value ← parseUnitExpr
  pure (.accept value)

def parseKernel : Parser (Expr .decision) := do
  expectByte 4
  let condition ← parseBoolExpr
  let whenTrue ← parseReject
  let whenFalse ← parseAccept
  pure (.ifThenElse condition whenTrue whenFalse)

def expectBounds (steps live depth workspace : Nat) : Parser Unit := do
  expectU32 steps
  expectU32 live
  expectU32 depth
  expectU32 workspace

def parseModule : Parser (Expr .decision) := do
  expectBytes "SEKI".toUTF8.toList
  expectU32 0
  expectByte 0
  expectU32 404

  expectU32 0
  expectU32 3
  expectName "seki"
  expectName "experiments"
  expectName "minimum_age"
  expectU32 1
  expectName "c11_bounded"
  expectU32 1

  expectU32 0
  expectU32 0
  expectU32 2
  expectName "Applicant"
  expectByte 2
  expectU32 1
  expectName "age"
  expectU8Type
  expectName "Rejection"
  expectByte 3
  expectU32 1
  expectU32 1
  expectName "Underage"
  expectByte 0
  expectU32 0

  expectU32 1
  expectName "decide"
  expectU32 1
  expectName "applicant"
  expectU32 1
  expectApplicantType
  expectDecisionType
  expectU32 1
  expectLocalTypeRef 1
  expectU32 1
  let program ← parseKernel
  expectBounds 32 256 16 0
  expectBounds 8 25 5 0
  expectByte 0

  expectU32 0
  expectU32 2
  expectU32 0
  expectU32 1
  expectU32 0
  expectU32 1
  expectU32 0
  expectU32 5
  expectByte 0
  expectByte 1
  expectByte 2
  expectByte 3
  expectByte 4
  expectU32 3
  expectByte 0
  expectByte 1
  expectByte 3

  expectU32 1048576
  expectU32 32
  expectU32 4096
  expectU32 65536
  expectU32 256
  expectU32 32
  expectBounds 16777216 8388608 256 8388608
  expectU32 0
  expectU32 2
  expectU32 0
  expectU32 1
  expectU32 0
  pure program

def decodeExactProgram : Option (Expr .decision) := do
  let bytes ← decodeHex exactSCB0Hex
  let (program, rest) ← parseModule bytes
  if rest.isEmpty then pure program else none

theorem decodeExactProgram_eq :
    decodeExactProgram = some minimumAgeProgram := by
  native_decide

theorem decoded_program_satisfies_policy
    (program : Expr .decision)
    (decoded : decodeExactProgram = some program) :
    Requirement.MinimumAgePolicy program.eval := by
  rw [decodeExactProgram_eq] at decoded
  cases decoded
  exact minimumAgeProgram_policy

theorem decoded_program_noMinorApproved
    (program : Expr .decision)
    (decoded : decodeExactProgram = some program) :
    Requirement.NoMinorApproved program.eval :=
  Requirement.minimumAgePolicy_implies_noMinorApproved
    (decoded_program_satisfies_policy program decoded)

theorem decoded_program_adultApproved
    (program : Expr .decision)
    (decoded : decodeExactProgram = some program) :
    Requirement.AdultApproved program.eval :=
  Requirement.minimumAgePolicy_implies_adultApproved
    (decoded_program_satisfies_policy program decoded)

end SCB0

end Seki.E0
