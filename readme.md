# XS language — rules & patterns (living spec)

> This is a consolidated cheat‑sheet of the **xs** language semantics, constraints, and standard patterns.

---

## 1) Execution regions & scope

* Variables are **region‑scoped**, not block‑scoped.

  * Regions: **top‑level (main)**, `func`, `void`, `Site` / `SiteConfig`.
* **Redeclaration is allowed** within the same region.

  * Redeclaration **does not** create a new variable.
  * If redeclaration has an initializer → behaves like an **assignment**.
  * If redeclaration has no initializer → **ignored**.
* **Where declarations are allowed**:

  * Allowed inside: `if`, `for`, `while`, `try` (and other non‑excluded blocks)
  * **NOT allowed** inside: `do`, `catch`

### Type consistency per region

* Each variable has one effective type per region.
* Weak types: `var`, `object`.

  * Weak → strong upgrade is allowed.
  * Strong → weak redeclare is ignored.
  * Strong → different strong type redeclare → **compile error** (should report both declaration locations).

### Initialization happens once

* Automatic initialization (e.g., `StringBuilder`, collections) occurs **only on the first declaration**.
* Redeclarations do **not** reinitialize.

---

## 2) Imports, CLR interop, and naming

### Imports

* Imports must be **only at the top of the file**.
* Syntax: `import Full.Namespace.OrType as Alias;`
* After import, the alias replaces the **first segment after** `clr.`

  * `import System.String as Str;` → `clr.Str.IsNullOrWhiteSpace(...)`

### CLR calls

* Any CLR call must be **fully qualified** and **prefixed with** `clr.` (or `clr.<Alias>`).
* CLR methods/properties are invoked via **subcomponent access**:

  * `clr.System.DateTime.Now` (static property)
  * `obj.Prop` / `obj.Method(...)` via subcomponents

### Extension‑style calls

* Only **self‑defined** `func` methods can be used extension‑style.

  * If `func Foo(x)` exists, you may call: `Foo(x)` or `x.Foo()`.
* CLR methods **cannot** be called extension‑style.

### Reserved keyword

* `url` is a keyword (script folder path). Do **not** use `url` as a variable name.

---

## 3) Script parameters & globals

### Positional parameters

* `[p1]`, `[p2]`, ... map to runner arguments:

  * `clr script.xs arg1, arg2, ...`

### Globals

* Global variables use a leading `@`:

  * `@scriptDir = url;`
* Globals do **not** support explicit type keywords.

---

## 4) Strings

* Normal: `"..."`

* Verbatim: `@"..."` (double quotes escaped as `""`)

* Free‑text (multiline literal):

  ```
  StringBuilder cmd =<<<
  any text
  multiple lines
  >>>;
  ```

  * Treat free‑text blocks as literal content.
  * Prefer declaring free‑text blocks as `StringBuilder`.

* String concatenation operator: `&`

---

## 5) Collections, indexing, and generics

* C# arrays are not supported; use **ArrayList**.

* Access elements with `.get_item(i)` (not `[]`).

* Dictionary access uses `[ident]` syntax.

* Generics in CLR type names use backtick notation:

  * `Dictionary\`2[System.String,System.Object]`

* `Dictionary.Keys` may not be recognized due to generics; convert:

  * `var keys = e.Keys.ToArrayList();`
  * then `keys.get_item(i)`

* ArrayList literal syntax is supported:

  * `[expr1, expr2]`

---

## 6) Control flow & restrictions

### Supported constructs

* `if / elseif / else`
* `for`, `while`, `do while`
* `try { } catch { }`
* labels + `goto`
* `break`, `continue`

### Important restrictions

* No `foreach`.
* No `using` blocks. Dispose manually via `.Dispose()`.
* No `async/await`, delegates, events.
* No `out/ref/in/params` parameter modifiers.
* No nullable types.

### `elseif` only

* Use `elseif` (single token). `else if` is not supported.

### Returns

* `func` / `void` support early return.
* **Early return is NOT allowed inside `catch`.**
* **Top‑level (main) should avoid early return** (use flow or goto patterns if needed).

---

## 7) Operators & precedence highlights

* Ternary `?:` is supported.
* Logical: `||`, `&&`
* Equality/relational: `== != < > <= >=`
* Numeric: `+ - * / %`
* Int variants: `+i -i *i \\`
* Bitwise: `|`
* String concat: `&`

### Special operators

* `..` enforces CLR property/method resolution when type is unknown.
* `->` computed property access operator.

  * Lower precedence than arithmetic/concat; parentheses may be needed.

---

## 8) Standard libraries / helpers (xs native conventions)

### Native helper methods

* `Replstr(old, new)` for string replace
* `IsEmpty(...)` for null/empty checks

### LINQ via Dlinq

* Import: `import Dlinq.Linq as Dlinq;`
* `clr.Dlinq.Select/Where/OrderBy/Any` take:

  * `IEnumerable source`
  * `string expr` (lambda as string)
* Return type is always **ArrayList**.

---

## 9) PowerShell integration patterns

* Standard runner for captured output: `RunPowershellFromMemory(command, shouldShowError)`

  * Uses `powershell.exe -EncodedCommand`.
  * Returns stdout; optionally shows stderr via `mark`.
* `clr.Ex.Powershell.Run(cmd)` may write directly to console; don’t rely on its return for captured output.

---

## 10) Canonical templates

### User config (standard trio)

* `GetUserConfigPath(fileName)`
* `LoadUserConfig(fileName, templateObj)` (template must have full structure)
* `SaveUserConfig(fileName, obj)`

### Working folder initializer

* `GetWorkingFolder([p1])`:

  * Loads `last_folder` from user config
  * Prompts to confirm/change
  * Loops until folder exists
  * Returns normalized folder path

---

## 11) Practical style guidelines (project conventions)

* Use **tabs** for indentation in xs code.
* Prefer explicit typing when possible (`int/string/bool/double/StringBuilder/object`); use `var` for complex CLR types.
* Prefer combined declarations for same type: `int i=0, n=0;`
* Convert `func` parameters (objects) to concrete locals early:

  * `string s = p.ToString();`
* Avoid throwing exceptions in xs scripts (xs does not support `throw`).
* Keep main program short; move logic into `func/void`.

---

## 12) Quick examples

### Redeclare behaves like assignment (same region)

```xs
void test() {
	int total = 1;
	if(true) {
		int total = 5;
	}
	[p] = total; // 5
}
```

### StringBuilder not reinitialized on redeclare

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
