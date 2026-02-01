import System.String as Str;
import System.Collections.ArrayList as ArrayList
import Ex.Console as Console;
import System.IO.File as File;
import System.Collections.Generic.Dictionary`2[System.String,System.String] as Dictionary
import Newtonsoft.Json.Linq.JObject as JObject;
import Newtonsoft.Json.Linq.JArray as JArray;
import Newtonsoft.Json.Linq.JToken as JToken;


string folder = [p1], scale;

if(clr.Str.IsNullOrEmpty(folder) || !clr.System.IO.Directory.Exists(folder)) {
	folder = GetFolderFromConfig();
}

while(folder == url || !clr.System.IO.Directory.Exists(folder)) {
	folder = clr.Console.Ask("Please give the folder to the media files?\r\n");
}

var options = (clr.Dictionary)PrepareOptions();
var videoSizeOptions = (clr.Dictionary)PrepareVideoSize();
string selection = clr.Console.Prompt("Which option do you want?",
								options.Keys.ToArrayList());
string choice = options.get_item(selection);

@videoSize = "1920";


// 1. Prepare folder
string processingFolder = build_processing_folder(folder).ToString();

// 2. Prepare files
var files = get_mp4_files_with_path(folder).ToArrayList();
remove_irregular_chars(files);
files = get_mp4_files_with_path(folder).ToArrayList();

// 3. Do it
if(choice == "all") {
	write_to_mp4(files, folder);
	write_to_mp4_no_resize(files, folder);
	write_to_no_audio(files, folder);
	write_to_fast_forward(files, folder);
	write_to_gif(files, folder);
}
if(choice == "write_to_mp4") {
	@videoSize = clr.Console.Prompt("Which video size do you want?", videoSizeOptions.Keys.ToArrayList());
	write_to_mp4(files, folder);
}
if(choice == "write_to_mp4_no_resize") {
	write_to_mp4_no_resize(files, folder);
}
if(choice == "write_to_no_audio") {
	write_to_no_audio(files, folder);
}
if(choice == "write_to_fast_forward") {
	write_to_fast_forward(files, folder);
}
if(choice == "write_to_gif") {
	write_to_gif(files, folder);
}
if(choice == "write_to_gif_scale") {
	scale = clr.Console.Ask("Please tell how much to scaling?\r\n");
	write_to_gif_scale(files, folder, scale);
}


SaveUserConfig("media_convert.txt", new { last_folder: folder });

=> "done";

func GetFolderFromConfig() {
	var cfg = new { last_folder: "" }, input = "", folder = "";
	cfg = LoadUserConfig("media_convert.txt", cfg);
	if(cfg != null) {
		folder = cfg.last_folder; mark("5FD7AF", "Folder: " & folder);
		input = clr.Console.Ask("Please give the folder to the files? Yes (y) is for no change: \r\n");
		if(!clr.System.String.IsNullOrWhiteSpace(input) && input.Trim() != "y" && input.Trim() != "yes" ) { folder = input; }
	}
	=> folder;
}

func GetWorkingDirectory() {
	string folder = [p1], input = "";
	if(clr.System.String.IsNullOrEmpty(folder) || !clr.System.IO.Directory.Exists(folder)) {
		folder = clr.System.IO.Directory.GetCurrentDirectory();
	}

	mark("3399FF", "Folder: " & folder);
	input = clr.Console.Ask("Please give the folder to the files? Yes (y) is for no change: \r\n");
	if(!clr.Str.IsNullOrWhiteSpace(input) && input.Trim() != "y" && input.Trim() != "yes" ) { folder = input; }
	while (!clr.System.IO.Directory.Exists(folder)) {
		mark("3399FF", "Folder: " & folder);
		input = clr.Console.Ask("Please give the folder to the files? \r\n");
		folder = input;
	}
	=> folder;
}

func PrepareOptions() {
	var options = new clr.Dictionary();
	options.Add("all", "all");
	options.Add("mp4", "write_to_mp4");
	options.Add("mp4 no resize", "write_to_mp4_no_resize");
	options.Add("mp4 no audio", "write_to_no_audio");
	options.Add("mp4 fast forward", "write_to_fast_forward");
	options.Add("mp4 to gif", "write_to_gif");
	options.Add("gif scale", "write_to_gif_scale");

	=> options;
}

func PrepareVideoSize() {
	var options = new clr.Dictionary();
	options.Add("1920", "1920");
	options.Add("1280", "1280");

	=> options;
}


void write_to_mp4(files_arr, folder) {
	StringBuilder sb;
	sb.AppendLine("::代码页中文\r\nchcp 65001");
	var files = (clr.System.Collections.ArrayList)files_arr;
	for(int i = 0; i < files.Count; i++) {
		sb.Append(
			convert_to_mp4(files.get_item(i))
		).AppendLine();
	}
	clr.System.IO.File.WriteAllText(
			clr.System.IO.Path.Combine(folder, "convert_to_mp4.bat"), 
			sb.ToString(), clr.System.Text.Encoding.UTF8);
}


void write_to_mp4_no_resize(files_arr, folder) {
	StringBuilder sb;
	sb.AppendLine("::代码页中文\r\nchcp 65001");
	var files = (clr.System.Collections.ArrayList)files_arr;
	for(int i = 0; i < files.Count; i++) {
		sb.Append(
			convert_to_mp4_faststart(files.get_item(i))
		).AppendLine();
	}
	clr.System.IO.File.WriteAllText(
			clr.System.IO.Path.Combine(folder, "convert_to_mp4_no_resize.bat"), 
			sb.ToString(), clr.System.Text.Encoding.UTF8);
}

void write_to_no_audio(files_arr, folder) {
	StringBuilder sb;
	sb.AppendLine("::代码页中文\r\nchcp 65001");
	var files = (clr.System.Collections.ArrayList)files_arr;
	for(int i = 0; i < files.Count; i++) {
		sb.Append(
			remove_mp4_audio(files.get_item(i))
		).AppendLine();
	}
	clr.System.IO.File.WriteAllText(
			clr.System.IO.Path.Combine(folder, "convert_to_mp4_no_audio.bat"), 
			sb.ToString(), clr.System.Text.Encoding.UTF8);
}


void write_to_fast_forward(files_arr, folder) {
	int speed = clr.Console.Ask("Please give the x of speed?\r\n");
	StringBuilder sb;
	sb.AppendLine("::代码页中文\r\nchcp 65001");
	var files = (clr.System.Collections.ArrayList)files_arr;
	for(int i = 0; i < files.Count; i++) {
		sb.Append(
			fast_foward(speed, files.get_item(i))
		).AppendLine();
	}
	clr.System.IO.File.WriteAllText(
			clr.System.IO.Path.Combine(folder, "convert_to_mp4_fast_forward.bat"), 
			sb.ToString(), clr.System.Text.Encoding.UTF8);
}

void write_to_gif(files_arr, folder) {
	StringBuilder sb;
	sb.AppendLine("::代码页中文\r\nchcp 65001");
	var files = (clr.System.Collections.ArrayList)files_arr;
	for(int i = 0; i < files.Count; i++) {
		sb.Append(
			mp4_to_gif(files.get_item(i))
		).AppendLine();
	}
	clr.System.IO.File.WriteAllText(
			clr.System.IO.Path.Combine(folder, "convert_to_gif.bat"), 
			sb.ToString(), clr.System.Text.Encoding.UTF8);
}

void write_to_gif_scale(files_arr, folder, scale) {
	StringBuilder sb;
	sb.AppendLine("::代码页中文\r\nchcp 65001");
	var files = (clr.System.Collections.ArrayList)files_arr;
	for(int i = 0; i < files.Count; i++) {
		sb.Append(
			gif_scale(files.get_item(i), scale)
		).AppendLine();
	}
	clr.System.IO.File.WriteAllText(
			clr.System.IO.Path.Combine(folder, "gif_scale.bat"), 
			sb.ToString(), clr.System.Text.Encoding.UTF8);
}

func resize(w, h) {
	=> "-filter:v \"scale=iw*min(" & w &"/iw\\," & h &"/ih):ih*min(" & w &"/iw\\," & h &"/ih), pad=" & w &":" & h &":(" & w &"-iw*min(" & w &"/iw\\," & h &"/ih))/2:(" & h &"-ih*min(" & w &"/iw\\," & h &"/ih))/2\" " ;
}

func build_scale(width, height) {
	//-filter:v "scale=iw*min($width/iw\,$height/ih):ih*min($width/iw\,$height/ih), pad=$width:$height:($width-iw*min($width/iw\,$height/ih))/2:($height-ih*min($width/iw\,$height/ih))/2"
	return "scale=iw*min(" & width & "/iw\," & height & "/ih):ih*min(" & width & "/iw\," & height & "/ih)";
}
func build_pad(width, height) {
	//-filter:v "scale=iw*min($width/iw\,$height/ih):ih*min($width/iw\,$height/ih), pad=$width:$height:($width-iw*min($width/iw\,$height/ih))/2:($height-ih*min($width/iw\,$height/ih))/2"
	return "pad=" & width & ":" & height & ":(" & width & "-iw*min(" & width & "/iw\," & height & "/ih))/2:(" & height & "-ih*min(" & width & "/iw\," & height & "/ih))/2";
}

func get_mp4_files_with_path(input_folder) {
	var arr = new clr.System.Collections.ArrayList();
	string folder = (string)input_folder;
	folder = folder.ToLower();
	var files = clr.System.IO.Directory.GetFiles(folder).ToArrayList();
	var ext = "";
	for (int i = 0; i < files.Count; i++) {
		ext = clr.System.IO.Path.GetExtension(files.get_item(i).ToString()).ToLower();
		if (ext == ".mov" || ext == ".wmv" || ext == ".avi" || ext == ".mp4" || ext == ".mkv" 
			|| ext == ".rmvb" || ext == ".flv" || ext == ".mpeg") {
			arr.Add(files..get_item(i));
		}
	}
	return arr;
}

func process_folder() { => "Processed"; }

func fast_foward(speed, file) {
	var directory = new clr.System.IO.FileInfo(file).Directory.FullName;
	var output = clr.System.IO.Path.GetFileNameWithoutExtension(file) & "_" & speed & "x.mp4";

	=> get_ffmpeg() & " -i " 
	& "\"" & directory & "\\" & clr.System.IO.Path.GetFileNameWithoutExtension(file) & GetFileExtension(file) & "\""
	& " -c:v libx264 -pix_fmt yuv420p -movflags +faststart"
	& " -filter_complex [0:v]setpts=1/" & speed & "*PTS[v] -map \"[v]\""
	& " \"" & directory & "\\" & process_folder() & "\\" & output & "\"";
}

func mp4_to_gif(input) {
	var directory = new clr.System.IO.FileInfo(input).Directory.FullName;
	var output = clr.System.IO.Path.GetFileNameWithoutExtension(input) & ".gif";
	
	=> get_ffmpeg() & " -i " & input
			&  " -vf \"fps=10,scale=-1:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse\" -loop 0 "
			& " \"" & directory & "\\" & process_folder() & "\\" & output & "\"";
}

func gif_scale(input, scale) {
	var directory = new clr.System.IO.FileInfo(input).Directory.FullName;
	var output = clr.System.IO.Path.GetFileNameWithoutExtension(input) & "_scale" & scale & "x.gif";
	var palette = clr.System.IO.Path.GetFileNameWithoutExtension(input) & "_palette.png";

	StringBuilder sb;
	// Step 1: palettegen
	sb.Append(get_ffmpeg()).Append(" -i ").Append(input)
		.Append(" -vf \"scale=iw*" & scale & ":ih*" & scale & ",palettegen\" ")
		.Append(palette).AppendLine();

	// Step 2: paletteuse
	sb.Append(get_ffmpeg()).Append(" -i ").Append(input)
		.Append(" -i ").Append(palette)
		.Append(" -filter_complex \"scale=iw*" & scale & ":ih*" & scale & "[x];[x][1:v]paletteuse\" ")
		.Append(" ").Append(directory & "\\" & process_folder() & "\\" & output);

	sb.AppendLine();
	sb.AppendLine("del \"" & palette & "\"");

	=> sb;
}

func GetTimeName() {
	var t = clr.System.DateTime.Now;
	=> t.Year & TimeToString(t.Month) & TimeToString(t.Day); //& TimeToString(t.Hour) & TimeToString(t.Minute) 
}

func TimeToString(t) {
	string r = t.ToString();
	if (t < 10) { r = "0" & t ; }
	return r;
}

func GetFileExtension(fileName) {
	var fi = new clr.System.IO.FileInfo(fileName);  
	=> fi.Extension;
}

func convert_to_mp4_faststart(input) {
	var folder = new clr.System.IO.FileInfo(input).Directory.FullName;
	var output = GetTimeName() & "_" & clr.System.IO.Path.GetFileNameWithoutExtension(input) & ".mp4";

	=> get_ffmpeg() & " -i "
	& "\"" & input & "\""
	& " -c:v libx264 -vf \"format=yuv420p" & fps_cap_clause(input, 15) & "\" -c:a mp3 -movflags +faststart "
	& "\"" & folder & "\\" & process_folder() & "\\" & output & "\"" ;
}


func convert_to_mp4(input) {
	string folder = new clr.System.IO.FileInfo(input).Directory.FullName;
	string output = GetTimeName() & "_" & clr.System.IO.Path.GetFileNameWithoutExtension(input) & ".mp4";
	string stream = ""; 
	string venc = select_video_encoder(); 

	if (!clr.System.String.IsNullOrEmpty([p2])) {
		stream = " -map 0:v:0 -map 0:a:" & [p2] & " -c:a copy ";
	}

	=> get_ffmpeg() & " -i "
	& "\"" & input & "\""
	& " -vf \"" & (@videoSize == "1920" ? build_scale(1920, 1080) : build_scale(1280, 720) ) 
				& "," & (@videoSize == "1920" ? build_pad(1920, 1080) : build_pad(1280, 720) ) 
				& fps_cap_clause(input, 15) & "\""
	& " " & venc 
	& " " & stream // only non-empty when [p2] specified
	& " -movflags +faststart "
	//& " -movflags +empty_moov+frag_keyframe+default_base_moof -frag_duration 2000000 "
	& generateSoundTrackMatch(input)
	& "\"" & folder & "\\" & process_folder() & "\\" & output & "\"";
}

func select_video_encoder() {
	//=> "-c:v libx264 -pix_fmt yuv420p -preset slow -crf 23 -tune animation -profile:v high -level:v 4.0";
	=> "-c:v libx264 -pix_fmt yuv420p ";
}


// FIXED: robust FPS probe using real|avg|r; legacy probe_fps removed.
// Tabs used; no early returns (goto exit); func returns are object → convert before use.
// Returns ",fps=fps=<maxFps>" only if chosen FPS > maxFps; otherwise returns "".
func fps_cap_clause(input, maxFps) {
	double cap = 0.0, real = 0.0, avg = 0.0, r = 0.0, src = 0.0;
	string triplet = "", sReal = "", sAvg = "", sR = "", result = "", action = "";
	var parts = new clr.System.Collections.ArrayList();

	cap = clr.System.Double.Parse(maxFps.ToString());
	triplet = probe_fps_triplet(input).ToString();
	parts = triplet.Split("|".ToCharArray(), clr.System.StringSplitOptions.RemoveEmptyEntries).ToArrayList();

	if (parts.Count >= 1) { sReal = parts.get_item(0).ToString(); try { real = clr.System.Double.Parse(sReal); } catch { real = 0.0; } }
	if (parts.Count >= 2) { sAvg  = parts.get_item(1).ToString(); avg = parse_rate(sAvg); }
	if (parts.Count >= 3) { sR    = parts.get_item(2).ToString(); r   = parse_rate(sR); }

	// Choose best available: real (nb_frames/duration) > avg_frame_rate > r_frame_rate
	if (real > 0.1) { src = real; }
	elseif (avg > 0.1) { src = avg; }
	else { src = r; }

	if (src > cap + 0.001) { result = ",fps=fps=" & maxFps; action = "apply"; }
	else { result = ""; action = "skip"; }

	// Status line showing decision context
	mark("5FD7AF", "FPS decision: src=" & src.ToString() & " cap=" & cap.ToString()
		& " action=" & action & " (real/avg/r=" & sReal & "/" & sAvg & "/" & sR & ") "
		& input);

	=> result;
}

// Calls ffprobe once and returns "real|avg|r"
// real = nb_frames / duration (when both available and > 0); avg/r are raw strings from ffprobe.
func probe_fps_triplet(input) {
	string exe = "", cmd = "", out = "", raw = "", nb = "", dur = "", avg = "", r = "", result = "";
	var lines = new clr.System.Collections.ArrayList();
	double frames = 0.0, seconds = 0.0, calc = 0.0;

	exe = get_ffprobe().ToString();
	cmd = exe & " -v error -select_streams v:0 -show_entries stream=nb_frames,duration,avg_frame_rate,r_frame_rate -of default=nk=1:nw=1 " & "\"" & input & "\"";
	out = RunPowershellFromMemory(cmd).ToString().Trim();

	raw = out.Replace("\r", "\n");
	lines = raw.Split("\n".ToCharArray(), clr.System.StringSplitOptions.RemoveEmptyEntries).ToArrayList();

	// Expected order: nb_frames, duration, avg_frame_rate, r_frame_rate
	if (lines.Count >= 1) { nb  = lines.get_item(0).ToString().Replace("\"", "").Trim(); }
	if (lines.Count >= 2) { dur = lines.get_item(1).ToString().Replace("\"", "").Trim(); }
	if (lines.Count >= 3) { avg = lines.get_item(2).ToString().Replace("\"", "").Trim(); }
	if (lines.Count >= 4) { r   = lines.get_item(3).ToString().Replace("\"", "").Trim(); }

	try { frames = clr.System.Double.Parse(nb); } catch { frames = 0.0; }
	try { seconds = clr.System.Double.Parse(dur); } catch { seconds = 0.0; }
	if (frames > 0.0 && seconds > 0.0) { calc = frames / seconds; }

	// Status line showing raw probe values and computed real FPS
	mark("5FD7AF", "ffprobe fps: nb_frames=" & nb & " duration=" & dur
		& " avg=" & avg & " r=" & r & " real=" & calc.ToString() & " " & input);

	result = calc.ToString() & "|" & avg & "|" & r;
	=> result;
}

// Parses "num/den" or plain number into a double; returns 0 on failure.
func parse_rate(rate) {
	string s = "", nstr = "", dstr = "";
	double val = 0.0;
	int n = 0, d = 1, slash = -1;

	s = rate.ToString().Trim();
	if (clr.System.String.IsNullOrEmpty(s)) { goto exit; }

	slash = s.IndexOf("/");
	if (slash >= 0) {
		nstr = s.Substring(0, slash);
		dstr = s.Substring(slash + 1);
		try { n = clr.System.Int32.Parse(nstr); } catch { n = 0; }
		try { d = clr.System.Int32.Parse(dstr); } catch { d = 1; }
		if (d != 0) { val = (double)n / (double)d; }
		goto exit;
	}

	try { val = clr.System.Double.Parse(s); } catch { val = 0.0; }

exit:
	=> val;
}




// lowercase helper

func lc(s) {
	string ss = s == null ? "" : s.ToString();
	=> ss.ToLowerInvariant();
}

func splitCsv(csv) {
	string text = csv == null ? "" : csv.ToString();
	var parts = new clr.System.Collections.ArrayList();
	try { parts = text.Split(",".ToCharArray(), clr.System.StringSplitOptions.RemoveEmptyEntries).ToArrayList(); } catch { parts = new clr.System.Collections.ArrayList(); }
	=> parts;
}

// Direct key access (no SelectToken)
func jtChild(tok, key) {
	var child=(clr.JToken)tok, obj=(clr.JObject)tok;
	string k = key == null ? "" : key.ToString();
	try { obj = (clr.JObject)tok; } catch { obj = null; }
	if (obj != null) { try { child = (clr.JToken)obj.get_Item(k); } catch { child = null; } } else { child = null; }
	=> child;
}
func jtChild2(tok, key1, key2) {
	var a=(clr.JToken)tok, b=(clr.JToken)tok;
	a = jtChild(tok, key1);
	if (a != null) { b = jtChild(a, key2); } else { b = null; }
	=> b;
}
func jtStrKey(tok, key) {
	string v=""; var t=(clr.JToken)tok;
	t = jtChild(tok, key);
	if (t != null) { try { v = t.ToString(); } catch { v = ""; } }
	=> v;
}
func jtStrKey2(tok, key1, key2) {
	string v=""; var t=(clr.JToken)tok;
	t = jtChild2(tok, key1, key2);
	if (t != null) { try { v = t.ToString(); } catch { v = ""; } }
	=> v;
}
func jtIntKey(tok, key, defVal) {
	int v=defVal; string s="";
	var t=(clr.JToken)tok;
	t = jtChild(tok, key);
	if (t != null) { try { s = t.ToString(); } catch { s = ""; } }
	if (s != "") { try { v = clr.System.Int32.Parse(s); } catch { v = defVal; } }
	=> v;
}

func scoreStream(lang, title, handler) {
	string L="", T="", H="", lLower="", tLower="", hLower="", v="";
	int score=0, j=0, k=0;
	var languageCodes, labels;

	L = lang == null ? "" : lang.ToString();
	T = title == null ? "" : title.ToString();
	H = handler == null ? "" : handler.ToString();

	languageCodes = (clr.System.Collections.ArrayList)splitCsv("cmn,chi,zho,zh,zh-cn,zh-hans,zh-hant,zh-tw,zh-hk");
	labels        = (clr.System.Collections.ArrayList)splitCsv("国配,国语,國語,普通话,中文,中文配音,国配国语,国语配音,Mandarin,Chinese,Chi");

	lLower = lc(L).ToString();
	if (lLower == "cmn") { score = score + 140; }
	elseif (lLower == "chi" || lLower == "zho") { score = score + 120; }
	elseif (lLower.IndexOf("zh") == 0) { score = score + 110; }

	for (j=0; j<languageCodes.Count; j++) {
		if (lLower == lc(languageCodes.get_item(j)).ToString()) { score = score + 30; }
	}

	tLower = lc(T).ToString();
	hLower = lc(H).ToString();
	for (k=0; k<labels.Count; k++) {
		v = lc(labels.get_item(k)).ToString();
		if (tLower.Contains(v)) { score = score + 25; }
		if (hLower.Contains(v)) { score = score + 20; }
	}

	// Explicit Mandarin emphasis
	if (tLower.Contains("国语")) { score = score + 100; }
	if (tLower.Contains("普通话")) { score = score + 30; }

	// Cantonese treated as foreign: hard exclude
	if (tLower.Contains("粤语")) { score = score - 100000; }
	if (hLower.Contains("粤语")) { score = score - 100000; }

	=> score;
}

func pickMandarinAudioOrdinal(input) {
	string inPath="", exe="", cmd="", json="", chosenWhy="",
		codec="", bestCodec="", codecLower="", bestCodecLower="",
		currLang="", currTitle="", currHandler="",
		bestLang="", bestTitle="", bestHandler="";
	int idx=-1, bestOrd=-1, sc=0, bestScore=-1, channels=0, bestChannels=-1, n=0, result=-1,
		pref=0, prefBest=0, i=0;
	var root, streamsTok, streams, sTok;

	inPath = input == null ? "" : input.ToString();
	exe = get_ffprobe();

	cmd = exe & " -v error -select_streams a -show_entries " &
		"stream=index,codec_name,channels,channel_layout,bit_rate,sample_rate,disposition.default:stream_tags=language,title,handler_name " &
		"-of json " & "\"" & inPath & "\"";

	try { json = RunPowershellFromMemory(cmd).ToString(); } catch { json = ""; }
	if (json == null) { json = ""; }
	mark("5FD7AF", "Probe audio JSON len=" & json.Length.ToString() & " " & inPath);

	try { root = clr.JObject.Parse(json); } catch { root = new clr.JObject(); }
	try { streamsTok = (clr.JToken)root.get_Item("streams"); } catch { streamsTok = null; }
	if (streamsTok == null) { result = -1; goto exit; }
	try { streams = (clr.JArray)streamsTok; } catch { streams = new clr.JArray(); }
	if (streams == null) { streams = new clr.JArray(); }

	try { n = streams.Count; } catch { n = 0; }

	for (i=0; i<n; i++) {
		try { sTok = streams.get_item(i); } catch { sTok = new clr.Newtonsoft.Json.Linq.JValue(""); }

		idx        = jtIntKey(sTok, "index", -1);
		codec      = jtStrKey(sTok, "codec_name").ToString();
		channels   = jtIntKey(sTok, "channels", 0);
		currLang   = jtStrKey2(sTok, "tags", "language").ToString();
		currTitle  = jtStrKey2(sTok, "tags", "title").ToString();
		currHandler= jtStrKey2(sTok, "tags", "handler_name").ToString();

		codecLower     = lc(codec).ToString();
		bestCodecLower = lc(bestCodec).ToString();

		sc = clr.System.Int32.Parse(scoreStream(currLang, currTitle, currHandler).ToString());
		pref     = codecLower == "aac" ? 2 : (codecLower == "ac3" ? 1 : 0);
		prefBest = bestCodecLower == "aac" ? 2 : (bestCodecLower == "ac3" ? 1 : 0);

		if (sc > bestScore) {
			bestScore = sc; bestOrd = i; bestChannels = channels; bestCodec = codec;
			bestLang = currLang; bestTitle = currTitle; bestHandler = currHandler;
		} elseif (sc == bestScore && sc >= 0) {
			if (channels > bestChannels) {
				bestOrd = i; bestChannels = channels; bestCodec = codec;
				bestLang = currLang; bestTitle = currTitle; bestHandler = currHandler;
			} elseif (channels == bestChannels) {
				if (pref > prefBest) {
					bestOrd = i; bestCodec = codec;
					bestLang = currLang; bestTitle = currTitle; bestHandler = currHandler;
				} elseif (pref == prefBest) {
					if (bestOrd < 0 || i < bestOrd) {
						bestOrd = i; bestCodec = codec;
						bestLang = currLang; bestTitle = currTitle; bestHandler = currHandler;
					}
				}
			}
		}
	}

	chosenWhy = "ord=" & bestOrd.ToString() & " lang='" & bestLang & "' title='" & bestTitle & "' codec=" & bestCodec & " ch=" & bestChannels.ToString();
	mark("5FD7AF", "Chosen audio " & chosenWhy);
	result = bestOrd;

exit:
	=> result;
}

func generateSoundTrackMatch(input) {
	string inPath="", aiStr="";
	int ai=-1;
	StringBuilder s;
	var aiAny;

	inPath = input == null ? "" : input.ToString();
	s = " -map 0:v:0 ";
	aiAny = pickMandarinAudioOrdinal(inPath);
	aiStr = aiAny == null ? "-1" : aiAny.ToString();

	try { ai = clr.System.Int32.Parse(aiStr); } catch { ai = -1; }

	if (ai >= 0) { _ s.Append("-map 0:a:" & ai.ToString() & " -c:a copy "); }
	else { _ s.Append("-map 0:a:0? -c:a copy "); }

	=> s;
}


func AppendFileName(input, toAppend) {
	var folder = new clr.System.IO.FileInfo(input).Directory.FullName;
	var ext = clr.System.IO.Path.GetExtension(input);
	var output = folder & "\\" & clr.System.IO.Path.GetFileNameWithoutExtension(input) & toAppend & ext;
	return output;
}

func remove_mp4_audio(input) {
	var folder = new clr.System.IO.FileInfo(input).Directory.FullName;
	var output = clr.System.IO.Path.GetFileNameWithoutExtension(input) & "_no_audio.mp4";
	=> get_ffmpeg() & " -i " 
	& "\"" & input & "\""
	& " -an -c:v libx264 -pix_fmt yuv420p -movflags +faststart " 
	& "\"" & folder & "\\" & process_folder() & "\\" & output & "\"" ;

}

func build_processing_folder(folder) {
	var folderInfo = new clr.System.IO.DirectoryInfo(folder);
	=> folderInfo.CreateSubdirectory(process_folder());
}

func get_ffmpeg() {
	string result = "D:\\Green\\ffmpeg\\ffmpeg.exe";
	result = "ffmpeg"; goto exit;

	if(clr.File.Exists(result)) {
		goto exit;
	}
	result = "ffmpeg.exe";
	exit: 
	=> result;
}

func get_ffprobe() { => "ffprobe.exe"; }

func build_command(input) {
	var output = clr.System.IO.Path.ChangeExtension(input, ".mp4");
	=>
	"=======" & input & "=======\r\n"
	& get_ffmpeg() & " -i " 
	& "\"" & input & "\""
	& " -c:v libx264 -pix_fmt yuv420p -movflags +faststart "
	& "\"" & output & "\""
	& " " & resize(1920, 1080)
	& clr.System.Environment.Newline & clr.System.Environment.Newline

	& "------去除音频代码-----" & clr.System.Environment.Newline & clr.System.Environment.Newline
	& get_ffmpeg() & " -i " 
	& "\"" & output & "\""
	& " -an -vcodec copy " 

	&  "\r\n\r\n------快速代码-----" 
	& clr.System.Environment.Newline & clr.System.Environment.Newline
	& fast_foward(3, input) 

	& clr.System.Environment.Newline & clr.System.Environment.Newline
	& "=======" & input & "=======\r\n"
	;
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

	//string stderrx = p.StandardError.ReadToEnd();
	var outputStream = p.StandardOutput.BaseStream;
	var ms = new clr.System.IO.MemoryStream();
	outputStream.CopyTo(ms);

	p.WaitForExit();
	/* if(!clr.System.String.IsNullOrEmpty(stderrx)) { 
		mark("F65B3B", stderrx);
	}*/
	p.Dispose();
	outputStream.Dispose();
	string output = clr.System.Text.Encoding.UTF8.GetString(ms.ToArray());
	ms.Dispose();

	return output;
}


void rename_file(file) {
	var ext = clr.System.IO.Path.GetExtension(file).ToLower();
	var folder = new clr.System.IO.FileInfo(file).Directory.FullName;
	var fileToRename = folder & "\\" & clr.System.IO.Path.GetFileName(file).Replace(" ", "_");
	clr.System.IO.File.Move(file, fileToRename);
}

void remove_irregular_chars(input) {
	var files = (clr.System.Collections.ArrayList) input;
	var file = "";
	for(int i = 0; i < files.Count; i++) {
		file = files.get_item(i).ToString().ToLower();
		if(clr.System.IO.Path.GetFileName(file).Contains(" ")) {
			rename_file(file);
		}
	}
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


// mark("FF005F", "Red" ) 
// mark("5FD7AF", "Green" ) 
void mark(color, content) {
	clr.Ex.Console.Markup("[#" & color & "]"
		& content.ToString().Replace("[", "").Replace("]", "").Replace("[/]", "")
		& "[/]\r\n"
	);
}