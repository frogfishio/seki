/-
The Lean evaluator as a differential oracle for sekic's generated C
(VISION.md §17, step 4).

    oracle show <core.scb0>
    oracle harness <core.scb0> <count> <out.c>

`harness` decodes the exact typed-core bytes, generates `count` inputs from the
kernel's parameter type, evaluates every one with `Seki.eval`, and writes a C
program that feeds the same inputs to the generated kernel and compares every
defined decision field with the evaluator's answer. The expected decisions come
from the typed core, not from anyone's reading of the source or of the C.

Inputs are type-directed: integers at 0, 1, the maximum, the kernel's own
literals and their neighbours, and at random; octet strings at random or equal
to another field of the same type, so identity premises are exercised both
ways; variant fields at every declared payload-free case, and, in a tenth of
the vectors, at an undeclared tag, which is not an admitted input and must
produce disposition 0 if the kernel inspects it.
-/
import Seki.Decode
import Seki.Eval

open Seki

/-! ## Literals of the kernel, for boundary values -/

mutual
def litsE : Expr → List (IntTy × Nat)
  | .mk _ t => litsT t
def litsT : Term → List (IntTy × Nat)
  | .int w n => [(w, n)]
  | .record _ fs => litsI fs
  | .project e _ _ => litsE e
  | .variant _ _ fs => litsN fs
  | .eq a b | .ne a b | .andThen a b | .orElse a b | .cmp _ a b => litsE a ++ litsE b
  | _ => []
def litsI : Inits → List (IntTy × Nat)
  | .nil => []
  | .cons _ e rest => litsE e ++ litsI rest
def litsN : NamedInits → List (IntTy × Nat)
  | .nil => []
  | .cons _ e rest => litsE e ++ litsN rest
end

mutual
def litsK : KExpr → List (IntTy × Nat)
  | .accept e => litsE e
  | .reject r _ => litsE r
  | .require c r _ k => litsE c ++ litsE r ++ litsK k
  | .let_ v k => litsE v ++ litsK k
  | .ite c t f => litsE c ++ litsK t ++ litsK f
  | .match_ s as => litsE s ++ litsA as
def litsA : Arms → List (IntTy × Nat)
  | .nil => []
  | .cons _ _ k rest => litsK k ++ litsA rest
end

/-! ## Input generation -/

structure Gen where
  seed : Nat
  pool : List (Ty × Value)
  lits : List (IntTy × Nat)
  hostile : Bool

abbrev G := StateM Gen

def rand (n : Nat) : G Nat := do
  let g ← get
  let s := (g.seed * 6364136223846793005 + 1442695040888963407) % 2 ^ 64
  set { g with seed := s }
  pure (if n = 0 then 0 else (s / 2 ^ 32) % n)

def pick (xs : List α) (default : α) : G α := do
  let i ← rand xs.length
  pure (xs[i]?.getD default)

def fromPool (t : Ty) : G (Option Value) := do
  let same := (← get).pool.filter (·.1 == t)
  if same.isEmpty then pure none else
  if (← rand 2) = 0 then pure none else
  pure (some (← pick same (t, .unit)).2)

def genInt (w : IntTy) : G Nat := do
  let top := 2 ^ w.bits - 1
  let near := ((← get).lits.filter (·.1 == w)).flatMap fun (_, n) =>
    [n, n + 1] ++ (if n > 0 then [n - 1] else [])
  match ← rand 3 with
  | 0 => pick ([0, 1, top] ++ near.filter (· ≤ top)) 0
  | _ => rand (2 ^ w.bits)

def genOctets (n : Nat) : G (List Nat) := do
  let mut out := []
  for _ in List.range n do out := (← rand 256) :: out
  pure out

def remember (t : Ty) (v : Value) : G Unit :=
  modify fun g => { g with pool := (t, v) :: g.pool }

def genValue (decls : List Decl) : Nat → Ty → G (Option Value)
  | 0, _ => pure none
  | fuel + 1, t => do
    match t with
    | .unit => pure (some .unit)
    | .bool => pure (some (.bool ((← rand 2) = 1)))
    | .int w => do
        if let some v ← fromPool t then return some v
        let v := Value.int w (← genInt w)
        remember t v; pure (some v)
    | .bytes n | .digest n => do
        if let some v ← fromPool t then return some v
        let v := Value.bytes (← genOctets n)
        remember t v; pure (some v)
    | .decision _ _ => pure none
    | .declared i =>
        match decls[i]? with
        | some ⟨_, .alias r⟩ | some ⟨_, .nominal r⟩ => do
            if let some v ← fromPool t then return some v
            let v ← genValue decls fuel r
            if let some v := v then remember t v
            pure v
        | some ⟨_, .record fs⟩ => do
            let mut vs := []
            for f in fs do
              match ← genValue decls fuel f.ty with
              | some v => vs := vs ++ [v]
              | none => return none
            pure (some (.record vs))
        | some ⟨_, .variant cs⟩ => do
            let nullary := cs.filter (·.payload.isNone)
            if (← get).hostile then
              let used := cs.map (·.tag)
              let bad := (List.range (used.length + 2)).find? (fun t => !used.contains t)
              pure (bad.map fun t => .variant t none)
            else if nullary.isEmpty then pure none
            else pure (some (.variant (← pick nullary ⟨0, "", none⟩).tag none))
        | none => pure none

/-! ## C emission -/

def lower (s : String) : String := s.map Char.toLower

def intC (w : IntTy) (n : Nat) : String :=
  match w with
  | .u8 => s!"(uint8_t){n}U" | .u16 => s!"(uint16_t){n}U"
  | .u32 => s!"UINT32_C({n})" | .u64 => s!"UINT64_C({n})"

/-- Statements that store `v`, of type `t`, into the C lvalue `lv`. -/
def store (decls : List Decl) : Nat → String → Ty → Value → List String
  | 0, _, _, _ => []
  | fuel + 1, lv, t, v =>
    match t, v with
    | .bool, .bool b => [s!"{lv} = {if b then 1 else 0};"]
    | .int _, .int w n => [s!"{lv} = {intC w n};"]
    | .bytes _, .bytes bs | .digest _, .bytes bs =>
        bs.zipIdx.map fun (b, i) => s!"{lv}[{i}] = (uint8_t){b}U;"
    | .declared i, _ =>
        match decls[i]?, v with
        | some ⟨_, .alias r⟩, _ | some ⟨_, .nominal r⟩, _ => store decls fuel lv r v
        | some ⟨_, .record fs⟩, .record vs =>
            (fs.zip vs).flatMap fun (f, x) => store decls fuel s!"{lv}.seki_f_{f.name}" f.ty x
        | some ⟨_, .variant _⟩, .variant tag _ => [s!"{lv}.tag = UINT32_C({tag});"]
        | _, _ => []
    | _, _ => []

/-- Conditions that hold when the C lvalue `lv` differs from `v`. -/
def differs (decls : List Decl) : Nat → String → Ty → Value → List String
  | 0, _, _, _ => ["1"]
  | fuel + 1, lv, t, v =>
    match t, v with
    | .unit, _ => []
    | .bool, .bool b => [s!"({lv} != {if b then 1 else 0})"]
    | .int _, .int w n => [s!"({lv} != {intC w n})"]
    | .bytes _, .bytes bs | .digest _, .bytes bs =>
        bs.zipIdx.map fun (b, i) => s!"({lv}[{i}] != (uint8_t){b}U)"
    | .declared i, _ =>
        match decls[i]?, v with
        | some ⟨_, .alias r⟩, _ | some ⟨_, .nominal r⟩, _ => differs decls fuel lv r v
        | some ⟨_, .record fs⟩, .record vs =>
            (fs.zip vs).flatMap fun (f, x) => differs decls fuel s!"{lv}.seki_f_{f.name}" f.ty x
        | some ⟨_, .variant _⟩, .variant tag _ => [s!"({lv}.tag != UINT32_C({tag}))"]
        | _, _ => ["1"]
    | _, _ => ["1"]

def rejectionDecl (decls : List Decl) (k : Kernel) : Option (List Case) :=
  match k.result with
  | .decision _ (.declared i) =>
      match decls[i]? with
      | some ⟨_, .variant cs⟩ => some cs
      | _ => none
  | _ => none

/-- Conditions under which the C decision `d` differs from the expected outcome. -/
def expectation (decls : List Decl) (k : Kernel) : Option Outcome → List String
  | none => ["(d.disposition != 0U)"]
  | some (.accept v) =>
      ["(d.abi_revision != 2U)", "(d.disposition != 1U)", "(d.rejection_tag != 0U)",
       "(d.premise_tag != 0U)"] ++
      (match k.result with
       | .decision a _ => differs decls (decls.length + 2) "d.accepted" a v
       | _ => ["1"])
  | some (.reject (.variant tag payload) prec viaRequire) =>
      ["(d.abi_revision != 2U)", "(d.disposition != 2U)",
       s!"(d.rejection_tag != {tag}U)",
       s!"(d.premise_tag != {if viaRequire then prec + 1 else 0}U)"] ++
      (match payload, rejectionDecl decls k with
       | some vs, some cs =>
           match cs.find? (·.tag == tag) with
           | some ⟨_, n, some fs⟩ =>
               (fs.zip vs).flatMap fun (f, x) =>
                 differs decls (decls.length + 2) s!"d.rejection.{lower n}.seki_f_{f.name}" f.ty x
           | _ => ["1"]
       | none, _ => []
       | _, none => ["1"])
  | some _ => ["1"]

def harness (m : Module) (count : Nat) : Except String (String × Nat × Nat × Nat) := do
  let some k := m.kernels.head? | throw "no kernel"
  let [pt] := k.params | throw "the oracle supports one-parameter kernels"
  let some modName := m.path.getLast? | throw "empty module path"
  let pre := s!"seki_a0_{lower modName}"
  let recName ← match pt with
    | .declared i => match m.types[i]? with
      | some d => pure (lower d.name)
      | none => throw "parameter type reference out of range"
    | _ => throw "the parameter is not a declared record"
  let fuel := m.types.length + 2
  let lits := litsK k.body
  let mut out : List String := [
    "/* Generated by the Seki Lean oracle. Every expected decision is Seki.eval of",
    "   the kernel's exact typed-core bytes. */",
    "#include <stdint.h>", "#include <stdio.h>", "#include <string.h>",
    s!"#include \"{pre}.h\"", "",
    "int main(void) {", "  unsigned bad = 0U;"]
  let mut seed := 20260926
  let mut accepted := 0
  let mut rejected := 0
  let mut unadmitted := 0
  for i in List.range count do
    let hostile := i % 10 == 9
    let (v, g) := (genValue m.types fuel pt).run { seed, pool := [], lits, hostile }
    seed := g.seed
    let some v := v | throw "cannot generate a value of the parameter type"
    let outcome := k.eval [v]
    match outcome with
    | some (.accept _) => accepted := accepted + 1
    | some (.reject ..) => rejected := rejected + 1
    | none => unadmitted := unadmitted + 1
    let checks := expectation m.types k outcome
    out := out ++ ["  {", s!"    {pre}_{recName} r;", s!"    {pre}_decision d;",
      "    memset(&r, 0, sizeof r);"] ++
      (store m.types fuel "r" pt v).map ("    " ++ ·) ++
      [s!"    d = {pre}_{k.name}(r);",
       s!"    if ({" || ".intercalate checks}) \{",
       s!"      if (bad < 10U) fprintf(stderr, \"vector {i}: decision differs from Seki.eval\\n\");",
       "      bad += 1U;", "    }", "  }"]
  out := out ++ [
    s!"  printf(\"lean_oracle=%s vectors={count} accepted={accepted} rejected={rejected} unadmitted={unadmitted} mismatches=%u\\n\",",
    "         bad == 0U ? \"agrees\" : \"DISAGREES\", bad);",
    "  return bad == 0U ? 0 : 1;", "}", ""]
  pure ("\n".intercalate out, accepted, rejected, unadmitted)

def readCore (path : String) : IO Module := do
  let bytes ← IO.FS.readBinFile path
  match Decode.envelope (bytes.toList.map (·.toNat)) with
  | .ok m => pure m
  | .error e => throw (IO.userError s!"{path}: SCB-0 decode rejected: {e}")

def main (args : List String) : IO UInt32 := do
  match args with
  | ["show", path] =>
      let m ← readCore path
      IO.println s!"module={".".intercalate m.path} types={m.types.length} kernels={m.kernels.length}"
      for d in m.types do IO.println s!"  type {d.name}"
      for k in m.kernels do
        IO.println s!"  kernel {k.name} params={k.params.length} rejects={k.rejects.length} exact={k.exact.steps},{k.exact.liveBits},{k.exact.controlDepth},{k.exact.workspaceBits}"
      pure 0
  | ["harness", path, count, outPath] =>
      let m ← readCore path
      match harness m count.toNat! with
      | .ok (text, _, _, _) => IO.FS.writeFile outPath text; pure 0
      | .error e => IO.eprintln s!"oracle: {e}"; pure 1
  | _ => IO.eprintln "usage: oracle show <core> | oracle harness <core> <count> <out.c>"; pure 2
