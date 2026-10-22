import Ex.Console as Console;
import System.IO.File as File;
import System.Collections.ArrayList as ArrayList;
import Ex.LiveProgressConsole as LiveProgressConsole;

@cfg = new {
	sqlite: "sqlite3.exe",
	sqlitePath: "___.db",
	progressTitle: "Redis picture-count export",
	legacyStagingPrefix: "___:v1:__exporting__",
	redisKeyBatchSize: 50,
	redisScanPageSize: 1000,
	claimSequence: 0,
	configuredKeyCount: 0,
	initialStagingKeyCount: 0,
	exportWorkTotal: 0,
	validRedisKeyCount: 0,
	aggregateRowCount: 0,
	verifiedKeyCount: 0,
	deadKeyCount: 0,
	failedKeyCount: 0,
	readFailed: 0,
	nonHash: 0,
	schemaInvalid: 0,
	valueInvalid: 0,
	sqliteFailed: 0,
	verifyFailed: 0,
	deleteFailed: 0,
	deleted: 0,
	deadDeleted: 0,
	hashReadOk: false,
	lastBatchDistinct: 0,
	exportDisposition: "",
	exportStage: "",
	exportStagedKey: "",
	exportError: "",
	exportClaimed: false,
	exportRow: null,
	exportScannedSoFar: 0,
	runImported: 0,
	runFailed: 0,
	runSkipped: 0,
	runPending: 0,
	runClaimed: 0,
	sqliteRowsCommitted: 0,
	progressStep: 1,
	failureLog: "",
	failureMessageCount: 0,
	colors: new {
		red: "FF005F",
		green: "5FD7AF",
		blue: "3399FF",
		yellow: "FFAF00"
	},
	redis: null
};
@cfg.redis = CreateRedisConnectionConfig();

var summary = RunExport();
=> summary;

func ResolveRedisCliExecutable() {
	var candidates = new clr.System.Collections.ArrayList();
	candidates.Add("C:\\Program Files\\Redis\\redis-cli.exe");
	candidates.Add("C:\\ProgramData\\chocolatey\\lib\\redis\\tools\\redis-cli.exe");
	for(int i = 0; i < candidates.Count; i++) {
		string candidate = candidates[i].ToString();
		if(clr.System.IO.File.Exists(candidate)) {
			=> candidate;
		}
	}
	=> "redis-cli.exe";
}

func CreateRedisConnectionConfig() {
	var normalPrefixes = new clr.System.Collections.ArrayList();
	normalPrefixes.Add("___:piccount:v1:");
	normalPrefixes.Add("___:piccount:v1:");
	var stagingPrefixes = new clr.System.Collections.ArrayList();
	stagingPrefixes.Add("___:piccount:v1:__exporting:");
	stagingPrefixes.Add("___:piccount:v1:__exporting:");
	=> new {
		Executable: ResolveRedisCliExecutable(),
		Host: "192.168.___.___",
		Port: 6379,
		Database: 0,
		Password: "___",
		NormalPrefixes: normalPrefixes,
		StagingPrefixes: stagingPrefixes
	};
}

func RunProcess(executable, arguments, standardInputText) {
	var process = new clr.System.Diagnostics.Process();
	process.StartInfo.FileName = executable.ToString();
	process.StartInfo.UseShellExecute = false;
	process.StartInfo.CreateNoWindow = true;
	process.StartInfo.RedirectStandardOutput = true;
	process.StartInfo.RedirectStandardError = true;
	process.StartInfo.RedirectStandardInput = standardInputText != null;
	var argumentList = process.StartInfo.ArgumentList;
	var argArray = (clr.System.Collections.ArrayList)arguments;
	for(int i = 0; i < argArray.Count; i++) {
		argumentList.Add(argArray[i].ToString());
	}
	process.Start();
	if(standardInputText != null) {
		process.StandardInput.Write(standardInputText.ToString());
		process.StandardInput.Close();
	}
	string stdoutText = process.StandardOutput.ReadToEnd();
	string stderrText = process.StandardError.ReadToEnd();
	process.WaitForExit();
	int exitCode = process.ExitCode;
	process.Dispose();
	=> new { ExitCode: exitCode, StdOut: stdoutText, StdErr: stderrText };
}

func RunRedis(operationArguments) {
	=> RunRedisCore(operationArguments, false);
}

func RunRedisQuiet(operationArguments) {
	=> RunRedisCore(operationArguments, true);
}

func RunRedisCore(operationArguments, quiet) {
	var args = new clr.System.Collections.ArrayList();
	args.Add("-h"); args.Add(@cfg.redis.Host.ToString());
	args.Add("-p"); args.Add(@cfg.redis.Port.ToString());
	args.Add("-n"); args.Add(@cfg.redis.Database.ToString());
	args.Add("-a"); args.Add(@cfg.redis.Password.ToString());
	args.Add("--no-auth-warning"); args.Add("--raw");
	var operation = (clr.System.Collections.ArrayList)operationArguments;
	for(int i = 0; i < operation.Count; i++) { args.Add(operation[i].ToString()); }
	var result = RunProcess(@cfg.redis.Executable, args, null);
	if(result.ExitCode != 0) {
		if(!quiet) {
			mark(@cfg.colors.red, "redis-cli failed with exit code " & result.ExitCode);
		}
		=> new { Ok: false, Output: "", Error: result..StdErr, ExitCode: result..ExitCode };
	}
	=> new { Ok: true, Output: result..StdOut, Error: "", ExitCode: 0 };
}

func RunSqlite(sqlText) {
	var args = new clr.System.Collections.ArrayList();
	args.Add(@cfg.sqlitePath.ToString());
	var result = RunProcess(@cfg.sqlite, args, sqlText);
	if(result.ExitCode != 0) {
		mark(@cfg.colors.red, "sqlite3 failed with exit code " & result.ExitCode);
		=> new { Ok: false, Output: "", Error: result..StdErr, ExitCode: result..ExitCode };
	}
	=> new { Ok: true, Output: result..StdOut, Error: "", ExitCode: 0 };
}

func EnsureSqliteDatabase() {
	string parent = clr.System.IO.Path.GetDirectoryName(@cfg.sqlitePath.ToString());
	if(!clr.System.String.IsNullOrEmpty(parent) && !clr.System.IO.Directory.Exists(parent)) {
		clr.System.IO.Directory.CreateDirectory(parent);
	}
	string schema = <<<
PRAGMA journal_mode=WAL;
PRAGMA busy_timeout=30000;
CREATE TABLE IF NOT EXISTS PicCount (
	source_key TEXT NOT NULL, variant TEXT NOT NULL, source_path TEXT NOT NULL,
	total_count INTEGER NOT NULL DEFAULT 0, last_visit_utc INTEGER NOT NULL DEFAULT 0,
	schema_version INTEGER NOT NULL DEFAULT 1, imported_utc INTEGER NOT NULL DEFAULT 0,
	PRIMARY KEY (source_key, variant));
CREATE INDEX IF NOT EXISTS IX_PicCount_LastVisit ON PicCount(last_visit_utc);
CREATE INDEX IF NOT EXISTS IX_PicCount_SourcePath ON PicCount(source_path);

>>>;
	var result = RunSqlite(schema);
	=> result.Ok;
}

func ScanKeys(pattern) {
	var keys = new clr.System.Collections.ArrayList();
	string cursor = "0", error = "";
	int calls = 0;
	bool ok = true;
	for(int round = 0; round < 100000 && (round == 0 || cursor != "0"); round++) {
		var args = new clr.System.Collections.ArrayList();
		args.Add("SCAN"); args.Add(cursor); args.Add("MATCH"); args.Add(pattern.ToString());
		args.Add("COUNT"); args.Add(@cfg.redisScanPageSize.ToString());
		var result = RunRedis(args);
		calls = calls + 1;
		if(!result.Ok) { ok = false; error = result.Error; break; }
		string response = result.Output.ToString().ReplStr("\r\n", "\n");
		var lines = response.Split("\n".ToCharArray(), clr.System.StringSplitOptions.RemoveEmptyEntries);
		if(lines.Length < 1) { ok = false; error = "SCAN returned no cursor"; break; }
		cursor = lines[0].ToString().Trim();
		if(!IsMatch(cursor, "^[0-9]+$")) { ok = false; error = "SCAN returned invalid cursor"; break; }
		for(int i = 1; i < lines.Length; i++) {
			string key = lines[i].ToString().Trim();
			if(!key.IsEmpty()) { AddUnique(keys, key); }
		}
	}
	if(cursor != "0" && calls >= 100000) { ok = false; error = "SCAN exceeded bounded cursor calls"; }
	=> new { Ok: ok, Keys: keys, Error: error, Pattern: pattern.ToString(), Calls: calls };
}

func CountScanKeys(pattern, skipStagingKeys, stagingPrefixes) {
	var seenKeys = new clr.System.Collections.Hashtable();
	string cursor = "0", error = "";
	int calls = 0, count = 0;
	bool ok = true;
	for(int round = 0; round < 100000 && (round == 0 || cursor != "0"); round++) {
		var args = new clr.System.Collections.ArrayList();
		args.Add("SCAN"); args.Add(cursor); args.Add("MATCH"); args.Add(pattern.ToString());
		args.Add("COUNT"); args.Add(@cfg.redisScanPageSize.ToString());
		var result = RunRedis(args);
		calls = calls + 1;
		if(!result.Ok) { ok = false; error = result.Error; break; }
		string response = result.Output.ToString().ReplStr("\r\n", "\n");
		var lines = response.Split("\n".ToCharArray(), clr.System.StringSplitOptions.RemoveEmptyEntries);
		if(lines.Length < 1) { ok = false; error = "SCAN returned no cursor"; break; }
		cursor = lines[0].ToString().Trim();
		if(!IsMatch(cursor, "^[0-9]+$")) { ok = false; error = "SCAN returned invalid cursor"; break; }
		for(int i = 1; i < lines.Length; i++) {
			string key = lines[i].ToString().Trim();
			if(key.IsEmpty()) { continue; }
			if(skipStagingKeys && IsStagingKey(key, stagingPrefixes)) { continue; }
			if(seenKeys[key] != null) { continue; }
			seenKeys.Add(key, true);
			count = count + 1;
		}
	}
	if(cursor != "0" && calls >= 100000) { ok = false; error = "SCAN exceeded bounded cursor calls"; }
	=> new { Ok: ok, Count: count, Error: error, Pattern: pattern.ToString(), Calls: calls };
}

func ScanPatternInBatches(pattern, pass, skipStagingKeys, stagingPrefixes, normalPrefixes) {
	var batchKeys = new clr.System.Collections.ArrayList();
	string cursor = "0", error = "";
	int calls = 0, batchCount = 0;
	bool ok = true;
	for(int round = 0; round < 100000 && (round == 0 || cursor != "0"); round++) {
		var args = new clr.System.Collections.ArrayList();
		args.Add("SCAN"); args.Add(cursor); args.Add("MATCH"); args.Add(pattern.ToString());
		args.Add("COUNT"); args.Add(@cfg.redisScanPageSize.ToString());
		var result = RunRedis(args);
		calls = calls + 1;
		if(!result.Ok) { ok = false; error = result.Error; break; }
		string response = result.Output.ToString().ReplStr("\r\n", "\n");
		var lines = response.Split("\n".ToCharArray(), clr.System.StringSplitOptions.RemoveEmptyEntries);
		if(lines.Length < 1) { ok = false; error = "SCAN returned no cursor"; break; }
		cursor = lines[0].ToString().Trim();
		if(!IsMatch(cursor, "^[0-9]+$")) { ok = false; error = "SCAN returned invalid cursor"; break; }
		for(int i = 1; i < lines.Length; i++) {
			string key = lines[i].ToString().Trim();
			if(key.IsEmpty()) { continue; }
			if(skipStagingKeys && IsStagingKey(key, stagingPrefixes)) { continue; }
			if(!AddUnique(batchKeys, key)) { continue; }
			if(batchKeys.Count >= @cfg.redisKeyBatchSize) {
				var batchStats = ProcessExportBatch(batchKeys, pass, normalPrefixes, stagingPrefixes);
				@cfg.runImported = @cfg.runImported + batchStats..Imported;
				@cfg.runFailed = @cfg.runFailed + batchStats..Failed;
				@cfg.runSkipped = @cfg.runSkipped + batchStats..Skipped;
				@cfg.runPending = @cfg.runPending + batchStats..Pending;
				@cfg.runClaimed = @cfg.runClaimed + batchStats..Claimed;
				batchKeys = new clr.System.Collections.ArrayList();
				batchCount = batchCount + 1;
			}
		}
	}
	if(batchKeys.Count > 0) {
		var batchStats = ProcessExportBatch(batchKeys, pass, normalPrefixes, stagingPrefixes);
		@cfg.runImported = @cfg.runImported + batchStats..Imported;
		@cfg.runFailed = @cfg.runFailed + batchStats..Failed;
		@cfg.runSkipped = @cfg.runSkipped + batchStats..Skipped;
		@cfg.runPending = @cfg.runPending + batchStats..Pending;
		@cfg.runClaimed = @cfg.runClaimed + batchStats..Claimed;
		batchKeys = new clr.System.Collections.ArrayList();
		batchCount = batchCount + 1;
	}
	if(cursor != "0" && calls >= 100000) { ok = false; error = "SCAN exceeded bounded cursor calls"; }
	=> new { Ok: ok, Error: error, Pattern: pattern.ToString(), Calls: calls, Batches: batchCount };
}

func PingRedis() {
	var args = new clr.System.Collections.ArrayList();
	args.Add("PING");
	var result = RunRedis(args);
	=> result.Ok && result.Output.ToString().Trim() == "PONG";
}

func RedisType(key) {
	var args = new clr.System.Collections.ArrayList();
	args.Add("TYPE"); args.Add(key.ToString());
	var result = RunRedisQuiet(args);
	if(!result.Ok) { => ""; }
	=> result.Output.ToString().Trim();
}

func IsStagingKey(key, prefixes) {
	if(key.ToString().StartsWith(@cfg.legacyStagingPrefix)) { => true; }
	var list = (clr.System.Collections.ArrayList)prefixes;
	for(int i = 0; i < list.Count; i++) {
		if(key.ToString().StartsWith(list[i].ToString())) { => true; }
	}
	=> false;
}

func AddUnique(items, value) {
	var list = (clr.System.Collections.ArrayList)items;
	for(int i = 0; i < list.Count; i++) {
		if(list[i].ToString() == value.ToString()) { => false; }
	}
	list.Add(value);
	=> true;
}

func StagingPrefixForKey(key, normalPrefixes, stagingPrefixes) {
	var normals = (clr.System.Collections.ArrayList)normalPrefixes;
	var stagings = (clr.System.Collections.ArrayList)stagingPrefixes;
	for(int i = 0; i < normals.Count && i < stagings.Count; i++) {
		if(key.ToString().StartsWith(normals[i].ToString())) { => stagings[i].ToString(); }
	}
	=> stagings[0].ToString();
}

func ReadHash(key) {
	@cfg.hashReadOk = false;
	var args = new clr.System.Collections.ArrayList();
	args.Add("HGETALL"); args.Add(key.ToString());
	var result = RunRedisQuiet(args);
	var hash = new clr.System.Collections.Hashtable();
	if(!result.Ok) { => hash; }
	var values = result.Output.ToString().ReplStr("\r\n", "\n")
		.Split("\n".ToCharArray(), clr.System.StringSplitOptions.RemoveEmptyEntries);
	for(int i = 0; i + 1 < values.Length; i++) {
		string fieldName = values[i].ToString().Trim();
		string fieldValue = values[i + 1].ToString().Trim();
		if(!clr.System.String.IsNullOrEmpty(fieldName)) {
			hash.Add(fieldName, fieldValue);
		}
		i++;
	}
	if(values.Length < 2 || values.Length % 2 != 0) { => hash; }
	@cfg.hashReadOk = true;
	=> hash;
}

func Number(value) {
	long n = 0;
	string text = value == null ? "" : value.ToString().Trim();
	if(!text.IsEmpty() && IsMatch(text, "^-?[0-9]+$")) {
		n = clr.System.Int64.Parse(text);
	}
	=> n;
}

func SqliteNumericOutput(output, expected) {
	string text = output == null ? "" : output.ToString()
		.ReplStr("\r\n", "\n").ReplStr("---", "\n");
	var lines = text.Split("\n".ToCharArray(), clr.System.StringSplitOptions.RemoveEmptyEntries);
	for(int i = 0; i < lines.Length; i++) {
		string line = lines[i].ToString().Trim();
		if(line == expected.ToString()) { => expected; }
	}
	=> -1l;
}

func HashValue(hash, key) {
	var value = hash[key.ToString()];
	if(value == null) { => ""; }
	=> value.ToString();
}

func HashSchemaOk(hash) {
	string sourceKey = HashValue(hash, "sourceKey");
	string sourcePath = HashValue(hash, "sourcePath");
	string variant = HashValue(hash, "variant");
	string deltaCount = HashValue(hash, "deltaCount");
	string totalCount = HashValue(hash, "totalCount");
	string lastVisitUtc = HashValue(hash, "lastVisitUtc");
	string schemaVersion = HashValue(hash, "schemaVersion");
	=> !sourceKey.IsEmpty() && !sourcePath.IsEmpty() && !variant.IsEmpty()
		&& !deltaCount.IsEmpty() && !totalCount.IsEmpty()
		&& !lastVisitUtc.IsEmpty() && !schemaVersion.IsEmpty();
}

func ReportFailure(stage, key, errorText) {
	string message = "stage=" & stage & " key=" & key & " error=" & errorText;
	if(@cfg.failureMessageCount < 10) {
		@cfg.failureLog = @cfg.failureLog & message & "\r\n";
		@cfg.failureMessageCount = @cfg.failureMessageCount + 1;
		mark(@cfg.colors.red, message);
	}
	=> null;
}

func SummaryRow(metric, value) {
	=> new { Metric = (string)metric.ToString(), Value = (string)value.ToString() };
}

void AddSummaryRowIfNonZero(rows, metric, value) {
	if(!SummaryRowIsZeroCount(value)) {
		((clr.System.Collections.ArrayList)rows).Add(SummaryRow(metric, value));
	}
}

func SummaryRowIsZeroCount(value) {
	string valueText = value.ToString().Trim();
	if(valueText.IsEmpty()) { => false; }
	bool isZero = false;
	try {
		double number = clr.System.Convert.ToDouble(valueText);
		isZero = number == 0;
	}
	catch {
		isZero = false;
	}
	=> isZero;
}

func select(arr, prop) { => clr.Dlinq.Linq.Select(arr, prop.ToString()); }

func GetDtoValueAsArrayList(dto) {
	var propNames = dto.GetType().GetProperties(clr.System.Reflection.BindingFlags.Public | clr.System.Reflection.BindingFlags.Instance)
		.Arr().select("it.Name");
	var values = new clr.System.Collections.ArrayList();
	for(int i = 0; i < propNames.Count; i++) {
		values.Add(dto -> propNames[i]);
	}
	=> values;
}

void toTable(data) {
	var propNames = data[0]
		.GetType().GetProperties(clr.System.Reflection.BindingFlags.Public | clr.System.Reflection.BindingFlags.Instance)
		.Arr().select("it.Name");
	var table = clr.Console.Table(propNames, "LeftAligned");
	table.ShowRowSeparators = true;
	var dtos = (clr.System.Collections.ArrayList)data;
	var values = [];
	for(int i = 0; i < dtos.Count; i++) {
		values = GetDtoValueAsArrayList(dtos[i]);
		table = clr.Ex.Console.AddRow(table, values);
	}
	table.Border = clr.Spectre.Console.TableBorder.Square;
	clr.Spectre.Console.AnsiConsole.Write(table);
}

func BuildSummaryRows(endpoint, scanTotal, stagedCount, rawRowCount, aggregateRowCount,
	imported, scanned, claimed, skipped, failed, pending, exitCode) {
	var rows = new clr.System.Collections.ArrayList();
	rows.Add(SummaryRow("endpoint", endpoint));
	rows.Add(SummaryRow("sqlitePath", @cfg.sqlitePath));
	AddSummaryRowIfNonZero(rows, "configuredKeys", scanTotal);
	AddSummaryRowIfNonZero(rows, "initialStagingKeys", stagedCount);
	AddSummaryRowIfNonZero(rows, "scanned", scanned);
	AddSummaryRowIfNonZero(rows, "claimed", claimed);
	AddSummaryRowIfNonZero(rows, "validRedisKeys", rawRowCount);
	AddSummaryRowIfNonZero(rows, "aggregateRows", aggregateRowCount);
	AddSummaryRowIfNonZero(rows, "committedAggregateRows", imported);
	AddSummaryRowIfNonZero(rows, "verifiedAggregateRows", imported);
	AddSummaryRowIfNonZero(rows, "verifiedRedisKeys", @cfg.verifiedKeyCount);
	AddSummaryRowIfNonZero(rows, "deleted", @cfg.deleted);
	AddSummaryRowIfNonZero(rows, "deadDeleted", @cfg.deadDeleted);
	AddSummaryRowIfNonZero(rows, "skipped", skipped);
	AddSummaryRowIfNonZero(rows, "readFailed", @cfg.readFailed);
	AddSummaryRowIfNonZero(rows, "nonHash", @cfg.nonHash);
	AddSummaryRowIfNonZero(rows, "schemaInvalid", @cfg.schemaInvalid);
	AddSummaryRowIfNonZero(rows, "sqliteFailed", @cfg.sqliteFailed);
	AddSummaryRowIfNonZero(rows, "verifyFailed", @cfg.verifyFailed);
	AddSummaryRowIfNonZero(rows, "deleteFailed", @cfg.deleteFailed);
	AddSummaryRowIfNonZero(rows, "deadStagingKeys", @cfg.deadKeyCount);
	AddSummaryRowIfNonZero(rows, "failedStagingKeys", @cfg.failedKeyCount);
	rows.Add(SummaryRow("redisKeyBatchSize", @cfg.redisKeyBatchSize));
	AddSummaryRowIfNonZero(rows, "failed", failed);
	AddSummaryRowIfNonZero(rows, "pending", pending);
	rows.Add(SummaryRow("exitCode", exitCode));
	=> rows;
}

void ShowExportSummary(endpoint, scanTotal, stagedCount, rawRowCount, aggregateRowCount,
	imported, scanned, claimed, skipped, failed, pending, exitCode) {
	var rows = BuildSummaryRows(endpoint, scanTotal, stagedCount, rawRowCount, aggregateRowCount,
		imported, scanned, claimed, skipped, failed, pending, exitCode);
	mark(@cfg.colors.green, "Export summary");
	toTable(rows);
}

func EmptyExportRow() {
	=> new {
		SourceKey: "", Variant: "", SourcePath: "", DeltaCount: 0l,
		LastVisitUtc: 0l, SchemaVersion: 0l, ImportedUtc: 0l
	};
}

func SetExportResult(disposition, stage, stagedKey, errorText, claimed, row) {
	@cfg.exportDisposition = disposition.ToString();
	@cfg.exportStage = stage.ToString();
	@cfg.exportStagedKey = stagedKey.ToString();
	@cfg.exportError = errorText.ToString();
	@cfg.exportClaimed = claimed;
	@cfg.exportRow = row;
	=> @cfg.exportDisposition;
}

func ProcessExportKey(pass, key, normalPrefixes, stagingPrefixes) {
	string stagedKey = key.ToString();
	bool didClaim = false;
	var emptyRow = EmptyExportRow();
	if(pass == 1) {
		stagedKey = StagingPrefixForKey(key, normalPrefixes, stagingPrefixes)
			& clr.System.Guid.NewGuid().ToString("N") & ":" & @cfg.claimSequence;
		@cfg.claimSequence = @cfg.claimSequence + 1;
		var claimArgs = new clr.System.Collections.ArrayList();
		claimArgs.Add("EVAL");
		claimArgs.Add(<<<
if redis.call('EXISTS',KEYS[1])==0 then return 0 end redis.call('RENAME',KEYS[1],KEYS[2]) return 1
>>>);
		claimArgs.Add("2"); claimArgs.Add(key); claimArgs.Add(stagedKey);
		var claim = RunRedisQuiet(claimArgs);
		if(!claim.Ok || Number(claim.Output) != 1) {
			=> SetExportResult("failed", "claim", stagedKey, claim..Error, false, emptyRow);
		}
		didClaim = true;
	}
	string keyType = RedisType(stagedKey);
	if(keyType.IsEmpty() || keyType != "hash") {
		=> SetExportResult("skipped", "TYPE", stagedKey, "type=" & keyType, didClaim, emptyRow);
	}
	var hash = ReadHash(stagedKey);
	if(!@cfg.hashReadOk) {
		=> SetExportResult("pending", "HGETALL", stagedKey,
			"Redis hash output was unavailable or malformed", didClaim, emptyRow);
	}
	string sourceKey = HashValue(hash, "sourceKey");
	string variant = HashValue(hash, "variant");
	string sourcePath = HashValue(hash, "sourcePath");
	string deltaText = HashValue(hash, "deltaCount");
	long deltaCount = Number(deltaText);
	if(sourceKey.IsEmpty() || variant.IsEmpty() || sourcePath.IsEmpty()
		|| deltaText.IsEmpty() || deltaCount < 0) {
		=> SetExportResult("pending", "schema", stagedKey,
			"required field or deltaCount invalid", didClaim, emptyRow);
	}
	var row = new {
		SourceKey: sourceKey, Variant: variant, SourcePath: sourcePath,
		DeltaCount: deltaCount,
		LastVisitUtc: Number(HashValue(hash, "lastVisitUtc")),
		SchemaVersion: Number(HashValue(hash, "schemaVersion")),
		ImportedUtc: clr.System.DateTimeOffset.UtcNow.ToUnixTimeSeconds()
	};
	=> SetExportResult("ok", "", stagedKey, "", didClaim, row);
}

func ApplyExportKeyResult(rawRows, rawKeys, key) {
	string disposition = @cfg.exportDisposition;
	if(disposition == "failed") {
		ReportFailure(@cfg.exportStage, @cfg.exportStagedKey, @cfg.exportError);
		=> new { Failed: 1, Skipped: 0, Pending: 0, Claimed: 0, Added: false };
	}
	if(disposition == "skipped") {
		@cfg.nonHash = @cfg.nonHash + 1;
		@cfg.deadKeyCount = @cfg.deadKeyCount + 1;
		ReportFailure(@cfg.exportStage, @cfg.exportStagedKey, @cfg.exportError);
		=> new { Failed: 0, Skipped: 1, Pending: 0, Claimed: 0, Added: false };
	}
	if(disposition == "pending") {
		if(@cfg.exportStage == "HGETALL") {
			@cfg.readFailed = @cfg.readFailed + 1;
			@cfg.failedKeyCount = @cfg.failedKeyCount + 1;
		} else {
			@cfg.schemaInvalid = @cfg.schemaInvalid + 1;
			@cfg.deadKeyCount = @cfg.deadKeyCount + 1;
		}
		ReportFailure(@cfg.exportStage, @cfg.exportStagedKey, @cfg.exportError);
		=> new { Failed: 0, Skipped: 0, Pending: 1, Claimed: 0, Added: false };
	}
	((clr.System.Collections.ArrayList)rawRows).Add(@cfg.exportRow);
	((clr.System.Collections.ArrayList)rawKeys).Add(@cfg.exportStagedKey);
	int claimDelta = @cfg.exportClaimed ? 1 : 0;
	=> new { Failed: 0, Skipped: 0, Pending: 0, Claimed: claimDelta, Added: true };
}

func SqlQuote(value) {
	=> "'" & value.ToString().ReplStr("'", "''") & "'";
}

func DistinctPairCount(rows) {
	var pairs = new clr.System.Collections.ArrayList();
	for(int i = 0; i < rows.Count; i++) {
		AddUnique(pairs, rows[i].SourceKey & "|" & rows[i].Variant);
	}
	=> pairs.Count;
}

func SamePair(left, right) {
	=> left.SourceKey == right.SourceKey && left.Variant == right.Variant;
}

func ConsolidateRows(inputRows, inputKeys) {
	var rows = new clr.System.Collections.ArrayList();
	var keys = new clr.System.Collections.ArrayList();
	var keysByRow = new clr.System.Collections.ArrayList();
	for(int i = 0; i < inputRows.Count; i++) {
		bool seen = false;
		for(int prior = 0; prior < i; prior++) {
			if(SamePair(inputRows[prior], inputRows[i])) { seen = true; break; }
		}
		if(seen) { continue; }
		long delta = 0, lastVisit = 0, schemaVersion = 0;
		string sourcePath = inputRows[i].SourcePath;
		var contributingKeys = new clr.System.Collections.ArrayList();
		for(int j = i; j < inputRows.Count; j++) {
			if(SamePair(inputRows[i], inputRows[j])) {
				delta = delta + inputRows[j].DeltaCount;
				if(inputRows[j].LastVisitUtc > lastVisit) { lastVisit = inputRows[j].LastVisitUtc; }
				if(inputRows[j].SchemaVersion > schemaVersion) { schemaVersion = inputRows[j].SchemaVersion; }
				contributingKeys.Add(inputKeys[j]);
			}
		}
		rows.Add(new { SourceKey: inputRows[i].SourceKey, Variant: inputRows[i].Variant,
			SourcePath: sourcePath, DeltaCount: delta, LastVisitUtc: lastVisit,
			SchemaVersion: schemaVersion, ImportedUtc: inputRows[i].ImportedUtc });
		keysByRow.Add(contributingKeys);
	}
	=> new { Rows: rows, Keys: keys, KeysByRow: keysByRow };
}

func ImportBatch(rows, keys) {
	if(rows.Count == 0) { => true; }
	@cfg.lastBatchDistinct = DistinctPairCount(rows);
	string sql = <<<
PRAGMA busy_timeout=30000;
BEGIN IMMEDIATE;

>>>;
	string upsertTail = <<<
) ON CONFLICT(source_key,variant) DO UPDATE SET source_path=excluded.source_path,
total_count=PicCount.total_count+excluded.total_count,
last_visit_utc=CASE WHEN excluded.last_visit_utc>PicCount.last_visit_utc THEN excluded.last_visit_utc ELSE PicCount.last_visit_utc END,
schema_version=CASE WHEN excluded.schema_version>PicCount.schema_version THEN excluded.schema_version ELSE PicCount.schema_version END,
imported_utc=excluded.imported_utc;

>>>;
	for(int i = 0; i < rows.Count; i++) {
		var row = rows[i];
		sql = sql & "INSERT INTO PicCount(source_key,variant,source_path,total_count,last_visit_utc,schema_version,imported_utc) VALUES("
			& SqlQuote(row.SourceKey) & "," & SqlQuote(row.Variant) & "," & SqlQuote(row.SourcePath)
			& "," & row.DeltaCount & "," & row.LastVisitUtc & "," & row.SchemaVersion & "," & row.ImportedUtc
			& upsertTail;
	}
	string verificationSql = "SELECT COUNT(*) FROM PicCount WHERE ";
	for(int i = 0; i < rows.Count; i++) {
		if(i > 0) { verificationSql = verificationSql & " OR "; }
		verificationSql = verificationSql & "(source_key=" & SqlQuote(rows[i].SourceKey)
			& " AND variant=" & SqlQuote(rows[i].Variant) & ")";
	}
	verificationSql = verificationSql & ";\r\n";
	sql = sql & "COMMIT;\r\n";
	var result = RunSqlite(sql);
	if(!result.Ok) {
		@cfg.sqliteFailed = @cfg.sqliteFailed + 1;
		ReportFailure("sqlite", keys[0], result..Error & " output=" & result..Output);
		=> false;
	}
	var verification = RunSqlite(verificationSql);
	long actual = SqliteNumericOutput(verification.Output, @cfg.lastBatchDistinct);
	string actualText = actual.ToString(), expectedText = @cfg.lastBatchDistinct.ToString();
	if(actualText != expectedText) {
		@cfg.verifyFailed = @cfg.verifyFailed + 1;
		ReportFailure("verify", keys[0], "batchInputCount=" & rows.Count
			& " batchKeyCount=" & keys.Count & " expectedDistinctPairs=" & @cfg.lastBatchDistinct
			& " actual=" & actual & " sqliteOutput=" & verification..Output
			& " sqliteError=" & verification..Error & " exitCode=" & verification..ExitCode);
		=> false;
	}
	@cfg.verifiedKeyCount = @cfg.verifiedKeyCount + keys.Count;
	=> true;
}

void ClearArrayList(list) {
	if(list == null) { return; }
	((clr.System.Collections.ArrayList)list).Clear();
}

void ClearNestedArrayList(list) {
	if(list == null) { return; }
	var outer = (clr.System.Collections.ArrayList)list;
	for(int i = 0; i < outer.Count; i++) {
		ClearArrayList(outer[i]);
	}
	outer.Clear();
}

void ResetExportResultState() {
	@cfg.exportDisposition = "";
	@cfg.exportStage = "";
	@cfg.exportStagedKey = "";
	@cfg.exportError = "";
	@cfg.exportClaimed = false;
	@cfg.exportRow = EmptyExportRow();
}

void ReleaseWorkingMemory() {
	clr.System.GC.Collect();
	clr.System.GC.WaitForPendingFinalizers();
	clr.System.GC.Collect();
}

void ReleaseExportBatchResources(rawRows, rawKeys, rows, keysByRow, sqliteKeys, batchKeys) {
	ClearArrayList(rawRows);
	ClearArrayList(rawKeys);
	ClearArrayList(rows);
	ClearNestedArrayList(keysByRow);
	ClearArrayList(sqliteKeys);
	ClearArrayList(batchKeys);
	ResetExportResultState();
	ReleaseWorkingMemory();
}

func CleanupKeys(keys, isDead) {
	var list = (clr.System.Collections.ArrayList)keys;
	for(int i = 0; i < list.Count; i++) {
		var existsBeforeArgs = new clr.System.Collections.ArrayList();
		existsBeforeArgs.Add("EXISTS"); existsBeforeArgs.Add(list[i].ToString());
		var existsBefore = RunRedis(existsBeforeArgs);
		if(!existsBefore.Ok) { @cfg.deleteFailed = @cfg.deleteFailed + 1; continue; }
		if(Number(existsBefore.Output) == 0) { continue; }
		var delArgs = new clr.System.Collections.ArrayList();
		delArgs.Add("DEL"); delArgs.Add(list[i].ToString());
		var deleted = RunRedis(delArgs);
		var existsAfterArgs = new clr.System.Collections.ArrayList();
		existsAfterArgs.Add("EXISTS"); existsAfterArgs.Add(list[i].ToString());
		var existsAfter = RunRedis(existsAfterArgs);
		if(!deleted.Ok || Number(deleted.Output) != 1 || !existsAfter.Ok || Number(existsAfter.Output) != 0) {
			@cfg.deleteFailed = @cfg.deleteFailed + 1;
			ReportFailure("delete", list[i], deleted..Error & " exists=" & existsAfter..Output);
		} else if(isDead) {
			@cfg.deadDeleted = @cfg.deadDeleted + 1;
		} else {
			@cfg.deleted = @cfg.deleted + 1;
		}
	}
	=> null;
}

func CountAllConfiguredKeys(stagingPrefixes, normalPrefixes) {
	@cfg.configuredKeyCount = 0;
	@cfg.initialStagingKeyCount = 0;
	var stagings = (clr.System.Collections.ArrayList)stagingPrefixes;
	var normals = (clr.System.Collections.ArrayList)normalPrefixes;
	for(int prefixIndex = 0; prefixIndex < stagings.Count; prefixIndex++) {
		var countResult = CountScanKeys(stagings[prefixIndex].ToString() & "*", false, stagingPrefixes);
		if(!countResult.Ok) { => false; }
		@cfg.initialStagingKeyCount = @cfg.initialStagingKeyCount + countResult..Count;
	}
	var legacyCount = CountScanKeys(@cfg.legacyStagingPrefix & "*", false, stagingPrefixes);
	if(!legacyCount.Ok) { => false; }
	@cfg.initialStagingKeyCount = @cfg.initialStagingKeyCount + legacyCount..Count;
	for(int prefixIndex = 0; prefixIndex < normals.Count; prefixIndex++) {
		var countResult = CountScanKeys(normals[prefixIndex].ToString() & "*", true, stagingPrefixes);
		if(!countResult.Ok) { => false; }
		@cfg.configuredKeyCount = @cfg.configuredKeyCount + countResult..Count;
	}
	@cfg.exportWorkTotal = @cfg.configuredKeyCount + @cfg.initialStagingKeyCount;
	ReleaseWorkingMemory();
	=> true;
}

func ProcessExportBatch(batchKeys, pass, normalPrefixes, stagingPrefixes) {
	var rawRows = new clr.System.Collections.ArrayList();
	var rawKeys = new clr.System.Collections.ArrayList();
	int batchScanned = 0, batchClaimed = 0, batchSkipped = 0, batchFailed = 0, batchPending = 0;
	int batchImported = 0;
	var keys = (clr.System.Collections.ArrayList)batchKeys;
	for(int i = 0; i < keys.Count; i++) {
		string key = keys[i].ToString();
		batchScanned = batchScanned + 1;
		@cfg.exportScannedSoFar = @cfg.exportScannedSoFar + 1;
		TouchExportProgress(false, "");
		bool rowProcessed = false;
		try {
			ProcessExportKey(pass, key, normalPrefixes, stagingPrefixes);
			rowProcessed = true;
		}
		catch {
			rowProcessed = false;
		}
		if(!rowProcessed) {
			batchFailed = batchFailed + 1;
			batchPending = batchPending + 1;
			@cfg.readFailed = @cfg.readFailed + 1;
			@cfg.failedKeyCount = @cfg.failedKeyCount + 1;
			ReportFailure("row", key, "unexpected error while processing Redis key");
			continue;
		}
		var applied = ApplyExportKeyResult(rawRows, rawKeys, key);
		batchFailed = batchFailed + applied..Failed;
		batchSkipped = batchSkipped + applied..Skipped;
		batchPending = batchPending + applied..Pending;
		batchClaimed = batchClaimed + applied..Claimed;
	}
	if(rawRows.Count == 0) {
		ClearArrayList(rawRows);
		ClearArrayList(rawKeys);
		ClearArrayList(batchKeys);
		ResetExportResultState();
		ReleaseWorkingMemory();
		=> new {
			Scanned: batchScanned, Claimed: batchClaimed, Skipped: batchSkipped,
			Failed: batchFailed, Pending: batchPending, Imported: 0
		};
	}
	@cfg.validRedisKeyCount = @cfg.validRedisKeyCount + rawRows.Count;
	var consolidated = ConsolidateRows(rawRows, rawKeys);
	var rows = (clr.System.Collections.ArrayList)(consolidated..Rows);
	var keysByRow = (clr.System.Collections.ArrayList)(consolidated..KeysByRow);
	@cfg.aggregateRowCount = @cfg.aggregateRowCount + rows.Count;
	var sqliteKeys = new clr.System.Collections.ArrayList();
	for(int rowIndex = 0; rowIndex < keysByRow.Count; rowIndex++) {
		var aggregateKeys = (clr.System.Collections.ArrayList)keysByRow[rowIndex];
		for(int keyIndex = 0; keyIndex < aggregateKeys.Count; keyIndex++) {
			sqliteKeys.Add(aggregateKeys[keyIndex]);
		}
	}
	TouchExportProgress(true, " importing");
	if(ImportBatch(rows, sqliteKeys)) {
		batchImported = @cfg.lastBatchDistinct;
		@cfg.sqliteRowsCommitted = @cfg.sqliteRowsCommitted + rows.Count;
		TouchExportProgress(true, "");
	} else {
		batchFailed = batchFailed + 1;
		@cfg.failedKeyCount = @cfg.failedKeyCount + sqliteKeys.Count;
	}
	ReleaseExportBatchResources(rawRows, rawKeys, rows, keysByRow, sqliteKeys, batchKeys);
	=> new {
		Scanned: batchScanned, Claimed: batchClaimed, Skipped: batchSkipped,
		Failed: batchFailed, Pending: batchPending, Imported: batchImported
	};
}

func DeleteRedisPrefix(prefix) {
	string matchPattern = prefix.ToString() & "*";
	string lua = <<<
local cursor='0'
local removed=0
repeat
  local result=redis.call('SCAN',cursor,'MATCH',ARGV[1],'COUNT',1000)
  cursor=result[1]
  local keys=result[2]
  for i=1,#keys do
    removed=removed+redis.call('DEL',keys[i])
  end
until cursor=='0'
return removed
>>>;
	int maxPasses = 100;
	for(int pass = 0; pass < maxPasses; pass++) {
		var args = new clr.System.Collections.ArrayList();
		args.Add("EVAL");
		args.Add(lua);
		args.Add("0");
		args.Add(matchPattern);
		var result = RunRedis(args);
		if(!result.Ok) {
			@cfg.deleteFailed = @cfg.deleteFailed + 1;
			ReportFailure("delete", prefix, result..Error);
		} else {
			long removed = Number(result.Output);
			@cfg.deleted = @cfg.deleted + removed;
		}
		var stagingPrefixes = (clr.System.Collections.ArrayList)(@cfg.redis..StagingPrefixes);
		var remaining = CountScanKeys(matchPattern, false, stagingPrefixes);
		if(!remaining.Ok) {
			@cfg.deleteFailed = @cfg.deleteFailed + 1;
			ReportFailure("delete", prefix, remaining..Error);
		} elseif(remaining..Count == 0) {
			=> true;
		}
	}
	@cfg.deleteFailed = @cfg.deleteFailed + 1;
	ReportFailure("delete", prefix, "remaining keys after cleanup retries");
	=> false;
}

void CleanupAllStagingKeys() {
	mark(@cfg.colors.blue, "Deleting remaining staging/exporting Redis keys");
	var stagingPrefixesForCleanup = (clr.System.Collections.ArrayList)(@cfg.redis..StagingPrefixes);
	for(int cleanupIndex = 0; cleanupIndex < stagingPrefixesForCleanup.Count; cleanupIndex++) {
		DeleteRedisPrefix(stagingPrefixesForCleanup[cleanupIndex]);
	}
	DeleteRedisPrefix(@cfg.legacyStagingPrefix);
}

func RunExport() {
	int scanned = 0, claimed = 0, imported = 0, skipped = 0, failed = 0, pending = 0, exitCode = 0;
	@cfg.deleted = 0; @cfg.deadDeleted = 0;
	@cfg.claimSequence = 0; @cfg.exportScannedSoFar = 0;
	@cfg.configuredKeyCount = 0; @cfg.initialStagingKeyCount = 0; @cfg.exportWorkTotal = 0;
	@cfg.validRedisKeyCount = 0; @cfg.aggregateRowCount = 0;
	@cfg.verifiedKeyCount = 0; @cfg.deadKeyCount = 0; @cfg.failedKeyCount = 0;
	@cfg.runImported = 0; @cfg.runFailed = 0; @cfg.runSkipped = 0; @cfg.runPending = 0; @cfg.runClaimed = 0;
	@cfg.sqliteRowsCommitted = 0;
	@cfg.progressStep = 1;
	if(!PingRedis()) {
		=> "scanned=0 claimed=0 imported=0 verified=0 deleted=0 skipped=0 failed=1 pending=0 exitCode=1";
	}
	if(!EnsureSqliteDatabase()) {
		=> "scanned=0 claimed=0 imported=0 verified=0 deleted=0 skipped=0 failed=1 pending=0 exitCode=1";
	}
	var stagingPrefixes = (clr.System.Collections.ArrayList)(@cfg.redis..StagingPrefixes);
	var normalPrefixes = (clr.System.Collections.ArrayList)(@cfg.redis..NormalPrefixes);
	if(!CountAllConfiguredKeys(stagingPrefixes, normalPrefixes)) {
		=> "scanned=0 claimed=0 imported=0 verified=0 deleted=0 skipped=0 failed=1 pending=0 exitCode=1";
	}
	if(@cfg.configuredKeyCount == 0 && @cfg.initialStagingKeyCount == 0) {
		var diagnosticResult = CountScanKeys("*:piccount:v1:*", false, stagingPrefixes);
		if(!diagnosticResult.Ok) {
			=> "scanned=0 claimed=0 imported=0 verified=0 deleted=0 skipped=0 failed=1 pending=0 exitCode=1";
		}
		if(diagnosticResult..Count > 0) {
			mark(@cfg.colors.red, "PREFIX_MISMATCH diagnosticKeys=" & diagnosticResult..Count);
			=> "endpoint=" & @cfg.redis.Host & ":" & @cfg.redis.Port & " database=" & @cfg.redis.Database
				& " configuredPatterns=" & (normalPrefixes.Count + stagingPrefixes.Count)
				& " configuredKeys=0 diagnosticKeys=" & diagnosticResult..Count
				& " scanned=0 claimed=0 imported=0 verified=0 deleted=0 skipped=0 failed=1 pending=0 exitCode=1";
		}
		mark(@cfg.colors.yellow, "REDIS_NAMESPACE_EMPTY endpoint=" & @cfg.redis.Host & ":" & @cfg.redis.Port
			& " database=" & @cfg.redis.Database & " configuredKeys=0");
		=> "endpoint=" & @cfg.redis.Host & ":" & @cfg.redis.Port & " database=" & @cfg.redis.Database
			& " configuredPatterns=" & (normalPrefixes.Count + stagingPrefixes.Count)
			& " configuredKeys=0 diagnosticKeys=0 scanned=0 claimed=0 imported=0 verified=0"
			& " deleted=0 skipped=0 failed=0 pending=0 exitCode=2";
	}
	InitExportProgress();
	ReleaseWorkingMemory();
	for(int prefixIndex = 0; prefixIndex < stagingPrefixes.Count; prefixIndex++) {
		var batchResult = ScanPatternInBatches(stagingPrefixes[prefixIndex].ToString() & "*",
			0, false, stagingPrefixes, normalPrefixes);
		if(!batchResult.Ok) {
			mark(@cfg.colors.red, "Redis scan failed during staging recovery");
			goto finish_export;
		}
	}
	var legacyBatch = ScanPatternInBatches(@cfg.legacyStagingPrefix & "*", 0, false, stagingPrefixes, normalPrefixes);
	if(!legacyBatch.Ok) {
		mark(@cfg.colors.red, "Redis scan failed during legacy staging recovery");
		goto finish_export;
	}
	for(int prefixIndex = 0; prefixIndex < normalPrefixes.Count; prefixIndex++) {
		var batchResult = ScanPatternInBatches(normalPrefixes[prefixIndex].ToString() & "*",
			1, true, stagingPrefixes, normalPrefixes);
		if(!batchResult.Ok) {
			mark(@cfg.colors.red, "Redis scan failed during piccount export");
			goto finish_export;
		}
	}

finish_export:
	scanned = @cfg.exportScannedSoFar;
	claimed = @cfg.runClaimed;
	imported = @cfg.runImported;
	skipped = @cfg.runSkipped;
	failed = @cfg.runFailed;
	pending = @cfg.runPending;
	CleanupAllStagingKeys();
	failed = failed + @cfg.sqliteFailed + @cfg.verifyFailed + @cfg.deleteFailed;
	if(failed > 0 || pending > 0) { exitCode = 1; }
	clr.LiveProgressConsole.Progress(@cfg.progressTitle, 100, "Done");
	clr.LiveProgressConsole.Stop();
	string endpoint = @cfg.redis.Host & ":" & @cfg.redis.Port & " db=" & @cfg.redis.Database;
	ShowExportSummary(endpoint, @cfg.configuredKeyCount, @cfg.initialStagingKeyCount, @cfg.validRedisKeyCount, @cfg.aggregateRowCount,
		imported, scanned, claimed, skipped, failed, pending, exitCode);
	=> "endpoint=" & endpoint
		& " configuredPatterns=" & (normalPrefixes.Count + stagingPrefixes.Count)
		& " configuredKeys=" & @cfg.configuredKeyCount & " diagnosticKeys=0"
		& " initialStagingKeys=" & @cfg.initialStagingKeyCount & " verifiedStagingKeys=" & @cfg.verifiedKeyCount
		& " deadStagingKeys=" & @cfg.deadKeyCount & " failedStagingKeys=" & @cfg.failedKeyCount
		& " validRedisKeys=" & @cfg.validRedisKeyCount & " aggregateRows=" & @cfg.aggregateRowCount
		& " committedAggregateRows=" & imported & " verifiedAggregateRows=" & imported
		& " verifiedRedisKeys=" & @cfg.verifiedKeyCount
		& " scanned=" & scanned & " claimed=" & claimed & " imported=" & imported & " verified=" & imported
		& " deleted=" & @cfg.deleted & " deadDeleted=" & @cfg.deadDeleted & " skipped=" & skipped
		& " readFailed=" & @cfg.readFailed & " nonHash=" & @cfg.nonHash & " schemaInvalid=" & @cfg.schemaInvalid
		& " valueInvalid=" & @cfg.valueInvalid & " sqliteFailed=" & @cfg.sqliteFailed
		& " verifyFailed=" & @cfg.verifyFailed & " deleteFailed=" & @cfg.deleteFailed
		& " failed=" & failed
		& " pending=" & pending & " exitCode=" & exitCode;
}

func Percent(done, total) {
	long d = clr.System.Convert.ToInt64(done);
	long t = clr.System.Convert.ToInt64(total);
	long p = 0;
	if(t <= 0) { => 100; }
	if(d <= 0) { => 0; }
	if(d >= t) { => 100; }
	p = (d * 100) / t;
	if(p < 0) { p = 0; }
	if(p > 100) { p = 100; }
	=> clr.System.Convert.ToInt32(p);
}

func ExportProgressLabel(suffix) {
	string label = "(" & @cfg.exportScannedSoFar & "/" & @cfg.exportWorkTotal & ")";
	if(suffix != null && !suffix.ToString().IsEmpty()) {
		label = label & suffix.ToString();
	}
	=> label;
}

void InitExportProgress() {
	@cfg.progressStep = 1;
	if(@cfg.exportWorkTotal > 0) {
		@cfg.progressStep = @cfg.exportWorkTotal / 200;
		if(@cfg.progressStep <= 0) { @cfg.progressStep = 1; }
	}
	@cfg.progressTitle = "Redis picture-count export (" & @cfg.configuredKeyCount & " keys)";
	if(@cfg.initialStagingKeyCount > 0) {
		mark(@cfg.colors.yellow, "Recovering " & @cfg.initialStagingKeyCount & " staged Redis keys before export");
	}
	clr.LiveProgressConsole.Start([@cfg.progressTitle]);
	TouchExportProgress(true, "");
}

void TouchExportProgress(updateBar, suffix) {
	if(@cfg.exportWorkTotal <= 0) { return; }
	string label = ExportProgressLabel(suffix);
	clr.LiveProgressConsole.Status(@cfg.progressTitle, label);
	if(updateBar || (@cfg.exportScannedSoFar % @cfg.progressStep) == 0 || @cfg.exportScannedSoFar >= @cfg.exportWorkTotal) {
		clr.LiveProgressConsole.Progress(@cfg.progressTitle, Percent(@cfg.exportScannedSoFar, @cfg.exportWorkTotal), label);
	}
}

void mark(color, content) {
	clr.Ex.Console.Markup("[#" & color & "]" & content.ToString().ReplStr("[", "").ReplStr("]", "") & "[/]\r\n");
}
