# XS language guide

> Revised: 2026-03-31
>
> This file is a practical, self-contained guide to XS.
> It is written for a future reader who starts with zero XS knowledge.
> The goal is simple:
>
> - understand what XS is
> - read existing XS scripts confidently
> - write new XS scripts fluently
> - avoid the common compile-time and runtime traps
>
> If older notes or examples disagree with this guide, prefer this guide.

---

## 1. What XS is

XS is a small scripting language hosted on top of .NET / CLR.

Think of it as:

- a compact automation language
- with direct CLR interop
- plus a few engine-provided helpers
- plus special support for anonymous objects, ArrayList-style data, console UI, JSON, CSV, SQL, HTTP, and dynamic LINQ

XS is **not** C#.
It looks C#-like in many places, but it has its own grammar, its own scope rules, and some important restrictions.

The safest mental model is:

1. XS is a script language first.
2. CLR objects and methods are used heavily.
3. Anonymous-object shape matters a lot.
4. The engine provides several built-in helpers that feel like a small standard library.

---

## 2. How to think about an XS script

An XS script is usually one of these:

1. A top-level script that runs statements and ends with a final result.
2. A set of helper `func` / `void` methods plus a top-level entry flow.
3. A `Site`-style DSL block used by a specific engine feature.

Most real scripts are plain top-level automation scripts.

Typical top-level shape:

```xs
import Ex.Console as Console

string name = [p1];
if(name.IsEmpty()) {
	name = clr.Console.Ask("What is your name?\r\n");
}

mark("5FD7AF", "Hello " & name);
=> "Done";
```

The final expression is often returned with `=>`.

---

## 3. The fastest mental model

When writing XS, remember these rules first:

1. Use `clr.` for CLR types, properties, and methods.
2. Use `import X as Y` only at the top of the file.
3. Use `&` for string concatenation.
4. Use `new { ... }` for anonymous objects.
5. Use `[p1]`, `[p2]`, ... for script arguments.
6. Use `@name` for globals.
7. Use `elseif`, not `else if`.
8. Do not write `var x = null;`.
9. Variables are region-scoped, not block-scoped.
10. If you want JSON or config data, define a full template object first.

If you internalize only those ten rules, you will already avoid many XS mistakes.

---

## 4. Program regions and scope

XS variables are **region-scoped**, not block-scoped.

A region is one of:

- top-level main program
- `func`
- `void`
- `Site` / `SiteConfig`

Blocks like `if`, `for`, `while`, `try` do **not** create a new scope.

Example:

```xs
int a = 1;
if(true) {
	int a = 2;
}
// a == 2
```

That inner `int a = 2;` is not a new variable.
It behaves like assignment to the same regional variable.

### Redeclaration rules

Redeclaration inside the same region is allowed, but:

- declaration with initializer acts like assignment
- declaration without initializer is ignored
- strong type to different strong type is a compile error
- weak type to strong type upgrade is allowed

### Weak vs strong types

Weak types:

- `var`
- `object`

Strong types:

- `int`
- `long`
- `double`
- `bool`
- `string`
- `StringBuilder`
- and other concrete CLR-resolved types

### Important pitfall

Never do this:

```xs
var x = null;
```

`var` needs a concrete initializer so the compiler can lock in the type and emit conversions correctly.

Use one of these instead:

```xs
string x = null;
var cfg = CreateConfigTemplate();
object value = null;
```

---

## 5. File structure

### Imports

Imports must be at the top of the file.

Syntax:

```xs
import Full.Namespace.OrType as Alias;
```

Examples:

```xs
import System.String as String;
import Ex.Console as Console
import Dlinq.Linq as Dlinq;
```

Notes:

- semicolon after import is commonly used and recommended
- alias is still referenced through `clr.`
- imported alias replaces the first segment after `clr.`

Example:

```xs
import System.String as Str;
clr.Str.IsNullOrWhiteSpace(s);
```

### Top-level return

Most scripts end with:

```xs
=> result;
```

or:

```xs
=> "Done";
```

Prefer a single final return in top-level code.
If you need early exits, use a `goto done` pattern.

---

## 6. Values and basic types

Built-in declared types:

- `int`
- `long`
- `double`
- `bool`
- `string`
- `object`
- `var`
- `StringBuilder`

Examples:

```xs
int n = 1;
long size = 100l;
double rate = 1.25;
bool ok = true;
string name = "xs";
StringBuilder sb;
var dto = new { Name = "", Age = 0 };
```

### Numeric notes

Long literals use lowercase `l`:

```xs
0l
100l
```

Promotion order:

```text
double > long > int
```

### Special constants / keywords

- `null`
- `true`
- `false`
- `this`
- `now`
- `date`
- `url`

`url` is a keyword meaning the current script folder.
Do not use `url` as a variable name.

---

## 7. Variables, globals, and parameters

### Local variables

```xs
string s = "";
int i = 0, n = 10;
var dto = new { Name = "" };
```

### Globals

Globals start with `@`.

```xs
@scriptFolder = url;
@responseFile = "r:\\response.json";
```

Rules:

- globals do not use explicit type keywords
- globals are visible everywhere

### Positional parameters

Use `[p1]`, `[p2]`, ... to read script arguments.

```xs
string folder = [p1];
string pattern = [p2];
```

This maps to:

```text
clr script.xs arg1 arg2 ...
```

Internally, `[p1]` is dictionary-style access to the key `"p1"`.

---

## 8. Strings

XS has three important string forms.

### Normal strings

```xs
string s = "hello";
```

### Verbatim strings

```xs
string s = @"c:\temp\file.txt";
```

### Free-text / multiline literals

```xs
StringBuilder cmd =<<<
line1
line2
line3
>>>;
```

These are ideal for:

- PowerShell bodies
- SQL
- JSON templates
- large command text

### String concatenation

Use `&`, not `+`, for normal string composition.

```xs
string s = "Hello " & name;
```

### Escaping and quoting

Use backslash escapes in normal strings:

```xs
string s = "a\"b";
```

Practical advice:

- for heavy quoting, prefer `StringBuilder <<< >>>`
- for Windows tools, prefer explicit `\r\n` when line endings matter

### Single quote note

Single quotes are awkward in XS string literals.
If needed, use:

```xs
"can" & chr(39) & "t"
```

---

## 9. Operators

### Common operators

- assignment: `=`
- equality: `==`, `!=`
- comparison: `<`, `>`, `<=`, `>=`
- logical: `&&`, `||`, `!`
- numeric: `+`, `-`, `*`, `/`, `%`
- string concat: `&`
- ternary: `?:`
- increment / decrement: `++`, `--`

### XS-specific or important operators

#### `=>`

Return an expression:

```xs
=> value;
```

#### `_`

Discard the result of an expression used only for side effects:

```xs
_ sb.Append("x");
_ clr.Ex.Console.Markup("hello");
```

#### `->`

Computed property access.
Used mainly with anonymous objects or dynamic-like objects.

```xs
dto -> "Name"
dto -> propName
```

This is low-precedence.
Use parentheses when mixing it with concatenation or arithmetic.

#### `..`

Force CLR property or method resolution when the type is unknown.
This appears in real scripts when chaining CLR methods on weakly typed values.

```xs
files..Count
files..get_item(i)
```

Use it when normal `.` binding is not enough.

#### `<-` and `<+`

Special assignment-like operators allowed by the grammar.
These are used in variable descriptions / assignments in engine-specific scenarios.
If you are writing normal scripts, use ordinary `=`.

---

## 10. Collections and indexing

### Preferred collection style

XS commonly uses:

- `ArrayList`
- anonymous-object lists
- CLR collections

C# array syntax is not the normal XS working style.

### Array-like literal

```xs
var items = [1, 2, 3];
var names = ["a", "b"];
```

This produces an `ArrayList`-style collection for XS usage.

### Indexing

```xs
items[0];
dict["key"];
```

### Important ambiguity rule

`[p1]` is **not** an array literal.
It is dictionary access to argument `"p1"`.

So:

```xs
[p1]
```

means "read the parameter", not "build a one-element list".

If you need a one-element list containing the value of `p1`, break the exact token shape:

```xs
[(p1)]
[(string)p1]
[p1 & ""]
```

### Common CLR collection calls

You will often see:

```xs
arr.Count
arr.get_item(i)
arr.Add(x)
arr.Insert(i, x)
arr.ToArrayList()
```

---

## 11. Anonymous objects

Anonymous objects are central to XS.

Example:

```xs
var dto = new {
	Name = "",
	Age = 0,
	Address = new {
		City = "",
		Zip = ""
	}
};
```

They are heavily used for:

- JSON templates
- config templates
- table rows
- ad hoc DTOs

### Important rule

Anonymous objects should be treated as immutable.
If you want to "change" them, build a new object and reassign.

```xs
cfg = new {
	last_folder = folder,
	last_lookup = lookup
};
```

### Why templates matter

JSON and CSV helpers use template shape to reconstruct values correctly.
Always provide a full template for deserialization.

Good:

```xs
var tpl = new {
	access_token = "",
	user = new { name = "", email = "" }
};
var dto = clr.Ex.Json.Deserialize(json, tpl);
```

Bad:

```xs
var dto = null;
dto = clr.Ex.Json.Deserialize(json, dto);
```

---

## 12. Functions and methods

### `func`

Use `func` for value-returning methods.

```xs
func Add(a, b) {
	=> (int)a + (int)b;
}
```

You may also write:

```xs
func string FormatName(x) {
	=> x.ToString().Trim();
}
```

### `void`

Use `void` for procedures.

```xs
void print(s) {
	clr.System.Console.WriteLine(s.ToString());
}
```

### Return forms

Inside `func`:

- `=> expr;`
- `return expr;`
- `ret expr;`

Inside `void`:

- `return;`
- `ret;`

### Parameters

Parameters are untyped at the signature level in real-world usage.
A common pattern is to normalize them early:

```xs
func Run(pathIn, contentIn) {
	string path = pathIn.ToString();
	string content = contentIn.ToString();
	=> Save(path, content);
}
```

---

## 13. Control flow

Supported:

- `if / elseif / else`
- `for`
- `while`
- `do { ... } while (...)`
- `try / catch`
- labels + `goto`
- `break`
- `continue`

### `elseif`

Use:

```xs
if(a) {
}
elseif(b) {
}
else {
}
```

Do not use `else if`.

### `for`

```xs
for(int i = 0; i < arr.Count; i++) {
	// ...
}
```

### `while`

```xs
while(!done) {
	// ...
}
```

### `do while`

```xs
do {
	// ...
}
while(ok);
```

### `try / catch`

```xs
try {
	value = Parse(x);
}
catch {
	value = 0;
}
```

Rules:

- empty `catch {}` is not supported
- `return` is allowed inside `try` and `catch`
- avoid `goto` inside `catch`
- declarations are not allowed inside `catch`

### Labels and goto

Common top-level pattern:

```xs
string result = "ok";

if(hasError) {
	result = "fail";
	goto done;
}

done:
=> result;
```

---

## 14. Where declarations are allowed

Declarations are allowed inside:

- `if`
- `for`
- `while`
- `try`

Declarations are **not** allowed inside:

- `do`
- `catch`

If unsure, declare outside those blocks first.

---

## 15. CLR interop

CLR interop is one of the most important XS features.

### Always use `clr.`

Use `clr.` for:

- static methods
- instance methods
- properties
- constructors

Examples:

```xs
clr.System.Math.Ceiling(x);
clr.System.IO.File.ReadAllText(path);
var p = new clr.System.Diagnostics.Process();
```

### Imports and `clr.`

Even if you import a type alias, you still use `clr.`

```xs
import System.IO.File as File;
clr.File.ReadAllText(path);
```

### Constructors

```xs
var p = new clr.System.Diagnostics.Process();
```

### Type conversion

Common examples:

```xs
(int)x
(string)y
(double)z
```

### CLR method chaining

Normal:

```xs
path.ToString().Trim()
```

Forced CLR resolution:

```xs
obj..ToString()
```

Use `..` when the receiver type is too weak for normal binding.

---

## 16. Engine-provided helper libraries

XS has two kinds of reusable helpers:

1. engine-provided helpers bundled into the runtime
2. plugin-style `Ex.*` helper classes loaded by the host

### 16.1 String and regex helpers

These are engine-native helpers from `StringLibrary`.
They are callable directly and often support extension-style syntax.

Common methods:

- `IsEmpty(x)`
- `IsNullOrEmpty(x)`
- `IsNullOrWhiteSpace(x)`
- `ReplStr(s, old, new)`
- `SubStr(s, index, length)`
- `Trim(s)`
- `LTrim(s, prefix)`
- `RTrim(s, suffix)`
- `Len(s)`
- `chr(code)`

Regex helpers:

- `IsMatch(content, pattern)`
- `Match(content, pattern)`
- `MatchAll(content, pattern, splitter)`
- `MatchGroup(content, pattern, group)`
- `MatchGroupI(content, pattern, group, index)`
- `MatchCollection(content, pattern)`
- `Replace(content, pattern, replacer)` for regex replacement

Typical usage:

```xs
if(path.IsEmpty()) { ... }
if("abc".IsMatch(@"[a-z]+")) { ... }
name = name.ReplStr("[", "").ReplStr("]", "");
```

Important distinction:

- `ReplStr` = plain substring replace
- `Replace` = regex replace

### 16.2 Enumerable helpers

These normalize enumerable results to `ArrayList`.

- `ToArrayList(x)`
- `AsArray(x)`
- `Arr(x)`

### 16.3 Dlinq helpers

These are powered by dynamic LINQ and exposed under `clr.Dlinq`.

Common methods:

- `clr.Dlinq.Where(source, "predicate")`
- `clr.Dlinq.Select(source, "selector")`
- `clr.Dlinq.OrderBy(source, "it.Score desc")`
- `clr.Dlinq.Take(source, 10)`
- `clr.Dlinq.Any(source, "predicate")`
- `clr.Dlinq.FirstOrDefault(source, "predicate")`

Example:

```xs
var top = clr.Dlinq.Take(
	clr.Dlinq.OrderBy(items, "it.Score desc"),
	10
);
```

Sequence-returning Dlinq methods usually return `ArrayList`.
Anonymous projections are rebuilt into XS-friendly anonymous objects.

### 16.4 `Ex.*` helpers

Common plugin helpers:

- `clr.Ex.Console`
- `clr.Ex.StatusConsole`
- `clr.Ex.ProgressConsole`
- `clr.Ex.LiveProgressConsole`
- `clr.Ex.TableConsole`
- `clr.Ex.Json`
- `clr.Ex.Csv`
- `clr.Ex.Sql`
- `clr.Ex.Http`
- `clr.Ex.Clipboard`
- `clr.Ex.Powershell`

Common examples:

```xs
clr.Ex.Console.Markup("hello");
clr.Ex.Json.Serialize(obj);
clr.Ex.Json.Deserialize(json, template);
clr.Ex.Csv.Read(file, template);
clr.Ex.Http.Send("GET", url, headers);
clr.Ex.Clipboard.Copy(text);
```

These helpers are implemented in the host runtime / extension assemblies, not in user XS scripts.

---

## 17. Console and progress APIs

See `ConsoleExtension.md` for detailed usage.
This section is the quick working summary.

### Logging / markup

Common helper:

```xs
void mark(color, content) {
	clr.Ex.Console.Markup("[#" & color & "]"
		& content.ToString().Replace("[", "").Replace("]", "").Replace("[/]", "")
		& "[/]\r\n"
	);
}
```

### Status spinner

```xs
clr.StatusConsole.Start("Working");
clr.StatusConsole.Status("Step 1");
clr.StatusConsole.Stop();
```

### Progress console

```xs
clr.ProgressConsole.Start(["Read", "Process", "Write"]);
clr.ProgressConsole.Progress("Read", 100);
clr.ProgressConsole.Stop();
```

### Live progress console

```xs
clr.LiveProgressConsole.Start(["Download"]);
clr.LiveProgressConsole.Progress("Download", 30, "file_01");
clr.LiveProgressConsole.Stop();
```

Rule:

- while live consoles are active, prefer `mark(...)`
- avoid raw `System.Console.WriteLine(...)` because it can corrupt live rendering

---

## 18. JSON, CSV, SQL, HTTP, clipboard

### JSON

Use template-driven deserialize:

```xs
var tpl = new {
	name = "",
	age = 0,
	tags = [""]
};

var dto = clr.Ex.Json.Deserialize(jsonText, tpl);
```

### CSV

```xs
var tpl = new { Name = "", Value = "" };
var rows = clr.Ex.Csv.Read(file, tpl);
```

### SQL

```xs
var cmd = new clr.Microsoft.Data.SqlClient.SqlCommand();
clr.Ex.Sql.SqlCommandStoredProcedure(cmd, dict);
var reader = clr.Ex.Sql.ExecuteReader(cmd);
```

### HTTP

```xs
var headers = [
	new { Name = "Accept", Value = "application/json" }
];
var resp = clr.Ex.Http.Send("GET", url, headers);
```

### Clipboard

```xs
_ clr.Ex.Clipboard.Copy(text);
string pasted = clr.Ex.Clipboard.Paste();
```

---

## 19. Async / await

XS does not have a full async programming model.

It supports a limited `await` only for direct CLR async method calls returning:

- `Task`
- `Task<T>`
- `ValueTask`
- `ValueTask<T>`

Allowed:

```xs
var x = await clr.System.Threading.Tasks.Task.FromResult(123);
var h = clr.AwaitInterpreter_Test.AwaitTestHelper.Create();
var n = await h.GetIntAsync(41);
```

Not allowed:

```xs
var t = clr.System.Threading.Tasks.Task.FromResult(7);
var x = await t;
```

Rule:

- await direct CLR async calls only
- do not expect user-defined async methods
- when mixing with operators, use parentheses around the whole await expression

Example:

```xs
var n = (await h.GetIntAsync(41)) + 1;
```

---

## 20. Writing scripts safely

### Good style

- keep top-level script short
- move reusable logic into `func` / `void`
- normalize parameters early
- use explicit types where practical
- use `StringBuilder <<< >>>` for large templates
- use full config templates for JSON
- prefer one final `=>` in main
- use tabs for indentation if matching existing house style

### Avoid

- `var x = null`
- `else if`
- declarations in `catch`
- declarations in `do`
- raw `System.Console.WriteLine` during live progress rendering
- relying on block scope
- mutating anonymous objects in place

### Safe error-handling pattern

```xs
bool ok = false;
string value = "";

try {
	value = RiskyCall();
	ok = true;
}
catch {
	ok = false;
}

if(!ok) {
	value = "";
}
```

---

## 21. Common script patterns

### Read args with fallback prompt

```xs
string folder = [p1];
while(folder.IsEmpty()) {
	folder = clr.Console.Ask("Please give folder\r\n");
}
```

### Working with files

```xs
if(!clr.System.IO.File.Exists(path)) {
	=> "missing";
}

string text = clr.System.IO.File.ReadAllText(path);
```

### PowerShell runner pattern

Many real scripts use a user-defined helper like:

```xs
func RunPowershellFromMemory(command, showError) {
	// process setup
	// powershell.exe -EncodedCommand or -Command
	// capture stdout
	=> output;
}
```

Use it when:

- PowerShell output is part of program logic

Use `clr.Ex.Powershell.Run(...)` when:

- PowerShell is mainly for side effects or console output

### Config template pattern

```xs
func CreateConfigTemplate() {
	=> new {
		last_folder = "",
		last_lookup = "",
		items = [""]
	};
}
```

### Table display pattern

```xs
func Dto() {
	=> new { Name = "", Value = "" };
}
```

Use reflection to get property names and values when needed.
This pattern is extremely common in existing scripts.

---

## 22. Common restrictions

XS does **not** support normal C# breadth.

Do not assume support for:

- `foreach`
- `using`
- user-defined `async`
- delegates
- events
- `out`, `ref`, `in`, `params`
- nullable types
- `throw`

Also remember:

- `catch {}` empty is invalid
- `else if` is invalid, use `elseif`

---

## 23. Beginner-to-master learning path

### Stage 1: beginner

Learn these first:

1. imports
2. top-level script + `=>`
3. `string`, `int`, `bool`, `var`
4. `if`, `for`, `while`
5. `[p1]`, `@global`
6. `clr.` method calls
7. `&` for string concat

You should already be able to write utility scripts after this stage.

### Stage 2: productive

Learn these next:

1. anonymous objects
2. `StringBuilder <<< >>>`
3. `clr.Ex.Json.Deserialize(json, template)`
4. `ArrayList` / indexing / `get_item`
5. `mark(...)`
6. `goto done` top-level flow
7. `IsEmpty`, `ReplStr`, `IsMatch`

At this stage you can write real automation scripts.

### Stage 3: advanced

Learn these:

1. `obj -> prop`
2. `..` forced CLR resolution
3. `clr.Dlinq.*`
4. progress / live console APIs
5. reflection-driven table patterns
6. config-template and DTO-template design
7. limited `await` rules

At this stage you can read and author most existing house-style XS scripts.

### Stage 4: expert

Master these:

1. region-scoped variable behavior
2. redeclaration semantics
3. anonymous-object reconstruction patterns
4. dynamic LINQ result shaping
5. when to use CLR methods directly vs engine helpers
6. how `Ex.*` helpers and templates preserve shape
7. how to avoid subtle compile-time errors from weak typing

At this stage you should be able to design new XS scripts fluently.

---

## 24. Final checklist before writing a new XS script

Use this checklist every time.

### Script setup

- Do I need imports at the top?
- Do I need globals like `@currentFolder = url`?
- Do I need `[p1]`, `[p2]` inputs?

### Data modeling

- If using JSON or CSV, did I define a full template object?
- Did I avoid `var x = null`?
- If using collections, do I want `ArrayList`-style behavior?

### Control flow

- Am I using `elseif`, not `else if`?
- Did I avoid declarations in `catch` and `do`?
- Should top-level use `goto done` plus one final `=>`?

### CLR interop

- Did I prefix CLR access with `clr.`?
- If type is weak, do I need `..`?
- If calling async, is it a direct CLR async method call?

### Strings and commands

- Should I use `StringBuilder <<< >>>` instead of a heavily escaped string?
- Did I use `&` for string concatenation?
- Did I use `\r\n` when Windows tools care about CRLF?

### Console behavior

- If using live progress, did I avoid raw console writes?
- Should I use `mark(...)`?

---

## 25. Canonical starter templates

### Minimal utility script

```xs
import Ex.Console as Console;

string input = [p1];
while(input.IsEmpty()) {
	input = clr.Console.Ask("Please give input\r\n");
}

mark("5FD7AF", "Input: " & input);
=> "Done";

void mark(color, content) {
	clr.Ex.Console.Markup("[#" & color & "]"
		& content.ToString().Replace("[", "").Replace("]", "").Replace("[/]", "")
		& "[/]\r\n"
	);
}
```

### JSON-driven script

```xs
func ConfigTemplate() {
	=> new {
		last_folder = "",
		items = [""]
	};
}
```

### Safe top-level main

```xs
string result = "ok";

if(hasError) {
	result = "fail";
	goto done;
}

// main logic

done:
=> result;
```

---

## 26. Final rule of thumb

If you are unsure how to write something in XS:

1. prefer explicit types over cleverness
2. prefer full templates over partial/dynamic guesses
3. prefer CLR calls through `clr.`
4. prefer `StringBuilder <<< >>>` for large text
5. prefer simple top-level flow with one final `=>`
6. prefer existing house patterns over inventing new syntax

If you follow those rules, you can write new XS scripts with very little debugging.
