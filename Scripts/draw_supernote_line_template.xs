import Ex.Console as Console;
import System.String as Str;
import System.Int32 as Int32;

int lineMm = AskLineSpacingMm();
string cmd = BuildDrawLinesCommand(lineMm);

_ Run(cmd);

=> 1;

func AskLineSpacingMm() {
	string input = "";
	int mm = 8;

	input = clr.Console.Ask("Line spacing (mm)");
	if(!clr.Str.IsNullOrWhiteSpace(input)) {
		mm = clr.Int32.Parse(input.Trim());
	}

	=> mm;
}

func BuildDrawLinesCommand(pLineMm) {
	int lineMm = 8;
	string s = "";

	if(pLineMm != null) {
		lineMm = clr.Int32.Parse(pLineMm.ToString());
	}

	StringBuilder ps =<<<
& { `
	$ErrorActionPreference='Stop'; `
	Add-Type -AssemblyName System.Drawing; `
	$Width=1920; `
	$Height=2560; `
	$Dpi=300; `
	$LineSpacingMm=__LINE_MM__; `
	$MarginTopMm=0; `
	$MarginBottomMm=0; `
	$MarginLeftMm=0; `
	$MarginRightMm=0; `
	$LineColorHex='B0B0B0'; `
	$LineAlpha=255; `
	$LineThicknessPx=1; `
	$TransparentBackground=$true; `
	$OutFile="$PWD\template-lined-$($LineSpacingMm)mm.png"; `
	function MmToPx([double]$mm,[double]$dpi){ [int][Math]::Round(($mm/25.4)*$dpi) }; `
	function ParseHexColor([string]$hex,[int]$a){ `
		$h=$hex.Trim().TrimStart('#'); `
		if($h.Length -ne 6){ throw "LineColorHex must be 6 hex chars like B0B0B0"; }; `
		$r=[Convert]::ToInt32($h.Substring(0,2),16); `
		$g=[Convert]::ToInt32($h.Substring(2,2),16); `
		$b=[Convert]::ToInt32($h.Substring(4,2),16); `
		[System.Drawing.Color]::FromArgb([Math]::Max(0,[Math]::Min(255,$a)),$r,$g,$b) `
	}; `
	$spacingPx=MmToPx $LineSpacingMm $Dpi; `
	if($spacingPx -lt 1){ throw "LineSpacingMm too small for DPI; spacingPx=$spacingPx"; }; `
	$mt=MmToPx $MarginTopMm $Dpi; `
	$mb=MmToPx $MarginBottomMm $Dpi; `
	$ml=MmToPx $MarginLeftMm $Dpi; `
	$mr=MmToPx $MarginRightMm $Dpi; `
	$color=ParseHexColor $LineColorHex $LineAlpha; `
	$pf=[System.Drawing.Imaging.PixelFormat]::Format32bppArgb; `
	$bmp=New-Object System.Drawing.Bitmap($Width,$Height,$pf); `
	$bmp.SetResolution($Dpi,$Dpi); `
	$g=[System.Drawing.Graphics]::FromImage($bmp); `
	$g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::None; `
	$g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor; `
	$g.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::Half; `
	if($TransparentBackground){ $g.Clear([System.Drawing.Color]::Transparent) } else { $g.Clear([System.Drawing.Color]::White) }; `
	$pen=New-Object System.Drawing.Pen($color,[float]$LineThicknessPx); `
	$x1=[Math]::Max(0,$ml); `
	$x2=[Math]::Min($Width-1,$Width-1-$mr); `
	$y=$mt; `
	while($y -le ($Height-1-$mb)){ `
		$g.DrawLine($pen,$x1,$y,$x2,$y); `
		$y+=$spacingPx `
	}; `
	$dir=[System.IO.Path]::GetDirectoryName($OutFile); `
	if(-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -LiteralPath $dir)){ `
		[System.IO.Directory]::CreateDirectory($dir) | Out-Null `
	}; `
	$bmp.Save($OutFile,[System.Drawing.Imaging.ImageFormat]::Png); `
	$pen.Dispose(); `
	$g.Dispose(); `
	$bmp.Dispose(); `
	Write-Host $OutFile `
}
>>>;

	s = ps.ToString().Replstr("__LINE_MM__", lineMm.ToString());
	=> s;
}

func Run(command) {
	=> clr.Ex.Powershell.Run(command.ToString()).StandardOutput;
}

void mark(color, content) {
	clr.Ex.Console.Markup("[#" & color & "]"
		& content.ReplStr("[", "").ReplStr("]", "").ReplStr("[/]", "")
		& "[/]\r\n"
	);
}
