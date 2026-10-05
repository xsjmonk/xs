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
Do not copy this skill into agent-specific folders or other project folders.

**Monorepo mirror:** keep **Long text `<<< >>>`** and **RunPowershellFromMemory contract**
in sync with `../xs-language/SKILL.md` (xs-agent repo root). Extended API tables
live in the root skill; both files must carry the same required contract text.

## Local authoritative sources

| Source | Use |
| --- | --- |
| `Interpreter.ATG` | Simplified token and grammar reference |
| `readme.md` | Living language specification |
| `readme_new.md` | Additional language guide and patterns |
| `ConsoleExtension.md` | Console, progress, and status APIs |
| `Scripts/*.xs` | Known-working scripts and idioms |
| `Scripts/MediaConvert.xs` | **`clr.Console.Prompt` droplist**: dictionary keys = labels, values = domain codes |

When sources disagree, follow the priority order in **Priority of evidence**
below. Search the local scripts for a working example before inventing syntax.

## Core language contract

- XS has CLR/.NET interop, but its syntax is not C#.
- A program may contain imports, `func`/`void` definitions, top-level flow,
  and a final `return`/`=>`/`ret`.
- **`func` and `void` are not the Parser main part.** Helper bodies support
  early exit and **multiple** exits: `return;` in **`void`**, `=> expr;` /
  `return expr;` in **`func`**, including under `if`, `for`, and `while`.
  **Do not use `goto exit` (or similar) in `func`/`void` when `return`/`=>`
  is enough** — reserve `goto` in helpers only for rare loop exits.
- **No early `return`/`=>` in main execution regions** (not inside `func`/`void`):
  **Parser mode top-level main** (the statement flow that ends in one final
  `=>`/`return`) and **Site mode output column blocks** and **`config` blocks**.
  Use straight-line logic plus one final result, or **`goto label;`** then a
  single final `=>`/`return expr` in that region.
- `func` paths must return a value on every path; `void` methods may use bare
  `return;` to stop early.
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

### Return rules (agents — avoid wrong `goto`)

| Where | Early `return` / `=>`? | Use instead |
| --- | --- | --- |
| **Parser top-level main** | No | `goto label;` → one final `=>` |
| **Site output columns** and **`config` blocks** | No | `goto` → one final `=> expr` in that block |
| **`func` / `void` bodies** | Yes | `return;`, `=> expr;`, `return expr;`; multiple exits OK |

**Do not** copy Parser-main `goto exit` into **`func`/`void`** when **`return`/`=>`**
is enough.

## Keywords and expressions

- `url`, `now`, and `config` are reserved keywords. Never use `url` as an
  identifier (variable, parameter, property, or alias); use `uri`, `pageUrl`,
  `picUrl`, or `targetUrl`. The built-in crawler expression `url` and quoted
  string/regex text are fine. Declaring `string url = ...` typically fails with
  **`invalid VarDesc`**.

```xs
// WRONG — keyword as identifier (invalid VarDesc)
string url = GetFirstGalleryImage(param);
func IsValidImageUrl(url) { ... }

// CORRECT
string picUrl = GetFirstGalleryImage(param);
func IsValidImageUrl(imageUrl) { ... }
```
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
- **`func` parameters are untyped** — do not call CLR `.Add` / `.Append` on
  parameter lists (`Func name Add not found`; `_ param.Add(x)` does not help).
  Use a **local** `var list = new clr.System.Collections.ArrayList();`,
  `_ list.Add(...)`, **`=> list`**, and reassign in the caller. Do not assume
  pass-by-reference when passing ArrayList into helpers.
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
  `<<< ... >>>` multiline free-text (see **Long text** below).
- Regex escapes in normal strings use one backslash (`"\s+"`, `"\d+"`), not
  C# doubled escapes (`"\\s+"`). Use `@"..."` or `<<< >>>` when backslashes
  must stay literal.

### Long text: `<<< >>>` and placeholder markers (required)

Use the XS-native **`<<< ... >>>`** operator for **long or multiline** text
(PowerShell bodies, SQL batches, curl templates, bat fragments, big regex).
Assign to **`StringBuilder`** (built-in type; no `new` required):

```xs
StringBuilder ps = <<<
Add-Type -AssemblyName System.Drawing;
$imgPath = '__IMG_PATH__';
$maxW = __MAX_W__;
>>> ;
_ ps.ReplStr("__IMG_PATH__", SafeForPs(path));
_ ps.ReplStr("__MAX_W__", maxWidth.ToString());
```

**When there are not many dynamic values**, keep the heredoc **static** and use
**marker tokens** in the text (`USER`, `SERVER`, `__PATH__`, `ip_to_be_replaced`),
then **`ReplStr` / `Replace` in place** on the `StringBuilder` — do not embed
many `&` interpolations inside the template.

**Rules**

- Prefer **`StringBuilder s = <<< ... >>>;`** over long `"line1" & "\r\n" & "line2"` chains.
- Replace placeholders on the builder: `_ s.ReplStr("MARKER", value);` — avoid
  `s.ToString().ReplStr(...).ReplStr(...)` intermediate strings (readme §16.7).
- Markers should be **unique** in the template (e.g. `__UPLOAD_URL__`, not `x`).
- For regex/Windows paths inside the block, `<<< >>>` avoids doubling backslashes;
  use `@"..."` only for short single-line literals.
- Generated PowerShell/batch for Windows tools: normalize to **`\r\n`** where needed.

**Anti-pattern:** one giant string with `\"` and `\n` escapes — hard to read and
easy to break; use `<<< >>>` + markers instead.

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
Use `goto label;` for early exit, retries (`Retry:`), and waits in **Parser
main** and **Site column/config** blocks only — not inside `func`/`void` when
`return`/`=>` suffices.

### Dropdown choice lists (`clr.Console.Prompt`)

Use **`clr.Ex.Console.Prompt`** (`clr.Console.Prompt` after `import Ex.Console as
Console`) for a **droplist / selection menu** in interactive Parser scripts.
Canonical example: **`Scripts/MediaConvert.xs`** (`PrepareOptions`,
`PrepareVideoSize`, `PromptVideoSize`).

**Label → value pattern**

- Build **`clr.Dictionary`** (`Dictionary\`2[System.String,System.String]`):
  **keys** = labels shown in the menu; **values** = domain codes for `if`/config.
- **`Prompt(title, options.Keys.ToArrayList())`** returns the **selected key** (label).
- **`options[selection]`** yields the **domain value** — branch on that,
  not on the label (unless key and value are the same).

```xs
var options = (clr.Dictionary)PrepareOptions();
string selection = clr.Console.Prompt("Which option do you want?",
	options.Keys.ToArrayList());
string choice = options[selection];
```

**Default / last-used:** `clr.Console.Prompt(title, options.Keys.ToArrayList(), defaultKey)`
— `defaultKey` must match one choice string (usually a dictionary **key**). Or
reorder keys manually (`BuildPromptChoices` in `MediaConvert.xs`).

Full Prompt API and extended tables: **`../xs-language/SKILL.md`** (xs-agent repo root).
Required **Long text** and **RunPowershellFromMemory** sections are duplicated in both skills.

Use the canonical patterns already present in `Scripts/*.xs` for:

- command-line arguments `[p1]`, `[p2]`, and interactive fallback;
- PowerShell execution and captured output;
- JSON template-driven serialization/deserialization;
- CSV import/export;
- SQL connections and disposal;
- console, status, progress, and table output;
- **`clr.Console.Prompt` droplist** (`Scripts/MediaConvert.xs`: dictionary keys → menu, values → logic);
- user configuration persistence.

### RunPowershellFromMemory contract (required)

User-defined helper that runs an **embedded PowerShell script** via `-EncodedCommand`.
Treat it as a **machine interface**, not a console command.

**Helper — do not add noise**

- **Never** `mark`, `Write-Host`, or print stderr/stdout from inside the helper.
- Wrap every script with `$ProgressPreference = 'SilentlyContinue'` and
  `$WarningPreference = 'SilentlyContinue'` (avoids CLIXML progress on stderr).
- Redirect stdout/stderr; **return normalized stdout only** (`=> stdoutx`).
- Strip accidental CLIXML / progress blobs from stdout (`NormalizePowershellStdout`).
- Do **not** use `shouldShowError` to dump stderr to the UI — callers parse stdout.

**Embedded PowerShell — simple, parseable stdout**

- Success: `Write-Output 'token'` or `Write-Output 'prefix|details'`
  (e.g. `resized|600x400 q85`, `skipped`, `ok|...`).
- Failure: **catch**, then `Write-Output ('error|' + $_.Exception.Message)` —
  tolerant; message must say **what failed**.
- **No** `Write-Host`, `Write-Progress`, or verbose streams for normal flow.

**XS caller**

- Parse returned string; **`mark()` at the call site** with context
  (e.g. `"PicUrl resize: " & detail`), not raw PowerShell output.

**Live vs captured**

- `clr.Ex.Powershell.Run` → interactive / live side effects.
- `RunPowershellFromMemory(command)` → captured pipeline only.

Canonical implementation: **`Scripts/frequent_user_defined_methods.xs`**
(`NormalizePowershellStdout` + `RunPowershellFromMemory`).

For `<<< >>>` templates, **keep the heredoc static**; use **placeholder markers**
and `_ tpl.ReplStr("MARKER", val)` (or `.Replace`) in place — not many `&`
interpolations inside the block. Do not build long text from chained
`.ToString().ReplStr(...)` off the literal.

Initialize JSON config from a full-shape template via
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
Read the Site-related sections in `readme.md` and the full Site reference in
`xs-language/SKILL.md` (same repo) before editing crawler scripts.

```xs
Site Example {
  config Addr = {
    @cfg = new {
      EnableTranslation: true,
      PicUrlDownloadFolder: "r:\\1688",
      ProductDescImagesFolder: "d:\\Models\\Images\\"
    };
    => "";
  }
  name = { => MatchGroup(this, "<title>(.*?)</title>", "g"); };
}
```

### `@` globals in Site mode

**File layout (Site / crawler scripts)**

- Between **`import`** and **`Site { }`**: only imports and helper `func`/`void`
  definitions — **no** top-level `var`, **no** `@name = ...`.
- **`var`** is allowed only inside **`func`**, **`void`**, Site **output column**
  blocks, and **`config ... = { }`** blocks.
- **`@name = ...`** is allowed only inside Site **output columns** or
  **`config init`**, **`config Addr`**, or other **`config`** blocks — prefer
  **`config init`** for `@cfg` plus any per-run caches or counters.

**Assignment and visibility**
- A Site-scoped `@` global is visible **only** in Site **output columns** and
  **`config` blocks** in the same `Site { }`.
- **`func` and `void` cannot see Site-scoped `@` globals** (same file or
  not). Pass config values as **function parameters** from the Site column.
- In **Parser mode**, `@` globals *are* shared across `func`/`void` in the
  same file.

### Config encapsulation

When settings are numerous (paths, flags, API URLs, tool executables), assign
one **`@cfg = new { Field: value, ... }`** in `config Addr` or `config init`.
Optional per-run **`@` caches** (e.g. memoized JSON) belong in the same
`config init` block — not at file top. Read `@cfg.<Field>` only in Site columns;
pass each needed field into helpers. Do not reference `@cfg` inside `func`/`void`.

Site output fields become CSV columns. A null output field can drop the entire
row, so return an intentional default such as `""` or `-1` unless dropping
the row is required. **Site output columns and `config` blocks follow the same
no-early-return rule as Parser main** — one final `=> expr` per block, or
`goto` then a single final `=>`; put branching helpers in `func`/`void` and
call them from the column. `config` blocks may be reevaluated by the host. In
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

- **`url` keyword:** never `string url = ...` or `func F(url)` — use `imageUrl`,
  `pageUrl`, `picUrl`, `uri`, etc. Compile error **`invalid VarDesc`** is common.
- **Untyped `func` parameters:** no CLR `.Add` on arguments; build a local
  `ArrayList`, return it, merge with reassignment — do not mutate a list
  passed into a `void` helper (reference semantics are not reliable).
- **`(Type)obj..Member` needs inner parentheses:** `(bool)response..IsSuccessStatusCode`
  casts the object, not the property. Use `(bool)(response..IsSuccessStatusCode)`.
  A `try/catch` around this can hide the bug and make translation/API checks look disabled.
- **`clr.Console.Prompt`:** pass **`options.Keys.ToArrayList()`**; return is the **key**;
  use **`options[selection]`** for the domain value (`Scripts/MediaConvert.xs`).
- `&` is concatenation; `+` is numeric addition.
- `Replace` is regex; `ReplStr` is plain text.
- `elseif` is required.
- **Parser main** and **Site output/config blocks** cannot early-return — use
  `goto` + one final `=>`. **`func`/`void` can** use `return`/`=>` freely;
  avoid unnecessary **`goto exit`** in helpers.
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
- **Long text:** use **`StringBuilder <<< >>>`** + marker **`ReplStr`/`Replace`**;
  avoid long escaped `"..."` chains (see **Long text** section above).
- **Captured PowerShell:** `RunPowershellFromMemory(command)` — no console noise;
  stdout tokens `ok|…` / `error|…`; caller **`mark()`** with context (see
  **RunPowershellFromMemory contract** above). Do not use `shouldShowError` stderr dumps.
- `await` only on direct CLR method calls returning Task/ValueTask.
- Site mode: a `null` output field drops the whole row.
- Site mode: `url` in `config` is the Excel ID, not the downloaded URL.
- Site mode: `@` globals — Site columns/`config` only; invisible in `func`/`void`; pass parameters.
- Site mode: no file-level `var`/`@` before `Site { }`; put `@cfg` and caches in `config init` / `config Addr`.
- Site mode: many configs — one `@cfg = new { ... }` object; pass fields to helpers.
- `url`, `now`, and `config` are reserved (never use `url` as an identifier;
  **`invalid VarDesc`** if you do).
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
