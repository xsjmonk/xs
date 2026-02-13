<!-- revised_at: 2026-02-06 16:34:50 +0100 (Europe/Oslo) -->
# XS language — rules & patterns (living spec)

> **Authoritative, consolidated specification** of the xs language.
> This document merges all confirmed rules, limitations, internal helpers,
> and patterns that have been introduced, corrected, or persisted over time.
> When conflicts exist, **this document wins**.

---


## 1) Execution regions & scope

### Region‑scoped variables

* Variables are **region‑scoped**, not block‑scoped.
* A *region* is one of:

  * **Top‑level (main program)**
  * `func`
  * `void`
  * `Site` / `SiteConfig`

Block constructs (`if`, `for`, `while`, etc.) **do not introduce new scope**.

---

### Redeclaration rules

* Redeclaration of a variable **in the same region is allowed**.
* Redeclaration:

  * **Does not create** a new variable
  * With initializer → behaves like an **assignment**
  * Without initializer → **ignored**

Example:

```xs
int a = 1;
if(true) {
	int a = 2;   // assignment, not a new variable
}
// a == 2
```

---

### Where declarations are allowed

* Allowed inside:

  * `if`
  * `for`
  * `while`
  * `try`

* **NOT allowed** inside:

  * `do`
  * `catch`

Declaring inside forbidden blocks is a **compile‑time error**.

---

### Type consistency per region

Each variable has **one effective type per region**.

* Weak types: `var`, `object`

Rules:

* Weak → strong upgrade is **allowed**
* Strong → weak redeclare is **ignored**
* Strong → different strong redeclare → **compile‑time error**

  * Compiler must report **both declaration locations**

---

### Initialization happens once

* Automatic initialization (e.g. `StringBuilder`, collections) occurs **only on the first declaration**
* Redeclarations **never reinitialize** the variable

Example:

```xs
StringBuilder sb;
_ sb.Append("a");
if(true) {
	StringBuilder sb;
	_ sb.Append("b");
}
// sb == "ab"
```

---

## 2) Imports, CLR interop & naming

### Imports

* Imports must appear **only at the top of the file**
* Syntax:

```xs
import Full.Namespace.OrType as Alias;
```

* The alias replaces the **first segment after `clr.`**
* **Aliases still require the `clr.` prefix** when referenced (`clr.Alias...`, not `Alias...`)

Example:

```xs
import System.String as Str;
clr.Str.IsNullOrWhiteSpace(s);
```

---

### CLR calls (strict rule)

* **Every CLR call must be prefixed with `clr.`**
* Applies to:

  * static methods
  * instance methods
  * properties

Examples:

```xs
clr.System.Math.Ceiling(x);
clr.Path.GetExtension(p);
```

---

### Extension‑style calls

* Only **self‑defined `func` methods** may be called extension‑style
* CLR methods **cannot** be called extension‑style

Allowed:

```xs
func Foo(x) { ... }
x.Foo();
```

Not allowed:

```xs
s.ToLower();  // CLR method → invalid
```

---

### Reserved keywords

* `url` is a **keyword** (folder of the current script)
* Do **not** use `url` as a variable name

---

## 3) Script parameters & globals

### Positional parameters

* `[p1]`, `[p2]`, … map to runner arguments

```text
clr script.xs arg1 arg2 ...
```

---

### Globals

* Global variables start with `@`
* Example:

```xs
@scriptDir = url;
```

Rules:

* Globals **do not support explicit type keywords**
* Globals are visible everywhere

---

## 4) Strings

### String forms

* Normal: `"text"`
* Verbatim: `@"text"`
* Free‑text (multiline literal):

```xs
StringBuilder cmd =<<<
any text
multiple lines
>>>;
```

Rules:

* Content is literal
* Prefer declaring free‑text blocks as `StringBuilder`
* **Single-quote characters (`'`) are not supported inside xs string literals.**
  * Workaround: compose via `chr(39)` + `&` (string concat), e.g. `"can" & chr(39) & "t"`.

---

### Operators

* String concatenation: `&`

---

### Quoting & escaping rules (practical)

When embedding quotes inside an xs string literal, escape them using backslash sequences:

```xs
string a = "a\"b";              // a"b
string git = " --format=\"%(refname:short)\"";
```

For complex scripts or commands with heavy quoting, prefer free‑text `StringBuilder <<< >>>` and do placeholder replace.

---


## 6) Collections, indexing & literals

### Primary collection type

* C# arrays are **not supported**
* Use **ArrayList**

---

### Array‑like accessor

* Use **`[expr]`**, not `.get_item`
* `expr` is limited to:

  * `int`
  * `string`

Examples:

```xs
items[0];
dict["key"];
```

#### Regex named‑group access

```xs
m["groupName"];
```

---

### Bracket ambiguity: Dictionary access vs ArrayList literal

XS uses the same bracket syntax for two different meanings. The parser resolves the ambiguity using a fixed lookahead rule.

#### Dictionary access (engine/internal dictionary)

**Form (token shape):**

* `[` **ident** `]`

**Parser rule (authoritative):** the grammar checks the following before deciding how to parse a bracketed expression:

```csharp
bool IsDictionaryAccess()
{
	return la.kind == _lbrack
		&& Peek(1).kind == _ident
		&& Peek(2).kind == _rbrack;
}
```

**Semantics:**

* If the token sequence is exactly `[` ident `]`, it is parsed as **DictionaryAccess("ident")**.
* This is how positional parameters work: `[p1]`, `[p2]`, … are dictionary lookups for keys `"p1"`, `"p2"`, …

Examples:

```xs
string folder = [p1].ToString();
var user = [p2];
```

#### ArrayList literal (collection literal)

**Form:**

* `[` `Expr` { `,` `Expr` } `]`

**Semantics:**

* Produces a CLR `System.Collections.ArrayList`.

Examples:

```xs
var a = ["1", "2"];
var b = [BuildProxyTpl()];
var c = [1, 2, 3];
```

#### Critical disambiguation rule

Because `[` **ident** `]` is reserved for dictionary access, the following is **not** an ArrayList literal:

```xs
[p1];
```

It is always parsed as a dictionary lookup: **DictionaryAccess("p1")**.

---

### One‑element ArrayList whose element comes from a variable

To construct an ArrayList with a single element that is the value of a variable (e.g. `p1`), you must break the exact token pattern `[` ident `]`.

Recommended patterns:

1. Parenthesize the expression:

```xs
var one = [(p1)];
```

2. Use any expression involving the variable:

```xs
var one = [p1 & ""];       // if you want string coercion
var one = [(string)p1];     // via type conversion
```

These forms cannot match `IsDictionaryAccess()` and therefore are parsed as an **ArrayList literal** with one element.

---

### Array‑like initialization (literal)

Supported syntax:

```xs
[expr1, expr2]
```

Common use (config templates):

```xs
func BuildConfigTpl() {
	=> new {
		logLevel: "",
		proxies: [BuildProxyTpl()]
	};
}

func BuildProxyTpl() {
	=> new {
		appNames: ["app"],
		socks5ProxyEndpoint: "",
		supportedProtocols: ["tcp"],
		ipRanges: ["192.168.0.1"]
	};
}
```

---

## 7) Control flow & restrictions

### Supported constructs

* `if / elseif / else`
* `for`, `while`, `do while`
* `try { } catch { }`
* labels + `goto`
* `break`, `continue`

---

### Hard restrictions

* No `foreach`
* No `using`
* No `async / await`
* No delegates or events
* No `out / ref / in / params`
* No nullable types
* No `throw`

---

### `elseif` only

* Must use `elseif`
* `else if` is **not supported**

---

## 8) Returns & main‑program limits

### func / void

* Early `return` **is allowed**
* Early return is **NOT allowed inside `catch`**

**Rule of thumb:** do not `=>` / `return` from inside `catch`; capture a flag/result, and return after the try/catch.

---

### Top‑level (main program)

The main program is **restricted**:

* Avoid early return
* Prefer:

  * straight‑line logic + final `=> result;`
  * or branching with `goto done` → single `=>`

Canonical pattern:

```xs
string result = "ok";

if(error) {
	result = "fail";
	goto done;
}

// main logic

done:
=> result;
```

---

## 9) Operators & precedence highlights

* Ternary `?:`
* Logical: `||`, `&&`
* Equality / relational: `== != < > <= >=`
* Numeric: `+ - * / %`
* Int variants: `+i -i *i \\`
* Bitwise: `|`
* String concat: `&`

### Special operators

* `..` — force CLR property/method resolution when type is unknown
* `->` — computed property access (anonymous/dynamic property access)
  * Left side is an **object**
  * Right side is an **expression** (commonly a computed string property name)
  * **Lowest precedence operator** — use parentheses when mixing with `&`, `+`, etc.
    * Example: `"Name: " & (obj -> propName)`

---

## 10) LINQ via Dlinq

* Import:

```xs
import Dlinq.Linq as Dlinq;
```

* Methods:

  * `clr.Dlinq.Select`
  * `clr.Dlinq.Where`
  * `clr.Dlinq.OrderBy`
  * `clr.Dlinq.Any`

Rules:

* First argument: `IEnumerable`
* Second argument: `string` lambda expression
* Return type: **ArrayList**

---

## 11) PowerShell integration patterns

* Preferred runner (captured output):

```xs
RunPowershellFromMemory(command, shouldShowError)
```

* Uses `powershell.exe -EncodedCommand`
* Returns stdout
* stderr optionally shown via `mark`

Important:

* `clr.Ex.Powershell.Run(cmd)` returns a result object (normal+error output) but may also write directly to console; do not rely on it for captured stdout.
* When building multi-line PowerShell bodies, prefer `StringBuilder <<< >>>` + placeholder replace.

---

## 12) Canonical templates

### User config (standard trio)

Additional rule:
* When holding loaded config in a `var`, **initialize it from `CreateConfigTpl(...)`** (two parameters) so the shape is known before calling `LoadUserConfig(...)`.
* Do not use `var cfg = null` as a placeholder.


* `GetUserConfigPath(fileName)`
* `LoadUserConfig(fileName, templateObj)` — template must have full structure
* `SaveUserConfig(fileName, obj)`

---

### Working folder initializer

* `GetWorkingFolder([p1])`

  * Loads `last_folder` from user config
  * Prompts to confirm/change
  * Loops until folder exists
  * Returns normalized folder path

---

## 13) Practical style guidelines

* **Anonymous objects are immutable.** To "set" a property, create a new object and reassign:

```xs
cfg = new { gcloud_application_auth_time: now.ToString(), last_claude_working_folder: workingFolder };
```

* Use **tabs** for indentation
* Prefer explicit types (`int`, `string`, `bool`, `double`, `StringBuilder`) when possible
* Use `var` for complex CLR types
* **`var` must be initialized to a known object shape.** Never write `var cfg = null`.
  * Rationale: `var` inference needs a concrete initializer so the compiler can lock object structure.
  * For config objects, always initialize using `CreateConfigTpl(...)` (two parameters) rather than `null`.

* Combine same‑type declarations:

```xs
int i=0, n=0;
```

* Convert `func` parameters to concrete locals early
* Keep main program short; move logic into `func` / `void`
* Avoid exceptions (`throw` not supported)

---

## 14) Quick correctness examples

### Redeclare behaves like assignment

```xs
void test() {
	int total = 1;
	if(true) {
		int total = 5;
	}
	[p] = total; // 5
}
```

### StringBuilder not reinitialized

```xs
void test() {
	StringBuilder sb;
	_ sb.Append("a");
	if(true) {
		StringBuilder sb;
		_ sb.Append("b");
	}
	[p] = sb.ToString(); // "ab"
}
```

---

## 15) Automation lessons (generic)

### Defensive automation principles

* **Do not change user state implicitly**.
  Scripts should not alter the caller’s working context (current branch, working directory, selection state) unless explicitly requested.

* **Prefer explicit policy over inference**.
  When a condition cannot be determined reliably (e.g., missing metadata, absent upstream, partial state), apply a clear, documented rule instead of guessing.

* **Fail-safe defaults**.
  When parsing or external commands behave unexpectedly, default to *not performing destructive actions*.

* **Avoid hidden control flow**.
  Do not return from inside `catch`. Capture results and decide after structured error handling.

* **Use stable primitives for text processing**.
  When language overload resolution is limited, prefer well-defined primitives (e.g., regex-based splitting) over ambiguous helpers.

---

## 16) Common methods (frequent reusable helpers)

This section is a **living index** of generic helpers and patterns that recur across scripts.
Items here should remain **technology-agnostic** and broadly reusable.

### 16.1 Console / logging

* `mark(color, content)`
  * Single responsibility: render formatted output.
  * Always normalize line endings (`
`).
  * Do not embed logic in presentation helpers.

### 16.2 Path helpers

* `NormalizeFolder(path)`
  * Ensures a consistent trailing directory separator.
  * Never mutates global state.

* `CurrentPath(relativePath)`
  * Resolves paths relative to a known base (e.g., script folder).

### 16.3 PowerShell execution (native vs user-defined)

**Important distinction:** only methods under `clr.Ex.*` are **native internal methods**.
Anything else is **user-defined**, even if commonly used.

#### Native PowerShell runner

* `object clr.Ex.Powershell.Run(object cmd, object engines = null)`

  * Returns a **result object** containing **normal output** and **error output**.

  * Executes PowerShell and **redirects output directly to the current CLR console**.
  * Intended for *side-effect* commands (logging, progress, provisioning).
  * If `engines` contains `"pwsh"` or `"pwsh.exe"`, PowerShell 7 is used.
    Otherwise, it falls back to **Windows PowerShell (`powershell.exe`)**.
  * Return value should **not** be relied on for captured stdout.

#### User-defined PowerShell runner (pattern)

* `string RunPowershellFromMemory(command, shouldShowError)`

  * **Not a native method** — defined by the user in xs.
  * Executes PowerShell via `-EncodedCommand`.
  * **Does not redirect output to the CLR console**.
  * Captures **stdout as string**, suitable for parsing and further xs processing.
  * Best used when PowerShell is treated as a *function* returning a value.

Guideline:

* Use `clr.Ex.Powershell.Run(...)` for commands whose output is meant for the console.
* Use a user-defined `RunPowershellFromMemory(...)` when stdout must be consumed programmatically.

### 16.4 Text processing
 Text processing

* Prefer **regex-based splitting** when multiple delimiters are possible.
* Normalize input before parsing (trim, remove empty lines).

### 16.5 Safe parsing pattern

* Never return from inside `catch`.
* Pattern:

```xs
bool ok = false;
int value = 0;

try {
    value = Parse(x);
    ok = true;
}
catch {
    ok = false;
}

if(!ok) {
    // fallback or skip
}
```

This section should evolve over time as stable patterns emerge.


### 16.6 PowerShell CRLF alignment (Windows-safe output)

When generating or emitting PowerShell scripts or text intended for Windows tools:

* **Always use CRLF (`\r\n`)**, not LF (`\n`) alone.
* Do not rely on implicit newline behavior of helpers or the host.
* Normalize explicitly when building output strings.

Recommended patterns:

```xs
// Explicit CRLF in literals
string s = "line1\r\nline2\r\n";

// When composing dynamically
StringBuilder sb;
_ sb.Append("line1").Append("\r\n");
_ sb.Append("line2").Append("\r\n");
```

Rationale:

* Some Windows tools (PowerShell, cmd.exe, legacy parsers) mis-align or concatenate output when only LF is used.
* Explicit CRLF avoids invisible formatting bugs and makes output copy‑paste safe.


### 16.7 StringBuilder mutation pattern (avoid intermediate strings)

When using `StringBuilder` as a template holder, **prefer mutating it in-place**
instead of calling `.ToString()` and creating new strings.

Anti-pattern (creates intermediate strings):

```xs
string ps = tpl.ToString()
	.Replstr("__P__", pathPS)
	.Replstr("__A__", argsPS);

_ clr.Ex.Powershell.Run(ps, []);
```

Preferred pattern (in-place mutation):

```xs
_ tpl.Replace("__P__", pathPS);
_ tpl.Replace("__A__", argsPS);

_ clr.Ex.Powershell.Run(tpl, []);
```

Rationale:

* Avoids unnecessary string allocations
* Preserves `StringBuilder` semantics
* Clearer intent: template → mutate → consume
* Especially important for large multi-line templates

# XS extension methods
  ├─ Clipboard
  ├─ Json
  ├─ Sql
  ├─ Csv
  ├─ Http
  ├─ StatusConsole
  └─ TableConsole

This section documents **engine-provided internal methods** exposed to xs scripts.
They behave like a **standard library** and are callable via `clr.Ex.*` unless otherwise noted.

This is a **living API reference**:
- Signatures are intentionally concise
- Semantics are stable unless explicitly changed
- This section should be extended over time as new internals are added

---

## Clipboard

**Namespace:** `Ex.Clipboard`

* `bool Copy(object text)`
  * Copies text to system clipboard.
  * Always returns `true` on successful invocation.

* `string Paste()`
  * Returns clipboard text.
  * Returns empty string if clipboard is empty or whitespace.

---

## Json

**Namespace:** `Ex.Json`

* `object DeepCopy(object value)`
  * Performs a deep clone via JSON round‑trip.
  * Preserves anonymous-object shape.

* `object Serialize(object template)`
  * Serializes an object to JSON string.

* `object Deserialize(object json, object template)`
  * Deserializes JSON into the **shape defined by template**.
  * Template **must be a full structural template** (anonymous object / array shape).
  * Date parsing is disabled (`DateParseHandling.None`).

Notes:
- Supports anonymous objects, scalars, arrays, and `IEnumerable<T>`
- Array templates preserve array vs list shape

---

## Sql

**Namespace:** `Ex.Sql`

* `SqlDataReader ExecuteReader(object sqlCommand)`
  * Executes a `SqlCommand` and returns an open reader.

* `void ExecuteNonQuery(object sqlCommand)`
  * Executes a `SqlCommand` without returning results.

* `void SqlCommandStoredProcedure(object sqlCommand, object parameters)`
  * Configures command as stored procedure.
  * `parameters` is a dictionary `{ name → value }`
  * Parameter names auto‑prefix with `@` if missing.

---

## Csv

**Namespace:** `Ex.Csv`

* `ArrayList Read(object file, object template)`
  * Reads tab‑delimited file into anonymous objects defined by template.

* `ArrayList ReadWithDelimiter(object file, object delimiter, object template)`
  * Same as `Read`, with custom delimiter.

* `bool Write(object file, object records)`
  * Writes records to file (tab‑delimited).
  * Appends without header if file exists.

* `bool WriteWithDelimiter(object file, object delimiter, object records)`
  * Same as `Write`, with custom delimiter.

Notes:
- Template drives column mapping by property name
- Header row required for read

---

## Http

**Namespace:** `Ex.Http`

* `HttpResponse Send(object method, object url, object headers = null)`
  * Sends request without body.

* `HttpResponse Send(object method, object url, object body, object headers = null)`
  * Sends request with string body.

* `HttpResponse SendByFile(object method, object url, object filePath, object headers = null)`
  * Reads body from file and sends request.

Notes:
- Behavior mirrors PowerShell `Invoke-WebRequest`
- Automatic gzip/deflate
- Content-Length is managed internally
- UTF‑8 JSON content type normalized to `application/json; charset=utf-8`

---

## StatusConsole

**Namespace:** `Ex.StatusConsole`

* `void Start(string status)`
  * Starts background status spinner.

* `void Start(string status, object autoUpdate)`
  * Starts spinner with optional auto refresh.

* `void Status(string text)`
  * Updates status text (auto‑clamped to console width).

* `void Stop()`
  * Stops the status spinner.

Notes:
- Safe for frequent updates
- Markup-aware and width-safe

---

## TableConsole

**Namespace:** `Ex.TableConsole`

* `void Start(object columns)`
  * Starts live table with initial columns.

* `void AddColumn(string column)`
* `void AddColumns(object columns)`
* `void AddRow(object row)`
* `void UpdateCell(object row, object column, object value)`
* `int Count()`
* `void Refresh()`
* `void Stop()`

Notes:
- Backed by Spectre.Console live tables
- Thread-safe refresh model
- Designed for incremental updates


### 16.8 User-defined common helpers (xs-level)

The following helpers are **user-defined xs methods**, not engine-provided.
They are widely reused and documented here as **recommended patterns**, not runtime APIs.

#### mark(color, content)

```xs
void mark(color, content)
```

* Thin presentation helper around `clr.Ex.Console.Markup`.
* Sanitizes markup tokens (`[`, `]`, `[/]`) from content defensively.
* Always appends `\r\n` to ensure Windows console alignment.
* Intended for **human-facing output only** (logging, status, errors).

#### RunPowershellFromMemory(command, shouldShowError)

```xs
func RunPowershellFromMemory(command, shouldShowError)
```

* **User-defined**, not native.
* Executes PowerShell via `powershell.exe -EncodedCommand`.
* Captures **stdout** as a string and returns it.
* Does **not** redirect PowerShell output to the CLR console.
* Suitable when PowerShell is used as a *function* whose output must be parsed.
* Optional error display via `mark(...)` when `shouldShowError == true`.

Guideline:

* Prefer `clr.Ex.Powershell.Run(...)` for side-effect commands and live console output.
* Prefer `RunPowershellFromMemory(...)` when stdout is part of program logic.

---

---

# Engine-provided native helpers
  ├─ String / text helpers
  ├─ Regex helpers
  ├─ Enumerable helpers
  └─ Dlinq (dynamic LINQ) helpers

This section documents **engine-provided native helpers** implemented inside the xs runtime.
They are **not user-defined** and are versioned together with the engine.

Characteristics:

* Callable **directly in xs** (no `clr.` prefix)
* Participate in **extension-style syntax sugar**
  * `IsMatch("sss","[s]+")`
  * `"sss".IsMatch("[s]+")`
* Compiler rewrites extension-style calls to canonical internal form

---

## String / text helpers

Implemented in `StringLibrary`.

Notes:

* `ReplStr` → plain substring replace (non-regex)
* `Replace` → regex replace
* `IsEmpty(x)` → `IsNullOrWhiteSpace(x?.ToString())`

### API

* `bool IsEmpty(x)`
* `bool IsNullOrEmpty(x)`
* `bool IsNullOrWhiteSpace(x)`
* `string ReplStr(s, textToReplace, replaceBy)`
* `string SubStr(s, index, length)` — `length = -1` → to end
* `string Trim(s)`
* `string LTrim(s, prefix)`
* `string RTrim(s, suffix)`
* `int Len(s)`
* `string chr(intCodePoint)`

### Examples

```xs
if(path.IsEmpty()) { ... }
name = name.ReplStr("[", "").ReplStr("]", "")
part = s.SubStr(0, 3)
```

---

## Regex helpers (optimized field reuse)

Internal signature shape:

```
(caller, fieldName, content, pattern, ...)
```

Runtime behavior:

* Reuses cached `Regex` fields when available
* Otherwise creates `Regex(pattern, IgnoreCase | Multiline | Compiled)`

### Optimized fields

* `Replace`
* `IsMatch`
* `Match`
* `MatchAll`
* `MatchMultiGroupAll`
* `MatchGroupAll`
* `MatchGroup`
* `MatchGroupI`
* `MatchCollection`

### API

* `bool IsMatch(content, pattern)`
* `string Match(content, pattern)`
* `string MatchAll(content, pattern, splitter)`
* `string MatchMultiGroupAll(content, pattern, groupSplitter, splitter)`
* `string MatchGroupAll(content, pattern, groupName, splitter)`
* `string MatchGroup(content, pattern, groupName)`
* `string MatchGroupI(content, pattern, groupName, index)`
* `MatchCollection MatchCollection(content, pattern)`
* `string Replace(content, pattern, replacer)`

### Example

```xs
if("sss".IsMatch(@"[s]+")) {
	var id = "123".MatchGroup(@"(?<id>\d+)", "id");
}
```

---

## Enumerable helpers

Normalize enumerable results to `ArrayList`.

### API

* `ToArrayList(x)`
* `AsArray(x)`
* `Arr(x)`

Notes:

* All three are equivalent aliases
* Always return `System.Collections.ArrayList`


---

## Dlinq (dynamic LINQ) helpers

These helpers are **engine-provided** and exposed under `clr.Dlinq.Linq`.
They implement a **safe, xs-friendly subset of LINQ** using string-based predicates
and projections.

Characteristics:

* Always return `ArrayList` unless otherwise noted
* Accept `string` predicates / selectors
* Preserve anonymous-object shapes via engine reconstruction
* Participate in xs **extension-style sugar** (grammar-level)

### API (one-line)

* `ArrayList clr.Dlinq.Where(object source, string predicate)`
* `ArrayList clr.Dlinq.Select(object source, string selector)`
* `ArrayList clr.Dlinq.OrderBy(object source, string predicate)`
* `ArrayList clr.Dlinq.Take(object source, int count)`
* `ArrayList clr.Dlinq.TakeWhile(object source, string predicate)`
* `int clr.Dlinq.Count(object source, string predicate)`
* `bool clr.Dlinq.Any(object source, string predicate)`
* `ArrayList clr.Dlinq.Reverse(object source)`
* `object clr.Dlinq.Max(object source, string projection)`
* `object clr.Dlinq.Min(object source, string projection)`
* `double clr.Dlinq.Average(object source, string predicate)`
* `object clr.Dlinq.Sum(object source, string projection)`
* `object clr.Dlinq.Distinct(object source)`
* `object clr.Dlinq.FirstOrDefault(object source, string predicate)`
* `object clr.Dlinq.LastOrDefault(object source, string predicate)`

Notes:

* `Max/Min/Sum` may return an anonymous-object-shaped value; the runtime normalizes anonymous types so xs can consume them.
* Sequence-returning methods always return `ArrayList`.

### Example

```xs
import Dlinq.Linq as Dlinq;

var top = clr.Dlinq.Take(
	clr.Dlinq.OrderBy(items, "it.Score desc"),
	10
);

if(clr.Dlinq.Any(items, "it.Status == "Ready"")) {
	mark("5FD7AF", "Ready items exist");
}
```
