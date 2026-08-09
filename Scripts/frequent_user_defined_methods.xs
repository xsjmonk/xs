=> null;

func RunPowershellFromMemory(command, shouldShowError) {
	var p = new clr.System.Diagnostics.Process();
	p.StartInfo.WindowStyle = clr.System.Diagnostics.ProcessWindowStyle.Minimized;
	p.StartInfo.CreateNoWindow = true;
	p.StartInfo.UseShellExecute = false;
	p.StartInfo.RedirectStandardOutput = true;
	p.StartInfo.RedirectStandardError = true;
	p.StartInfo.FileName = "powershell.exe";
	p.StartInfo.Arguments = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand " &
				clr.System.Convert.ToBase64String(clr.System.Text.Encoding.Unicode.GetBytes("& {" & command.ToString() & "}")) ;

	p.Start();
	string stdoutx = p.StandardOutput.ReadToEnd();
	string stderrx = p.StandardError.ReadToEnd();
	p.WaitForExit();

	if((bool)shouldShowError && !stderrx.IsEmpty()) { mark("F65B3B", stderrx); }
	p.Dispose();

	return stdoutx;
}


void print_json(obj) {
	string json = "", safe = "", sIn = "", trimmed = "";
	bool isStr = false, isJsonLike = false;

	if (obj == null) {
		clr.Spectre.Console.AnsiConsole.MarkupLine("[grey italic](null)[/]");
		goto exit;
	}

	try { sIn = (string)obj; isStr = true; } catch { isStr = false; }
	if (isStr) {
		trimmed = sIn.Trim();
		if (trimmed.StartsWith("{") || trimmed.StartsWith("[")) { isJsonLike = true; }
	}

	if (isStr && isJsonLike) { json = sIn; }
	else {
		try { json = clr.Newtonsoft.Json.JsonConvert.SerializeObject(obj); }
		catch { json = "(unserializable object)"; }
	}

	safe = json.Replace("[", "[[").Replace("]", "]]");
	safe = clr.System.Text.RegularExpressions.Regex.Replace(safe, "(?<=\\s*)\"([^\"]+)\"(?=\\s*:)", "[cyan]\"$1\"[/]");
	safe = clr.System.Text.RegularExpressions.Regex.Replace(safe, ":\\s*\"([^\"]*)\"", ": [green]\"$1\"[/]");
	safe = clr.System.Text.RegularExpressions.Regex.Replace(safe, ":\\s*(-?\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?)", ": [yellow]$1[/]");
	safe = clr.System.Text.RegularExpressions.Regex.Replace(safe, "(?i):\\s*(true|false)", ": [blue]$1[/]");
	safe = clr.System.Text.RegularExpressions.Regex.Replace(safe, "(?i):\\s*(null)", ": [red]$1[/]");
	exit:
	clr.Spectre.Console.AnsiConsole.MarkupLine(safe);
}


void mark(color, content) {
	clr.Ex.Console.Markup("[#" & color & "]"
		& content.ReplStr("[", "").ReplStr("]", "").ReplStr("[/]", "")
		& "[/]\n"
	);
}