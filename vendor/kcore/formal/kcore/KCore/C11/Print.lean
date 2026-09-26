/-
The KCore → C11 printer (AR-1 §7, KCORE_C11_SUBSET §4).

`lower` maps a well-formed KCore program and a valid target layout to the
typed subset AST (`KCore.C11.Ast`); `render` prints that AST. Operand types
come from the KCore typing function `typeOf`, and select the translation
table row: u32/u64 operators are emitted directly, u8/u16 operators through
the promotion pattern of KCORE_C11_SUBSET §3.

Trust status (AR-1 §4(b), §4a): the printer is not proved. Every emitted
file must pass the independent checker (`KCore.C11.Check`), which rebuilds the
KCore program from the C text alone and compares it with the proved program.
-/
import KCore.C11.Ast
import KCore.WellFormed

namespace KCore.C11
open KCore

abbrev PrintM := Except String

def indexOf {α : Type} (p : α → Bool) (xs : List α) (what : String) : PrintM Nat :=
  match xs.findIdx? p with
  | some i => pure i
  | none => throw s!"unresolved {what}"

section lower
variable (P : Program)

def lowerTy : Ty → PrintM CTy
  | .int w => pure (.int w)
  | .bool => pure .bool
  | .ptr t => do pure (.ptr (← lowerTy t))
  | .struct n => do pure (.struct (← indexOf (·.name == n) P.structs "struct"))

def isWide : IntTy → Bool
  | .u32 | .u64 => true
  | .u8 | .u16 => false

def arithOf : BinOp → Option CArith
  | .add | .wadd => some .add
  | .sub | .wsub => some .sub
  | .mul | .wmul => some .mul
  | .div => some .div | .mod => some .mod
  | .band => some .band | .bor => some .bor | .bxor => some .bxor
  | .shl | .wshl => some .shl | .shr => some .shr
  | _ => none

def relOf : BinOp → Option CRel
  | .eq => some .eq | .ne => some .ne | .lt => some .lt | .le => some .le
  | .land => some .land | .lor => some .lor
  | _ => none

variable (fd : FunDef)

def varIdx (x : String) : PrintM Nat := indexOf (·.1 == x) fd.vars "variable"

def tyOfE (e : Expr) : PrintM Ty :=
  match typeOf P fd.vars e with
  | some t => pure t
  | none => throw "ill-typed expression"

mutual
def lowerExpr : Expr → PrintM CExpr
  | .var x => do pure (.var (.v (← varIdx fd x)))
  | .lit (.int w n) => if n < w.bound then pure (.intLit w n) else throw "literal out of range"
  | .lit (.bool b) => pure (.boolLit b)
  | .lit (.ptr _ .null) => pure .null
  | .lit _ => throw "non-literal value"
  | .bin op a b => do
      let ta ← tyOfE P fd a
      let ca ← lowerExpr a
      let cb ← lowerExpr b
      match ta, arithOf op, relOf op with
      | .int w, some o, _ => pure (if isWide w then .wide o ca cb else .narrow w o ca cb)
      | _, _, some r => pure (.rel r ca cb)
      | _, _, _ => throw "operator/type mismatch"
  | .un op a => do
      let ta ← tyOfE P fd a
      let ca ← lowerExpr a
      match op, ta with
      | .lnot, _ => pure (.lnot ca)
      | .bnot, .int w => pure (if isWide w then .complWide ca else .complNarrow w ca)
      | .zext to, _ => pure (.conv to ca)
      | .trunc to, _ => pure (.conv to ca)
      | _, _ => throw "operator/type mismatch"
  | .field e i => do pure (.field (← lowerExpr e) i)
  | .mk n es => do
      let s ← indexOf (·.name == n) P.structs "struct"
      pure (.compound s (← lowerExprs es))

def lowerExprs : List Expr → PrintM (List CExpr)
  | [] => pure []
  | e :: es => do pure ((← lowerExpr e) :: (← lowerExprs es))
end

/-- Typed zero of a heap element type (pointer-free by `Program.wf`). -/
def zeroOfTy : Nat → Ty → PrintM CExpr
  | _, .int w => pure (.intLit w 0)
  | _, .bool => pure (.boolLit false)
  | _, .ptr _ => throw "pointer-bearing element type"
  | 0, .struct _ => throw "struct nesting too deep"
  | d + 1, .struct n => do
      let s ← indexOf (·.name == n) P.structs "struct"
      match P.struct? n with
      | some sd => do pure (.compound s (← sd.fields.mapM (zeroOfTy d)))
      | none => throw "unresolved struct"

def lowerStmt (entryIdx : Nat) : Stmt → PrintM (List CStmt)
  | .skip => pure [.empty]
  | .assign x e => do pure [.assign (.v (← varIdx fd x)) (← lowerExpr P fd e)]
  | .load x p => do pure [.load (.v (← varIdx fd x)) (← lowerExpr P fd p)]
  | .store p v => do pure [.store (← lowerExpr P fd p) (← lowerExpr P fd v)]
  | .ptrAdd x p k => do pure [.ptrAdd (.v (← varIdx fd x)) (← lowerExpr P fd p) (← lowerExpr P fd k)]
  | .alloc x t c => do
      pure [.alloc (.v (← varIdx fd x)) (← lowerTy P t) (← lowerExpr P fd c)
        (← zeroOfTy P (P.structs.length + 1) t)]
  | .free p => do pure [.free (← lowerExpr P fd p)]
  | .call x f args => do
      let fi ← indexOf (·.name == f) P.funs "function"
      if fi = entryIdx then throw "the entry function may not be called internally"
      pure [.call (.v (← varIdx fd x)) fi (← lowerExprs P fd args)]
  | .checkpoint => pure [.checkpoint]
  | .ite c a b => do
      pure [.ite (← lowerExpr P fd c) (← lowerStmt entryIdx a) (← lowerStmt entryIdx b)]
  | .while c b => do pure [.while (← lowerExpr P fd c) (← lowerStmt entryIdx b)]
  | .seq a b => do pure ((← lowerStmt entryIdx a) ++ (← lowerStmt entryIdx b))
  | .ret e => do pure [.ret (← lowerExpr P fd e)]

end lower

/-- Element types of every `alloc`, in first-occurrence order. -/
def allocTys : List CStmt → List CTy → List CTy
  | [], acc => acc
  | s :: ss, acc =>
      let acc := match s with
        | .alloc _ t _ _ => if acc.contains t then acc else acc ++ [t]
        | .ite _ a b => allocTys b (allocTys a acc)
        | .while _ b => allocTys b acc
        | _ => acc
      allocTys ss acc

/-- Layout facts, in the order of `KCore.Encode.layout`. -/
def layoutAsserts (P : Program) (L : Layout) : PrintM (List CAssert) := do
  let fact (t : Ty) : PrintM (List CAssert) := do
    let c ← lowerTy P t
    pure [.sizeOf c (L.sizeOf t), .alignOf c (L.alignOf t)]
  let base ← [Ty.int .u8, .int .u16, .int .u32, .int .u64, .bool].flatMapM fact
  let structs ← (P.structs.zipIdx).flatMapM fun (sd, i) => do
    let own ← fact (.struct sd.name)
    let offs := (L.fieldOffsets sd.name).zipIdx.map fun (o, j) => CAssert.offsetOf i j o
    let fields ← sd.fields.flatMapM fact
    pure (own ++ offs ++ fields)
  pure (base ++ structs)

/-- Lower a program. Refuses anything outside the printer's premises. -/
def lower (P : Program) (L : Layout) (entry : String) : PrintM CUnit := do
  unless P.wf do throw "program is not well-formed"
  unless L.valid P do throw "target layout is not valid"
  unless P.entryWf entry do throw "entry rule violated"
  unless L.sizeMax = 2 ^ 64 - 1 do throw "the C target requires a 64-bit SIZE_MAX"
  if P.structs.any (·.fields.isEmpty) then throw "empty struct"
  let entryIdx ← indexOf (·.name == entry) P.funs "entry"
  let structs ← P.structs.mapM (·.fields.mapM (lowerTy P))
  let funs ← (P.funs.zipIdx).mapM fun (fd, i) => do
    pure { idx := i, entry := i == entryIdx
           params := ← fd.params.mapM (lowerTy P ·.2)
           locals := ← fd.locals.mapM (lowerTy P ·.2)
           result := ← lowerTy P fd.result
           body := ← lowerStmt P fd entryIdx fd.body : CFun }
  pure { structs, asserts := ← layoutAsserts P L,
         allocTypes := funs.foldl (fun acc f => allocTys f.body acc) [],
         funs, entry := entryIdx }

/-! ## Rendering -/

def intTyName : IntTy → String
  | .u8 => "uint8_t" | .u16 => "uint16_t" | .u32 => "uint32_t" | .u64 => "uint64_t"

def litMacro : IntTy → String
  | .u8 => "UINT8_C" | .u16 => "UINT16_C" | .u32 => "UINT32_C" | .u64 => "UINT64_C"

/-- The program-scope prefix of unit `un`: `kc_u<un>_`. -/
def unitPre (un : Nat) : String := s!"kc_u{un}_"

def tyName (un : Nat) : CTy → String
  | .int w => intTyName w
  | .bool => "bool"
  | .ptr t => tyName un t ++ " *"
  | .struct i => s!"struct {unitPre un}s{i}"

/-- A declarator: `T name`, with `*` attached to the name. -/
def decl (un : Nat) (t : CTy) (name : String) : String :=
  let s := tyName un t
  if s.endsWith "*" then s ++ name else s ++ " " ++ name

def varName : CVar → String
  | .v i => s!"v{i}"
  | .out => "kc_out" | .st => "kc_st" | .n => "kc_n" | .i => "kc_i"

def arithSym : CArith → String
  | .add => "+" | .sub => "-" | .mul => "*" | .div => "/" | .mod => "%"
  | .band => "&" | .bor => "|" | .bxor => "^" | .shl => "<<" | .shr => ">>"

def relSym : CRel → String
  | .eq => "==" | .ne => "!=" | .lt => "<" | .le => "<="
  | .land => "&&" | .lor => "||"

mutual
def expr (un : Nat) : CExpr → String
  | .var x => varName x
  | .intLit w n => s!"{litMacro w}({n})"
  | .boolLit b => if b then "true" else "false"
  | .null => "NULL"
  | .wide o a b => s!"({expr un a} {arithSym o} {expr un b})"
  | .narrow w o a b =>
      s!"(({intTyName w})((uint32_t)({expr un a}) {arithSym o} (uint32_t)({expr un b})))"
  | .rel o a b => s!"({expr un a} {relSym o} {expr un b})"
  | .lnot a => s!"(!{expr un a})"
  | .complWide a => s!"(~{expr un a})"
  | .complNarrow w a => s!"(({intTyName w})(~(uint32_t)({expr un a})))"
  | .conv w a => s!"(({intTyName w}){expr un a})"
  | .field e i => s!"({expr un e}).f{i}"
  | .compound s es => s!"((struct {unitPre un}s{s})\{ {inits un 0 es} })"
def inits (un : Nat) : Nat → List CExpr → String
  | _, [] => ""
  | j, [e] => s!".f{j} = {expr un e}"
  | j, e :: es => s!".f{j} = {expr un e}, " ++ inits un (j + 1) es
end

/-- Typed zero initializer of a local (defensive; definite assignment is
    proved in KCore). -/
def localZero (un : Nat) (structs : List (List CTy)) : Nat → CTy → String
  | _, .int w => s!"{litMacro w}(0)"
  | _, .bool => "false"
  | _, .ptr _ => "NULL"
  | 0, .struct _ => "0"
  | d + 1, .struct i =>
      let fs := (structs.getD i []).zipIdx.map fun (t, j) => s!".f{j} = {localZero un structs d t}"
      s!"((struct {unitPre un}s{i})\{ {", ".intercalate fs} })"

def pad (k : Nat) : String := "".pushn ' ' (2 * k)

/-- The parenthesized condition of `if`/`while`. A relation already renders
    as `(a OP b)`, and those are the statement's parentheses (a second pair
    around `==` is diagnosed by clang's -Wparentheses-equality). -/
def cond (un : Nat) : CExpr → String
  | c@(.rel ..) => expr un c
  | c => s!"({expr un c})"

def stmt (un k : Nat) : CStmt → List String
  | .empty => [pad k ++ ";"]
  | .assign x e => [pad k ++ s!"{varName x} = {expr un e};"]
  | .load x p => [pad k ++ s!"{varName x} = *({expr un p});"]
  | .store p e => [pad k ++ s!"*({expr un p}) = {expr un e};"]
  | .ptrAdd x p q => [pad k ++ s!"{varName x} = ({expr un p}) + ({expr un q});"]
  | .alloc x t c z =>
      [pad k ++ s!"kc_n = {expr un c};",
       pad k ++ s!"{varName x} = {unitPre un}alloc_{t.code}(kc_c, kc_n);",
       pad k ++ s!"if ({varName x} == NULL) goto kc_fail_alloc;",
       pad k ++ "kc_i = UINT64_C(0);",
       pad k ++ "while (kc_i < kc_n) {",
       pad (k + 1) ++ s!"{varName x}[kc_i] = {expr un z};",
       pad (k + 1) ++ "kc_i = kc_i + UINT64_C(1);",
       pad k ++ "}"]
  | .free p => [pad k ++ s!"kc_rt_free(kc_c, {expr un p});"]
  | .checkpoint => [pad k ++ "if (kc_rt_cancelled(kc_c)) goto kc_fail_cancel;"]
  | .call x f args =>
      let as := args.map (expr un) ++ [s!"&{varName x}"]
      [pad k ++ s!"kc_st = {unitPre un}f{f}(kc_c, {", ".intercalate as});",
       pad k ++ "if (kc_st != KC_OK) goto kc_propagate;"]
  | .ret e => [pad k ++ s!"*kc_out = {expr un e};", pad k ++ "return KC_OK;"]
  | .ite c a b =>
      [pad k ++ s!"if {cond un c} \{"] ++ a.flatMap (stmt un (k + 1)) ++
      [pad k ++ "} else {"] ++ b.flatMap (stmt un (k + 1)) ++ [pad k ++ "}"]
  | .while c b =>
      [pad k ++ s!"while {cond un c} \{"] ++ b.flatMap (stmt un (k + 1)) ++ [pad k ++ "}"]

/-- Which failure labels a body jumps to: (alloc, cancel, propagate). -/
def labelsUsed : List CStmt → Bool × Bool × Bool
  | [] => (false, false, false)
  | s :: ss =>
      let (a, c, p) := labelsUsed ss
      match s with
      | .alloc .. => (true, c, p)
      | .checkpoint => (a, true, p)
      | .call .. => (a, c, true)
      | .ite _ x y =>
          let (a1, c1, p1) := labelsUsed x
          let (a2, c2, p2) := labelsUsed y
          (a || a1 || a2, c || c1 || c2, p || p1 || p2)
      | .while _ x =>
          let (a1, c1, p1) := labelsUsed x
          (a || a1, c || c1, p || p1)
      | _ => (a, c, p)

def funName (un : Nat) (f : CFun) : String :=
  if f.entry then unitPre un ++ "entry" else s!"{unitPre un}f{f.idx}"

def signature (un : Nat) (f : CFun) : String :=
  let ps := ["kc_ctx *kc_c"] ++ (f.params.zipIdx.map fun (t, i) => decl un t s!"v{i}") ++
    [decl un (.ptr f.result) "kc_out"]
  (if f.entry then "" else "static ") ++ s!"uint32_t {funName un f}({", ".intercalate ps})"

def function (un : Nat) (structs : List (List CTy)) (f : CFun) : List String :=
  let depth := structs.length + 1
  let np := f.params.length
  let (ua, uc, up) := labelsUsed f.body
  let locals := f.locals.zipIdx.map fun (t, i) =>
    pad 1 ++ decl un t s!"v{np + i}" ++ s!" = {localZero un structs depth t};"
  let support := [pad 1 ++ "uint32_t kc_st = KC_OK;"] ++
    (if ua then [pad 1 ++ "uint64_t kc_n = UINT64_C(0);", pad 1 ++ "uint64_t kc_i = UINT64_C(0);"]
     else []) ++
    -- a function without events or calls does not otherwise use the context
    [pad 1 ++ "(void)kc_c;"]
  let epilogue :=
    [pad 1 ++ "kc_st = KC_STUCK;", pad 1 ++ "goto kc_fail;"] ++
    (if ua then ["kc_fail_alloc:", pad 1 ++ "kc_st = KC_ALLOCATION_FAILED;", pad 1 ++ "goto kc_fail;"]
     else []) ++
    (if uc then ["kc_fail_cancel:", pad 1 ++ "kc_st = KC_CANCELLED;", pad 1 ++ "goto kc_fail;"]
     else []) ++
    (if up then ["kc_propagate:", pad 1 ++ "goto kc_fail;"] else []) ++
    ["kc_fail:"] ++ (if f.entry then [pad 1 ++ "kc_rt_release_all(kc_c);"] else []) ++
    [pad 1 ++ "return kc_st;"]
  [signature un f ++ " {"] ++ locals ++ support ++ f.body.flatMap (stmt un 1) ++ epilogue ++ ["}"]

def assertLine (un : Nat) : CAssert → String
  | .sizeOf t n => s!"_Static_assert(sizeof({tyName un t}) == {n}u, \"kcore layout\");"
  | .alignOf t n => s!"_Static_assert(_Alignof({tyName un t}) == {n}u, \"kcore layout\");"
  | .offsetOf s j n =>
      s!"_Static_assert(offsetof(struct {unitPre un}s{s}, f{j}) == {n}u, \"kcore layout\");"

def structDef (un : Nat) (fields : List CTy) (i : Nat) : List String :=
  [s!"struct {unitPre un}s{i} \{"] ++
    (fields.zipIdx.map fun (t, j) => pad 1 ++ decl un t s!"f{j}" ++ ";") ++ ["};"]

/-- The fixed preamble of every emitted `.c` file (KCORE_C11_SUBSET §1). -/
def preamble (un : Nat) : List String := [
  "#include <stdint.h>",
  "#include <stdbool.h>",
  "#include <stddef.h>",
  "#include <limits.h>",
  "#include \"kc_rt.h\"",
  s!"#include \"kc_u{un}.h\"",
  "",
  "_Static_assert(CHAR_BIT == 8, \"8-bit bytes\");",
  "_Static_assert(UINT_MAX == 4294967295u, \"32-bit unsigned int\");",
  "_Static_assert(INT_MAX == 2147483647, \"32-bit int\");",
  "_Static_assert(SIZE_MAX == UINT64_MAX, \"64-bit size_t\");",
  "_Static_assert(UINT8_MAX == 255u && UINT16_MAX == 65535u, \"exact widths\");",
  "_Static_assert(UINT32_MAX == 4294967295u, \"exact width\");",
  "_Static_assert(UINT64_MAX == 18446744073709551615u, \"exact width\");"]

def banner (programId : String) : String :=
  s!"/* Generated by the KCore C11 printer from KCore program {programId}. Do not edit. */"

/-- The header `kc_u<un>.h`: struct definitions and the entry prototype. -/
def renderHeader (un : Nat) (u : CUnit) (programId : String) : String :=
  let entry := u.funs.find? (·.entry)
  "\n".intercalate ([banner programId, s!"#ifndef KC_U{un}_H", s!"#define KC_U{un}_H", "",
    "#include <stdint.h>", "#include <stdbool.h>", "#include \"kc_rt.h\"", ""] ++
    (u.structs.zipIdx.flatMap fun (fs, i) => structDef un fs i ++ [""]) ++
    (match entry with | some f => [signature un f ++ ";"] | none => []) ++
    ["", "#endif"]) ++ "\n"

/-- The implementation file `kc_u<un>.c`. -/
def renderSource (un : Nat) (u : CUnit) (programId : String) : String :=
  let allocs := u.allocTypes.map fun t =>
    let name := unitPre un ++ "alloc_" ++ t.code
    s!"static {decl un (.ptr t) name}(kc_ctx *kc_c, uint64_t kc_n) " ++
    s!"\{ return kc_rt_alloc(kc_c, kc_n, sizeof({tyName un t})); }"
  let protos := (u.funs.filter (!·.entry)).map (signature un · ++ ";")
  "\n".intercalate ([banner programId] ++ preamble un ++ [""] ++ u.asserts.map (assertLine un) ++
    [""] ++ allocs ++ [""] ++ protos ++ [""] ++
    u.funs.flatMap (fun f => function un u.structs f ++ [""]))

end KCore.C11
