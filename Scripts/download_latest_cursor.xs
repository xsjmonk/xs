import Ex.Console as Console;
import Ex.Powershell as Powershell;
import System.Collections.ArrayList as ArrayList;
import System.IO.File as File;

var prefsTpl = new { last_install_kind: "User version" };
var prefs = LoadUserConfig("download_latest_cursor.json", prefsTpl);
string installKind = PromptInstallKind(prefs.last_install_kind.ToString());
SaveUserConfig("download_latest_cursor.json", new { last_install_kind: installKind });

@cursorDlConfig = BuildDownloadLatestCursorConfig(installKind);

mark("2B91AF", "Download latest Cursor (Windows x64 " & installKind & ", stable)");

bool ok = true;

if(!EnsureDownloadDriveReady()) {
	ok = false;
}
else if(!RunPowershellLive(BuildDownloadLatestCursorPowershell())) {
	mark("F65B3B", "Download failed.");
	ok = false;
}

if(ok) {
	mark("5FD7AF", "Download completed.");
}

=> "Done";

func InstallKindLabels() {
	var labels = new clr.ArrayList();
	labels.Add("User version");
	labels.Add("System version");
	=> labels;
}

func PromptInstallKind(lastKindIn) {
	string lastKind = lastKindIn == null ? "" : lastKindIn.ToString().Trim();
	string defaultKey = "User version";
	if(lastKind == "System version") { defaultKey = "System version"; }

	string selection = clr.Console.Prompt(
		"Cursor Windows installer:",
		InstallKindLabels(),
		defaultKey
	);

	if(selection == "System version") { => "System version"; }
	=> "User version";
}

func CursorApiUrlForInstallKind(installKindIn) {
	string kind = installKindIn.ToString();
	if(kind == "System version") {
		=> "https://cursor.com/api/download?platform=win32-x64&releaseTrack=stable";
	}
	=> "https://cursor.com/api/download?platform=win32-x64-user&releaseTrack=stable";
}

func CursorPlatformLabelForInstallKind(installKindIn) {
	string kind = installKindIn.ToString();
	if(kind == "System version") { => "win32-x64"; }
	=> "win32-x64-user";
}

func DefaultExeNameForInstallKind(installKindIn) {
	string kind = installKindIn.ToString();
	if(kind == "System version") { => "CursorSetup-x64.exe"; }
	=> "CursorUserSetup-x64.exe";
}

func BuildDownloadLatestCursorConfig(installKindIn) {
	string installKind = installKindIn.ToString();
	=> new {
		downloadRoot: "R:\\",
		installKind: installKind,
		cursorApiUrl: CursorApiUrlForInstallKind(installKind),
		platformLabel: CursorPlatformLabelForInstallKind(installKind),
		defaultExeName: DefaultExeNameForInstallKind(installKind),
		aria2MaxConnections: 16,
		aria2Split: 16,
		aria2MinSplitSize: "1M"
	};
}

func EnsureDownloadDriveReady() {
	string root = (@cursorDlConfig -> "downloadRoot").ToString();

	try {
		var drive = new clr.System.IO.DriveInfo(root);
		if(!drive.IsReady) {
			mark("F65B3B", "Download drive is not available. Mount or connect " & root & " and try again.");
			=> false;
		}
		if(!clr.System.IO.Directory.Exists(root)) {
			mark("F65B3B", "Download folder does not exist: " & root);
			=> false;
		}
	}
	catch {
		mark("F65B3B", "Download drive is not available. Mount or connect " & root & " and try again.");
		=> false;
	}

	mark("5FD7AF", "Download folder OK: " & root);
	=> true;
}

func EscapePsSingleQuoted(valueIn) {
	string value = valueIn.ToString();
	=> value.Replstr("'", "''");
}

func GetDownloadLatestCursorPsTemplate() {
	=> <<<
& {
	$ErrorActionPreference = 'Stop';
	$downloadRoot = '@@DOWNLOAD_ROOT@@';
	$apiUrl = '@@API_URL@@';
	$platformLabel = '@@PLATFORM_LABEL@@';
	$defaultExeName = '@@DEFAULT_EXE@@';
	$maxConn = @@MAX_CONN@@;
	$split = @@SPLIT@@;
	$minSplit = '@@MIN_SPLIT@@';
	function Get-Aria2Path {
		$cmd = Get-Command aria2c.exe -ErrorAction SilentlyContinue;
		if ($cmd) { return $cmd.Source };
		$candidates = @(
			(Join-Path $env:ProgramFiles 'Aria2\aria2c.exe'),
			(Join-Path ${env:ProgramFiles(x86)} 'Aria2\aria2c.exe'),
			(Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\aria2c.exe')
		);
		foreach ($c in $candidates) {
			if (Test-Path -LiteralPath $c) { return $c };
		};
		return $null;
	};
	$aria2 = Get-Aria2Path;
	if (-not $aria2) {
		Write-Host 'aria2c not found on PATH or in common install locations.';
		Write-Host 'Install aria2 (e.g. winget install aria2) and ensure aria2c.exe is on PATH.';
		exit 1;
	};
	Write-Host ('Using aria2: ' + $aria2);
	Write-Host ('Resolving latest Cursor ' + $platformLabel + ' from: ' + $apiUrl);
	$meta = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing;
	if (-not $meta.downloadUrl) {
		Write-Host 'API response did not include downloadUrl.';
		exit 1;
	};
	$downloadUrl = [string]$meta.downloadUrl;
	$version = [string]$meta.version;
	$fileName = [IO.Path]::GetFileName(([Uri]$downloadUrl).LocalPath);
	if ([string]::IsNullOrWhiteSpace($fileName)) { $fileName = $defaultExeName };
	Write-Host ('Version: ' + $version);
	Write-Host ('URL: ' + $downloadUrl);
	Write-Host ('Destination: ' + (Join-Path $downloadRoot $fileName));
	Write-Host '';
	& $aria2 -d $downloadRoot -o $fileName -x $maxConn -s $split -k $minSplit --console-log-level=notice --summary-interval=1 $downloadUrl;
	$exitCode = $LASTEXITCODE;
	if ($exitCode -ne 0) { Write-Host ('aria2 exited with code ' + $exitCode); exit $exitCode };
	Write-Host '';
	Write-Host ('Saved: ' + (Join-Path $downloadRoot $fileName));
}
>>> ;
}

func BuildDownloadLatestCursorPowershell() {
	string ps = GetDownloadLatestCursorPsTemplate();
	string downloadRoot = EscapePsSingleQuoted((@cursorDlConfig -> "downloadRoot").ToString());
	string apiUrl = EscapePsSingleQuoted((@cursorDlConfig -> "cursorApiUrl").ToString());
	string platformLabel = EscapePsSingleQuoted((@cursorDlConfig -> "platformLabel").ToString());
	string defaultExe = EscapePsSingleQuoted((@cursorDlConfig -> "defaultExeName").ToString());
	int maxConn = (@cursorDlConfig -> "aria2MaxConnections");
	int split = (@cursorDlConfig -> "aria2Split");
	string minSplit = EscapePsSingleQuoted((@cursorDlConfig -> "aria2MinSplitSize").ToString());

	ps = ps.ReplStr("@@DOWNLOAD_ROOT@@", downloadRoot);
	ps = ps.ReplStr("@@API_URL@@", apiUrl);
	ps = ps.ReplStr("@@PLATFORM_LABEL@@", platformLabel);
	ps = ps.ReplStr("@@DEFAULT_EXE@@", defaultExe);
	ps = ps.ReplStr("@@MAX_CONN@@", maxConn.ToString());
	ps = ps.ReplStr("@@SPLIT@@", split.ToString());
	ps = ps.ReplStr("@@MIN_SPLIT@@", minSplit);

	=> ps;
}

func RunPowershellLive(psIn) {
	string ps = psIn.ToString();
	int exitCode = 1;

	if(ps.IsEmpty()) { => false; }

	try {
		var runner = clr.Ex.Powershell.Run(ps, []);
		exitCode = clr.System.Convert.ToInt32(runner.ExitCode);
	}
	catch {
		=> false;
	}

	=> exitCode == 0;
}

func GetUserConfigPath(fileName) {
	string root = clr.System.Environment.GetFolderPath(clr.System.Environment.SpecialFolder.UserProfile);
	string folder = root & "\\xs_config";
	if(!clr.System.IO.Directory.Exists(folder)) {
		clr.System.IO.Directory.CreateDirectory(folder);
	}
	=> folder & "\\" & fileName.ToString();
}

func LoadUserConfig(fileName, templateObj) {
	string path = GetUserConfigPath(fileName);
	var obj = templateObj;
	if(!clr.File.Exists(path)) { => obj; }
	try {
		obj = clr.Ex.Json.Deserialize(clr.File.ReadAllText(path), templateObj);
	}
	catch {
		obj = templateObj;
	}
	=> obj;
}

void SaveUserConfig(fileName, obj) {
	try {
		clr.File.WriteAllText(GetUserConfigPath(fileName), clr.Ex.Json.Serialize(obj));
	}
	catch { }
}

void mark(color, content) {
	clr.Ex.Console.Markup("[#" & color & "]"
		& content.ToString().ReplStr("[", "").ReplStr("]", "").ReplStr("[/]", "")
		& "[/]\r\n"
	);
}
