/-
The statements the project relies on, written out in full. Each `example`
only type-checks if the named theorem proves exactly this statement, so a
theorem cannot be weakened while keeping its name.
-/
import Seki.Totality
import Seki.Proofs.MinimumAge

open Seki

/-- Totality: an admitted kernel on an argument of its parameter type always
    reaches a decision. -/
example : ∀ {m : Module}, Admit.module m = true → ∀ {k : Kernel}, k ∈ m.kernels →
    ∀ {args : List Value}, HasTypes m.types args k.params → ∃ o, k.eval args = some o :=
  @totality

namespace Seki.Proofs.MinimumAge

/-- The exact E0 bytes decode to an admitted module. -/
example : decoded.map Admit.module = some true := admitted

/-- The requirement, over the exact bytes. -/
example : ∀ age, age < 256 →
    run age = some (if age < 18 then .underage else .approve) := policy

end Seki.Proofs.MinimumAge

#eval IO.println "seki_statements=verified totality=pinned minimum_age=pinned"
