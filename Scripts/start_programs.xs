import System.Environment as Env;
import Ex.Console as Console;
import Ex.Powershell as Powershell
import System.String as String;
import Newtonsoft.Json.JsonConvert as JsonConvert
import Newtonsoft.Json.Formatting as Formatting
import System.IO.File as File;
import Ex.Powershell as pwsh
import System.String as Str;

StartWslIfNotRunning();

string folder = <<<c:\Docs\Green\ProxiFyre-improve\>>>.Trim();
EnsureProxiFyreUdpConfig(folder);

Launch(<<<c:\Docs\Green\CpuHzTray\CpuHzTray.exe>>>.Trim());

CheckServiceMustBeDisabled("dptftcs");
CheckServiceMustBeDisabled("IntuneManagementExtension");


=> null;


void CheckServiceMustBeDisabled(serviceName) {
	string name = "", out = "", tag = "", mode = "", state = "", disp = "", msg = "";
	string disOut = "", disTag = "", disMsg = "";
	var parts = null.ToArrayList();
	var disParts = null.ToArrayList();
	bool isIme = false;

	if(serviceName != null) { name = serviceName.ToString(); }
	name = name.Trim();

	if(name.IsEmpty()) {
		mark("FF5C5C", "Service check failed: empty service name");
		return;
	}

	StringBuilder psCmd =<<<
$name='__NAME__';
$tag='NOTFOUND'; $mode=''; $state=''; $disp='';
try {
	$c=Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $name) -ErrorAction SilentlyContinue;
	if($c){
		$tag='OK';
		$mode=$c.StartMode;
		$state=$c.State;
		$disp=$c.DisplayName;
	}
} catch {}

if($tag -ne 'OK'){
	try {
		$s=Get-Service -Name $name -ErrorAction Stop;
		$tag='OK';
		$state=$s.Status.ToString();
		$disp=$s.DisplayName;
		$start=(Get-ItemProperty -Path ("HKLM:\SYSTEM\CurrentControlSet\Services\{0}" -f $name) -Name Start -ErrorAction SilentlyContinue).Start;
		if($start -eq 4){ $mode='Disabled'; }
		elseif($start -eq 3){ $mode='Manual'; }
		elseif($start -eq 2){ $mode='Auto'; }
		elseif($start -eq 1){ $mode='System'; }
		elseif($start -eq 0){ $mode='Boot'; }
	}
	catch {}
}

Write-Output ('{0}|{1}|{2}|{3}' -f $tag,$mode,$state,$disp);
>>>;

	out = RunPowershellFromMemory(psCmd.ReplStr("__NAME__", name), false).ToString().Trim();

	if(out.IsEmpty()) {
		mark("FF5C5C", "Service '" & name & "' check failed: empty result");
		return;
	}

	parts = out.Split("|".ToCharArray(), clr.System.StringSplitOptions.None).ToArrayList();
	if(parts.Count >= 1 && parts[0] != null) { tag = parts[0].ToString().Trim(); }
	if(parts.Count >= 2 && parts[1] != null) { mode = parts[1].ToString().Trim(); }
	if(parts.Count >= 3 && parts[2] != null) { state = parts[2].ToString().Trim(); }
	if(parts.Count >= 4 && parts[3] != null) { disp = parts[3].ToString().Trim(); }

	if(!clr.Str.Equals(tag, "OK", clr.System.StringComparison.OrdinalIgnoreCase)) {
		mark("FF5C5C", "Service '" & name & "' not found or unreadable");
		return;
	}

	msg =
		"Service '" & name & "' (" & disp & ") " &
		"StartMode=" & mode & " State=" & state;

	isIme = clr.Str.Equals(name, "IntuneManagementExtension", clr.System.StringComparison.OrdinalIgnoreCase);

	if(!clr.Str.Equals(mode, "Disabled", clr.System.StringComparison.OrdinalIgnoreCase)) {
		mark("FF5C5C", msg);

		if(isIme) {
			disOut = DisableService(name).Trim();

			if(disOut.IsEmpty()) {
				mark("FF5C5C", "Service '" & name & "' disable failed: empty result");
				return;
			}

			disParts = disOut.Split("|".ToCharArray(), clr.System.StringSplitOptions.None).ToArrayList();
			if(disParts.Count >= 1 && disParts[0] != null) { disTag = disParts[0].ToString().Trim(); }
			if(disParts.Count >= 2 && disParts[1] != null) { disMsg = disParts[1].ToString().Trim(); }

			if(!clr.Str.Equals(disTag, "OK", clr.System.StringComparison.OrdinalIgnoreCase)) {
				mark("FF5C5C", "Service '" & name & "' disable failed: " & disMsg);
				return;
			}

			mark("5FD7AF", "Service '" & name & "' disable requested");

			out = RunPowershellFromMemory(psCmd.ReplStr("__NAME__", name), false).ToString().Trim();
			if(!out.IsEmpty()) {
				tag = ""; mode = ""; state = ""; disp = ""; parts = null.ToArrayList();
				parts = out.Split("|".ToCharArray(), clr.System.StringSplitOptions.None).ToArrayList();
				if(parts.Count >= 1 && parts[0] != null) { tag = parts[0].ToString().Trim(); }
				if(parts.Count >= 2 && parts[1] != null) { mode = parts[1].ToString().Trim(); }
				if(parts.Count >= 3 && parts[2] != null) { state = parts[2].ToString().Trim(); }
				if(parts.Count >= 4 && parts[3] != null) { disp = parts[3].ToString().Trim(); }

				if(clr.Str.Equals(tag, "OK", clr.System.StringComparison.OrdinalIgnoreCase)) {
					msg =
						"Service '" & name & "' (" & disp & ") " &
						"StartMode=" & mode & " State=" & state;

					if(!clr.Str.Equals(mode, "Disabled", clr.System.StringComparison.OrdinalIgnoreCase)) {
						mark("FF5C5C", msg);
					} else {
						mark("5FD7AF", msg);
					}
				}
			}
		}

	} else {
		mark("5FD7AF", msg);
	}
}

func DisableService(serviceName) {
	string name = "", out = "";

	if(serviceName != null) { name = serviceName.ToString(); }
	name = name.Trim();

	if(name.IsEmpty()) { => "ERR|empty service name"; }

	StringBuilder ps =<<<
$name='__NAME__';
try {
	$svc = Get-Service -Name $name -ErrorAction Stop;
	try { Stop-Service -Name $name -Force -ErrorAction SilentlyContinue; } catch {}
	Set-Service -Name $name -StartupType Disabled -ErrorAction Stop;
	Write-Output ('OK|disabled');
} catch {
	Write-Output ('ERR|{0}' -f $_.Exception.Message);
}
>>>;

	out = RunPowershellFromMemory(ps.ReplStr("__NAME__", name), false).ToString();
	=> out;
}

void StartWslIfNotRunning() {
	mark("00A4EF", "Start wsl");
	Run(<<<
& {
	$ErrorActionPreference='Stop';
	$distro='Ubuntu-20.04';
	$running = wsl.exe -l -v | Select-String "^\s*$distro\s+Running";
	if(-not $running){
		wsl.exe -d $distro -u root /usr/local/sbin/wsl-net-setup.sh;
	}
}
>>>);
}

void EnsureProxiFyreUdpConfig(folder) {
	string configPath = folder & "app-config.json";

	mark("5FD7AF", "Deserializing JSON with template...");
	var cfg = clr.Ex.Json.Deserialize(clr.File.ReadAllText(configPath), BuildConfigTpl());

	string wslIp = GetWslIp();
	mark("5FD7AF", "WSL IP detected: " & wslIp);

	string endpoint = wslIp & ":1080";
	mark("5FD7AF", "Updating UDP proxy endpoints to: " & endpoint);

	cfg = UpdateUdpProxyEndpoints(cfg, endpoint);

	string outJson = clr.JsonConvert.SerializeObject(cfg, clr.Formatting.Indented);
	clr.File.WriteAllText(configPath, outJson);

	print_json((string)clr.JsonConvert.SerializeObject(cfg.proxies[1], clr.Formatting.Indented));
}

void EnableHostIPRouter() {
	mark("F65B3B", "Enable IPEnableRouter");
	string sb = RunPowershellFromMemory("Set-ItemProperty -Path \"HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\" -Name \"IPEnableRouter\" -Value 1", false);
	mark("CC3768", sb);
}

void Launch(exe) {
	mark("5FD7AF", "Launching " & exe.ToString());
	_ clr.pwsh.Run(<<<
	& {
		$exe = '[exe_path]'
		$name = [System.IO.Path]::GetFileNameWithoutExtension($exe)

		if (-not (Get-Process -Name $name -ErrorAction SilentlyContinue)) {
			Start-Process -FilePath $exe
		}
	}
	>>>.ReplStr("[exe_path]", exe.ToString()), null);
}

void Run(command) {
	_ clr.Powershell.Run(command.ToString(), []);
}

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

func getRouteTableCommand() {
	=> <<<
& {
    $listenPort = 50808
    $listenAddr = '0.0.0.0'
    $connectPort = 1080
    $connectAddr = '127.0.0.1'

    $existing = netsh interface portproxy show v4tov4 | Select-String "Listen on IPv4:.*$listenPort"
    if ($existing) {
        Write-Host "Existing rule for port $listenPort found. Deleting..."
        netsh interface portproxy delete v4tov4 listenport=$listenPort listenaddress=$listenAddr | Out-Null
        Write-Host "Old rule deleted."
    } else {
        Write-Host "No existing rule for port $listenPort found."
    }

    Write-Host "Creating new rule..."
    netsh interface portproxy add v4tov4 listenport=$listenPort listenaddress=$listenAddr connectport=$connectPort connectaddress=$connectAddr | Out-Null
    Write-Host "New rule created successfully."

    Write-Host "`nCurrent portproxy rules:"
    netsh interface portproxy show v4tov4
}

>>>;
}

func GetWslIp() {
	string ip = "", out = "";

	StringBuilder ps =<<<
& { $ErrorActionPreference='Stop'; $out=''; $ip=''; `
  $cmd1="ip -4 -o addr show dev eth0 scope global 2>/dev/null | awk '{print `$4}' | cut -d/ -f1 | head -n 1"; `
  $out=(wsl.exe -e sh -lc $cmd1) 2>$null; `
  if($out){ $ip=$out.Trim(); } `
  if(-not $ip){ $out=(wsl.exe hostname -I) 2>$null; if($out){ $ip=$out.Trim(); } } `
  if(-not $ip){ throw 'empty'; } `
  ($ip -replace "`r|`n",'').Trim().Split(@(' ', "`t"), [System.StringSplitOptions]::RemoveEmptyEntries)[0] }
>>>;

	out = RunPowershellFromMemory(ps, false).ToString();
	ip = out.Trim();
	=> ip;
}

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

func UpdateUdpProxyEndpoints(objCfg, udpProxy) {
	var cfg = BuildConfigTpl(), proxy = BuildProxyTpl();
	cfg = objCfg;

	string endpoint = udpProxy.ToString();
	var protosArr = null.ToArrayList();

	string old = "";
	bool hasUdp = false;

	for(int i = 0; i < cfg.proxies.Count; i++) {
		proxy = cfg.proxies[i];
		protosArr = proxy.supportedProtocols.ToArrayList();

		hasUdp = false;
		for(int j = 0; j < protosArr.Count; j = j + 1) {
			if(clr.Str.Equals(protosArr[j].ToString(), "UDP", clr.System.StringComparison.OrdinalIgnoreCase)) {
				hasUdp = true;
				break;
			}
		}

		if(hasUdp) {
			old = "";
			if(proxy.socks5ProxyEndpoint != null) { old = proxy.socks5ProxyEndpoint.ToString(); }

			if(!clr.Str.Equals(old, endpoint, clr.System.StringComparison.OrdinalIgnoreCase)) {
				proxy.SetProperty("socks5ProxyEndpoint", endpoint);
				mark("5FD7AF", proxy.appNames & old & " -> " & endpoint);
			}
		}
	}
	=> cfg;
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
		try { json = clr.Newtonsoft.Json.JsonConvert.SerializeObject(obj, clr.Newtonsoft.Json.Formatting.Indented); }
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
		& content.ToString().ReplStr("[", "").ReplStr("]", "").ReplStr("[/]", "")
		& "[/]\r\n"
	);
}