import System.String as Str;
import Ex.Console as Console;

@cfgFile = "clean_html_text.json";

string htmlFile = ResolveHtmlFile();
string html = clr.System.IO.File.ReadAllText(htmlFile, clr.System.Text.Encoding.UTF8);

string text = HtmlToText(html);

string outFile = htmlFile & ".txt";
clr.System.IO.File.WriteAllText(outFile, text, clr.System.Text.Encoding.UTF8);

mark("5FD7AF", "Saved: " & outFile);
=> 1;

func ResolveHtmlFile() {
	string input = "";
	var cfg = new { last_file : "" };

	cfg = LoadUserConfig((string)@cfgFile, cfg);

	if([p1] != null) { input = [p1].ToString(); }
	input = input.Trim();

	while(input.isempty() || !clr.System.IO.File.Exists(input)) {
		if(cfg != null && !cfg.last_file.isempty() && clr.System.IO.File.Exists(cfg.last_file)) {
			input = clr.Console.Ask(
				"HTML file (Enter to reuse last):" &
				clr.System.Environment.NewLine &
				cfg.last_file &
				clr.System.Environment.NewLine
			);
			if(input.isempty()) { input = cfg.last_file; }
		} else {
			input = clr.Console.Ask(
				"HTML file path:" & clr.System.Environment.NewLine
			);
		}
		input = input.Trim();
	}

	cfg = new { last_file : input };
	SaveUserConfig((string)@cfgFile, cfg);

	=> input;
}

func HtmlToText(html) {
	string s = "";

	s = html.ToString();

	s = Replace(s, "\r\n|\r|\n", clr.System.Environment.NewLine);

	s = Replace(s, "<br\\s*/?>", clr.System.Environment.NewLine);

	s = Replace(s, "</p\\s*>", clr.System.Environment.NewLine & clr.System.Environment.NewLine);
	s = Replace(s, "<p\\b[^>]*>", "");

	s = Replace(s, "</div\\s*>", clr.System.Environment.NewLine);
	s = Replace(s, "<div\\b[^>]*>", clr.System.Environment.NewLine);

	s = Replace(s, "</section\\s*>", clr.System.Environment.NewLine);
	s = Replace(s, "<section\\b[^>]*>", clr.System.Environment.NewLine);

	s = Replace(s, "</article\\s*>", clr.System.Environment.NewLine);
	s = Replace(s, "<article\\b[^>]*>", clr.System.Environment.NewLine);

	s = Replace(s, "<h[1-6]\\b[^>]*>", clr.System.Environment.NewLine);
	s = Replace(s, "</h[1-6]\\s*>", clr.System.Environment.NewLine);

	s = Replace(s, "<li\\b[^>]*>", "- ");
	s = Replace(s, "</li\\s*>", clr.System.Environment.NewLine);

	s = Replace(s, "<(ul|ol)\\b[^>]*>", clr.System.Environment.NewLine);
	s = Replace(s, "</(ul|ol)\\s*>", clr.System.Environment.NewLine);

	s = Replace(s, "<tr\\b[^>]*>", "");
	s = Replace(s, "</tr\\s*>", clr.System.Environment.NewLine);
	s = Replace(s, "<td\\b[^>]*>", " ");
	s = Replace(s, "</td\\s*>", " ");

	s = Replace(s, "<table\\b[^>]*>", clr.System.Environment.NewLine);
	s = Replace(s, "</table\\s*>", clr.System.Environment.NewLine);

	s = Replace(s, "<!--[\\s\\S]*?-->", "");
	s = Replace(s, "<script\\b[^>]*>[\\s\\S]*?</script\\s*>", "");
	s = Replace(s, "<style\\b[^>]*>[\\s\\S]*?</style\\s*>", "");

	s = Replace(s, "<[^>]+>", "");

	s = Replace(s, "&nbsp;", " ");
	s = Replace(s, "&lt;", "<");
	s = Replace(s, "&gt;", ">");
	s = Replace(s, "&amp;", "&");
	s = Replace(s, "&quot;", "\"");

	s = Replace(s, "[ \\t]+", " ");
	s = Replace(s, clr.System.Environment.NewLine & "[ \\t]+", clr.System.Environment.NewLine);
	s = Replace(
		s,
		"(" & clr.System.Environment.NewLine & "){3,}",
		clr.System.Environment.NewLine & clr.System.Environment.NewLine
	);

	=> s.Trim();
}

func GetUserConfigPath(fileName) {
	string profileDir = clr.System.Environment.GetFolderPath(clr.System.Environment.SpecialFolder.UserProfile);
	string configDir = clr.System.IO.Path.Combine(profileDir, "xs_config");
	if (!clr.System.IO.Directory.Exists(configDir)) {
		clr.System.IO.Directory.CreateDirectory(configDir);
	}
	string filePath = clr.System.IO.Path.Combine(configDir, fileName.ToString());
	=> filePath;
}

func LoadUserConfig(fileName, templateObj) {
	string filePath = GetUserConfigPath(fileName);
	object result = null;
	if (!clr.System.IO.File.Exists(filePath)) { goto exit; }
	string jsonText = clr.System.IO.File.ReadAllText(filePath);
	result = clr.Ex.Json.Deserialize(jsonText, templateObj);

	exit:
	=> result;
}

void SaveUserConfig(fileName, obj) {
	string filePath = GetUserConfigPath(fileName);
	string json = clr.Ex.Json.Serialize(obj);
	clr.System.IO.File.WriteAllText(filePath, json);
}



void mark(color, content) {
	clr.Ex.Console.Markup("[#" & color & "]"
		& content.ReplStr("[", "").ReplStr("]", "").ReplStr("[/]", "")
		& "[/]\r\n"
	);
}