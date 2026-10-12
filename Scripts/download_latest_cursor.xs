import Ex.Console as Console;
import Ex.Powershell as Powershell;

func BuildDownloadLatestCursorConfig() {
	=> new {
		downloadRoot: "R:\\",
		cursorApiUrl: "https://cursor.com/api/download?platform=win32-x64-user&releaseTrack=stable",
		aria2MaxConnections: 16,
		aria2Split: 16,
		aria2MinSplitSize: "1M"
	};
}

@cursorDlConfig = BuildDownloadLatestCursorConfig();

mark("2B91AF", "Download latest Cursor (Windows x64 User installer, stable)");

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
	Write-Host ('Resolving latest Cursor win32-x64-user from: ' + $apiUrl);
	$meta = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing;
	if (-not $meta.downloadUrl) {
		Write-Host 'API response did not include downloadUrl.';
		exit 1;
	};
	$downloadUrl = [string]$meta.downloadUrl;
	$version = [string]$meta.version;
	$fileName = [IO.Path]::GetFileName(([Uri]$downloadUrl).LocalPath);
	if ([string]::IsNullOrWhiteSpace($fileName)) { $fileName = 'CursorUserSetup-x64.exe' };
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
	int maxConn = (@cursorDlConfig -> "aria2MaxConnections");
	int split = (@cursorDlConfig -> "aria2Split");
	string minSplit = EscapePsSingleQuoted((@cursorDlConfig -> "aria2MinSplitSize").ToString());

	ps = ps.ReplStr("@@DOWNLOAD_ROOT@@", downloadRoot);
	ps = ps.ReplStr("@@API_URL@@", apiUrl);
	ps = ps.ReplStr("@@MAX_CONN@@", maxConn.ToString());
	ps = ps.ReplStr("@@SPLIT@@", split.ToString());
	ps = ps.ReplStr("@@MIN_SPLIT@@", minSplit);

	=> ps;
}

func RunPowershellLive(psIn) {
	string ps = psIn.ToString();

	if(ps.IsEmpty()) { => false; }

	try {
		_ clr.Ex.Powershell.Run(ps, []);
	}
	catch {
		=> false;
	}

	=> true;
}

void mark(color, content) {
	clr.Ex.Console.Markup("[#" & color & "]"
		& content.ToString().ReplStr("[", "").ReplStr("]", "").ReplStr("[/]", "")
		& "[/]\r\n"
	);
}
