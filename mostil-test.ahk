#ErrorStdOut UTF-8
#Warn All, StdOut
#SingleInstance force
traySetIcon("shell32.dll", 251)
#include %A_SCRIPTDIR%/mostil.ahk

hotkey("!f5", Mostil.start({
	debug: true,
	closeOnFocusLost: false,
	matchWindowPositionTolerance: 16,
	gui: {
		maxIconCount: 8,
		iconScale: "20%",
		maxIconSize: 256,
		iconOffsetX: "10%",
		iconDist: "8%",
	},
	screens: {
		;Q: { x: -2560, y: -200, w: 2560, h: 2880, split: "v60%", grid: "10%", snap: ["30%", "70%"], inputs: ["h", "n"] },
		;W: { x:     0, y:    0, w: 5120, h: 2160, split: "h38%", grid: "12%", snap: ["20%", "51%"], inputs: ["r", "t"] },
		;L: { x: 3040, y: 0, w: 800, h: 600, split: "h38%", grid: "10%", snap: ["20%", "90%"], inputs: ["a", "b"], ui: { x: 3100, y: 50, scale: 80 } },
		;R: { x: 2790, y: 600, w: 1050, h: 750, split: "v", grid: "7%", snap: ["25%", "75%"], inputs: ["c", "d"], ui: { input: true } },
		L: { x: -1920, y: 1750, w: 700, h: 1060, split: "v38%", grid: "10%", snap: ["20%", "90%"], inputs: ["a", "b"], ui: { x: -1900, y: 1750, scale: 90 } },
		R: { x: -1217, y: 1800, w: 1210, h: 750, split: "h", grid: "7%", snap: ["25%", "75%"], inputs: ["c", "d"], ui: { input: true } },
	},
	commands: [ ;
		{ command: "NOP", input: " `t" }, ;
		{ command: "comment", input: "[]" }, ;
		{ command: "resizeSplit", input: "-" }, ;
		{ command: "placeWindow", input: ".", name: "(current)" }, ;
		{ command: "placeWindow", input: "zzz", name: "zsh 3", run: "mintty.exe --class=mintty-3 --tabbar=4 -i /bin/zsh.exe,0 -e zsh", criteria: "ahk_exe i)\bmintty\. ahk_class i)^mintty-3", previewIcon: "c:\cygwin\bin\zsh.exe" }, ;
		{ command: "placeWindow", input: "zz", name: "zsh 2", run: "mintty.exe --class=mintty-2 --tabbar=4 -i /bin/zsh.exe,0 -e zsh", criteria: "ahk_exe i)\bmintty\. ahk_class i)^mintty-2", previewIcon: "c:\cygwin\bin\zsh.exe" }, ;
		{ command: "placeWindow", input: "z", name: "zsh 1", run: "mintty.exe --class=mintty-1 --tabbar=4 -i /bin/zsh.exe,0 -e zsh", criteria: "ahk_exe i)\bmintty\. ahk_class i)^mintty-1", previewIcon: "c:\cygwin\bin\zsh.exe" }, ;
		{ command: "placeWindow", input: "e", name: "Notepad", run: "notepad.exe", criteria: "ahk_exe i)\bnotepad.exe$" }, ;
		{ command: "placeWindow", input: "C", name: "CalculatorC", run: "calc.exe", criteria: "Calculator ahk_class i)^ApplicationFrameWindow$ ahk_exe i)\bApplicationFrameHost\." }, ;
		{ command: "placeWindow", input: "c", name: "Calculator", criteria: "Calculator ahk_class i)^ApplicationFrameWindow$ ahk_exe i)\bApplicationFrameHost\." }, ;
		{ command: "placeWindow", input: "T", name: "Task Manager", run: "taskmgr.exe", criteria: "Task Manager ahk_class i)^TaskManagerWindow$ ahk_exe i)\btaskmgr\." }, ;
		{ command: "placeWindow", input: "da", name: "Deezer", criteria: "ahk_exe i)\bdeezer\." }, ;
		{ command: "placeWindow", input: "db", name: "Vivaldi", run: "vivaldi.exe", criteria: "ahk_exe i)\bvivaldi\." }, ;
		{ command: "placeWindow", input: "xxx", name: "Test 3", run: "mintty.exe --class=Test3 -t 'Test 3' -i c:/windows/system32/shell32.dll,203 -e sleep infinity", criteria: "ahk_exe i)\bmintty\. ahk_class i)^Test3$" }, ;
		{ command: "placeWindow", input: "xx", name: "Test 2 ", run: "mintty.exe --class=Test2 -t 'Test 2' -i c:/windows/system32/shell32.dll,184 -e sleep infinity", criteria: "ahk_exe i)\bmintty\. ahk_class i)^Test2$", previewIcon: '[184]shell32.dll' }, ;
		{ command: "placeWindow", input: "x", name: "Test 1  ", run: "mintty.exe --class=Test1 -t 'Test 1' -i c:/windows/system32/shell32.dll,174 -e sleep infinity", criteria: "ahk_exe i)\bmintty\. ahk_class i)^Test1$", previewIcon: '[174]shell32.dll' }, ;
		{ command: "placeWindow", input: "E", name: "Test (error: command does not yield matching window)", run: "mintty.exe --class=TestE -t 'Test Error' -e sleep infinity", criteria: "ahk_exe i)\bmintty\. ahk_class i)^Test_Error$", previewIcon: '[175]shell32.dll' }, ;
	],
}))