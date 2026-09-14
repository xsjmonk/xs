---
name: xs-language
description: >
  Develop, modify, review, debug, and explain XS programs. Use this skill for
  .xs files, XS Interpreter or Site mode, clr.exe scripts, XS grammar, and
  XS engine extensions. XS is a custom language; do not infer its syntax from
  C#, JavaScript, PowerShell, or another language.
---

# XS Language

This skill is mandatory for every XS-related task. Read it before inspecting,
explaining, writing, reviewing, or debugging XS code. Use the local repository
sources below as the authoritative knowledge base; do not require another
repository or a second skill.

## Skill ownership and availability

This file is the single canonical XS skill for this repository. Add every new
XS rule or piece of guidance here so it remains available to all agents.
Do not copy this skill into agent-specific folders, other project folders, or
duplicate skill files. Agents working in different contexts must reference
this skill and its local sources instead of creating a second copy that can
drift or require the knowledge to be learned again.

## Local authoritative sources

| Source | Use |
| --- | --- |
| `Interpreter.ATG` | Simplified token and grammar reference |
| `readme.md` | Living language specification |
| `readme_new.md` | Additional language guide and patterns |
| `ConsoleExtension.md` | Console, progress, and status APIs |
| `Scripts/*.xs` | Known-working scripts and idioms |

When sources disagree, follow the priority order in **Priority of evidence**
below. Search the local scripts for a working example before inventing syntax.

## Core language contract

- XS has CLR/.NET interop, but its syntax is not C#.
- A program may contain imports, `func`/`void` definitions, top-level flow,
  and a final `return`/`=>`/`ret`.
- The top-level main section has no early `return`; use a label and `goto`,
  then one final result.
- `func` paths must return a value; `void` methods may use bare `return`.
- Use `elseif`, never `else if`; there is no `foreach`, `switch`, `using`,
  `throw`, nullable type, or `out/ref/in/params` syntax.
- `catch` has no exception variable, cannot be empty, and cannot contain
  branching operators such as `goto`, `return`, `=>`, `continue`, or `break`.
  Use `catch` only for exception-handling statements such as logging or
  assignment to target variables; prefer a success flag and decide after the
  `try/catch`.
- Statements are separated by semicolons; newlines do not provide separation.
- Opening braces stay on the same line as the declaration or control statement.
- Variables are region-scoped (top-level, `func`, `void`, `Site`), not
  block-scoped; `if`/`for`/`while` do not create a new scope.
- `await` is supported only on a direct CLR method call that returns
  `Task`/`Task<T>`/`ValueTask`/`ValueTask<T>`; not on variables,
  parenthesized operands, user `func`s, or general expressions.

## Keywords and expressions

- `url`, `now`, and `config` are reserved keywords. Never use `url` as an
  identifier; use `uri`, `pageUrl`, or `targetUrl`.
- String concatenation is `&`, not `+`.
- `Replace` is regex replacement; use `ReplStr` for plain text replacement.
- Use `IsEmpty()`/`IsNullOrWhiteSpace()` rather than string comparisons when
  checking empty input.
- Compound assignments such as `+=` are not supported; expand them.
- `[ident]` is dictionary/argument access. Use `[(ident)]` or another
  disambiguated form for a one-element array. `[a, b]` with elements is an
  `ArrayList` literal; a lone `[ident]` is never a one-element list.
- Array literals are `[...]` and are ArrayList-like; C# arrays are not XS data.
- Index expressions are limited to integer or string forms.
- Prefer `expr[i]` over `expr.get_item(i)` when indexing is supported.
- Cast precedence differs from C#. `(Type)items[i]` and
  `(clr.JToken)root["key"]` bind the cast to the collection/root, not the
  indexed element. Parenthesize the full lookup: `(Type)(items[i])`.
- **Cast also binds before `..`:** `(bool)response..IsSuccessStatusCode` is
  parsed as `((bool)response)..IsSuccessStatusCode` and throws at runtime.
  Write `(bool)(response..IsSuccessStatusCode)` or compare without casting.
- After a cast, use `..name` to force CLR member resolution:
  `(clr.SqlConnection)con..Open()`.
- Dynamic member access: `expr -> "propName"` or `expr -> propVar` (GetProp).
- String literals: `"..."` with escapes, `@"..."` verbatim (`""` = one quote),
  `<<< ... >>>` multiline free-text; single quotes are valid inside literals.
- Regex escapes in normal strings use one backslash (`"\s+"`, `"\d+"`), not
  C# doubled escapes (`"\\s+"`). Use `@"..."` or `<<< >>>` when backslashes
  must stay literal.
- Anonymous objects are immutable; create and assign a new object to change
  their shape.

## Variables and types

- Declare variables at first use; do not predeclare every variable at the top.
- Prefer explicit `string`, `int`, `long`, `double`, and `bool` types when
  known; use `var` for complex CLR values only.
- `var` must be initialized with a concrete type the compiler can infer, such
  as `new clr.SomeType()`, a cast like `(clr.JObject)x`, or another concrete
  value. Never write `var a = null`; the compiler cannot infer the variable
  type. Do not later assign a different type to the same `var` variable.
- `StringBuilder` is a built-in type and may be used without `new`.
- Redeclaration behaves like assignment and does not reinitialize a variable;
  initialization happens only once (`StringBuilder sb;` inside an `if` does
  not create a new builder on re-entry).
- Do not declare variables inside `do` or `catch` blocks.
- Numeric promotion is `double > long > int`.
- `_` is the discard identifier for a call or assignment whose result is not
  needed.

## Imports and CLR interop

Imports use the form:

```xs
import System.IO.File as File;
```

Use the imported type through `clr`, for example `clr.File.ReadAllText(path)`.
The `clr.` prefix is still required after import; never call `File.ReadAllText`
without `clr.`. Generic types use backtick arity:
`import System.Collections.Generic.Dictionary`2[System.String,System.String] as Dictionary`.
Direct CLR types and methods use `clr.<namespace>.<type>`. Use `new clr...`
for constructors and cast when the runtime type is not known.

There are three API tiers:

1. Engine-native helpers are called by bare name, such as `Match`, `MatchGroup`,
   `MatchTags`, `ReplStr`, `Trim`, `IsEmpty`, `Trace`, and `Ceiling`.
2. Engine extensions are called through `clr`, such as `clr.Dlinq.Linq.*`.
3. External extension assemblies, when loaded by the host, are also called
   through their `clr` namespace.

Do not invent aliases or call CLR methods as engine-native helpers. Do not
`clr.`-prefix a Tier-1 native or bare-call a Tier-2/3 method. CLR instance
methods are not extension-style callable (`s.ToLower()` is invalid); only
engine-native helpers and user `func` methods may be called extension-style.
Follow working scripts when evidence differs. Confirm signatures in
`ConsoleExtension.md`, `readme.md`, or working scripts.

When a CLR object implements disposal, call `Dispose()` immediately after its
final use. XS has no `using` statement.

## Script structure and safe patterns

Keep scripts modular: imports, arguments/configuration, short main flow,
then focused helper functions. Each helper should have one responsibility and
explicit inputs/outputs. Avoid hidden state except deliberate `@` globals.

Typical layout: imports → `@` globals → `[p1]`/`Ask` argument reading → main
logic → final `=>`/`return` → helper `func`/`void` definitions below main.
Use `goto label;` for early exit, retries (`Retry:`), and waits in main flow.

Use the canonical patterns already present in `Scripts/*.xs` for:

- command-line arguments `[p1]`, `[p2]`, and interactive fallback;
- PowerShell execution and captured output;
- JSON template-driven serialization/deserialization;
- CSV import/export;
- SQL connections and disposal;
- console, status, progress, and table output;
- user configuration persistence.

For `<<< >>>` templates, replace placeholders in place
(`_ tpl.Replace("key", val)`), not via chained intermediate strings from
`.ToString()`. For PowerShell, `clr.Ex.Powershell.Run` streams live output;
capture stdout with an EncodedCommand helper when output must be parsed (see
`Scripts/*.xs`). Initialize JSON config from a full-shape template via
`Deserialize(json, templateObj)`, never `var cfg = null`.

Never hard-code credentials, tokens, private keys, or other secrets. Sanitize
and validate user input before embedding it in PowerShell, shell, SQL, or URLs.
Do not leave empty catches, unbounded polling loops, or swallowed failures.
Normalize generated Windows command text to `\r\n` where the target tool
requires Windows line endings.

## Coding style

- Keep the main section short; move logic into focused `func`/`void` helpers.
- Compose complex work as a pipeline of independent helpers with clear
  inputs and outputs.
- Keep conditionals compact when control flow stays clear; expand when a
  single line would hide important conditions or side effects.
- Presentation helpers such as `mark()` should render only; keep business
  logic separate and normalize line endings to `\r\n` in output helpers.
- Do not change user state (branch, cwd, selection) unless explicitly
  requested.

## Site mode

Site mode is distinct from Interpreter mode. Identify the mode before editing.
Read the Site-related sections in `readme.md` first.

```xs
Site Example {
    config Addr = "https://example.test/" & url;
    name = { => MatchGroup(this, "<title>(.*?)</title>", "g"); };
}
```

Site output fields become CSV columns. A null output field can drop the entire
row, so return an intentional default such as `""` or `-1` unless dropping
the row is required. `config` blocks may be reevaluated by the host. In
ParseItem `config` blocks, `url` is the Excel input ID; output blocks see the
downloaded URL. Output blocks can read or write sibling fields via
`[FieldName]` / `[FieldName] = value`. ParseIDs list mode adds `SiteIDs`
(one ID per line) and `SiteIDsNext` (next page URL; empty string stops).

For repeated HTML records, keep the extraction pipeline observable:

1. Isolate the smallest relevant container with `MatchTag`.
2. Enumerate records with `MatchTags`.
3. Extract and normalize fields from each record.
4. Build the expected object/list.
5. Serialize only the result, not raw HTML.

For Site changes, validate with the repository's available Site-mode runner or
host test if present. Do not claim validation from visual inspection alone.

## Editing rules

- Preserve existing behavior and working XS idioms.
- Make the smallest localized change.
- Do not delete unrelated helpers or rewrite a script into another language.
- Verify unfamiliar syntax against `Interpreter.ATG`, `readme.md`, and
  `Scripts/*.xs` before changing code.
- Avoid broad formatting and generated-file rewrites.
- Treat existing scripts as evidence: successful-looking syntax is not enough.

## Validation workflow

For every modified script:

1. Identify Interpreter versus Site mode.
2. Search `Scripts/*.xs` for the closest working pattern.
3. Check `Interpreter.ATG`, `readme.md`, and `readme_new.md` as needed.
4. Run the smallest available XS parser/interpreter or host test.
5. Read compiler/runtime output and correct the actual syntax/API issue.
6. Repeat until the relevant behavior is demonstrated.

When the repository does not contain the required runtime or test harness,
report that limitation explicitly. Do not substitute a different language
compiler or claim that static inspection proves runtime correctness.

## Common pitfalls

- **`(Type)obj..Member` needs inner parentheses:** `(bool)response..IsSuccessStatusCode`
  casts the object, not the property. Use `(bool)(response..IsSuccessStatusCode)`.
  A `try/catch` around this can hide the bug and make translation/API checks look disabled.
- `&` is concatenation; `+` is numeric addition.
- `Replace` is regex; `ReplStr` is plain text.
- `elseif` is required.
- Main flow cannot early-return.
- `catch {}` is invalid.
- `catch` cannot contain `goto`, `return`, `=>`, `continue`, or `break`.
- `var x = null` is invalid; initialize `var` with `new clr...`, a cast, or
  another concrete value, and do not reassign a different type later.
- `[ident]` is dictionary access, not a one-element list.
- `(Type)obj[i]` is not `(Type)(obj[i])`; parenthesize the full lookup
  before casting.
- `(Type)obj..Member` is not `(Type)(obj..Member)`; parenthesize before `..`.
- Variables are not block-scoped; redeclaration does not reinitialize.
- No C# arrays — use `ArrayList` and `[expr]`.
- `..` vs `.` after a cast: use `..` to reach CLR members on cast values.
- Three-tier call style: Tier-1 bare name, Tier-2/3 via `clr.<ns>...`.
- Regex escapes: `"\s+"` not `"\\s+"` in normal strings.
- `await` only on direct CLR method calls returning Task/ValueTask.
- Site mode: a `null` output field drops the whole row.
- Site mode: `url` in `config` is the Excel ID, not the downloaded URL.
- `url`, `now`, and `config` are reserved.
- C# syntax, CLR assumptions, and unverified extension APIs are not evidence.

## Priority of evidence

When sources disagree, use this order:

1. Working local scripts executed successfully
2. `Interpreter.ATG` (simplified grammar in this repo)
3. `readme.md` (living spec)
4. `readme_new.md` and `ConsoleExtension.md`
5. General programming-language assumptions (last resort)

## Completion standard

A task is complete only when the changed XS code follows the local grammar and
working-script conventions, the relevant runtime or test path was executed
when available, and any unavailable runtime/API validation is clearly
reported. Keep this skill as the single canonical XS guidance in this repo.
