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

---

### Operators

* String concatenation: `&`

---

## 5) xs internal helper methods (native)

These helpers are **engine-provided** (implemented in your runtime `StringLibrary` and related helpers).
They are callable directly in xs (i.e., **no `clr.` prefix**).

### 5.1 String / text helpers

Notes:

* `ReplStr` is **plain substring replace** (non-regex).
* `Replace` is **regex replace** (see 5.2).
* `IsEmpty(o)` is implemented as `IsNullOrEmptyOrWhiteSpace(o?.ToString())`.

Available helpers (per `StringLibrary`):

* `IsEmpty(x)`
* `IsNullOrEmpty(x)`
* `IsNullOrWhiteSpace(x)`
* `ReplStr(s, textToReplace, replaceBy)` (plain replace)
* `SubStr(s, index, length)` (implemented as `Substr`; supports `length = -1` meaning “to end”, clamps safely)
* `Trim(s)`
* `LTrim(s, prefix)`
* `RTrim(s, suffix)`
* `Len(s)`
* `chr(intCodePoint)`

Common xs style (instance-like usage depends on your binder; both styles are used in your scripts):

```xs
if(path.IsEmpty()) { ... }
name = name.ReplStr("[", "").ReplStr("]", "")
part = s.SubStr(0, 3)
```

### 5.2 Regex helpers (regex-optimized field support)

`StringLibrary` regex helpers share an internal signature shape:

* `(caller, fieldName, content, pattern, ...)`

Runtime behavior:

* If `fieldName` is non-empty and `caller` has a field of that name containing a `Regex`, it reuses it.
* Otherwise it builds a new `Regex(pattern, IgnoreCase | Multiline | Compiled)`.

Regex-optimized field names tracked by the engine:

* `Replace`, `IsMatch`, `Match`, `MatchAll`, `MatchMultiGroupAll`, `MatchGroupAll`, `MatchGroup`, `MatchGroupI`, `MatchCollection`

Available helpers:

* `IsMatch(content, pattern)`
* `Match(content, pattern)` → first match `.Value`
* `MatchAll(content, pattern, splitter)` → concatenates all match values
* `MatchMultiGroupAll(content, pattern, groupSplitter, splitter)` → per match, joins groups `1..N-1`
* `MatchGroupAll(content, pattern, groupName, splitter)` → extracts a named group across all matches
* `MatchGroup(content, pattern, groupName)` → extracts a named group from the first match
* `MatchGroupI(content, pattern, groupName, index)` → extracts a named group from match at `index`
* `MatchCollection(content, pattern)` → returns a CLR `MatchCollection`
* `Replace(content, pattern, replacer)` → regex replace

Example:

```xs
if(s.IsMatch(@"(?<id>\d+)") ) {
	var id = s.MatchGroup(@"(?<id>\d+)", "id");
}
```

### 5.3 Enumerable → ArrayList conversion helpers

Engine also provides commonly used helpers:

* `ToArrayList`
* `AsArray`
* `Arr`

These three are equivalent aliases.

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
var one = [p1 & ""];      // if you want string coercion
var one = [(string)p1];    // via type conversion
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
* `->` — computed property access

  * Lower precedence than arithmetic / concat

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

* `clr.Ex.Powershell.Run(cmd)` may write directly to console; do not rely on return value

---

## 12) Canonical templates

### User config (standard trio)

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

* Use **tabs** for indentation
* Prefer explicit types (`int`, `string`, `bool`, `double`, `StringBuilder`) when possible
* Use `var` for complex CLR types
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
