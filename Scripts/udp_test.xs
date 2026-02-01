import System.String as String

string hostPorts = [p1];

var prm = GetHostAndPorts(hostPorts);
string ip = prm..host.ToString();
string portsCsv = prm..portsCsv.ToString();

StringBuilder ps = BuildUdpProbePs(ip, portsCsv);

_ Run(ps);

=> "Done";

func GetHostAndPorts(p1) {
	string input = "", host = "", ports = "";
	var parts = "".Split(":".ToCharArray(), clr.System.StringSplitOptions.RemoveEmptyEntries).ToArrayList();

	if(p1 != null) { input = p1.ToString(); }
	input = input.Trim();

	while(clr.String.IsNullOrEmpty(input)) {
		input = clr.Ex.Console.Ask("Please give host:port or host:port1,port2,...\r\n").Trim();
	}

	if(input.Contains(":")) {
		parts = input.Split(":".ToCharArray(), clr.System.StringSplitOptions.RemoveEmptyEntries).ToArrayList();
		if(parts.Count >= 2) {
			host = parts.get_item(0).ToString().Trim();
			ports = parts.get_item(1).ToString().Trim();
		}
	} else {
		host = input.Trim();
		ports = "";
	}

	while(clr.String.IsNullOrEmpty(host)) {
		host = clr.Ex.Console.Ask("Please give host?\r\n").Trim();
	}

	while(clr.String.IsNullOrEmpty(ports)) {
		ports = clr.Ex.Console.Ask("Please give port list (e.g. 3478 or 3478,3479)\r\n").Trim();
	}

	ports = ports.Replstr(" ", "");
	while(ports.EndsWith(",")) {
		ports = ports.Substring(0, ports.Length - 1);
	}

	while(clr.String.IsNullOrEmpty(ports)) {
		ports = clr.Ex.Console.Ask("Please give port list (e.g. 3478 or 3478,3479)\r\n").Trim();
		ports = ports.Replstr(" ", "");
		while(ports.EndsWith(",")) {
			ports = ports.Substring(0, ports.Length - 1);
		}
	}

	=> new { host: host, portsCsv: ports };
}

func BuildUdpProbePs(host, portsCsv) {
	string h = host.ToString().Trim();
	string p = portsCsv.ToString().Trim();

	StringBuilder ps =<<<
& {
	$ErrorActionPreference = 'Stop'
	$ip='__UDP_HOST__'
	$ports=__UDP_PORTS__

	foreach($p in $ports){
		$c=$null
		$rng=$null
		try{
			$c=[System.Net.Sockets.UdpClient]::new()
			$c.Client.ReceiveTimeout=2500
			$c.Connect($ip,[int]$p)

			$tx = New-Object byte[] 20
			$tx[0]=0x00; $tx[1]=0x01
			$tx[2]=0x00; $tx[3]=0x00
			$tx[4]=0x21; $tx[5]=0x12; $tx[6]=0xA4; $tx[7]=0x42

			$rnd = New-Object byte[] 12
			$rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
			$rng.GetBytes($rnd)
			[Array]::Copy($rnd,0,$tx,8,12)

			[void]$c.Send($tx,$tx.Length)

			$remote = [System.Net.IPEndPoint]::new([System.Net.IPAddress]::Any,0)
			$r = $c.Receive([ref]$remote)

			"OK  ${ip}:$p  from=$($remote.Address):$($remote.Port)  respLen=$($r.Length)"
		} catch {
			"TIMEOUT ${ip}:$p  $($_.Exception.Message)"
		} finally {
			if($rng){$rng.Dispose()}
			if($c){$c.Close();$c.Dispose()}
		}
	}
}
>>>;

	_ ps.Replace("__UDP_HOST__", h);
	_ ps.Replace("__UDP_PORTS__", p);

	=> ps;
}

func Run(command) {
	var runner = clr.Ex.Powershell.Run(command.ToString());
	return runner.StandardOutput;
}
