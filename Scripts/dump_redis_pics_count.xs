import Ex.Console as Console;
import System.IO.File as File;
import System.Collections.ArrayList as ArrayList;
import Ex.ProgressConsole as ProgressConsole;

@sqlite = "sqlite3.exe";
@redis = CreateRedisConnectionConfig();
@sqlitePath = "D:\\BookImport\\piccount.db";
@progressTitle = "Redis picture-count export";
@legacyStagingPrefix = "mystore:piccount:v1:__exporting__";
@verifiedKeys = new clr.System.Collections.ArrayList();
@deadKeys = new clr.System.Collections.ArrayList();
@failedKeys = new clr.System.Collections.ArrayList();
@failureReports = new clr.System.Collections.ArrayList();
@readFailed = 0; @nonHash = 0; @schemaInvalid = 0; @valueInvalid = 0;
@sqliteFailed = 0; @verifyFailed = 0; @deleteFailed = 0;
@deleted = 0; @deadDeleted = 0;
@hashReadOk = false;
@lastBatchDistinct = 0;

var summary = RunExport();
mark("5FD7AF", summary);
=> summary;

func CreateRedisConnectionConfig() {
	var normalPrefixes = new clr.System.Collections.ArrayList();
	normalPrefixes.Add("mystore:piccount:v1:");
	normalPrefixes.Add("4u:piccount:v1:");
	var stagingPrefixes = new clr.System.Collections.ArrayList();
	stagingPrefixes.Add("mystore:piccount:v1:__exporting:");
	stagingPrefixes.Add("4u:piccount:v1:__exporting:");
	=> new {
		Executable: "C:\\Program Files\\Redis\\redis-cli.exe",
		Host: "192.168.100.26",
		Port: 6379,
		Database: 0,
		Password: "xxxxxx",
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
	var args = new clr.System.Collections.ArrayList();
	args.Add("-h"); args.Add(@redis.Host.ToString());
	args.Add("-p"); args.Add(@redis.Port.ToString());
	args.Add("-n"); args.Add(@redis.Database.ToString());
	args.Add("-a"); args.Add(@redis.Password.ToString());
	args.Add("--no-auth-warning"); args.Add("--raw");
	var operation = (clr.System.Collections.ArrayList)operationArguments;
	for(int i = 0; i < operation.Count; i++) { args.Add(operation[i].ToString()); }
	var result = RunProcess(@redis.Executable, args, null);
	if(result.ExitCode != 0) {
		mark("FF005F", "redis-cli failed with exit code " & result.ExitCode);
		=> new { Ok: false, Output: "", Error: result..StdErr, ExitCode: result..ExitCode };
	}
	=> new { Ok: true, Output: result..StdOut, Error: "", ExitCode: 0 };
}

func RunSqlite(sqlText) {
	var args = new clr.System.Collections.ArrayList();
	args.Add(@sqlitePath.ToString());
	var result = RunProcess(@sqlite, args, sqlText);
	if(result.ExitCode != 0) {
		mark("FF005F", "sqlite3 failed with exit code " & result.ExitCode);
		=> new { Ok: false, Output: "", Error: result..StdErr, ExitCode: result..ExitCode };
	}
	=> new { Ok: true, Output: result..StdOut, Error: "", ExitCode: 0 };
}

func EnsureSqliteDatabase() {
	string parent = clr.System.IO.Path.GetDirectoryName(@sqlitePath.ToString());
	if(!clr.System.String.IsNullOrEmpty(parent) && !clr.System.IO.Directory.Exists(parent)) {
		clr.System.IO.Directory.CreateDirectory(parent);
	}
	string schema = "PRAGMA journal_mode=WAL;\r\n"
		& "PRAGMA busy_timeout=30000;\r\n"
		& "CREATE TABLE IF NOT EXISTS PicCount ("
		& "source_key TEXT NOT NULL, variant TEXT NOT NULL, source_path TEXT NOT NULL,"
		& "total_count INTEGER NOT NULL DEFAULT 0, last_visit_utc INTEGER NOT NULL DEFAULT 0,"
		& "schema_version INTEGER NOT NULL DEFAULT 1, imported_utc INTEGER NOT NULL DEFAULT 0,"
		& "PRIMARY KEY (source_key, variant));\r\n"
		& "CREATE INDEX IF NOT EXISTS IX_PicCount_LastVisit ON PicCount(last_visit_utc);\r\n"
		& "CREATE INDEX IF NOT EXISTS IX_PicCount_SourcePath ON PicCount(source_path);\r\n";
	var result = RunSqlite(schema);
	=> result.Ok;
}

func ScanKeys(pattern) {
	var keys = new clr.System.Collections.ArrayList();
	string cursor = "0", raw = "", error = "";
	int calls = 0;
	bool ok = true;
	for(int round = 0; round < 100000 && (round == 0 || cursor != "0"); round++) {
		var args = new clr.System.Collections.ArrayList();
		args.Add("SCAN"); args.Add(cursor); args.Add("MATCH"); args.Add(pattern.ToString());
		args.Add("COUNT"); args.Add("1000");
		var result = RunRedis(args);
		calls = calls + 1;
		if(!result.Ok) { ok = false; error = result.Error; break; }
		string response = result.Output.ToString().ReplStr("\r\n", "\n");
		raw = raw & response;
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
	=> new { Ok: ok, Keys: keys, RawOutput: raw, Error: error, Pattern: pattern.ToString(), Calls: calls };
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
	var result = RunRedis(args);
	if(!result.Ok) { => ""; }
	=> result.Output.ToString().Trim();
}

func IsStagingKey(key, prefixes) {
	if(key.ToString().StartsWith(@legacyStagingPrefix)) { => true; }
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
	@hashReadOk = false;
	var args = new clr.System.Collections.ArrayList();
	args.Add("HGETALL"); args.Add(key.ToString());
	var result = RunRedis(args);
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
	@hashReadOk = true;
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
	var reports = (clr.System.Collections.ArrayList)@failureReports;
	if(reports.Count < 10) { reports.Add(message); mark("FF005F", message); }
	=> null;
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
	@lastBatchDistinct = DistinctPairCount(rows);
	string sql = "PRAGMA busy_timeout=30000;\r\nBEGIN IMMEDIATE;\r\n";
	for(int i = 0; i < rows.Count; i++) {
		var row = rows[i];
		sql = sql & "INSERT INTO PicCount(source_key,variant,source_path,total_count,last_visit_utc,schema_version,imported_utc) VALUES("
			& SqlQuote(row.SourceKey) & "," & SqlQuote(row.Variant) & "," & SqlQuote(row.SourcePath)
			& "," & row.DeltaCount & "," & row.LastVisitUtc & "," & row.SchemaVersion & "," & row.ImportedUtc
			& ") ON CONFLICT(source_key,variant) DO UPDATE SET source_path=excluded.source_path,"
			& "total_count=PicCount.total_count+excluded.total_count,"
			& "last_visit_utc=CASE WHEN excluded.last_visit_utc>PicCount.last_visit_utc THEN excluded.last_visit_utc ELSE PicCount.last_visit_utc END,"
			& "schema_version=CASE WHEN excluded.schema_version>PicCount.schema_version THEN excluded.schema_version ELSE PicCount.schema_version END,"
			& "imported_utc=excluded.imported_utc;\r\n";
	}
	string verificationSql = "SELECT COUNT(*) FROM PicCount WHERE ";
	for(int i = 0; i < rows.Count; i++) {
		if(i > 0) { verificationSql = verificationSql & " OR "; }
		verificationSql = verificationSql & "(source_key=" & SqlQuote(rows[i].SourceKey)
			& " AND variant=" & SqlQuote(rows[i].Variant) & ")";
	}
	verificationSql = verificationSql & ";\r\n";
	sql = sql & "COMMIT;\r\n";
	mark("87D7FF", "Importing consolidated Redis rows into SQLite...");
	var result = RunSqlite(sql);
	if(!result.Ok) {
		@sqliteFailed = @sqliteFailed + 1;
		ReportFailure("sqlite", keys[0], result..Error & " output=" & result..Output);
		=> false;
	}
	mark("87D7FF", "Verifying committed SQLite aggregate rows...");
	var verification = RunSqlite(verificationSql);
	long actual = SqliteNumericOutput(verification.Output, @lastBatchDistinct);
	string actualText = actual.ToString(), expectedText = @lastBatchDistinct.ToString();
	if(actualText != expectedText) {
		@verifyFailed = @verifyFailed + 1;
		ReportFailure("verify", keys[0], "batchInputCount=" & rows.Count
			& " batchKeyCount=" & keys.Count & " expectedDistinctPairs=" & @lastBatchDistinct
			& " actual=" & actual & " sqliteOutput=" & verification..Output
			& " sqliteError=" & verification..Error & " exitCode=" & verification..ExitCode);
		=> false;
	}
	mark("87D7FF", "batchInputCount=" & rows.Count & " distinctPairCount=" & @lastBatchDistinct
		& " actual=" & actual);
	clr.ProgressConsole.Progress(@progressTitle, 85);
	for(int i = 0; i < keys.Count; i++) {
		var verified = (clr.System.Collections.ArrayList)@verifiedKeys;
		verified.Add(keys[i].ToString());
	}
	=> true;
}

func CleanupKeys(keys, isDead) {
	var list = (clr.System.Collections.ArrayList)keys;
	for(int i = 0; i < list.Count; i++) {
		var existsBeforeArgs = new clr.System.Collections.ArrayList();
		existsBeforeArgs.Add("EXISTS"); existsBeforeArgs.Add(list[i].ToString());
		var existsBefore = RunRedis(existsBeforeArgs);
		if(!existsBefore.Ok) { @deleteFailed = @deleteFailed + 1; continue; }
		if(Number(existsBefore.Output) == 0) { continue; }
		var delArgs = new clr.System.Collections.ArrayList();
		delArgs.Add("DEL"); delArgs.Add(list[i].ToString());
		var deleted = RunRedis(delArgs);
		var existsAfterArgs = new clr.System.Collections.ArrayList();
		existsAfterArgs.Add("EXISTS"); existsAfterArgs.Add(list[i].ToString());
		var existsAfter = RunRedis(existsAfterArgs);
		if(!deleted.Ok || Number(deleted.Output) != 1 || !existsAfter.Ok || Number(existsAfter.Output) != 0) {
			@deleteFailed = @deleteFailed + 1;
			ReportFailure("delete", list[i], deleted..Error & " exists=" & existsAfter..Output);
		} else if(isDead) {
			@deadDeleted = @deadDeleted + 1;
		} else {
			@deleted = @deleted + 1;
		}
	}
	=> null;
}

func DeleteRedisPrefix(prefix) {
	var args = new clr.System.Collections.ArrayList();
	args.Add("EVAL");
	args.Add("local cursor='0'; local removed=0; repeat local result=redis.call('SCAN',cursor,'MATCH',ARGV[1],'COUNT',1000); cursor=result[1]; local keys=result[2]; if #keys>0 then removed=removed+redis.call('DEL',unpack(keys)); end until cursor=='0'; return removed");
	args.Add("0");
	args.Add(prefix.ToString() & "*");
	var result = RunRedis(args);
	if(!result.Ok) {
		@deleteFailed = @deleteFailed + 1;
		ReportFailure("delete", prefix, result..Error);
		=> false;
	}
	long removed = Number(result.Output);
	@deleted = @deleted + removed;
	mark("87D7FF", "Bulk deleted prefix=" & prefix & " count=" & removed);
	var remaining = ScanKeys(prefix.ToString() & "*");
	if(!remaining.Ok) {
		@deleteFailed = @deleteFailed + 1;
		ReportFailure("delete", prefix, remaining..Error);
		=> false;
	}
	var remainingKeys = (clr.System.Collections.ArrayList)(remaining..Keys);
	if(remainingKeys.Count != 0) {
		@deleteFailed = @deleteFailed + 1;
		ReportFailure("delete", prefix, "remaining=" & remainingKeys.Count);
		=> false;
	}
	=> true;
}

func RunExport() {
	int scanned = 0, claimed = 0, imported = 0, skipped = 0, failed = 0, pending = 0, exitCode = 0;
	@deleted = 0; @deadDeleted = 0;
	clr.ProgressConsole.Start([@progressTitle]);
	clr.ProgressConsole.Progress(@progressTitle, 0);
	var summary = "";
	if(!PingRedis()) {
		clr.ProgressConsole.Progress(@progressTitle, 100);
		clr.ProgressConsole.Stop();
		=> "scanned=0 claimed=0 imported=0 verified=0 deleted=0 skipped=0 failed=1 pending=0 exitCode=1";
	}
	if(!EnsureSqliteDatabase()) {
		clr.ProgressConsole.Progress(@progressTitle, 100);
		clr.ProgressConsole.Stop();
		=> "scanned=0 claimed=0 imported=0 verified=0 deleted=0 skipped=0 failed=1 pending=0 exitCode=1";
	}
	var stagingPrefixes = (clr.System.Collections.ArrayList)(@redis..StagingPrefixes);
	var normalPrefixes = (clr.System.Collections.ArrayList)(@redis..NormalPrefixes);
	var staged = new clr.System.Collections.ArrayList();
	var normal = new clr.System.Collections.ArrayList();
	clr.ProgressConsole.Progress(@progressTitle, 0);
	for(int prefixIndex = 0; prefixIndex < stagingPrefixes.Count; prefixIndex++) {
		var stagedResult = ScanKeys(stagingPrefixes[prefixIndex].ToString() & "*");
		if(!stagedResult.Ok) {
			clr.ProgressConsole.Progress(@progressTitle, 100);
			clr.ProgressConsole.Stop();
			=> "scanned=0 claimed=0 imported=0 verified=0 deleted=0 skipped=0 failed=1 pending=0 exitCode=1";
		}
		var stagedKeys = (clr.System.Collections.ArrayList)(stagedResult..Keys);
		for(int i = 0; i < stagedKeys.Count; i++) { AddUnique(staged, stagedKeys[i]); }
		mark("87D7FF", "stagingPattern=" & stagingPrefixes[prefixIndex] & " calls="
			& stagedResult..Calls & " count=" & stagedKeys.Count);
		if(stagedKeys.Count > 0 && !HashSchemaOk(ReadHash(stagedKeys[0]))) {
			clr.ProgressConsole.Progress(@progressTitle, 100);
			clr.ProgressConsole.Stop();
			=> "scanned=0 claimed=0 imported=0 verified=0 deleted=0 skipped=0 failed=1 pending=1 exitCode=1";
		}
	}
	var legacyResult = ScanKeys(@legacyStagingPrefix & "*");
	if(!legacyResult.Ok) {
		clr.ProgressConsole.Progress(@progressTitle, 100);
		clr.ProgressConsole.Stop();
		=> "scanned=0 claimed=0 imported=0 verified=0 deleted=0 skipped=0 failed=1 pending=0 exitCode=1";
	}
	var legacyKeys = (clr.System.Collections.ArrayList)(legacyResult..Keys);
	for(int legacyIndex = 0; legacyIndex < legacyKeys.Count; legacyIndex++) {
		AddUnique(staged, legacyKeys[legacyIndex]);
	}
	if(legacyKeys.Count > 0) {
		mark("87D7FF", "legacyStagingPattern=" & @legacyStagingPrefix
			& " calls=" & legacyResult..Calls & " count=" & legacyKeys.Count);
	}
	for(int prefixIndex = 0; prefixIndex < normalPrefixes.Count; prefixIndex++) {
		var normalResult = ScanKeys(normalPrefixes[prefixIndex].ToString() & "*");
		if(!normalResult.Ok) {
			clr.ProgressConsole.Progress(@progressTitle, 100);
			clr.ProgressConsole.Stop();
			=> "scanned=0 claimed=0 imported=0 verified=0 deleted=0 skipped=0 failed=1 pending=0 exitCode=1";
		}
		var normalKeys = (clr.System.Collections.ArrayList)(normalResult..Keys);
		for(int i = 0; i < normalKeys.Count; i++) {
			string normalKey = normalKeys[i].ToString();
			if(!IsStagingKey(normalKey, stagingPrefixes)) { AddUnique(normal, normalKey); }
		}
		mark("87D7FF", "normalPattern=" & normalPrefixes[prefixIndex] & " calls="
			& normalResult..Calls & " count=" & normalKeys.Count);
		if(normalKeys.Count > 0 && !HashSchemaOk(ReadHash(normalKeys[0]))) {
			clr.ProgressConsole.Progress(@progressTitle, 100);
			clr.ProgressConsole.Stop();
			=> "scanned=0 claimed=0 imported=0 verified=0 deleted=0 skipped=0 failed=1 pending=1 exitCode=1";
		}
	}
	int scanTotal = staged.Count + normal.Count;
	if(scanTotal == 0) {
		var diagnosticResult = ScanKeys("*:piccount:v1:*");
		if(!diagnosticResult.Ok) {
			clr.ProgressConsole.Progress(@progressTitle, 100);
			clr.ProgressConsole.Stop();
			=> "scanned=0 claimed=0 imported=0 verified=0 deleted=0 skipped=0 failed=1 pending=0 exitCode=1";
		}
		var diagnosticKeys = (clr.System.Collections.ArrayList)(diagnosticResult..Keys);
		if(diagnosticKeys.Count > 0) {
			mark("FF005F", "PREFIX_MISMATCH diagnosticKeys=" & diagnosticKeys.Count
				& " candidate=" & diagnosticKeys[0].ToString());
			clr.ProgressConsole.Progress(@progressTitle, 100);
			clr.ProgressConsole.Stop();
			=> "endpoint=" & @redis.Host & ":" & @redis.Port & " database=" & @redis.Database
				& " configuredPatterns=" & (normalPrefixes.Count + stagingPrefixes.Count)
				& " configuredKeys=0 diagnosticKeys=" & diagnosticKeys.Count
				& " scanned=0 claimed=0 imported=0 verified=0 deleted=0 skipped=0 failed=1 pending=0 exitCode=1";
		}
		mark("FFAF00", "REDIS_NAMESPACE_EMPTY endpoint=" & @redis.Host & ":" & @redis.Port
			& " database=" & @redis.Database & " configuredKeys=0");
		clr.ProgressConsole.Progress(@progressTitle, 100);
		clr.ProgressConsole.Stop();
		=> "endpoint=" & @redis.Host & ":" & @redis.Port & " database=" & @redis.Database
			& " configuredPatterns=" & (normalPrefixes.Count + stagingPrefixes.Count)
			& " configuredKeys=0 diagnosticKeys=0 scanned=0 claimed=0 imported=0 verified=0"
			& " deleted=0 skipped=0 failed=0 pending=0 exitCode=2";
	}
	var rawRows = new clr.System.Collections.ArrayList();
	var rawKeys = new clr.System.Collections.ArrayList();
	var keys = new clr.System.Collections.ArrayList();
	// Existing staged keys are retried before new keys are claimed.
	for(int pass = 0; pass < 2; pass++) {
		var source = pass == 0 ? staged : normal;
		for(int i = 0; i < source.Count; i++) {
			string key = source[i].ToString();
			scanned = scanned + 1;
			clr.ProgressConsole.Progress(@progressTitle, Percent(scanned, scanTotal));
			string stagedKey = key;
			if(pass == 1) {
				stagedKey = StagingPrefixForKey(key, normalPrefixes, stagingPrefixes)
					& clr.System.Guid.NewGuid().ToString("N") & ":" & i;
				var claimArgs = new clr.System.Collections.ArrayList();
				claimArgs.Add("EVAL");
				claimArgs.Add("if redis.call('EXISTS',KEYS[1])==0 then return 0 end redis.call('RENAME',KEYS[1],KEYS[2]) return 1");
				claimArgs.Add("2"); claimArgs.Add(key); claimArgs.Add(stagedKey);
				var claim = RunRedis(claimArgs);
				if(!claim.Ok || Number(claim.Output) != 1) { failed = failed + 1; continue; }
				claimed = claimed + 1;
			}
			string keyType = RedisType(stagedKey);
			if(keyType.IsEmpty() || keyType != "hash") {
				skipped = skipped + 1;
				@nonHash = @nonHash + 1;
				((clr.System.Collections.ArrayList)@deadKeys).Add(stagedKey);
				ReportFailure("TYPE", stagedKey, "type=" & keyType);
				mark("FFAF00", "Skipped non-hash key type=" & keyType);
				continue;
			}
			var hash = ReadHash(stagedKey);
			if(!@hashReadOk) {
				@readFailed = @readFailed + 1;
				pending = pending + 1;
				((clr.System.Collections.ArrayList)@failedKeys).Add(stagedKey);
				ReportFailure("HGETALL", stagedKey, "Redis hash output was unavailable or malformed");
				continue;
			}
			string sourceKey = HashValue(hash, "sourceKey");
			string variant = HashValue(hash, "variant");
			string sourcePath = HashValue(hash, "sourcePath");
			string deltaText = HashValue(hash, "deltaCount");
			long deltaCount = Number(deltaText);
			if(sourceKey.IsEmpty() || variant.IsEmpty() || sourcePath.IsEmpty()
				|| deltaText.IsEmpty() || deltaCount < 0) {
				pending = pending + 1;
				@schemaInvalid = @schemaInvalid + 1;
				((clr.System.Collections.ArrayList)@deadKeys).Add(stagedKey);
				ReportFailure("schema", stagedKey, "required field or deltaCount invalid");
				continue;
			}
			rawRows.Add(new { SourceKey: sourceKey, Variant: variant, SourcePath: sourcePath,
				DeltaCount: deltaCount,
				LastVisitUtc: Number(HashValue(hash, "lastVisitUtc")),
				SchemaVersion: Number(HashValue(hash, "schemaVersion")),
				ImportedUtc: clr.System.DateTimeOffset.UtcNow.ToUnixTimeSeconds() });
			rawKeys.Add(stagedKey);
		}
	}
	var consolidated = ConsolidateRows(rawRows, rawKeys);
	var rows = (clr.System.Collections.ArrayList)(consolidated..Rows);
	var keysByRow = (clr.System.Collections.ArrayList)(consolidated..KeysByRow);
	mark("87D7FF", "Redis consolidation validKeys=" & rawRows.Count
		& " aggregatePairs=" & rows.Count & " upsertRows=" & rows.Count);
	for(int batchStart = 0; batchStart < rows.Count; batchStart++) {
		if(batchStart % 100 != 0) { continue; }
		var batchRows = new clr.System.Collections.ArrayList();
		var batchKeys = new clr.System.Collections.ArrayList();
		int batchEnd = batchStart + 100;
		if(batchEnd > rows.Count) { batchEnd = rows.Count; }
		for(int batchIndex = batchStart; batchIndex < batchEnd; batchIndex++) {
			batchRows.Add(rows[batchIndex]);
			var aggregateKeys = (clr.System.Collections.ArrayList)keysByRow[batchIndex];
			for(int keyIndex = 0; keyIndex < aggregateKeys.Count; keyIndex++) {
				batchKeys.Add(aggregateKeys[keyIndex]);
			}
		}
		if(ImportBatch(batchRows, batchKeys)) { imported = imported + @lastBatchDistinct; }
		else {
			failed = failed + 1;
			for(int failedIndex = 0; failedIndex < batchKeys.Count; failedIndex++) {
				((clr.System.Collections.ArrayList)@failedKeys).Add(batchKeys[failedIndex]);
			}
		}
	}
	clr.ProgressConsole.Progress(@progressTitle, 90);
	if(failed == 0 && @sqliteFailed == 0 && @verifyFailed == 0) {
		mark("87D7FF", "Final cleanup: bulk deleting verified Redis exporting prefixes...");
		var stagingPrefixesForCleanup = (clr.System.Collections.ArrayList)(@redis..StagingPrefixes);
		for(int cleanupIndex = 0; cleanupIndex < stagingPrefixesForCleanup.Count; cleanupIndex++) {
			DeleteRedisPrefix(stagingPrefixesForCleanup[cleanupIndex]);
		}
		DeleteRedisPrefix(@legacyStagingPrefix);
	} else {
		mark("FFAF00", "Final cleanup skipped; failed batches remain for retry.");
	}
	failed = failed + @sqliteFailed + @verifyFailed + @deleteFailed;
	if(failed > 0 || pending > 0) { exitCode = 1; }
	clr.ProgressConsole.Progress(@progressTitle, 100);
	clr.ProgressConsole.Stop();
	=> "endpoint=" & @redis.Host & ":" & @redis.Port & " database=" & @redis.Database
		& " configuredPatterns=" & (normalPrefixes.Count + stagingPrefixes.Count)
		& " configuredKeys=" & scanTotal & " diagnosticKeys=0"
		& " initialStagingKeys=" & staged.Count & " verifiedStagingKeys=" & @verifiedKeys.Count
		& " deadStagingKeys=" & @deadKeys.Count & " failedStagingKeys=" & @failedKeys.Count
		& " validRedisKeys=" & rawRows.Count & " aggregateRows=" & rows.Count
		& " committedAggregateRows=" & imported & " verifiedAggregateRows=" & imported
		& " verifiedRedisKeys=" & @verifiedKeys.Count
		& " scanned=" & scanned & " claimed=" & claimed & " imported=" & imported & " verified=" & imported
		& " deleted=" & @deleted & " deadDeleted=" & @deadDeleted & " skipped=" & skipped
		& " readFailed=" & @readFailed & " nonHash=" & @nonHash & " schemaInvalid=" & @schemaInvalid
		& " valueInvalid=" & @valueInvalid & " sqliteFailed=" & @sqliteFailed
		& " verifyFailed=" & @verifyFailed & " deleteFailed=" & @deleteFailed
		& " failed=" & failed
		& " pending=" & pending & " exitCode=" & exitCode;
}

func Percent(done, total) {
	if(total <= 0l) { => 100l; }
	long result = (done * 100l) / total;
	if(result < 0l) { result = 0l; }
	if(result > 100l) { result = 100l; }
	=> result;
}

void mark(color, content) {
	clr.Ex.Console.Markup("[#" & color & "]" & content.ToString().ReplStr("[", "").ReplStr("]", "") & "[/]\r\n");
}
