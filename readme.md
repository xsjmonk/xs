# XS language — rules, patterns, and constraints (living spec)

> Consolidated and **authoritative** reference for the **xs** language as implemented in your compiler/runtime.
> This document is intentionally pragmatic: it records what **works**, what is **disallowed**, and the **standard patterns** used across your codebase.

---

## 0) One-page mental model

* xs is **C#-like syntax** compiled to IL, but with a curated feature set.
* Variables are **region-scoped** (main / func / void / Site), not block-scoped.
* Most runtime access happens via **CLR interop** using the `clr.` prefix.
* The **top-level (main program)** is intentionally restricted.

---

## 1) Regions, scope, and declarations

### 1.1 Regions

A script executes in one of these regions:

* **Top-level (main program)**
* `func` (returns a value)
* `void` (returns nothing)
* `Site` / `SiteConfig` (special configuration mode)

### 1.2 Variable scope model

* Variables are **region-scoped**.
* Blocks (`{}`) do **not** create a new scope.

### 1.3 Redeclaration rules (same region)

* Multiple declarations of the same name in the same region are **allowed**.
* Redeclaration does **not** create a new variable.
* Redeclaration behavior:

  * With initializer → behaves like an **assignment**.
  * Without initializer → **ignored**.

### 1.4 Type consistency (same region)

* Each variable has **one effective type per region**.
* Weak types: `var`, `object`.

Rules:

* Weak → strong upgrade is allowed.
* Strong → weak redeclaration is ignored.
* Strong → different strong redeclaration → **compile error**, reporting **both declaration locations**.

### 1.5 Where declarations are allowed

In `func` / `void` / Site regions:

* Allowed inside: `if`, `for`, `while`, `try`
* **NOT allowed** inside: `do`, `catch`

In **top-level (main program)**:

* The main program is restricted; treat it as **statement orchestration only**.
* **Avoid** declaring variables inside control blocks in main (keep declarations at top-level), because main-mode feature support is limited compared to `func`/`void`.

### 1.6 Initialization happens once

* Automatic initialization (e.g., `StringBuilder`, some collections) happens **only on first declaration**.
* Redeclarations do **not** reinitialize.

---

## 2) Types and conversions

### 2.1 Supported explicit types

* `int`, `string`, `bool`, `double`, `StringBuilder`, `object`
* `var` for complex/unknown CLR types

### 2.2 Not supported / important notes

* `long` is **not** a supported xs type → use `var`.
* `byte` is **not** a supported xs type.
* `char` is **not** supported → use `clr.System.Char.Parse("x")`.
* Nullable types are not supported.

### 2.3 Parameter typing rule

* `func` parameters are treated as **object**.
* Convert to concrete types at the start of the function:

```xs
func f(p) {
	string s = p.ToString();
	=> s;
}
```

---

## 3) Imports and CLR interop

### 3.1 Imports

* **All imports must be at the top of the file**.
* Syntax:

```xs
import Full.Namespace.OrType as Alias;
```

* Alias replaces the **first segment after** `clr.`

Example:

```xs
import System.String as Str;
clr.Str.IsNullOrWhiteSpace(s)
```

### 3.2 CLR calls (strict)

* All C# / CLR APIs must be called with the `clr.` prefix:

```xs
clr.Path.GetExtension(p)
clr.System.Math.Ceiling(x)
```

* Exception: **xs internal helpers** (Section 4) do not require `clr.`.

### 3.3 Subcomponents and special access operators

* `.` normal member access.
* `..` **forces CLR reflection resolution** when the compiler can’t infer the .NET type.

### 3.4 CLR extension-method style (disallowed)

* Only **self-defined** `func` methods can be used extension-style.
* CLR methods **cannot** be invoked extension-style.

---

## 4) xs internal helper methods (no `clr.`)

These are **engine-provided** helpers and must be treated as native.

### 4.1 String helpers

* `Str(...)`
* `ReplStr(old, new)`
* `SubStr(start, len)`
* `IsEmpty()`

Examples:

```xs
if(path.IsEmpty()) { ... }
name = name.ReplStr("[", "").ReplStr("]", "")
part = s.SubStr(0, 3)
```

### 4.2 Regex helpers

* `IsMatch(pattern)`
* `MatchGroup(pattern, groupNameOrIndex)`
* `MatchAll(pattern)`

Examples:

```xs
if(s.IsMatch(@"(?<id>\d+)") ) {
	var id = s.MatchGroup(@"(?<id>\d+)", "id");
}
```

### 4.3 Array conversion

* `AsArr()` — converts an IEnumerable to an ArrayList.

---

## 5) Strings

### 5.1 String literals

* Normal: `"..."`
* Verbatim: `@"..."` (escape quote as `""`)
* Free-text multiline:

```xs
StringBuilder sb =<<<
any text
multiple lines
>>>;
```

Notes:

* Free-text content is treated as literal text.
* Prefer declaring free-text blocks as `StringBuilder`.

### 5.2 Concatenation

* String concatenation operator: `&`

---

## 6) Collections and indexing

### 6.1 Arrays

* C# arrays are **not supported**.
* You primarily use **ArrayList**.

### 6.2 Array-like accessor

* Use `obj[expr]` instead of `.get_item(i)`.
* The index expression is limited to **`int` or `string`**.

Examples:

```xs
var first = list[0];
var v = dict["key"]; // dictionary access
```

### 6.3 Named-regex-group access via string index

* A string index is commonly used to access regex named groups:

```xs
var g = m["groupName"]; // groupName is string
```

### 6.4 ArrayList literal initialization

* Literal syntax:

```xs
[expr1, expr2, expr3]
```

* Common usage: configuration templates

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

### 6.5 Generics in CLR type names

* Use backtick CLR names:

```xs
import System.Collections.Generic.Dictionary`2[System.String,System.Object] as Dictionary;
```

* `Dictionary.Keys` may not be recognized due to generics; convert keys to ArrayList first:

```xs
var keys = e.Keys.ToArrayList();
for(int i=0;i<keys.Count;i++) {
	var k = keys[i];
}
```

---

## 7) Control flow

### 7.1 Supported constructs

* `if / elseif / else` (must use **`elseif`**, not `else if`)
* `for`, `while`, `do while`
* `try { } catch { }`
* labels + `goto`
* `break`, `continue`

### 7.2 Important restrictions

* No `foreach`.
* No `using` blocks — call `.Dispose()` manually.
* No `async/await`, delegates, events.
* No parameter modifiers: `out`, `ref`, `in`, `params`.
* No nullable types.
* No `throw` in xs scripts.

### 7.3 try/catch limitations

* A `catch` block cannot contain another `try-catch` (nested try-catch inside catch is unsupported).
* Early return is **not allowed inside `catch`**.

---

## 8) Returns and main-program limits

### 8.1 `func`

* `func` returns a value.
* Early return and multiple return statements are supported.

### 8.2 `void`

* `void` returns nothing.
* Early `return;` is supported (but **not inside `catch`**).

### 8.3 Top-level (main program) restrictions

The main program is deliberately limited.

Practical rules:

* Keep main as orchestration.
* Avoid early return and multiple returns.
* Prefer a single exit label and a single final `=> result;`.
* Avoid declaring variables inside control blocks in main; declare at top-level and assign inside.

Canonical main pattern:

```xs
string result = "done";

if(bad) { result = "aborted"; goto done; }

// main work


done:
=> result;
```

---

## 9) The `_` discard operator

* Use `_` only when calling a method that **returns a value** and you intend to discard the result.
* Do **not** use `_` with `void` methods.

Example:

```xs
_ sb.Append("x");
clr.System.IO.Directory.CreateDirectory(p); // void → no `_`
```

---

## 10) `url` keyword (script folder)

* `url` evaluates to the folder path of the currently executing script.
* Do not use `url` as a variable name.
* `url` cannot be used directly inside `func` blocks; capture it at top-level or into a global first:

```xs
@scriptDir = url;

func GetDir() {
	=> (string)@scriptDir;
}
```

---

## 11) PowerShell integration patterns

### 11.1 Capturing output

* Use `RunPowershellFromMemory(command, shouldShowError)` to get stdout.
* `clr.Ex.Powershell.Run(cmd)` may write directly to console; do not rely on its return value for captured output.

### 11.2 CRLF output

* Prefer `\r\n` in console/text output for Windows alignment.

---

## 12) Canonical templates

### 12.1 User config trio (standard)

* `GetUserConfigPath(fileName)` creates `%UserProfile%\\xs_config` if needed.
* `LoadUserConfig(fileName, templateObj)` requires a **full-structure template**.
* `SaveUserConfig(fileName, obj)` serializes and writes.

### 12.2 Working folder initializer

* `GetWorkingFolder([p1])` loads `last_folder` from user config, prompts, loops until exists, returns normalized path.

---

## 13) Practical style conventions

* Use **tabs** for indentation.
* Prefer explicit types for primitives (`int/string/bool/double/StringBuilder/object`).
* Use `var` for complex CLR types.
* Prefer combined declarations for same type:

```xs
int i=0, n=0;
string a="", b="";
```

* Avoid `goto` unless it actually changes control flow (no ceremonial `goto exit` / `exit:` pairs).
* Dispose resources explicitly (`Close()` then `Dispose()` if required by your library conventions).

---

## 14) Common pitfalls checklist

* ✅ All CLR APIs must start with `clr.` (unless internal helpers).
* ✅ No `long`, no `byte`, no `new byte[n]`.
* ✅ Use `obj[expr]` accessor (expr is int/string).
* ✅ No `else if` → use `elseif`.
* ✅ No nested try-catch inside `catch`.
* ✅ No early return inside `catch`.
* ✅ Keep main simple; avoid main-only unsupported features.
