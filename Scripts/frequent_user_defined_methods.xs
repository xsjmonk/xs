=> null;

func NormalizePowershellStdout(outputText) {
	string s = outputText == null ? "" : outputText.ToString().Trim();
	if(s.IsEmpty()) { => ""; }
	if(s.StartsWith("#< CLIXML")) {
		int lastNl = s.LastIndexOf("\n");
		if(lastNl >= 0) {
			s = s.Substring(lastNl + 1).Trim();
		}
	}
	=> s;
}

func RunPowershellFromMemory(command) {
	var p = new clr.System.Diagnostics.Process();
	p.StartInfo.WindowStyle = clr.System.Diagnostics.ProcessWindowStyle.Minimized;
	p.StartInfo.CreateNoWindow = true;
	p.StartInfo.UseShellExecute = false;
	p.StartInfo.RedirectStandardOutput = true;
	p.StartInfo.RedirectStandardError = true;
	p.StartInfo.FileName = "powershell.exe";
	p.StartInfo.Arguments = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand "
		& clr.System.Convert.ToBase64String(
			clr.System.Text.Encoding.Unicode.GetBytes(
				"& { $ProgressPreference = 'SilentlyContinue'; $WarningPreference = 'SilentlyContinue'; "
					& command.ToString()
					& " }"
			)
		) ;

	p.Start();
	string stdoutx = NormalizePowershellStdout(p.StandardOutput.ReadToEnd());
	_ p.StandardError.ReadToEnd();
	p.WaitForExit();
	p.Dispose();

	=> stdoutx;
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

	clr.Spectre.Console.AnsiConsole.MarkupLine(safe);

	exit:
	json = null;
}

void mark(color, content) {
	clr.Ex.Console.Markup("[#" & color & "]"
		& content.ToString().Replace("[", "").Replace("]", "").Replace("[/]", "")
		& "[/]\r\n"
	);
}
