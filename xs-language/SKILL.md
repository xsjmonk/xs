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

## Local authoritative sources

| Source | Use |
| --- | --- |
| `Interpreter.ATG` | Token and grammar reference |
| `readme.md` | Living language specification; wins over other documentation |
| `readme_new.md` | Additional language guide and patterns |
| `ConsoleExtension.md` | Console, progress, and status APIs |
| `Scripts/*.xs` | Known-working scripts and idioms |

When sources disagree, prefer working scripts and the behavior documented in
`readme.md`; use `Interpreter.ATG` to resolve grammar-level uncertainty.
Search the local scripts for a working example before inventing syntax.

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
  `goto`. Prefer a success flag and decide after the `try/catch`.
- Statements are separated by semicolons; newlines do not provide separation.
- Opening braces stay on the same line as the declaration or control statement.

## Keywords and expressions

- `url`, `now`, and `config` are reserved keywords. Never use `url` as an
  identifier; use `uri`, `pageUrl`, or `targetUrl`.
- String concatenation is `&`, not `+`.
- `Replace` is regex replacement; use `ReplStr` for plain text replacement.
- Use `IsEmpty()`/`IsNullOrWhiteSpace()` rather than string comparisons when
  checking empty input.
- Compound assignments such as `+=` are not supported; expand them.
- `[ident]` is dictionary/argument access. Use `[(ident)]` or another
  disambiguated form for a one-element array.
- Array literals are `[...]` and are ArrayList-like; C# arrays are not XS data.
- Index expressions are limited to integer or string forms.
- Anonymous objects are immutable; create and assign a new object to change
  their shape.

## Variables and types

- Declare variables at first use.
- Prefer explicit `string`, `int`, `long`, `double`, and `bool` types when
  known; use `var` for complex CLR values.
- Never initialize `var` from `null`; use a concrete template or value.
- Redeclaration behaves like assignment and does not reinitialize a variable.
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
Direct CLR types and methods use `clr.<namespace>.<type>`. Use `new clr...`
for constructors and cast when the runtime type is not known.

There are three API tiers:

1. Engine-native helpers are called by bare name, such as `Match`, `MatchGroup`,
   `MatchTags`, `ReplStr`, `Trim`, `IsEmpty`, `Trace`, and `Ceiling`.
2. Engine extensions are called through `clr`, such as `clr.Dlinq.Linq.*`.
3. External extension assemblies, when loaded by the host, are also called
   through their `clr` namespace.

Do not invent aliases or call CLR methods as engine-native helpers. Confirm
signatures in `ConsoleExtension.md`, `readme.md`, or working scripts.

When a CLR object implements disposal, call `Dispose()` immediately after its
final use. XS has no `using` statement.

## Script structure and safe patterns

Keep scripts modular: imports, arguments/configuration, short main flow,
then focused helper functions. Each helper should have one responsibility and
explicit inputs/outputs. Avoid hidden state except deliberate `@` globals.

Use the canonical patterns already present in `Scripts/*.xs` for:

- command-line arguments `[p1]`, `[p2]`, and interactive fallback;
- PowerShell execution and captured output;
- JSON template-driven serialization/deserialization;
- CSV import/export;
- SQL connections and disposal;
- console, status, progress, and table output;
- user configuration persistence.

Never hard-code credentials, tokens, private keys, or other secrets. Sanitize
and validate user input before embedding it in PowerShell, shell, SQL, or URLs.
Do not leave empty catches, unbounded polling loops, or swallowed failures.
Normalize generated Windows command text to `\r\n` where the target tool
requires Windows line endings.

## Site mode

Site mode is distinct from Interpreter mode. Identify the mode before editing.
Read the Site examples and Site-related sections in `readme.md` first.

```xs
Site Example {
    config Addr = "https://example.test/" & url;
    name = { => MatchGroup(this, "<title>(.*?)</title>", "g"); };
}
```

Site output fields become CSV columns. A null output field can drop the entire
row, so return an intentional default such as `""` or `-1` unless dropping
the row is required. `config` blocks may be reevaluated by the host.

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
3. Check `readme.md`, `readme_new.md`, and `Interpreter.ATG` as needed.
4. Run the smallest available XS parser/interpreter or host test.
5. Read compiler/runtime output and correct the actual syntax/API issue.
6. Repeat until the relevant behavior is demonstrated.

When the repository does not contain the required runtime or test harness,
report that limitation explicitly. Do not substitute a different language
compiler or claim that static inspection proves runtime correctness.

## Common pitfalls

- `&` is concatenation; `+` is numeric addition.
- `Replace` is regex; `ReplStr` is plain text.
- `elseif` is required.
- Main flow cannot early-return.
- `catch {}` is invalid.
- `goto` is not valid inside `catch`.
- `var x = null` is invalid.
- `[ident]` is dictionary access, not a one-element list.
- `url`, `now`, and `config` are reserved.
- C# syntax, CLR assumptions, and unverified extension APIs are not evidence.

## Completion standard

A task is complete only when the changed XS code follows the local grammar and
working-script conventions, the relevant runtime or test path was executed
when available, and any unavailable runtime/API validation is clearly
reported. Keep this skill as the single canonical XS guidance in this repo.
