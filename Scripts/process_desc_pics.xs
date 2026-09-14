import Ex.Console as Console;
import System.IO.File as File;
import System.IO.Directory as Directory;
import System.Collections.ArrayList as ArrayList;
import Ex.LiveProgressConsole as LiveProgressConsole;

@sqlite = "sqlite3.exe";
@sourceFolder = "d:\\Models\\Images\\";
@takenFolder = "d:\\Models\\Taken\\";
@trainingFolder = "d:\\Models\\Training\\";
@trainingDbPath = "d:\\Models\\training_db.db";
@digiKamDbUri = "file:d:/Models/digikam4.db?mode=ro";
@trainingDbFileName = "training_db.db";
@deleteOptionYes = "Yes, delete processed images from Images";
@deleteOptionNo = "No, keep source images in Images";
@deleteSourceImages = true;
@progressTitle = "process_desc_pics";
@progressStep = 1;
@progressStarted = false;
@lookupOk = false;
@lookupIsTaken = 1;
@lookupSourceTagId = -1;
@lookupError = "";
@processOk = false;
@processStep = "";
@processError = "";
@processIsTaken = 1;
@processExitCode = 0;
@processStdOut = "";
@processStdErr = "";

var result = RunProcessDescPics();
=> result;

func RunProcessDescPics() {
	string result = "Done";

	if(!clr.Directory.Exists(@sourceFolder.ToString())) {
		mark("FF005F", "Source folder does not exist: " & @sourceFolder);
		=> "Source folder missing.";
	}

	EnsureDestinationFolders();
	if(!EnsureTrainingDatabase()) {
		=> "Training database setup failed.";
	}

	@deleteSourceImages = PromptDeleteSourceImages();

	var sourceImages = CollectSourceImages();
	if(sourceImages.Count == 0) {
		mark("FCCE49", "No image files found in: " & @sourceFolder);
		=> "No images to process.";
	}

	int total = sourceImages.Count;
	@progressTitle = "process_desc_pics (" & total & " images)";
	@progressStep = 1;
	if(total > 0) {
		@progressStep = total / 200;
		if(@progressStep <= 0) {
			@progressStep = 1;
		}
	}
	clr.LiveProgressConsole.Start([@progressTitle]);
	@progressStarted = true;

	var processedSources = new clr.System.Collections.ArrayList();
	int takenCount = 0;
	int notTakenCount = 0;
	int failedCount = 0;
	int done = 0;
	bool batchOk = true;

	for(int i = 0; i < sourceImages.Count; i++) {
		string imagePath = sourceImages[i].ToString();
		string imageName = clr.System.IO.Path.GetFileName(imagePath);
		done = done + 1;
		TouchProgress(false, done, total, imageName);

		if(!ProcessOneImage(imagePath)) {
			batchOk = false;
			failedCount = failedCount + 1;
			ReportImageFailure(imagePath, @processStep, @processError);
			TouchProgress(true, done, total, "failed: " & imageName);
			continue;
		}
		processedSources.Add(imagePath);
		if(@processIsTaken == 1) {
			takenCount = takenCount + 1;
		} else {
			notTakenCount = notTakenCount + 1;
		}
		TouchProgress(true, done, total, BuildProgressLabel(imageName, @processIsTaken));
	}

	if(!batchOk) {
		mark("FF005F", "Batch failed. Source images were not deleted.");
		mark("FF005F", "Failed: " & failedCount & "; succeeded: " & processedSources.Count);
		result = "Batch failed.";
		goto end_main;
	}

	if(@deleteSourceImages) {
		TouchProgress(true, total, total, "Deleting sources");
		if(!DeleteProcessedSources(processedSources)) {
			mark("FF005F", "Batch processing succeeded but source deletion failed.");
			result = "Source deletion failed.";
			goto end_main;
		}
	} else {
		mark("3399FF", "Source images kept in: " & @sourceFolder);
	}

	clr.LiveProgressConsole.Progress(@progressTitle, 100, "Done");
	mark("5FD7AF", "Completed: " & processedSources.Count);
	mark("5FD7AF", "Taken: " & takenCount);
	mark("5FD7AF", "Not taken: " & notTakenCount);
	result = "Completed: " & processedSources.Count & "; Taken: " & takenCount & "; Not taken: " & notTakenCount;

end_main:
	if(@progressStarted) {
		clr.LiveProgressConsole.Stop();
	}
	=> result;
}

void EnsureDestinationFolders() {
	if(!clr.Directory.Exists(@takenFolder.ToString())) {
		_ clr.Directory.CreateDirectory(@takenFolder.ToString());
	}
	if(!clr.Directory.Exists(@trainingFolder.ToString())) {
		_ clr.Directory.CreateDirectory(@trainingFolder.ToString());
	}
}

func EnsureTrainingDatabase() {
	string parent = clr.System.IO.Path.GetDirectoryName(@trainingDbPath.ToString());
	if(!clr.System.String.IsNullOrEmpty(parent) && !clr.Directory.Exists(parent)) {
		_ clr.Directory.CreateDirectory(parent);
	}
	string schema = "PRAGMA journal_mode=WAL;\r\n"
		& "PRAGMA busy_timeout=30000;\r\n"
		& "CREATE TABLE IF NOT EXISTS training_images (\r\n"
		& "    id INTEGER PRIMARY KEY AUTOINCREMENT,\r\n"
		& "    image_name TEXT NOT NULL,\r\n"
		& "    image_path TEXT NOT NULL,\r\n"
		& "    is_taken INTEGER NOT NULL CHECK (is_taken IN (0, 1)),\r\n"
		& "    source_tag_id INTEGER NULL,\r\n"
		& "    discovered_at TEXT NOT NULL,\r\n"
		& "    processed_at TEXT NULL,\r\n"
		& "    taken_copy_path TEXT NULL,\r\n"
		& "    training_copy_path TEXT NULL,\r\n"
		& "    UNIQUE(image_path)\r\n"
		& ");\r\n"
		& "CREATE INDEX IF NOT EXISTS idx_training_images_name ON training_images(image_name);\r\n"
		& "CREATE INDEX IF NOT EXISTS idx_training_images_taken ON training_images(is_taken);\r\n";
	var result = RunTrainingSqlite(schema);
	if(!result) {
		mark("FF005F", "Failed to initialize training database: " & @processStdErr);
	}
	=> result;
}

func CollectSourceImages() {
	var images = new clr.System.Collections.ArrayList();
	if(!clr.Directory.Exists(@sourceFolder.ToString())) {
		=> images;
	}
	var files = clr.Directory
		.EnumerateFiles(@sourceFolder.ToString(), "*.*", clr.System.IO.SearchOption.TopDirectoryOnly)
		.ToArrayList();
	for(int i = 0; i < files.Count; i++) {
		string filePath = files[i].ToString();
		string fileName = clr.System.IO.Path.GetFileName(filePath);
		if(IsTrainingDbFile(fileName)) {
			continue;
		}
		if(IsSupportedImageFile(fileName)) {
			images.Add(filePath);
		}
	}
	=> images;
}

func IsTrainingDbFile(fileName) {
	=> clr.System.String.Equals(
		fileName.ToString(),
		@trainingDbFileName.ToString(),
		clr.System.StringComparison.OrdinalIgnoreCase
	);
}

func IsSupportedImageFile(fileName) {
	string extension = clr.System.IO.Path.GetExtension(fileName.ToString()).ToLowerInvariant();
	=> extension == ".jpg"
		|| extension == ".jpeg"
		|| extension == ".png"
		|| extension == ".webp";
}

func ProcessOneImage(imagePathIn) {
	string imagePath = imagePathIn.ToString();
	string imageName = clr.System.IO.Path.GetFileName(imagePath);
	string takenCopyPath = "";
	string trainingCopyPath = clr.System.IO.Path.Combine(@trainingFolder.ToString(), imageName);
	string nowUtc = Iso8601UtcNow();

	@processOk = false;
	@processStep = "";
	@processError = "";
	@processIsTaken = 1;

	if(!LookupIsTaken(imageName)) {
		@processStep = "digiKam lookup";
		@processError = @lookupError;
		=> false;
	}

	int isTaken = @lookupIsTaken;
	int sourceTagId = @lookupSourceTagId;
	string sourceTagSql = "NULL";
	if(sourceTagId >= 0) {
		sourceTagSql = sourceTagId.ToString();
	}
	@processIsTaken = isTaken;

	if(!UpsertTrainingRecord(imageName, imagePath, isTaken, sourceTagSql, nowUtc)) {
		@processStep = "training database upsert";
		@processError = @lookupError;
		=> false;
	}

	if(isTaken == 1) {
		takenCopyPath = clr.System.IO.Path.Combine(@takenFolder.ToString(), imageName);
		if(!CopyImageFile(imagePath, takenCopyPath)) {
			@processStep = "Taken copy";
			@processError = @lookupError;
			=> false;
		}
	}

	if(!CopyImageFile(imagePath, trainingCopyPath)) {
		@processStep = "Training copy";
		@processError = @lookupError;
		=> false;
	}

	string takenPathSql = "NULL";
	if(!clr.System.String.IsNullOrEmpty(takenCopyPath)) {
		takenPathSql = SqlQuote(takenCopyPath);
	}
	if(!FinalizeTrainingRecord(
		imagePath,
		nowUtc,
		takenPathSql,
		SqlQuote(trainingCopyPath)
	)) {
		@processStep = "training database update";
		@processError = @lookupError;
		=> false;
	}

	@processOk = true;
	=> true;
}

// Source files live under d:\Models\Images\ and digiKam stores them in the
// album root labeled "Images". When several Images rows share a file name,
// prefer that album; if nothing matches, fall back to any row with that name.
func LookupIsTaken(imageNameIn) {
	string imageName = imageNameIn.ToString();
	@lookupOk = false;
	@lookupIsTaken = 1;
	@lookupSourceTagId = -1;
	@lookupError = "";

	string sql = BuildIsTakenQuery(imageName, true);
	if(!RunDigiKamQuery(sql)) {
		@lookupError = @processStdErr;
		=> false;
	}
	if(ParseIsTakenQueryOutput(@processStdOut)) {
		@lookupOk = true;
		=> true;
	}

	sql = BuildIsTakenQuery(imageName, false);
	if(!RunDigiKamQuery(sql)) {
		@lookupError = @processStdErr;
		=> false;
	}
	if(ParseIsTakenQueryOutput(@processStdOut)) {
		@lookupOk = true;
		=> true;
	}

	// No digiKam row: treat as taken (no tag 20 present).
	@lookupOk = true;
	@lookupIsTaken = 1;
	@lookupSourceTagId = -1;
	=> true;
}

func BuildIsTakenQuery(imageName, restrictToImagesAlbum) {
	string quotedName = SqlQuote(imageName);
	string albumFilter = "";
	if(restrictToImagesAlbum) {
		albumFilter = " AND lower(ar.label) = 'images'";
	}
	=> "SELECT CASE WHEN SUM(CASE WHEN it.tagid = 20 THEN 1 ELSE 0 END) > 0 THEN 0 ELSE 1 END,"
		& " CASE WHEN SUM(CASE WHEN it.tagid = 20 THEN 1 ELSE 0 END) > 0 THEN 20 ELSE NULL END"
		& " FROM Images i"
		& " LEFT JOIN ImageTags it ON it.imageid = i.id"
		& " LEFT JOIN Albums a ON a.id = i.album"
		& " LEFT JOIN AlbumRoots ar ON ar.id = a.albumRoot"
		& " WHERE i.name = " & quotedName & albumFilter & ";";
}

func ParseIsTakenQueryOutput(outputText) {
	string trimmed = outputText.ToString().Trim();
	if(trimmed.IsEmpty()) {
		=> false;
	}
	var parts = trimmed.Split("|".ToCharArray(), clr.System.StringSplitOptions.None);
	if(parts.Length < 1) {
		=> false;
	}
	try {
		@lookupIsTaken = clr.System.Convert.ToInt32(parts[0].Trim());
	}
	catch {
		@lookupError = "Unexpected digiKam lookup result: " & trimmed;
		=> false;
	}
	@lookupSourceTagId = -1;
	if(parts.Length > 1 && !parts[1].Trim().IsEmpty()) {
		try {
			@lookupSourceTagId = clr.System.Convert.ToInt32(parts[1].Trim());
		}
		catch {
			@lookupSourceTagId = -1;
		}
	}
	=> true;
}

func UpsertTrainingRecord(imageName, imagePath, isTaken, sourceTagSql, discoveredAt) {
	string sql = "PRAGMA busy_timeout=30000;\r\nBEGIN IMMEDIATE;\r\n"
		& "INSERT INTO training_images("
		& "image_name, image_path, is_taken, source_tag_id, discovered_at"
		& ") VALUES ("
		& SqlQuote(imageName) & ","
		& SqlQuote(imagePath) & ","
		& isTaken & ","
		& sourceTagSql & ","
		& SqlQuote(discoveredAt)
		& ") ON CONFLICT(image_path) DO UPDATE SET "
		& "image_name=excluded.image_name,"
		& "is_taken=excluded.is_taken,"
		& "source_tag_id=excluded.source_tag_id;\r\n"
		& "COMMIT;\r\n";
	var result = RunTrainingSqlite(sql);
	if(!result) {
		@lookupError = @processStdErr;
		=> false;
	}
	=> true;
}

func FinalizeTrainingRecord(imagePath, processedAt, takenPathSql, trainingPathSql) {
	string sql = "PRAGMA busy_timeout=30000;\r\nBEGIN IMMEDIATE;\r\n"
		& "UPDATE training_images SET "
		& "processed_at=" & SqlQuote(processedAt) & ","
		& "taken_copy_path=" & takenPathSql & ","
		& "training_copy_path=" & trainingPathSql
		& " WHERE image_path=" & SqlQuote(imagePath) & ";\r\n"
		& "COMMIT;\r\n";
	var result = RunTrainingSqlite(sql);
	if(!result) {
		@lookupError = @processStdErr;
		=> false;
	}
	=> true;
}

// Destination copies overwrite existing files so reruns stay deterministic.
func CopyImageFile(sourcePath, destinationPath) {
	bool ok = false;
	try {
		clr.File.Copy(sourcePath.ToString(), destinationPath.ToString(), true);
		ok = true;
	}
	catch {
		@lookupError = "File copy failed: " & sourcePath.ToString() & " -> " & destinationPath.ToString();
		ok = false;
	}
	=> ok;
}

func DeleteProcessedSources(processedSources) {
	bool ok = true;
	for(int i = 0; i < processedSources.Count; i++) {
		string sourcePath = processedSources[i].ToString();
		try {
			if(clr.File.Exists(sourcePath)) {
				clr.File.Delete(sourcePath);
			}
		}
		catch {
			mark("FF005F", "Failed to delete source: " & sourcePath);
			ok = false;
		}
	}
	=> ok;
}

func RunTrainingSqlite(sqlText) {
	var args = new clr.System.Collections.ArrayList();
	args.Add(@trainingDbPath.ToString());
	RunProcess(@sqlite, args, sqlText);
	=> @processExitCode == 0;
}

func RunDigiKamQuery(sqlText) {
	var args = new clr.System.Collections.ArrayList();
	args.Add(@digiKamDbUri.ToString());
	args.Add(sqlText.ToString());
	RunProcess(@sqlite, args, null);
	=> @processExitCode == 0;
}

void RunProcess(executable, arguments, standardInputText) {
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
	@processExitCode = process.ExitCode;
	@processStdOut = stdoutText;
	@processStdErr = stderrText;
	process.Dispose();
}

func SqlQuote(value) {
	=> "'" & value.ToString().ReplStr("'", "''") & "'";
}

func Iso8601UtcNow() {
	=> clr.System.DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss") & "Z";
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

func BuildProgressLabel(imageName, isTaken) {
	if(isTaken == 1) {
		=> imageName.ToString() & " (taken)";
	}
	=> imageName.ToString() & " (not taken)";
}

void TouchProgress(updateBar, done, total, statusText) {
	string label = done.ToString() & "/" & total.ToString() & " " & statusText.ToString();
	clr.LiveProgressConsole.Status(@progressTitle, label);
	if(updateBar || (done % @progressStep) == 0 || done >= total) {
		clr.LiveProgressConsole.Progress(@progressTitle, Percent(done, total), label);
	}
}

void ReportImageFailure(imagePath, step, errorMessage) {
	string imageName = clr.System.IO.Path.GetFileName(imagePath.ToString());
	mark("FF005F", "Failed: " & imageName);
	mark("FF005F", "  step: " & step.ToString());
	mark("FF005F", "  error: " & errorMessage.ToString());
}

func PromptDeleteSourceImages() {
	var cfgTpl = new { delete_source_images: true };
	var cfg = LoadUserConfig("process_desc_pics.json", cfgTpl);
	bool lastDelete = true;
	if(cfg != null) {
		lastDelete = cfg.delete_source_images;
	}

	string preferred = lastDelete ? @deleteOptionYes.ToString() : @deleteOptionNo.ToString();
	var choices = new clr.System.Collections.ArrayList();
	choices.Add(@deleteOptionYes.ToString());
	choices.Add(@deleteOptionNo.ToString());
	string selection = clr.Console.Prompt(
		"Delete processed images from Images folder after successful batch?",
		choices,
		preferred
	);
	bool deleteSources = selection == @deleteOptionYes.ToString();
	SaveUserConfig("process_desc_pics.json", new { delete_source_images: deleteSources });
	mark("5FD7AF", "Delete source images: " & (deleteSources ? "Yes" : "No"));
	=> deleteSources;
}

func LoadUserConfig(fileName, templateObj) {
	string path = GetUserConfigPath(fileName);
	if(!clr.File.Exists(path)) { => templateObj; }
	var obj = templateObj;
	try {
		obj = clr.Ex.Json.Deserialize(clr.File.ReadAllText(path), templateObj);
	} catch { obj = templateObj; }
	=> obj;
}

void SaveUserConfig(fileName, obj) {
	try {
		clr.File.WriteAllText(
			GetUserConfigPath(fileName),
			clr.Ex.Json.Serialize(obj)
		);
	} catch {
		mark("FF005F", "Could not save process_desc_pics preferences.");
	}
}

func GetUserConfigPath(fileName) {
	string root = clr.System.Environment.GetFolderPath(
		clr.System.Environment.SpecialFolder.UserProfile);
	string folder = root & "\\xs_config";
	if(!clr.Directory.Exists(folder)) { clr.Directory.CreateDirectory(folder); }
	=> folder & "\\" & fileName;
}

void mark(color, content) {
	clr.Console.Markup(
		"[#" & color & "]"
		& content.ToString().ReplStr("[", "").ReplStr("]", "").ReplStr("[/]", "")
		& "[/]\r\n"
	);
}
