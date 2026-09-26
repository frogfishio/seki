/-
Axiom audit over every constant in the `Seki` namespace. Fails (non-zero exit
from `lake env lean`) if any depends on an axiom outside Lean's standard three.
That excludes `sorryAx`, and the axiom that deciding a proposition with
compiled code introduces, which would make Lean's compiler part of the proof.
-/
import Seki.Core
import Seki.Decode
import Seki.Eval
import Seki.Proofs.MinimumAge
import Lean

open Lean

#eval show CoreM Unit from do
  let allowed : List Name := [``propext, ``Classical.choice, ``Quot.sound]
  let env ← getEnv
  let mut checked := 0
  let mut bad : Array (Name × Name) := #[]
  for (name, _) in env.constants.toList do
    if (`Seki).isPrefixOf name && !name.isInternal then
      checked := checked + 1
      for ax in ← collectAxioms name do
        unless allowed.contains ax do
          bad := bad.push (name, ax)
  if bad.isEmpty then
    IO.println s!"seki_axiom_audit=verified constants={checked} allowed=propext,Classical.choice,Quot.sound"
  else
    throwError m!"forbidden axioms: {bad.toList}"
