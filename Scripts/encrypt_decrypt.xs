/*
Usage:
Encrypt single-file: clr encrypt_decrypt.xs R:\readme.txt 123
Encrypt folder: clr encrypt_decrypt.xs R:\*.txt 123

Decrypt single-file: clr encrypt_decrypt.xs R:\readme.txt.enc 123
Decrypt folder: clr encrypt_decrypt.xs R:\*.enc 123
*/

import System.Convert as Convert;
import System.Collections.ArrayList as ArrayList;
import System.Collections.Generic.List`1[System.Byte] as ListBytes;

import System.IO.Directory as Dir;
import System.IO.File as File;
import System.IO.Path as Path;
import System.IO.FileStream as FileStream;

import UnifiedTool.Security.AES as Aes;

import Ex.ProgressConsole as ProgressConsole;
import Ex.Console as Console;

@MaxChunk = 1024;

string result = "done";
string path = [p1], password = [p2];

if(path.IsEmpty()) {
	path = clr.Console.Ask("Please give the path\r\n");
}

if(password.IsEmpty()) {
	password = clr.Console.Secret("Please enter [green]password[/]\r\n");
}

if(path.IsEmpty() || password.IsEmpty()) {
	result = "aborted";
	goto done;
}

var files = ResolveFiles(path);

if(files == null || files.Count == 0) {
	mark("FCCE49", "No files matched.");
	goto done;
}

PrepareProgress(files);

string f = "", ext = "";

for(int i = 0; i < files.Count; i++) {
	f = files[i].ToString();
	ext = clr.Path.GetExtension((string)f).ToLower();

	if(ext == ".enc") {
		DecryptFile(f, password);
	}
	else {
		EncryptFile(f, password);
	}
}

clr.ProgressConsole.Stop();

done:
=> result;


// ---------- console ----------

void mark(color, content) {
	clr.Console.Markup(
		"[#" & color & "]"
		& content.ReplStr("[", "").ReplStr("]", "").ReplStr("[/]", "")
		& "[/]\r\n"
	);
}


// ---------- bytes ----------

func NewBytes(n) {
	int c = clr.Convert.ToInt32(n);
	var lst = new clr.ListBytes();
	for(int i = 0; i < c; i++) {
		lst.Add(0);
	}
	=> lst.ToArray();
}


// ---------- helpers ----------

func ResolveFiles(path) {
	var arr = new clr.ArrayList();

	if(clr.File.Exists((string)path)) {
		arr.Add((string)path);
		=> arr;
	}

	if(clr.Dir.Exists((string)path)) {
		=> clr.Dir
			.EnumerateFiles((string)path, "*.*", clr.System.IO.SearchOption.TopDirectoryOnly)
			.ToArrayList();
	}

	int idx = path.ToString().LastIndexOf("\\");
	if(idx < 0) { => arr; }

	string folder = path.ToString().Substring(0, idx + 1);
	string pattern = path.ToString().Substring(idx + 1);

	if(!clr.Dir.Exists(folder)) { => arr; }

	=> clr.Dir
		.EnumerateFiles(folder, pattern, clr.System.IO.SearchOption.TopDirectoryOnly)
		.ToArrayList();
}

func TitleOf(f) {
	string p = f.ToString();
	string ext = clr.Path.GetExtension((string)p).ToLower();
	string mode = ext == ".enc" ? "Decrypt " : "Encrypt ";
	string name = clr.Path.GetFileName((string)p);
	var len = new clr.System.IO.FileInfo((string)p).Length;
	=> mode & name & " " & len & " bytes";
}

func Percent(remain, total) {
	double d_curr = clr.Convert.ToDouble(remain);
	double d_total = clr.Convert.ToDouble(total);
	if(d_total <= 0) { => 100; }
	=> clr.System.Math.Ceiling(d_curr / d_total * 100);
}


// ---------- crypto ----------

void EncryptFile(path, key) {
	string p = path.ToString();
	if(clr.Path.GetExtension((string)p).ToLower() == ".enc") { return; }

	var r = new clr.FileStream((string)p, clr.System.IO.FileMode.Open);
	var w = new clr.FileStream(p & ".enc", clr.System.IO.FileMode.OpenOrCreate);

	var left = r.Length;
	var total = left;
	string title = TitleOf(p);

	int n = 0, read = 0;
	var buf = NewBytes(0);

	while(left > 0) {
		n = left > @MaxChunk ? (int)@MaxChunk : (int)left;
		buf = NewBytes(n);

		read = r.Read(buf, 0, n);
		left = left - read;

		var enc = clr.Aes.Encrypt((string)key, buf);
		w.Write(enc, 0, enc.Length);

		clr.ProgressConsole.Progress(title, 100 - Percent(left, total));
	}

	r.Close(); w.Close();
	r.Dispose(); w.Dispose();
}

void DecryptFile(path, key) {
	string p = path.ToString();
	if(clr.Path.GetExtension((string)p).ToLower() != ".enc") { return; }

	string outPath = p.ReplStr(".enc", "");

	var r = new clr.FileStream((string)p, clr.System.IO.FileMode.Open);
	var w = new clr.FileStream((string)outPath, clr.System.IO.FileMode.OpenOrCreate);

	var left = r.Length;
	var total = left;
	string title = TitleOf(p);

	int max = (int)@MaxChunk + 16 - ((int)@MaxChunk % 16);
	int n = 0, read = 0;
	var buf = NewBytes(0);

	while(left > 0) {
		n = left > max ? max : (int)left;
		buf = NewBytes(n);

		read = r.Read(buf, 0, n);
		left = left - read;

		var dec = clr.Aes.Decrypt((string)key, buf);
		w.Write(dec, 0, dec.Length);

		clr.ProgressConsole.Progress(title, 100 - Percent(left, total));
	}

	r.Close(); w.Close();
	r.Dispose(); w.Dispose();
}

void PrepareProgress(files) {
	var list = new clr.ArrayList();
	for(int i = 0; i < files.Count; i++) {
		list.Add((string)TitleOf(files[i]));
	}
	clr.ProgressConsole.Start(list);
}
