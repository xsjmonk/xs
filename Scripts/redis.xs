import System.IO.File as File
import Ex.Console as Console
import System.Collections.ArrayList as Array;
import System.String as String;
import System.Collections.Generic.Dictionary`2[System.String,System.Object] as Dictionary
import System.DateTime as DateTime;
import System.Collections.ArrayList as ArrayList
import Spectre.Console.AnsiConsole as AnsiConsole
import System.StringSplitOptions as SOption

string jsonFileName = clr.System.IO.Path.Combine(clr.System.IO.Path.GetTempPath(), clr.System.IO.Path.GetRandomFileName() & ".json");
string ip = [p1];
if(clr.String.IsNullOrEmpty(ip)) {
	ip = clr.Console.Ask("What ip to look up? \r\n");
}

_ Run(Command(jsonFileName, ip));
string json = clr.File.ReadAllText(jsonFileName);

mark("20AAFF", "Deserialize json " & jsonFileName);
ParseJsonAndDisplay(json);

clr.File.Delete(jsonFileName);

=> null;

void ParseJsonAndDisplay(json) {
	var ip_counts = (clr.ArrayList)clr.Ex.Json.Deserialize((string)json, jsonTemplates());
	ip_counts = ip_counts.orderby().where("Int32(it.Count) > 0");
	var dto = Dto();
	for(int i = 0; i < ip_counts.Count; i++) {
		dto = ip_counts[i];
		mark("38D6E2", "Get Ip: " & dto.Ip);
		dto.Country = RunRedis("--raw HGET \"IpCountry:" & dto.Ip & "\" " & "\"IpCountry:" & dto.Ip & "\"").ToString().Trim();
	}

	if(ip_counts.Count > 0) { toTable(ip_counts); }
	else { mark("F79898", "No record"); }
}

func Command(fileName, ip) {
	StringBuilder s = <<<

$redisHost = "__host__"
$redisPort = 6379
$redisExe = "C:\\Program Files\\Redis\\redis-cli.exe"
$topVisitedLimit = 500
$results = @()

$ipKeys = & $redisExe -h $redisHost -p $redisPort KEYS ipvisits:ip_to_be_replaced* | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

foreach ($ipKey in $ipKeys) {
    [Console]::Error.WriteLine("Processing ${ipKey}...")
    try {
        $visits = & $redisExe -h $redisHost -p $redisPort HGET $ipKey visits
        $userAgent = & $redisExe -h $redisHost -p $redisPort HGET $ipKey useragent
        $ip = $ipKey -replace '^ipvisits:', ''

        if ($ip -match '^\d+') {
            $results += [PSCustomObject]@{
                Ip = $ip
                Count = [int]$visits
                UserAgent = $userAgent
                Country = ""
            }
            if ($results.Count -ge $topVisitedLimit) { break }
        } else {
            [Console]::Error.WriteLine("Invalid visits value for ${ipKey}: '$visits'")
        }
    } catch {
        [Console]::Error.WriteLine("Failed to process ${ipKey}: $($_.Exception.Message)")
    }
}


$jsonArray = if ($results.Count -eq 0) {
		'[]'
} elseif ($results.Count -eq 1) {
		"[$($results | ConvertTo-Json -Depth 2 -Compress)]"
} else {
		$results | ConvertTo-Json -Depth 2 -Compress
}

[Console]::Error.WriteLine("Output json ...")
Set-Content -Path "my_file_name" -Value $jsonArray -Encoding UTF8


	>>>;
	_ s.Replace("my_file_name", fileName.ToString().Replace("\\", "\\\\"));
	_ s.Replace("ip_to_be_replaced", ip.ToString());
	=> s;
}


func Dto() {
	=> new {Count = 1, Ip= "", Country: "", UserAgent= "" };
}

/* -------Reusable dto to a Table display -------
	data: an ArrayList
-------------------------------------------------*/
void toTable(data) {
	var propNames = data[0]
							.GetType().GetProperties(clr.System.Reflection.BindingFlags.Public | clr.System.Reflection.BindingFlags.Instance)
							.Arr().select("it.Name");

	// Draw header
	var table = clr.Console.Table(propNames, "LeftAligned");
	table.ShowRowSeparators = true;
	var column = table.Columns.Arr()[1];
	column.NoWrap = true;
	
	// Draw rows
	var dtos = (clr.System.Collections.ArrayList)data;
	var values = [];
	for(int i = 0; i < dtos.Count; i++) {
		values = GetDtoValueAsArrayList(dtos[i]);
		table = clr.Ex.Console.AddRow(table, values);
	}
	table.Border = clr.Spectre.Console.TableBorder.Square;
	clr.Spectre.Console.AnsiConsole.Write(table);
}

// Functionality: { Count:10, Ip:"192.168" } => [10, "192.168"]
func GetDtoValueAsArrayList(dto) {
	// Assume - dto: new { Count:10, Ip:"192.168" }
	// propNames - [ "Count", "Ip" ]
	var propNames = dto.GetType().GetProperties(clr.System.Reflection.BindingFlags.Public | clr.System.Reflection.BindingFlags.Instance)
							.Arr().select("it.Name");
	var values = [];
	for(int i = 0; i < propNames.Count; i++) {
		values.Add(dto -> propNames[i]); // Get values of the current dto object
	}
	return values;
}
/* -------End of Reusable dto to a Table display -------*/

func getDtoPropNames() {
	var template = Dto();
	var props = getDtoProps();
	return props.select("it.Name"); // Select only property name as a string
}

func getDtoProps() {
	var template = Dto();
	var props = template.GetType()
									.GetProperties(
										clr.System.Reflection.BindingFlags.Public 
										| clr.System.Reflection.BindingFlags.Instance
									).Arr();
	return props;
}

func jsonTemplates() {
	=> [Dto()];
}

func RunRedis(command) {
	var p = new clr.System.Diagnostics.Process();
	p.StartInfo.WindowStyle = clr.System.Diagnostics.ProcessWindowStyle.Minimized;
	p.StartInfo.CreateNoWindow = true;
	p.StartInfo.UseShellExecute = false;
	p.StartInfo.RedirectStandardOutput = true;
	p.StartInfo.RedirectStandardError = true;
	p.StartInfo.FileName = "C:\\Program Files\\Redis\\redis-cli.exe";
	p.StartInfo.Arguments = "-h __host__ -p __port__ " & command;
	p.Start();

	var outputStream = p.StandardOutput.BaseStream;
	var ms = new clr.System.IO.MemoryStream();
	outputStream.CopyTo(ms);

	p.WaitForExit();

	outputStream.Dispose();
	p.Dispose();
	=> clr.System.Text.Encoding.UTF8.GetString(ms.ToArray());
}

func RunPowershellFromMemory(command) {
	var p = new clr.System.Diagnostics.Process();
	p.StartInfo.WindowStyle = clr.System.Diagnostics.ProcessWindowStyle.Minimized;
	p.StartInfo.CreateNoWindow = true;
	p.StartInfo.UseShellExecute = false;
	p.StartInfo.RedirectStandardOutput = true;
	p.StartInfo.RedirectStandardError = true;
	p.StartInfo.FileName = "powershell.exe";
	p.StartInfo.ArgumentList.Add("-NoLogo");
	p.StartInfo.ArgumentList.Add("-NoProfile");
	p.StartInfo.ArgumentList.Add("-NonInteractive");
	p.StartInfo.ArgumentList.Add("-ExecutionPolicy");
	p.StartInfo.ArgumentList.Add("Bypass");
	p.StartInfo.ArgumentList.Add("-Command");
	p.StartInfo.ArgumentList.Add("& {" & command & "}");
	p.Start();

	string stderrx = p.StandardError.ReadToEnd();
	var outputStream = p.StandardOutput.BaseStream;
	var ms = new clr.System.IO.MemoryStream();
	outputStream.CopyTo(ms);

	p.WaitForExit();
	if(!clr.System.String.IsNullOrEmpty(stderrx)) { 
		mark("CC3768", "====================Error stream starts====================");
		mark("B733F6", stderrx);
		mark("CC3768", "====================Error stream ends====================");
	}
	p.Dispose();
	outputStream.Dispose();
	string output = clr.System.Text.Encoding.UTF8.GetString(ms.ToArray());
	ms.Dispose();

	return output;
}


func GetIPCounts(keys) {
	var a = (clr.System.Collections.ArrayList) keys;
	var counts = new clr.System.Collections.ArrayList();
	int count = 0;
	for(int i=0; i < a.Count; i++) {
		count = clr.System.Int32.Parse(RunRedis("hget " & a.get_item(i) & " visits").ToString());
		counts.Add(count);
		clr.System.Console.WriteLine(a.get_item(i) & ": " & count );
	}
	=> counts;
}

func GetIndexOfMaxValue(array) {
	var a = (clr.System.Collections.ArrayList) array;
	int max = 1, value=0, index = 0;
	for(int i=0; i < a.Count; i++) {
		value = clr.System.Int32.Parse(a.get_item(i).ToString());
		if(max < value) {
			max = value;
			index = i;
		}
	}
	return index;
}

func Run(command) {
	var runner = clr.Ex.Powershell.Run(command.ToString(), null);
	return runner.StandardOutput;
}

func orderby(arr) { => clr.Dlinq.Linq.OrderBy(arr, "it.Count descending"); }
func take(arr, count) { => clr.Dlinq.Linq.Take(arr, clr.System.Int32.Parse(count.ToString() )); }
func where(arr, p) { => clr.Dlinq.Linq.Where(arr, p.ToString() ) ; }
func select(arr, prop) { => clr.Dlinq.Linq.Select(arr, prop.ToString()); }
func first(arr, p) { => clr.Dlinq.FirstOrDefault(arr, p.ToString()); }
func orderby(arr, by) { => clr.Dlinq.OrderBy(arr, by.ToString() ); }
func any(arr, p) { => clr.Dlinq.Any(arr, p) ; }

void mark(color, content) {
	clr.Ex.Console.Markup("[#" & color & "]"
		& content.ReplStr("[", "").ReplStr("]", "").ReplStr("[/]", "")
		& "[/]\r\n"
	);
}