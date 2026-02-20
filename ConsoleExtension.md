# Progress and Status Consoles (xs-engine)

This note documents the *supported* console APIs and the safe usage patterns in xs scripts.
It covers:

- `Ex.Console` (markup/log output)
- `Ex.StatusConsole` (single live status)
- `Ex.ProgressConsole` (multi-step progress)
- `Ex.LiveProgressConsole` (progress + live status line)

## Imports (xs)

Use these aliases consistently:

```xs
import Ex.Console as Console
import Ex.StatusConsole as StatusConsole
import Ex.ProgressConsole as ProgressConsole
import Ex.LiveProgressConsole as LiveProgressConsole
```

If you only need one console, import only that one.

## 0. Console output rules

### Markup vs raw Console writes

Prefer:

- `mark(color, text)` -> `clr.Ex.Console.Markup(...)`

Avoid during live rendering:

- `clr.System.Console.WriteLine(...)`

Reason:
- Live renderers (Status/Progress) own the terminal cursor.
- Direct writes can break the reserved region and cause flicker or missing progress.
- The engine routes/buffers `Ex.Console.Markup` during `LiveProgressConsole` sessions and flushes it safely on `Stop()`.
- Raw `System.Console` writes are *not* routed and can still corrupt the live area.

If you need “debug prints” during `LiveProgressConsole`, use `mark(...)` (safe) or store messages in a list and print after `Stop()`.

### Terminal width fallback

`LiveProgressConsole` now uses a safe width fallback chain:

1. `AnsiConsole.Profile.Width` (if > 0)
2. `System.Console.WindowWidth` (if > 0)
3. `System.Console.BufferWidth` (if > 0)
4. fallback `120`

This prevents “status shows only `…`” when the host reports unknown width.

---

## 1. Ex.Console (Markup)

### Purpose
Formatted (color) output with Spectre markup.

### Common helper (xs)

```xs
void mark(color, content) {
	clr.Ex.Console.Markup("[#" & color & "]"
		& content.ToString().Replace("[", "").Replace("]", "").Replace("[/]", "")
		& "[/]
"
	);
}
```

You can continue to use your existing `mark(...)` helper.

---

## 2. StatusConsole (single live status)

### When to use
- You need a spinner + one status line
- You want to keep printing logs normally (usually fine)
- You do *not* need a progress bar

### Typical pattern

```xs
import Ex.StatusConsole as StatusConsole

string title = "Downloading";
clr.StatusConsole.Start(title);

clr.StatusConsole.Status(title, "Connecting...");
/* work... */
clr.StatusConsole.Status(title, "Receiving...");

clr.StatusConsole.Stop();
```

Notes:
- StatusConsole is more tolerant of console output, but still best to avoid heavy spam while it’s active.

---

## 3. ProgressConsole (multi-step progress)

### When to use
- You have multiple steps (tasks) and want a stable progress UI
- You don't need a continuously changing status text line per tick
- You want the simplest, most stable progress visualization

### Pattern

```xs
import Ex.ProgressConsole as ProgressConsole

var steps = ["Read file", "Process", "Write output"];
clr.ProgressConsole.Start(steps);

clr.ProgressConsole.Progress("Read file", 10);
clr.ProgressConsole.Progress("Read file", 100);

clr.ProgressConsole.Progress("Process", 50);
clr.ProgressConsole.Progress("Process", 100);

clr.ProgressConsole.Progress("Write output", 100);

clr.ProgressConsole.Stop();
```

Percent values:
- pass 0..100 (int/double both OK; engine clamps)

---

## 4. LiveProgressConsole (progress + dedicated status line)

### When to use
- You want a progress bar *and* a live-updating per-item status line
- You want output that does not scroll while updating

### Correct pattern

```xs
import Ex.LiveProgressConsole as LiveProgressConsole
import Ex.Console as Console

string title = "Change file time (N files)";
clr.LiveProgressConsole.Start([title]);

for(int i = 0; i < total; i++) {
	var status = "file_" & i;
	clr.LiveProgressConsole.Progress(title, (int)Percent(i, total), status);

	// safe:
	mark("3399FF", "Working on " & status);

	// do work...
	clr.LiveProgressConsole.Progress(title, (int)Percent(i+1, total), status);
}

clr.LiveProgressConsole.Stop();
mark("5FD7AF", "Done");
```

### Status argument
The third argument can be:
- string (recommended)
- any object; the console will call `.ToString()`

### Output safety
During an active `LiveProgressConsole` session:
- `Ex.Console.Markup` is routed/buffered (safe)
- `System.Console.WriteLine` is not routed (unsafe)

If you must produce a lot of messages:
- accumulate into an ArrayList
- print after `Stop()`

### Avoid mixing with other live consoles
Do not run `StatusConsole` or `ProgressConsole` while `LiveProgressConsole` is active.

---

## 5. Recommended selections

- Want just “busy spinner”: **StatusConsole**
- Want step-based progress: **ProgressConsole**
- Want progress + live status text without scrolling: **LiveProgressConsole**

---

## 6. Utility helpers (xs)

### Percent(done,total)

```xs
func Percent(done, total) {
	double d = 0.0, t = 0.0, p = 0.0;
	d = (double)done;
	t = (double)total;
	if(t <= 0.0) { => 0.0; }
	p = (d * 100.0) / t;
	if(p < 0.0) { p = 0.0; }
	if(p > 100.0) { p = 100.0; }
	=> p;
}
```

---

## 7. Troubleshooting

### Progress shows only `…`
Cause: console width detected as 0/unknown by host.
Fix: run in a real terminal (Windows Terminal / conhost) or upgrade to the patched LiveProgressConsole that uses width fallback (already applied).

### Progress does not show / freezes / flickers
Cause: direct writes to console while live renderer is active (especially `System.Console.WriteLine`).
Fix: use `mark(...)` or buffer logs and print after `Stop()`.

