/-
Seki build glue; not an upstream file.

Axiom audit over every constant in the `KCore` namespace of the vendored core,
with upstream's permitted set. Upstream's own audit imports its root module,
which also imports Krisis's verified programs; this one imports the vendored
modules explicitly.
-/
import KCore.Syntax
import KCore.Semantics
import KCore.WellFormed
import KCore.Examples
import KCore.Theorems
import KCore.Fuel
import KCore.BigStep
import KCore.TypeSoundness
import KCore.Logic
import KCore.Kit
import KCore.LayoutFacts
import KCore.Encode
import KCore.C11.Ast
import KCore.C11.Print
import KCore.C11.Check
import Lean

open Lean

#eval show CoreM Unit from do
  let allowed : List Name := [``propext, ``Classical.choice, ``Quot.sound]
  let env ← getEnv
  let mut checked := 0
  let mut bad : Array (Name × Name) := #[]
  for (name, _) in env.constants.toList do
    if (`KCore).isPrefixOf name && !name.isInternal then
      checked := checked + 1
      for ax in ← collectAxioms name do
        unless allowed.contains ax do
          bad := bad.push (name, ax)
  if bad.isEmpty then
    IO.println s!"kcore_axiom_audit=verified constants={checked} allowed=propext,Classical.choice,Quot.sound"
  else
    throwError m!"forbidden axioms: {bad.toList}"
