/-
SCB-0 decoder for the alpha typed-core fragment
(`spec/encoding/SCB0_SCHEMA_LEDGER.md`, `SCB0_KEYS_ENVELOPE_AND_DIGEST.md`).

A single forward cursor over the exact module bytes. It either returns the
unique `Module` those bytes denote or rejects. It rejects every discriminant
outside the alpha fragment, every nonzero count where the alpha subset has
none (imports, domains, functions), truncation, and trailing bytes.

Recursion is structural on an explicit fuel bound, never well-founded, so the
Lean kernel itself can evaluate the decoder on concrete bytes. Every recursive
step consumes at least one byte, so the input length is enough fuel.

This checks structure only. Typing, canonical order of tables, and reference
ranges are admission, which is separate.
-/
import Seki.Core

namespace Seki.Decode

abbrev Dec (α : Type) := List Nat → Except String (α × List Nat)

def fail (msg : String) : Dec α := fun _ => .error msg

def pure' (a : α) : Dec α := fun s => .ok (a, s)

def bind' (m : Dec α) (f : α → Dec β) : Dec β := fun s =>
  match m s with
  | .ok (a, s') => f a s'
  | .error e => .error e

instance : Monad Dec where
  pure := pure'
  bind := bind'

def u8 : Dec Nat
  | b :: rest => .ok (b, rest)
  | [] => .error "truncated"

def u32 : Dec Nat := do
  let a ← u8; let b ← u8; let c ← u8; let d ← u8
  pure (((a * 256 + b) * 256 + c) * 256 + d)

/-- `n` raw octets. -/
def raw : Nat → Dec (List Nat)
  | 0 => pure []
  | n + 1 => do let b ← u8; let rest ← raw n; pure (b :: rest)

/-- Big-endian unsigned integer of `n` octets. -/
def beNat (n : Nat) : Dec Nat := do
  let bs ← raw n
  pure (bs.foldl (fun acc b => acc * 256 + b) 0)

def name : Dec String := do
  let n ← u32
  let bs ← raw n
  if bs.all (· < 128) then pure (String.ofList (bs.map Char.ofNat))
  else fail "name is not ASCII"

/-- `count` repetitions of `item`. -/
def seqN (item : Dec α) : Nat → Dec (List α)
  | 0 => pure []
  | n + 1 => do let x ← item; let rest ← seqN item n; pure (x :: rest)

def seq (item : Dec α) : Dec (List α) := do
  let n ← u32
  seqN item n

def expectZero (what : String) : Dec Unit := do
  let n ← u32
  if n = 0 then pure () else fail s!"{what} is outside the alpha subset"

/-- `TypeRef::local(index)`; imported references are outside the subset. -/
def typeRef : Dec Nat := do
  let t ← u8
  if t = 0 then u32 else fail "imported type reference"

def intTy : Nat → Option IntTy
  | 0 => some .u8 | 1 => some .u16 | 2 => some .u32 | 3 => some .u64 | _ => none

def ty : Nat → Dec Ty
  | 0 => fail "type nesting exceeds its fuel"
  | fuel + 1 => do
    match ← u8 with
    | 0 => pure .unit
    | 1 => pure .bool
    | 2 => pure (.int .u8)
    | 3 => pure (.int .u16)
    | 4 => pure (.int .u32)
    | 5 => pure (.int .u64)
    | 11 => do let n ← u32; pure (.bytes n)
    | 13 => do
        let alg ← u8
        if alg ≠ 0 then fail "digest algorithm" else
        let n ← u32; pure (.digest n)
    | 19 => do let a ← ty fuel; let r ← ty fuel; pure (.decision a r)
    | 21 => do let i ← typeRef; pure (.declared i)
    | t => fail s!"type {t} is outside the alpha subset"

def field (fuel : Nat) : Dec Field := do
  let n ← name
  let t ← ty fuel
  pure ⟨n, t⟩

def case (fuel : Nat) : Dec Case := do
  let tag ← u32
  let n ← name
  match ← u8 with
  | 0 => pure ⟨tag, n, none⟩
  | 1 => do let fs ← seq (field fuel); pure ⟨tag, n, some fs⟩
  | _ => fail "payload option tag"

def decl (fuel : Nat) : Dec Decl := do
  let n ← name
  match ← u8 with
  | 0 => do let t ← ty fuel; pure ⟨n, .alias t⟩
  | 1 => do let t ← ty fuel; pure ⟨n, .nominal t⟩
  | 2 => do let fs ← seq (field fuel); pure ⟨n, .record fs⟩
  | 3 => do let cs ← seq (case fuel); pure ⟨n, .variant cs⟩
  | k => fail s!"declaration kind {k}"

def cmpOp : Nat → Option CmpOp
  | 0 => some .lt | 1 => some .le | 2 => some .gt | 3 => some .ge | _ => none

mutual
def expr : Nat → Dec Expr
  | 0 => fail "expression nesting exceeds its fuel"
  | fuel + 1 => do
    let t ← ty fuel
    let term ← term fuel
    pure (.mk t term)

def term : Nat → Dec Term
  | 0 => fail "expression nesting exceeds its fuel"
  | fuel + 1 => do
    match ← u8 with
    | 0 => pure .unit
    | 1 => do
        match ← u8 with
        | 0 => pure (.bool false)
        | 1 => pure (.bool true)
        | _ => fail "Boolean literal"
    | 2 => do
        match intTy (← u8) with
        | some w => do let v ← beNat (w.bits / 8); pure (.int w v)
        | none => fail "integer type outside the alpha subset"
    | 4 => do let i ← u32; pure (.local i)
    | 6 => do
        let r ← typeRef
        let n ← u32
        let fs ← inits fuel n
        pure (.record r fs)
    | 7 => do
        let e ← expr fuel
        let owner ← u8
        if owner ≠ 0 then fail "field owner outside the alpha subset" else
        let r ← typeRef
        let f ← u32
        pure (.project e r f)
    | 8 => do
        let r ← typeRef
        let tag ← u32
        let n ← u32
        let fs ← namedInits fuel n
        pure (.variant r tag fs)
    | 14 => do let a ← expr fuel; let b ← expr fuel; pure (.eq a b)
    | 15 => do let a ← expr fuel; let b ← expr fuel; pure (.ne a b)
    | 17 => do let a ← expr fuel; let b ← expr fuel; pure (.andThen a b)
    | 18 => do let a ← expr fuel; let b ← expr fuel; pure (.orElse a b)
    | 19 => do
        match cmpOp (← u8) with
        | some op => do let a ← expr fuel; let b ← expr fuel; pure (.cmp op a b)
        | none => fail "comparison operator"
    | t => fail s!"term {t} is outside the alpha subset"

/-- `count` record constructor fields: `FieldRef(record_type, TypeRef, index)`,
    value. Each element, like every other recursive call, spends one unit of
    fuel: every call consumes input bytes, so the input length still bounds
    every call chain, and the recursion stays structural so the Lean kernel
    can evaluate it. -/
def inits : Nat → Nat → Dec Inits
  | 0, _ => fail "expression nesting exceeds its fuel"
  | _ + 1, 0 => pure .nil
  | fuel + 1, count + 1 => do
    let owner ← u8
    if owner ≠ 0 then fail "field owner outside the alpha subset" else
    let _ ← typeRef
    let f ← u32
    let e ← expr fuel
    let rest ← inits fuel count
    pure (.cons f e rest)

/-- `count` variant constructor fields: name, value. -/
def namedInits : Nat → Nat → Dec NamedInits
  | 0, _ => fail "expression nesting exceeds its fuel"
  | _ + 1, 0 => pure .nil
  | fuel + 1, count + 1 => do
    let n ← name
    let e ← expr fuel
    let rest ← namedInits fuel count
    pure (.cons n e rest)
end

mutual
def kexpr : Nat → Dec KExpr
  | 0 => fail "kernel nesting exceeds its fuel"
  | fuel + 1 => do
    match ← u8 with
    | 0 => do let e ← expr fuel; pure (.accept e)
    | 1 => do let r ← expr fuel; let p ← u32; pure (.reject r p)
    | 2 => do
        let c ← expr fuel
        let r ← expr fuel
        let p ← u32
        let k ← kexpr fuel
        pure (.require c r p k)
    | 3 => do let v ← expr fuel; let k ← kexpr fuel; pure (.let_ v k)
    | 4 => do
        let c ← expr fuel
        let t ← kexpr fuel
        let f ← kexpr fuel
        pure (.ite c t f)
    | 5 => do
        let s ← expr fuel
        let n ← u32
        let as ← arms fuel n
        pure (.match_ s as)
    | t => fail s!"kernel expression {t}"

/-- `count` arms: `ConstructorRef(declared_variant, TypeRef, tag)`, body. -/
def arms : Nat → Nat → Dec Arms
  | 0, _ => fail "kernel nesting exceeds its fuel"
  | _ + 1, 0 => pure .nil
  | fuel + 1, count + 1 => do
    let owner ← u8
    if owner ≠ 0 then fail "constructor owner outside the alpha subset" else
    let r ← typeRef
    let tag ← u32
    let k ← kexpr fuel
    let rest ← arms fuel count
    pure (.cons r tag k rest)
end

def bounds : Dec Bounds := do
  let a ← u32; let b ← u32; let c ← u32; let d ← u32
  pure ⟨a, b, c, d⟩

def kernel (fuel : Nat) : Dec Kernel := do
  let n ← name
  let labels ← seq name
  let params ← seq (ty fuel)
  let result ← ty fuel
  let rejects ← seq (do let r ← typeRef; let t ← u32; pure (r, t))
  let body ← kexpr fuel
  let declared ← bounds
  let exact ← bounds
  let pub ← u8
  if pub > 1 then fail "publication flag" else
  pure { name := n, labels, params, result, rejects, body, declared, exact,
         publicationEligible := pub == 1 }

def module (fuel : Nat) : Dec Module := do
  let schema ← u32
  if schema ≠ 0 then fail "module schema version" else
  let path ← seq name
  let version ← u32
  let profile ← name
  let profileVersion ← u32
  expectZero "imports"
  expectZero "domains"
  let types ← seq (decl fuel)
  expectZero "functions"
  let kernels ← seq (kernel fuel)
  -- exports: domains, types, functions, kernels
  let _ ← seq u32
  let _ ← seq u32
  let _ ← seq u32
  let _ ← seq u32
  let theorems ← seq u8
  let claims ← seq u8
  let _ ← seqN u32 10              -- declared module ceiling
  let dschema ← u32
  if dschema ≠ 0 then fail "derivation schema version" else
  let _ ← seq u32                  -- type dependency order
  let _ ← seq u32                  -- function dependency order
  pure { path, version, profile, profileVersion, types, kernels, theorems, claims }

/-- The complete envelope: magic, SCB version 0, object kind module, payload
    length, payload, and nothing after it. -/
def envelope (bytes : List Nat) : Except String Module :=
  let fuel := bytes.length
  let go : Dec Module := do
    let magic ← raw 4
    if magic ≠ [0x53, 0x45, 0x4b, 0x49] then fail "magic" else
    let version ← u32
    if version ≠ 0 then fail "SCB version" else
    let kind ← u8
    if kind ≠ 0 then fail "object kind" else
    let len ← u32
    let payload ← raw len
    match module fuel payload with
    | .ok (m, []) => pure m
    | .ok _ => fail "payload has trailing bytes"
    | .error e => fail e
  match go bytes with
  | .ok (m, []) => .ok m
  | .ok _ => .error "trailing bytes after the envelope"
  | .error e => .error e

end Seki.Decode
