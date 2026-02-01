import Ex.Console as Console
import Ex.Powershell as Powershell
import System.String as Str
import System.Text.RegularExpressions.Regex as Regex

string turboState = "", eppState = "", turboPrompt = "", eppPrompt = "", ans = "", yn = "", eppIn = "";
string turboReadable = "";
int eppVal = -1;

mark("00A4EF", "Reading Turbo (PERFBOOSTMODE)...");
turboState = GetTurboStateQh();
turboReadable = TurboStateToReadable(turboState);

turboPrompt =
	"Turbo current: " & turboReadable & "\r\n" &
	"Enable Turbo? (y = enable, n = disable): ";

while(yn != "y" && yn != "n") {
	ans = clr.Console.Ask(turboPrompt);
	if(ans != null) { yn = ans.ToString().Trim().ToLower(); }
}

_ SetTurboState(yn);

mark("00A4EF", "Reading Speed Shift EPP (PERFEPP)...");
eppState = GetEppStateQh();

eppPrompt =
	"EPP current: " & eppState & "\r\n" &
	"Enter EPP value (0..100). (Lower=performance, Higher=efficiency): ";

while(eppVal < 0 || eppVal > 100) {
	ans = clr.Console.Ask(eppPrompt);
	if(ans != null) { eppIn = ans.ToString().Trim(); }
	eppVal = ParseIntOrNeg1(eppIn);
}

_ SetEppState(eppVal);

mark("00A4EF", "Reading final states...");
turboState = GetTurboStateQh();
eppState = GetEppStateQh();
turboReadable = TurboStateToReadable(turboState);

mark("00A4EF", "Updated: Turbo=" & turboReadable & " ; EPP=" & eppState);
=> null;

void mark(color, content) {
	clr.Ex.Console.Markup("[#" & color & "]"
		& content.ReplStr("[", "").ReplStr("]", "").ReplStr("[/]", "")
		& "[/]\r\n"
	);
}

func RunPowershellFromMemory(command, shouldShowError) {
	var p = new clr.System.Diagnostics.Process();
	p.StartInfo.WindowStyle = clr.System.Diagnostics.ProcessWindowStyle.Minimized;
	p.StartInfo.CreateNoWindow = true;
	p.StartInfo.UseShellExecute = false;
	p.StartInfo.RedirectStandardOutput = true;
	p.StartInfo.RedirectStandardError = true;
	p.StartInfo.FileName = "powershell.exe";
	p.StartInfo.Arguments =
		"-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand " &
		clr.System.Convert.ToBase64String(
			clr.System.Text.Encoding.Unicode.GetBytes("& {" & command.ToString() & "}")
		);

	p.Start();
	string stdoutx = p.StandardOutput.ReadToEnd();
	string stderrx = p.StandardError.ReadToEnd();
	p.WaitForExit();

	string errTrim = "";
	errTrim = (stderrx == null) ? "" : stderrx.Trim();

	if((bool)shouldShowError) {
		if(!errTrim.IsEmpty()) {
			if(!errTrim.StartsWith("#< CLIXML")) { mark("F65B3B", stderrx); }
		}
	}

	p.Dispose();
	return stdoutx;
}

func TurboIndexToMode(idx) {
	int n = -1;
	string s = "", mode = "Unknown";

	if(idx != null) { s = idx.ToString().Trim(); }
	if(s.isempty()) { => "Unknown"; }

	if(s == "0") { mode = "Disabled"; }
	elseif(s == "1") { mode = "Enabled"; }
	elseif(s == "2") { mode = "Enabled (Aggressive)"; }
	elseif(s == "3") { mode = "Aggressive"; }
	elseif(s == "4") { mode = "Max Aggressive"; }
	else { mode = "Unknown(" & s & ")"; }

	=> mode;
}

func TurboStateToReadable(state) {
	string s = "", ac = "", dc = "", acMode = "", dcMode = "";

	if(state != null) { s = state.ToString().Trim(); }
	if(s.isempty() || s == "UNKNOWN") { => "Unknown [state=" & s & "]"; }

	ac = ExtractValue(s, "AC=");
	dc = ExtractValue(s, "DC=");

	acMode = TurboIndexToMode(ac);
	dcMode = TurboIndexToMode(dc);

	=> "AC: " & acMode & " (" & ac & "), DC: " & dcMode & " (" & dc & ")";
}

func ExtractValue(text, key) {
	string s = "", k = "", v = "";
	int p = -1, e = -1;

	if(text != null) { s = text.ToString(); }
	if(key != null) { k = key.ToString(); }

	p = s.IndexOf(k);
	if(p < 0) { => ""; }

	p = p + k.Length;
	e = s.IndexOf(";", p);
	if(e < 0) { v = s.Substring(p).Trim(); }
	else { v = s.Substring(p, e - p).Trim(); }

	=> v;
}

func GetTurboStateQh() {
	StringBuilder ps =<<<
$ErrorActionPreference='Stop';
$ProgressPreference='SilentlyContinue';
$active=(powercfg /getactivescheme | Out-String);
$scheme=([regex]::Match($active,'([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})')).Groups[1].Value;
if([string]::IsNullOrWhiteSpace($scheme)) { 'UNKNOWN'; exit; }
$txt=(powercfg /qh $scheme SUB_PROCESSOR | Out-String);
$guid='be337238-0d82-4146-a960-4f3749d470c7';
$blk=([regex]::Match($txt,"(?is)Power Setting GUID:\s*$([regex]::Escape($guid))\b.*?(?=Power Setting GUID:|\z)")).Value;
if([string]::IsNullOrWhiteSpace($blk)) { 'UNKNOWN'; exit; }
$mac=[regex]::Match($blk,'Current AC Power Setting Index:\s*0x([0-9a-fA-F]+)');
$mdc=[regex]::Match($blk,'Current DC Power Setting Index:\s*0x([0-9a-fA-F]+)');
if(!$mac.Success -or !$mdc.Success){ 'UNKNOWN'; exit; }
$ac=[convert]::ToInt32($mac.Groups[1].Value,16);
$dc=[convert]::ToInt32($mdc.Groups[1].Value,16);
"AC=$ac;DC=$dc"
>>>;

	string outp = "";
	outp = RunPowershellFromMemory(ps.ToString(), true);
	if(outp == null) { => "UNKNOWN"; }
	outp = outp.Trim();
	if(outp.isempty()) { => "UNKNOWN"; }
	=> outp;
}

func SetTurboState(enableTurbo) {
	string yn2 = "";
	if(enableTurbo != null) { yn2 = enableTurbo.ToString().Trim().ToLower(); }

	StringBuilder ps =<<<
$ErrorActionPreference='Stop';
$ProgressPreference='SilentlyContinue';
$enable=('__ENABLE__');
$active=(powercfg /getactivescheme | Out-String);
$scheme=([regex]::Match($active,'([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})')).Groups[1].Value;
if([string]::IsNullOrWhiteSpace($scheme)) { 'FAILED: no active scheme'; exit; }
$boost=if($enable -eq 'y'){ 2 } else { 0 };
powercfg /setacvalueindex $scheme SUB_PROCESSOR PERFBOOSTMODE $boost | Out-Null;
powercfg /setdcvalueindex $scheme SUB_PROCESSOR PERFBOOSTMODE $boost | Out-Null;
powercfg /setactive $scheme | Out-Null;
'OK'
>>>;

	string cmd = "";
	cmd = ps.ToString().Replstr("__ENABLE__", yn2);
	=> RunPowershellFromMemory(cmd, true);
}

func GetEppStateQh() {
	StringBuilder ps =<<<
$ErrorActionPreference='Stop';
$ProgressPreference='SilentlyContinue';
$active=(powercfg /getactivescheme | Out-String);
$scheme=([regex]::Match($active,'([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})')).Groups[1].Value;
if([string]::IsNullOrWhiteSpace($scheme)) { 'UNKNOWN'; exit; }
$txt=(powercfg /qh $scheme SUB_PROCESSOR | Out-String);
$guid='36687f9e-e3a5-4dbf-b1dc-15eb381c6863';
$blk=([regex]::Match($txt,"(?is)Power Setting GUID:\s*$([regex]::Escape($guid))\b.*?(?=Power Setting GUID:|\z)")).Value;
if([string]::IsNullOrWhiteSpace($blk)) { 'UNKNOWN'; exit; }
$mac=[regex]::Match($blk,'Current AC Power Setting Index:\s*0x([0-9a-fA-F]+)');
$mdc=[regex]::Match($blk,'Current DC Power Setting Index:\s*0x([0-9a-fA-F]+)');
if(!$mac.Success -or !$mdc.Success){ 'UNKNOWN'; exit; }
$ac=[convert]::ToInt32($mac.Groups[1].Value,16);
$dc=[convert]::ToInt32($mdc.Groups[1].Value,16);
"AC=$ac;DC=$dc"
>>>;

	string outp = "";
	outp = RunPowershellFromMemory(ps.ToString(), true);
	if(outp == null) { => "UNKNOWN"; }
	outp = outp.Trim();
	if(outp.isempty()) { => "UNKNOWN"; }
	=> outp;
}

func SetEppState(eppValue) {
	string epp2 = "";
	if(eppValue != null) { epp2 = eppValue.ToString().Trim(); }

	StringBuilder ps =<<<
$ErrorActionPreference='Stop';
$ProgressPreference='SilentlyContinue';
$epp=('__EPP__');
$active=(powercfg /getactivescheme | Out-String);
$scheme=([regex]::Match($active,'([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})')).Groups[1].Value;
if([string]::IsNullOrWhiteSpace($scheme)) { 'FAILED: no active scheme'; exit; }
if($epp -notmatch '^\d+$'){ 'FAILED: EPP not numeric'; exit; }
$val=[int]$epp;
if($val -lt 0 -or $val -gt 100){ 'FAILED: EPP out of range'; exit; }
powercfg /setacvalueindex $scheme SUB_PROCESSOR PERFEPP $val | Out-Null;
powercfg /setdcvalueindex $scheme SUB_PROCESSOR PERFEPP $val | Out-Null;
powercfg /setactive $scheme | Out-Null;
'OK'
>>>;

	string cmd = "";
	cmd = ps.ToString().Replstr("__EPP__", epp2);
	=> RunPowershellFromMemory(cmd, true);
}

func ParseIntOrNeg1(text) {
	string s = "";
	var m = null;
	int v = -1;

	if(text != null) { s = text.ToString().Trim(); }
	if(s.isempty()) { => -1; }

	m = clr.Regex.Match(s, "^-?\\d+$");
	if(m == null || !m.Success) { => -1; }

	v = clr.System.Int32.Parse(s);
	=> v;
}