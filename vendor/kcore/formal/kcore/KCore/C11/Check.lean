/-
Independent emitted-C checker (AR-1 amendment 12, KCORE_C11_SUBSET §5).

Shares no code with the printer (`KCore.C11.Ast`, `KCore.C11.Print`). It reads
the emitted `kc_u<n>.h` and `kc_u<n>.c` of unit `n` as text, with its own lexer and
its own grammar of the subset, and:

  1. rejects every construct outside the subset (the grammar has no rule for
     it), including every cast other than the `(uintW_t)` forms, every `goto`
     other than the fixed failure jumps, every library call other than the
     support component, and every operator form other than the table's;
  2. type-checks as it parses, so that every C operator form is used only at
     the widths where its C meaning is the KCore meaning: plain operators at
     u32/u64, the promotion pattern at exactly the operand width u8/u16;
  3. rebuilds the KCore program the C text denotes, and the layout facts it
     asserts;
  4. compares them with the proved program and its target layout.

The comparison is modulo `normalize ∘ erase ∘ anon`:
  * `anon` replaces every name by the printer's closed naming scheme;
  * `erase` identifies each checked operator with its wrapping form (`add`
    with `wadd`, …) and `zext` with `trunc`: the C text is the same for both,
    and on every run of a program that never gets stuck (KCore T4) they give
    the same value;
  * `normalize` re-associates `seq`, which C flattens.

Soundness argument (reviewed, not proved): if the check passes, the C text
means, row by row of the translation table, the rebuilt program; the rebuilt
program equals `normalize (erase (anon P))`; and that program behaves as `P`
on every run on which `P` is not stuck, which is every run (T4).
-/
import KCore.WellFormed
import KCore.Encode

namespace KCore.C11Check
open KCore

/-! ## Lexer -/

inductive Tok where
  | id (s : String)
  | num (n : Nat) (unsigned : Bool)
  | str (s : String)
  | p (s : String)
  /-- A whole preprocessor line, whitespace-normalized. -/
  | pp (s : String)
deriving DecidableEq, Repr

def puncts : List String :=
  ["<<", ">>", "<=", ">=", "==", "!=", "&&", "||", "(", ")", "{", "}", "[", "]", ";", ",", ".",
   "*", "&", "=", "<", ">", "+", "-", "/", "%", "^", "|", "!", "~", ":"]

def isIdStart (c : Char) : Bool := c.isAlpha || c == '_'
def isIdChar (c : Char) : Bool := c.isAlphanum || c == '_'

/-- Lex one line (no preprocessor directive, no comment start inside). -/
def lexLine : Nat → List Char → Except String (List Tok)
  | 0, _ => .error "lexer fuel"
  | _, [] => .ok []
  | fuel + 1, c :: cs =>
    if c == ' ' || c == '\t' || c == '\r' then lexLine fuel cs
    else if isIdStart c then
      let rest := cs.takeWhile isIdChar
      let after := cs.dropWhile isIdChar
      do pure (.id (String.ofList (c :: rest)) :: (← lexLine fuel after))
    else if c.isDigit then
      let ds := (c :: cs).takeWhile Char.isDigit
      let after := (c :: cs).dropWhile Char.isDigit
      let n := ds.foldl (fun a d => a * 10 + (d.toNat - '0'.toNat)) 0
      -- C reads a leading 0 as octal: only the constant `0` itself may start with 0.
      if ds.length > 1 && c == '0' then .error "octal constant" else
      match after with
      | 'u' :: after' => do pure (.num n true :: (← lexLine fuel after'))
      | _ =>
        if after.head?.map isIdChar == some true then .error "malformed number"
        else do pure (.num n false :: (← lexLine fuel after))
    else if c == '"' then
      let body := cs.takeWhile (· ≠ '"')
      let after := cs.dropWhile (· ≠ '"')
      if body.contains '\\' then .error "escape in string literal" else
      match after with
      | '"' :: after' => do pure (.str (String.ofList body) :: (← lexLine fuel after'))
      | _ => .error "unterminated string"
    else
      match puncts.find? (fun p => (c :: cs).take p.length == p.toList) with
      | some p => do pure (.p p :: (← lexLine fuel ((c :: cs).drop p.length)))
      | none => .error s!"unexpected character '{c}'"

/-- Lex a file: block comments are removed, `#` lines become `pp` tokens.
    Line comments, trigraphs, digraphs, line continuations and any other
    character are rejected. -/
def lex (src : String) : Except String (List Tok) := do
  -- Remove /* ... */ comments; reject //, backslashes and trigraphs.
  let cs := src.toList.toArray
  -- As in C translation phase 3: a comment becomes one space, and a string
  -- literal is copied verbatim (a `/*` inside it starts no comment).
  let mut out : Array Char := #[]
  let mut i := 0
  let mut inComment := false
  let mut inString := false
  while i < cs.size do
    let c := cs[i]!
    let d := cs[i + 1]?
    if inComment then
      if c == '*' && d == some '/' then
        inComment := false; out := out.push ' '; i := i + 2
      else i := i + 1
    else if inString then
      if c == '\n' then throw "newline in string literal"
      if c == '"' then inString := false
      out := out.push c; i := i + 1
    else if c == '"' then
      inString := true; out := out.push c; i := i + 1
    else if c == '/' && d == some '*' then
      inComment := true; i := i + 2
    else if c == '/' && d == some '/' then
      throw "line comment"
    else if c == '\\' then
      throw "backslash outside string"
    else if c == '?' && d == some '?' then
      throw "trigraph"
    else
      out := out.push c; i := i + 1
  if inComment then throw "unterminated comment"
  if inString then throw "unterminated string"
  let chars := out.toList
  let lines := (String.ofList chars).splitOn "\n"
  let mut toks : Array Tok := #[]
  for line in lines do
    let t := line.trimAscii.toString
    if t.startsWith "#" then
      toks := toks.push (.pp (" ".intercalate ((t.splitOn " ").filter (· ≠ ""))))
    else
      toks := toks ++ (← lexLine (t.length + 1) t.toList).toArray
  return toks.toList

/-! ## Parser monad -/

abbrev CP := StateT (List Tok) (Except String)

def fail {α : Type} (msg : String) : CP α := fun ts =>
  .error s!"{msg} at {repr (ts.take 6)}"

def peek : CP (Option Tok) := fun ts => .ok (ts.head?, ts)
def peek2 : CP (List Tok) := fun ts => .ok (ts.take 4, ts)

def next : CP Tok := fun ts =>
  match ts with
  | t :: r => .ok (t, r)
  | [] => .error "unexpected end of file"

def tok (t : Tok) : CP Unit := do
  let t' ← next
  if t' ≠ t then fail s!"expected {repr t}, found {repr t'}"

def ps (s : String) : CP Unit := tok (.p s)
def kw (s : String) : CP Unit := tok (.id s)

/-- Try `a`; on failure, restore the input and run `b`. -/
def orElse {α : Type} (a b : CP α) : CP α := fun ts =>
  match a ts with
  | .ok r => .ok r
  | .error _ => b ts

def isP (s : String) : CP Bool := do pure ((← peek) == some (.p s))
def isId (s : String) : CP Bool := do pure ((← peek) == some (.id s))

/-- A generated name `pre<digits>`. -/
def numbered (pre : String) (s : String) : Option Nat :=
  if s.startsWith pre then
    let d := (s.drop pre.length).toString
    if d.isEmpty || !d.all Char.isDigit || (d.length > 1 && d.startsWith "0") then none
    else some d.toNat!
  else none

/-- The program-scope prefix of unit `un`: `kc_u<un>_`. -/
def unitPre (un : Nat) : String := s!"kc_u{un}_"

/-- The code of an allocation component name `kc_u<un>_alloc_<code>`. -/
def allocCode (un : Nat) (s : String) : Option String :=
  let pre := unitPre un ++ "alloc_"
  if s.startsWith pre then some (s.drop pre.length).toString else none

def idNum (pre : String) : CP Nat := do
  match ← next with
  | .id s => match numbered pre s with
      | some n => pure n
      | none => fail s!"expected {pre}<n>"
  | _ => fail s!"expected {pre}<n>"

def decNum : CP Nat := do
  match ← next with
  | .num n false => pure n
  | _ => fail "expected a decimal constant"

def uNum : CP Nat := do
  match ← next with
  | .num n true => pure n
  | _ => fail "expected an unsigned constant"

/-! ## Types -/

def intOfName : String → Option IntTy
  | "uint8_t" => some .u8 | "uint16_t" => some .u16
  | "uint32_t" => some .u32 | "uint64_t" => some .u64
  | _ => none

def sName (i : Nat) : String := s!"s{i}"

/-- `T` then any number of `*`. -/
def cty (un nstructs : Nat) : CP Ty := do
  let base ← match ← next with
    | .id "bool" => pure Ty.bool
    | .id "struct" => do
        let i ← idNum (unitPre un ++ "s")
        if i < nstructs then pure (Ty.struct (sName i)) else fail "unknown struct"
    | .id s => match intOfName s with
        | some w => pure (Ty.int w)
        | none => fail "expected a type"
    | _ => fail "expected a type"
  let rec stars : Nat → Ty → CP Ty
    | 0, t => pure t
    | f + 1, t => do if ← isP "*" then do ps "*"; stars f (.ptr t) else pure t
  stars 8 base

def widthName : IntTy → String
  | .u8 => "uint8_t" | .u16 => "uint16_t" | .u32 => "uint32_t" | .u64 => "uint64_t"

def isNarrow : IntTy → Bool
  | .u8 | .u16 => true
  | _ => false

/-! ## Typed expressions -/

structure Env where
  /-- The unit number of the program-scope names. -/
  un : Nat
  structs : List (List Ty)
  vars : List Ty

def Env.var (E : Env) (i : Nat) : CP Ty :=
  match E.vars[i]? with
  | some t => pure t
  | none => fail "undeclared variable"

def litOfName : String → Option IntTy
  | "UINT8_C" => some .u8 | "UINT16_C" => some .u16
  | "UINT32_C" => some .u32 | "UINT64_C" => some .u64
  | _ => none

/-- The wrapping (erased) KCore operator of a C arithmetic operator. -/
def arithOp : String → Option BinOp
  | "+" => some .wadd | "-" => some .wsub | "*" => some .wmul | "/" => some .div
  | "%" => some .mod | "&" => some .band | "|" => some .bor | "^" => some .bxor
  | "<<" => some .wshl | ">>" => some .shr
  | _ => none

def relOp : String → Option BinOp
  | "==" => some .eq | "!=" => some .ne | "<" => some .lt | "<=" => some .le
  | _ => none

def logOp : String → Option BinOp
  | "&&" => some .land | "||" => some .lor
  | _ => none

def binOpTok : CP (Option String) := do
  match ← peek with
  | some (.p s) => pure (if (arithOp s).isSome || (relOp s).isSome || (logOp s).isSome then some s else none)
  | _ => pure none

/-- Is the input at `( ( <castname> )`? Returns the cast target. -/
def castAhead : CP (Option String) := do
  match ← peek2 with
  | [.p "(", .p "(", .id s, .p ")"] => pure (if (intOfName s).isSome then some s else none)
  | _ => pure none

mutual
/-- Parse an expression. `exp` is the expected type where the context fixes
    one; `NULL` is accepted only there. -/
def expr (E : Env) : Nat → Option Ty → CP (Expr × Ty)
  | 0, _ => fail "expression fuel"
  | f + 1, exp => do
    match ← peek with
    | some (.id "true") => do let _ ← next; pure (.lit (.bool true), .bool)
    | some (.id "false") => do let _ ← next; pure (.lit (.bool false), .bool)
    | some (.id "NULL") => do
        let _ ← next
        match exp with
        | some (.ptr t) => pure (.lit (.ptr t .null), .ptr t)
        | _ => fail "NULL without an expected pointer type"
    | some (.id s) =>
        match litOfName s with
        | some w => do
            let _ ← next; ps "("; let n ← decNum; ps ")"
            if n < w.bound then pure (.lit (.int w n), .int w) else fail "literal out of range"
        | none => do
            let i ← idNum "v"
            pure (.var s!"v{i}", ← E.var i)
    | some (.p "(") => paren E f exp
    | _ => fail "expected an expression"

def paren (E : Env) : Nat → Option Ty → CP (Expr × Ty)
  | 0, _ => fail "expression fuel"
  | f + 1, _ => do
    match ← castAhead with
    | some cname => do
        let w := (intOfName cname).getD .u32
        ps "("; ps "("; kw cname; ps ")"
        match ← peek2 with
        | [.p "(", .p "(", .id "uint32_t", .p ")"] => do
            -- promotion pattern: ((uintW_t)((uint32_t)(a) OP (uint32_t)(b)))
            unless isNarrow w do fail "promotion pattern at a non-narrow width"
            ps "("; ps "("; kw "uint32_t"; ps ")"; ps "("
            let (a, ta) ← expr E f none
            ps ")"
            let op ← match ← next with
              | .p s => match arithOp s with
                  | some o => pure o
                  | none => fail "expected an arithmetic operator"
              | _ => fail "expected an arithmetic operator"
            ps "("; kw "uint32_t"; ps ")"; ps "("
            let (b, tb) ← expr E f none
            ps ")"; ps ")"; ps ")"
            unless ta = .int w ∧ tb = .int w do fail "promotion pattern width mismatch"
            pure (.bin op a b, .int w)
        | [.p "(", .p "~", .p "(", .id "uint32_t"] => do
            -- ((uintW_t)(~(uint32_t)(a)))
            unless isNarrow w do fail "narrow complement at a non-narrow width"
            ps "("; ps "~"; ps "("; kw "uint32_t"; ps ")"; ps "("
            let (a, ta) ← expr E f none
            ps ")"; ps ")"; ps ")"
            unless ta = .int w do fail "complement width mismatch"
            pure (.un .bnot a, .int w)
        | _ => do
            -- ((uintW_t)a): conversion
            let (a, ta) ← expr E f none
            ps ")"
            match ta with
            | .int _ => pure (.un (.trunc w) a, .int w)
            | _ => fail "conversion of a non-integer"
    | none => do
      ps "("
      match ← peek2 with
      | [.p "(", .id "struct", _, .p ")"] => do
          -- ((struct kc_sI){ .f0 = e0, ... })
          ps "("; kw "struct"; let i ← idNum (unitPre E.un ++ "s"); ps ")"; ps "{"
          let fields ← match E.structs[i]? with
            | some fs => pure fs
            | none => fail "unknown struct"
          let es ← inits E f 0 fields
          ps "}"; ps ")"
          pure (.mk (sName i) es, .struct (sName i))
      | [.p "!", _, _, _] => do
          ps "!"; let (a, ta) ← expr E f none; ps ")"
          unless ta = .bool do fail "! of a non-bool"
          pure (.un .lnot a, .bool)
      | [.p "~", _, _, _] => do
          ps "~"; let (a, ta) ← expr E f none; ps ")"
          match ta with
          | .int w => if isNarrow w then fail "~ at a narrow width" else pure (.un .bnot a, .int w)
          | _ => fail "~ of a non-integer"
      | _ => do
          let (a, ta) ← expr E f none
          match ← binOpTok with
          | some s => do
              ps s
              let (b, tb) ← expr E f (some ta)
              ps ")"
              match ta, tb with
              | .int w, .int w' =>
                  if w ≠ w' then fail "operand widths differ" else
                  match arithOp s, relOp s with
                  | some o, _ =>
                      if isNarrow w then fail "plain operator at a narrow width"
                      else pure (.bin o a b, .int w)
                  | _, some o => pure (.bin o a b, .bool)
                  | _, _ => fail "logical operator on integers"
              | .bool, .bool =>
                  match s with
                  | "==" => pure (.bin .eq a b, .bool)
                  | "!=" => pure (.bin .ne a b, .bool)
                  | _ => match logOp s with
                      | some o => pure (.bin o a b, .bool)
                      | none => fail "operator on bool"
              | .ptr t, .ptr t' =>
                  if t ≠ t' then fail "pointer types differ" else
                  match relOp s with
                  | some o => pure (.bin o a b, .bool)
                  | none => fail "arithmetic on pointers"
              | _, _ => fail "operand types"
          | none => do
              ps ")"; ps "."
              let j ← idNum "f"
              match ta with
              | .struct n => match (numbered "s" n).bind (E.structs[·]?) with
                  | some fs => match fs[j]? with
                      | some t => pure (.field a j, t)
                      | none => fail "no such field"
                  | none => fail "unknown struct"
              | _ => fail "field of a non-struct"

/-- Designated initializers `.f<j> = e, …` for fields `j, j+1, …`. -/
def inits (E : Env) : Nat → Nat → List Ty → CP (List Expr)
  | 0, _, _ => fail "expression fuel"
  | _, _, [] => pure []
  | f + 1, j, t :: ts => do
      if j > 0 then ps ","
      ps "."; let j' ← idNum "f"
      unless j' = j do fail "fields out of order"
      ps "="
      let (e, te) ← expr E f (some t)
      unless te = t do fail "field type mismatch"
      pure (e :: (← inits E f (j + 1) ts))
end

/-- Full-width expression with a required type. -/
def exprAt (E : Env) (f : Nat) (t : Ty) : CP Expr := do
  let (e, te) ← expr E f (some t)
  unless te = t do fail "type mismatch"
  pure e

def isBin : Expr → Bool
  | .bin .. => true
  | _ => false

/-- The parenthesized condition of `if`/`while`. A relational or logical
    condition is written `(a OP b)`: the statement's parentheses are the
    operator's own. Every other condition is written `(e)`. Exactly one form
    is accepted for each condition. -/
def cond (E : Env) (f : Nat) : CP Expr :=
  orElse
    (do
      let (c, tc) ← expr E f (some .bool)
      unless tc = .bool ∧ isBin c do fail "not a relational condition"
      pure c)
    (do
      ps "("
      let c ← exprAt E f .bool
      ps ")"
      if isBin c then fail "doubly parenthesized relational condition"
      pure c)

/-! ## Typed zeros (as the printer must emit them) -/

def zeroExpr (structs : List (List Ty)) : Nat → Ty → Option Expr
  | _, .int w => some (.lit (.int w 0))
  | _, .bool => some (.lit (.bool false))
  | _, .ptr t => some (.lit (.ptr t .null))
  | 0, .struct _ => none
  | d + 1, .struct n => do
      let fs ← (numbered "s" n).bind (structs[·]?)
      pure (.mk n (← fs.mapM (zeroExpr structs d)))

/-! ## Statements -/

structure FEnv where
  env : Env
  /-- Parameter and result types of each function, by index. -/
  sigs : List (Option (List Ty × Ty))
  result : Ty
  /-- Element type of each allocation component, by code. -/
  allocs : List (String × Ty)

/-- The statements a body flattens to, and whether a label is needed:
    (alloc, cancel, propagate). -/
structure Uses where
  alloc : Bool := false
  cancel : Bool := false
  propagate : Bool := false

def Uses.join (a b : Uses) : Uses :=
  { alloc := a.alloc || b.alloc, cancel := a.cancel || b.cancel, propagate := a.propagate || b.propagate }

def varIdx : CP Nat := idNum "v"

mutual
def stmt (F : FEnv) : Nat → CP (Stmt × Uses)
  | 0 => fail "statement fuel"
  | f + 1 => do
    let E := F.env
    match ← peek with
    | some (.p ";") => do ps ";"; pure (.skip, {})
    | some (.id "kc_n") => do
        -- allocation template
        kw "kc_n"; ps "="
        let c ← exprAt E f (.int .u64)
        ps ";"
        let x ← varIdx
        ps "="
        let code ← match ← next with
          | .id s => match allocCode E.un s with
              | some c => pure c
              | none => fail "expected kc_u<n>_alloc_<code>"
          | _ => fail "expected kc_u<n>_alloc_<code>"
        let t ← match F.allocs.lookup code with
          | some t => pure t
          | none => fail "unknown allocation component"
        unless (← E.var x) = .ptr t do fail "allocation target type"
        ps "("; kw "kc_c"; ps ","; kw "kc_n"; ps ")"; ps ";"
        kw "if"; ps "("; let x' ← varIdx; ps "=="; kw "NULL"; ps ")"
        kw "goto"; kw "kc_fail_alloc"; ps ";"
        kw "kc_i"; ps "="; kw "UINT64_C"; ps "("; tok (.num 0 false); ps ")"; ps ";"
        kw "while"; ps "("; kw "kc_i"; ps "<"; kw "kc_n"; ps ")"; ps "{"
        let x'' ← varIdx; ps "["; kw "kc_i"; ps "]"; ps "="
        let z ← exprAt E f t
        ps ";"
        kw "kc_i"; ps "="; kw "kc_i"; ps "+"; kw "UINT64_C"; ps "("; tok (.num 1 false); ps ")"; ps ";"
        ps "}"
        unless x = x' ∧ x = x'' do fail "allocation template variable mismatch"
        let some zexp := zeroExpr E.structs (E.structs.length + 1) t | fail "no typed zero"
        unless Encode.expr z = Encode.expr zexp do fail "allocation initializer is not the typed zero"
        pure (.alloc s!"v{x}" t c, { alloc := true })
    | some (.id "kc_rt_free") => do
        kw "kc_rt_free"; ps "("; kw "kc_c"; ps ","
        let (p, tp) ← expr E f none
        ps ")"; ps ";"
        match tp with
        | .ptr _ => pure (.free p, {})
        | _ => fail "free of a non-pointer"
    | some (.id "if") => do
        match ← peek2 with
        | [.id "if", .p "(", .id "kc_rt_cancelled", _] => do
            kw "if"; ps "("; kw "kc_rt_cancelled"; ps "("; kw "kc_c"; ps ")"; ps ")"
            kw "goto"; kw "kc_fail_cancel"; ps ";"
            pure (.checkpoint, { cancel := true })
        | _ => do
            kw "if"
            let c ← cond E f
            ps "{"
            let (a, ua) ← block F f
            ps "}"; kw "else"; ps "{"
            let (b, ub) ← block F f
            ps "}"
            pure (.ite c a b, ua.join ub)
    | some (.id "while") => do
        kw "while"
        let c ← cond E f
        ps "{"
        let (b, ub) ← block F f
        ps "}"
        pure (.while c b, ub)
    | some (.id "kc_st") => do
        match ← peek2 with
        | [.id "kc_st", .p "=", .id g, .p "("] =>
          match numbered (unitPre F.env.un ++ "f") g with
          | some fi => do
              kw "kc_st"; ps "="; kw g; ps "("; kw "kc_c"
              let (pts, rt) ← match F.sigs[fi]? with
                | some (some s) => pure s
                | _ => fail "call of an unknown or entry function"
              let rec args : Nat → List Ty → CP (List Expr)
                | 0, _ => fail "statement fuel"
                | _, [] => pure []
                | g + 1, t :: ts => do ps ","; let e ← exprAt E f t; pure (e :: (← args g ts))
              let as ← args (pts.length + 1) pts
              ps ","; ps "&"; let x ← varIdx; ps ")"; ps ";"
              unless (← E.var x) = rt do fail "call result type"
              kw "if"; ps "("; kw "kc_st"; ps "!="; kw "KC_OK"; ps ")"
              kw "goto"; kw "kc_propagate"; ps ";"
              pure (.call s!"v{x}" s!"f{fi}" as, { propagate := true })
          | none => fail "expected a call"
        | _ => fail "unexpected assignment to kc_st"
    | some (.p "*") => do
        match ← peek2 with
        | [.p "*", .id "kc_out", _, _] => do
            ps "*"; kw "kc_out"; ps "="
            let e ← exprAt E f F.result
            ps ";"; kw "return"; kw "KC_OK"; ps ";"
            pure (.ret e, {})
        | _ => do
            ps "*"; ps "("
            let (p, tp) ← expr E f none
            ps ")"; ps "="
            match tp with
            | .ptr t => do
                let v ← exprAt E f t
                ps ";"
                pure (.store p v, {})
            | _ => fail "store through a non-pointer"
    | some (.id _) => do
        let x ← varIdx
        let tx ← E.var x
        ps "="
        if ← isP "*" then do
          ps "*"; ps "("
          let (p, tp) ← expr E f none
          ps ")"; ps ";"
          unless tp = .ptr tx do fail "load type"
          pure (.load s!"v{x}" p, {})
        else
          -- `x = (p) + (k);` is pointer arithmetic; no expression has that shape.
          orElse
            (do
              ps "("
              let (p, tp) ← expr E f none
              ps ")"; ps "+"; ps "("
              let k ← exprAt E f (.int .u64)
              ps ")"; ps ";"
              unless tp = tx do fail "pointer arithmetic type"
              match tp with
              | .ptr _ => pure (.ptrAdd s!"v{x}" p k, {})
              | _ => fail "pointer arithmetic on a non-pointer")
            (do
              let e ← exprAt E f tx
              ps ";"
              pure (.assign s!"v{x}" e, {}))
    | _ => fail "expected a statement"

/-- Statements up to a closing `}` (not consumed). -/
def block (F : FEnv) : Nat → CP (Stmt × Uses)
  | 0 => fail "statement fuel"
  | f + 1 => do
    let rec go : Nat → CP (List Stmt × Uses)
      | 0 => fail "statement fuel"
      | g + 1 => do
          if ← isP "}" then pure ([], {}) else
          let (s, u) ← stmt F f
          let (ss, u') ← go g
          pure (s :: ss, u.join u')
    let (ss, u) ← go (f + 1)
    if ss.isEmpty then fail "empty block"
    pure (build ss, u)

/-- Right-nested sequence (the normal form of `normalize`). -/
def build : List Stmt → Stmt
  | [] => .skip
  | [s] => s
  | s :: ss => .seq s (build ss)
end

/-! ## Normal form of the proved program -/

section anon
variable (P : Program)

def structIdx (n : String) : Nat := (P.structs.findIdx? (·.name == n)).getD 0
def funIdx (n : String) : Nat := (P.funs.findIdx? (·.name == n)).getD 0

def anonTy : Ty → Ty
  | .ptr t => .ptr (anonTy t)
  | .struct n => .struct (sName (structIdx P n))
  | t => t

def eraseBin : BinOp → BinOp
  | .add => .wadd | .sub => .wsub | .mul => .wmul | .shl => .wshl
  | op => op

variable (fd : FunDef)

def anonVar (x : String) : String := s!"v{(fd.vars.findIdx? (·.1 == x)).getD 0}"

mutual
def anonExpr : Expr → Expr
  | .var x => .var (anonVar fd x)
  | .lit (.ptr t p) => .lit (.ptr (anonTy P t) p)
  | .lit v => .lit v
  | .bin op a b => .bin (eraseBin op) (anonExpr a) (anonExpr b)
  | .un (.zext w) a => .un (.trunc w) (anonExpr a)
  | .un op a => .un op (anonExpr a)
  | .field e i => .field (anonExpr e) i
  | .mk n es => .mk (sName (structIdx P n)) (anonExprs es)
def anonExprs : List Expr → List Expr
  | [] => []
  | e :: es => anonExpr e :: anonExprs es
end

/-- The statements of a `seq` tree, flattened and normalized. -/
def flat : Stmt → List Stmt
  | .seq a b => flat a ++ flat b
  | .skip => [.skip]
  | .assign x e => [.assign (anonVar fd x) (anonExpr P fd e)]
  | .load x p => [.load (anonVar fd x) (anonExpr P fd p)]
  | .store p v => [.store (anonExpr P fd p) (anonExpr P fd v)]
  | .ptrAdd x p k => [.ptrAdd (anonVar fd x) (anonExpr P fd p) (anonExpr P fd k)]
  | .alloc x t c => [.alloc (anonVar fd x) (anonTy P t) (anonExpr P fd c)]
  | .free p => [.free (anonExpr P fd p)]
  | .call x g as => [.call (anonVar fd x) s!"f{funIdx P g}" (anonExprs P fd as)]
  | .checkpoint => [.checkpoint]
  | .ite c a b => [.ite (anonExpr P fd c) (build (flat a)) (build (flat b))]
  | .while c b => [.while (anonExpr P fd c) (build (flat b))]
  | .ret e => [.ret (anonExpr P fd e)]

end anon

/-- `normalize (erase (anon P))`. -/
def normalForm (P : Program) : Program :=
  { structs := P.structs.zipIdx.map fun (sd, i) =>
      { name := sName i, fields := sd.fields.map (anonTy P) }
    funs := P.funs.zipIdx.map fun (fd, i) =>
      { name := s!"f{i}"
        params := fd.params.zipIdx.map fun ((_, t), j) => (s!"v{j}", anonTy P t)
        result := anonTy P fd.result
        locals := fd.locals.zipIdx.map fun ((_, t), j) => (s!"v{fd.params.length + j}", anonTy P t)
        body := build (flat P fd fd.body) } }

/-- Layout facts the C file must assert, in order: (kind, type, value). -/
def expectedFacts (P : Program) (L : Layout) : List (String × Ty × Nat) :=
  let fact (t : Ty) := [("sizeof", anonTy P t, L.sizeOf t), ("_Alignof", anonTy P t, L.alignOf t)]
  [Ty.int .u8, .int .u16, .int .u32, .int .u64, .bool].flatMap fact ++
  P.structs.zipIdx.flatMap fun (sd, i) =>
    fact (.struct sd.name) ++
    (L.fieldOffsets sd.name).zipIdx.map (fun (o, j) => (s!"offsetof.f{j}", Ty.struct (sName i), o)) ++
    sd.fields.flatMap fact

/-! ## Files -/

/-- The fixed preamble, as tokens. -/
def preambleToks (un : Nat) : Except String (List Tok) := lex (String.intercalate "\n" [
  "#include <stdint.h>", "#include <stdbool.h>", "#include <stddef.h>", "#include <limits.h>",
  "#include \"kc_rt.h\"", s!"#include \"kc_u{un}.h\"",
  "_Static_assert(CHAR_BIT == 8, \"8-bit bytes\");",
  "_Static_assert(UINT_MAX == 4294967295u, \"32-bit unsigned int\");",
  "_Static_assert(INT_MAX == 2147483647, \"32-bit int\");",
  "_Static_assert(SIZE_MAX == UINT64_MAX, \"64-bit size_t\");",
  "_Static_assert(UINT8_MAX == 255u && UINT16_MAX == 65535u, \"exact widths\");",
  "_Static_assert(UINT32_MAX == 4294967295u, \"exact width\");",
  "_Static_assert(UINT64_MAX == 18446744073709551615u, \"exact width\");"])

def toks (ts : List Tok) : CP Unit := ts.forM tok

def structDefs (un : Nat) : Nat → Nat → CP (List (List Ty))
  | 0, _ => fail "fuel"
  | f + 1, i => do
    if ← isId "struct" then
      kw "struct"; let i' ← idNum (unitPre un ++ "s")
      unless i' = i do fail "structs out of order"
      ps "{"
      let rec fields : Nat → Nat → CP (List Ty)
        | 0, _ => fail "fuel"
        | g + 1, j => do
            if ← isP "}" then pure [] else
            let t ← cty un (i + 1) -- a struct may contain only earlier structs by value
            let j' ← idNum "f"
            unless j' = j do fail "fields out of order"
            ps ";"
            pure (t :: (← fields g (j + 1)))
      let fs ← fields (f + 1) 0
      ps "}"; ps ";"
      if fs.isEmpty then fail "empty struct"
      pure (fs :: (← structDefs un f (i + 1)))
    else pure []

/-- `(kc_ctx *kc_c, T v0, …, R *kc_out)`: parameter and result types. -/
def params (un ns : Nat) : CP (List Ty × Ty) := do
  ps "("; kw "kc_ctx"; ps "*"; kw "kc_c"
  let rec go : Nat → Nat → CP (List Ty × Ty)
    | 0, _ => fail "fuel"
    | f + 1, j => do
        ps ","
        let t ← cty un ns
        match ← next with
        | .id "kc_out" => do
            ps ")"
            match t with
            | .ptr r => pure ([], r)
            | _ => fail "out-parameter is not a pointer"
        | .id s => match numbered "v" s with
            | some j' => if j' = j then do let (ts, r) ← go f (j + 1); pure (t :: ts, r)
                         else fail "parameters out of order"
            | none => fail "parameter name"
        | _ => fail "parameter name"
  go 64 0

/-- `uint32_t kc_u<un>_entry` or `static uint32_t kc_u<un>_f<i>`: `none` for
    the entry. -/
def funHead (un : Nat) : CP (Option Nat) := do
  if ← isId "static" then
    kw "static"; kw "uint32_t"; let i ← idNum (unitPre un ++ "f"); pure (some i)
  else do
    kw "uint32_t"; kw (unitPre un ++ "entry"); pure none

def layoutFacts (un : Nat) : Nat → Nat → CP (List (String × Ty × Nat))
  | 0, _ => fail "fuel"
  | f + 1, ns => do
    match ← peek2 with
    | [.id "_Static_assert", .p "(", .id k, .p "("] => do
        kw "_Static_assert"; ps "("
        let fact ← match k with
          | "sizeof" | "_Alignof" => do
              kw k; ps "("; let t ← cty un ns; ps ")"; ps "=="; let n ← uNum
              pure (k, t, n)
          | "offsetof" => do
              kw k; ps "("; kw "struct"; let i ← idNum (unitPre un ++ "s"); ps ","; let j ← idNum "f"; ps ")"
              ps "=="; let n ← uNum
              pure (s!"offsetof.f{j}", Ty.struct (sName i), n)
          | _ => fail "unexpected static assertion"
        ps ","; tok (.str "kcore layout"); ps ")"; ps ";"
        pure (fact :: (← layoutFacts un f ns))
    | _ => pure []

def typeCode : Ty → String
  | .int .u8 => "u8" | .int .u16 => "u16" | .int .u32 => "u32" | .int .u64 => "u64"
  | .bool => "b"
  | .ptr t => "p" ++ typeCode t
  | .struct n => n

def allocComponents (un : Nat) : Nat → Nat → CP (List (String × Ty))
  | 0, _ => fail "fuel"
  | f + 1, ns => do
    match ← peek2 with
    | [.id "static", _, _, _] =>
      orElse
        (do
          kw "static"
          let pt ← cty un ns
          let t ← match pt with
            | .ptr t => pure t
            | _ => fail "allocation component type"
          let code ← match ← next with
            | .id s => match allocCode un s with
                | some c => pure c
                | none => fail "component name"
            | _ => fail "component name"
          unless code = typeCode t do fail "component code"
          ps "("; kw "kc_ctx"; ps "*"; kw "kc_c"; ps ","; kw "uint64_t"; kw "kc_n"; ps ")"; ps "{"
          kw "return"; kw "kc_rt_alloc"; ps "("; kw "kc_c"; ps ","; kw "kc_n"; ps ","
          kw "sizeof"; ps "("; let t' ← cty un ns; ps ")"; ps ")"; ps ";"; ps "}"
          unless t' = t do fail "component element size"
          pure ((code, t) :: (← allocComponents un f ns)))
        (pure [])
    | _ => pure []

def epilogue (entry : Bool) (u : Uses) : CP Unit := do
  kw "kc_st"; ps "="; kw "KC_STUCK"; ps ";"; kw "goto"; kw "kc_fail"; ps ";"
  if u.alloc then
    kw "kc_fail_alloc"; ps ":"; kw "kc_st"; ps "="; kw "KC_ALLOCATION_FAILED"; ps ";"
    kw "goto"; kw "kc_fail"; ps ";"
  if u.cancel then
    kw "kc_fail_cancel"; ps ":"; kw "kc_st"; ps "="; kw "KC_CANCELLED"; ps ";"
    kw "goto"; kw "kc_fail"; ps ";"
  if u.propagate then
    kw "kc_propagate"; ps ":"; kw "goto"; kw "kc_fail"; ps ";"
  kw "kc_fail"; ps ":"
  if entry then kw "kc_rt_release_all"; ps "("; kw "kc_c"; ps ")"; ps ";"
  kw "return"; kw "kc_st"; ps ";"; ps "}"

/-- One function definition. -/
def function (un : Nat) (structs : List (List Ty)) (sigs : List (Option (List Ty × Ty)))
    (allocs : List (String × Ty)) (fuel : Nat) : CP (Option Nat × FunDef) := do
  let ns := structs.length
  let head ← funHead un
  let (pts, rt) ← params un ns
  ps "{"
  let np := pts.length
  let rec locals : Nat → Nat → CP (List Ty)
    | 0, _ => fail "fuel"
    | f + 1, k => do
        match ← peek2 with
        | [.id "uint32_t", .id "kc_st", _, _] => pure []
        | _ => do
            let t ← cty un ns
            let k' ← idNum "v"
            unless k' = k do fail "locals out of order"
            ps "="
            let (z, tz) ← expr { un, structs, vars := [] } fuel (some t)
            unless tz = t do fail "initializer type"
            let some zexp := zeroExpr structs (ns + 1) t | fail "no typed zero"
            unless Encode.expr z = Encode.expr zexp do fail "local initializer is not the typed zero"
            ps ";"
            pure (t :: (← locals f (k + 1)))
  let lts ← locals 4096 np
  kw "uint32_t"; kw "kc_st"; ps "="; kw "KC_OK"; ps ";"
  let hasAllocVars ← do
    match ← peek2 with
    | [.id "uint64_t", .id "kc_n", _, _] => do
        kw "uint64_t"; kw "kc_n"; ps "="; kw "UINT64_C"; ps "("; tok (.num 0 false); ps ")"; ps ";"
        kw "uint64_t"; kw "kc_i"; ps "="; kw "UINT64_C"; ps "("; tok (.num 0 false); ps ")"; ps ";"
        pure true
    | _ => pure false
  ps "("; kw "void"; ps ")"; kw "kc_c"; ps ";"
  let F : FEnv := { env := { un, structs, vars := pts ++ lts }, sigs, result := rt, allocs }
  let rec body : Nat → CP (List Stmt × Uses)
    | 0 => fail "fuel"
    | g + 1 => do
        match ← peek2 with
        | [.id "kc_st", .p "=", .id "KC_STUCK", _] => pure ([], {})
        | _ => do
            let (s, u) ← stmt F fuel
            let (ss, u') ← body g
            pure (s :: ss, u.join u')
  let (ss, u) ← body fuel
  if ss.isEmpty then fail "empty body"
  if u.alloc && !hasAllocVars then fail "allocation without kc_n/kc_i"
  epilogue head.isNone u
  let idx := head
  pure (idx, { name := "", params := pts.zipIdx.map (fun (t, j) => (s!"v{j}", t)), result := rt,
               locals := lts.zipIdx.map (fun (t, j) => (s!"v{np + j}", t)), body := build ss })

/-- `static uint32_t kc_u<un>_f<i>(…);` prototypes. -/
def protos (un ns : Nat) : Nat → CP (List (Nat × (List Ty × Ty)))
  | 0 => fail "fuel"
  | f + 1 =>
      orElse
        (do
          kw "static"; kw "uint32_t"; let i ← idNum (unitPre un ++ "f")
          let sig ← params un ns
          ps ";"
          pure ((i, sig) :: (← protos un ns f)))
        (pure [])

structure Checked where
  program : Program
  entry : Nat
  facts : List (String × Ty × Nat)

/-- Parse `kc_u<un>.h` and `kc_u<un>.c` into the program they denote. -/
def parseFiles (un : Nat) (header source : String) : Except String Checked := do
  let h ← lex header
  let c ← lex source
  let fuel := c.length + 16
  -- header
  let (structs, sigEntry) ← (do
      toks [.pp s!"#ifndef KC_U{un}_H", .pp s!"#define KC_U{un}_H", .pp "#include <stdint.h>",
            .pp "#include <stdbool.h>", .pp "#include \"kc_rt.h\""]
      let structs ← structDefs un 1024 0
      kw "uint32_t"; kw (unitPre un ++ "entry")
      let sig ← params un structs.length
      ps ";"
      tok (.pp "#endif")
      if !(← get).isEmpty then fail "trailing text in header"
      pure (structs, sig) : CP _).run' h
  -- source
  let pre ← preambleToks un
  if pre.length < 60 then .error "preamble oracle did not lex"
  (do
    toks pre
    let facts ← layoutFacts un 4096 structs.length
    let allocs ← allocComponents un 256 structs.length
    -- prototypes of the non-entry functions
    let ps' ← protos un structs.length 1024
    let nfun := ps'.length + 1
    let sigs : List (Option (List Ty × Ty)) := (List.range nfun).map fun i =>
      (ps'.lookup i)
    let rec defs : Nat → Nat → CP (List (Option Nat × FunDef))
      | 0, _ => fail "fuel"
      | f + 1, k => do
          if (← get).isEmpty then pure [] else
          let d ← function un structs sigs allocs fuel
          pure (d :: (← defs f (k + 1)))
    let ds ← defs 1024 0
    unless ds.length = nfun do fail "function count"
    -- function k is `kc_u<un>_f<k>` except the entry
    let mut entry := none
    let mut funs : List FunDef := []
    for ((head, fd), k) in ds.zipIdx do
      match head with
      | some i =>
          unless i = k do fail "functions out of order"
          unless ps'.lookup k = some (fd.params.map (·.2), fd.result) do fail "prototype mismatch"
      | none =>
          if entry.isSome then fail "two entries"
          unless sigEntry = (fd.params.map (·.2), fd.result) do fail "entry prototype mismatch"
          entry := some k
      funs := funs ++ [{ fd with name := s!"f{k}" }]
    let some e := entry | fail "no entry"
    pure { program := { structs := structs.zipIdx.map fun (fs, i) => { name := sName i, fields := fs },
                        funs }
           entry := e, facts } : CP Checked).run' c

/-- The check: the emitted files denote exactly the proved program `P`
    (modulo `normalForm`) with entry `entry`, and assert exactly the layout
    `L`. -/
def check (un : Nat) (P : Program) (L : Layout) (entry : String) (header source : String) :
    Except String Unit := do
  unless P.wf do .error "the reference program is not well-formed"
  unless L.valid P do .error "the target layout is not valid"
  unless L.sizeMax = 2 ^ 64 - 1 do .error "SIZE_MAX of the layout is not asserted by the preamble"
  let got ← parseFiles un header source
  let want := normalForm P
  let some ei := P.funs.findIdx? (·.name == entry) | .error "no such entry"
  unless got.entry = ei do .error "entry function differs"
  unless Encode.program got.program = Encode.program want do
    .error "the emitted C does not denote the proved program"
  unless got.facts = expectedFacts P L do .error "layout assertions differ from the target layout"

end KCore.C11Check
