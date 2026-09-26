/-
Hostile admission cases. Each takes the decoded minimum-age module, which is
admitted, and breaks exactly one rule; every one must be rejected. A positive
control rebuilds a different but correct kernel from the same pieces, so the
cases cannot pass merely because the rebuilt module is malformed. The build
fails if any `#guard` does.
-/
import Seki.Decode
import Seki.Admit
import Seki.Proofs.MinimumAgeBytes

namespace Seki.Tests.Admission
open Seki

def base : Module :=
  match Decode.envelope Proofs.MinimumAge.exactBytes with
  | .ok m => m
  | .error _ => { path := [], version := 0, profile := "", profileVersion := 0,
                  types := [], kernels := [], theorems := [], claims := [] }

def kernel : Kernel :=
  match base.kernels with
  | k :: _ => k
  | [] => { name := "", labels := [], params := [], result := .unit, rejects := [],
            body := .accept (.mk .unit .unit), declared := ⟨0, 0, 0, 0⟩,
            exact := ⟨0, 0, 0, 0⟩, publicationEligible := false }

/-- The pieces of the original body:
    `(applicant age) < 18 ifTrue: [ reject Underage ] ifFalse: [ accept unit ]`. -/
def pieces : Option (Expr × Expr × Nat × Expr) :=
  match kernel.body with
  | .ite c (.reject r p) (.accept u) => some (c, r, p, u)
  | _ => none

def cond : Expr := (pieces.map (·.1)).getD (.mk .bool (.bool true))
def reason : Expr := (pieces.map (·.2.1)).getD (.mk .unit .unit)
def unitE : Expr := (pieces.map (·.2.2.2)).getD (.mk .unit .unit)

def withBody (b : KExpr) : Module := { base with kernels := [{ kernel with body := b }] }
def withKernel (k : Kernel) : Module := { base with kernels := [k] }

def admitted (m : Module) : Bool := Admit.module m

-- The original, and a different but correct kernel from the same pieces.
#guard admitted base
#guard pieces.isSome
#guard admitted (withBody (.require cond reason 0 (.accept unitE)))
#guard admitted (withBody (.ite cond (.accept unitE) (.reject reason 0)))

-- Accepting a value of the wrong type.
#guard !admitted (withBody (.ite cond (.reject reason 0) (.accept (.mk .bool (.bool true)))))
-- A claimed type that is not the computed one.
#guard !admitted (withBody (.ite cond (.reject reason 0) (.accept (.mk .bool .unit))))
-- A rejection whose precedence is not its case's position.
#guard !admitted (withBody (.ite cond (.reject reason 1) (.accept unitE)))
-- Precedence that does not increase along a path (check_order).
#guard !admitted (withBody (.require cond reason 0 (.require cond reason 0 (.accept unitE))))
-- A condition that is not Bool.
#guard !admitted (withBody (.ite (.mk .bool .unit) (.reject reason 0) (.accept unitE)))
-- An unbound local.
#guard !admitted (withBody (.ite cond (.reject reason 0) (.accept (.mk .unit (.local 1)))))
-- A literal outside its type.
#guard !admitted (withBody (.ite (.mk .bool (.cmp .lt (.mk (.int .u8) (.int .u8 256))
    (.mk (.int .u8) (.int .u8 18)))) (.reject reason 0) (.accept unitE)))
-- Comparing operands of different types.
#guard !admitted (withBody (.ite (.mk .bool (.cmp .lt (.mk (.int .u16) (.int .u16 1))
    (.mk (.int .u8) (.int .u8 18)))) (.reject reason 0) (.accept unitE)))
-- A rejection order that names a case twice.
#guard !admitted (withKernel { kernel with rejects := kernel.rejects ++ kernel.rejects })
-- A rejection order that omits a case.
#guard !admitted (withKernel { kernel with rejects := [] })
-- A parameter of the wrong type.
#guard !admitted (withKernel { kernel with params := [.int .u8] })
-- A result that is not a decision over a declared variant.
#guard !admitted (withKernel { kernel with result := .decision .unit .unit })
-- Declaration tables out of canonical order.
#guard !admitted { base with types := base.types.reverse }
-- A reference out of range.
#guard !admitted (withKernel { kernel with params := [.declared 9] })
-- Two kernels in one module.
#guard !admitted { base with kernels := [kernel, kernel] }

end Seki.Tests.Admission
