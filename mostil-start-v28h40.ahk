; mostil for 28" vertical 8:9 and horizontal 40" 21:9 displays
#ErrorStdOut UTF-8
#Warn All, StdOut
#SingleInstance force
traySetIcon("shell32.dll", 251)
#include %A_SCRIPTDIR%/mostil.ahk

hotkey("!AppsKey", Mostil.start({
	debug: false,
	closeOnFocusLost: true,
	matchWindowPositionTolerance: 16,
	gui: {
		maxIconCount: 5,
		iconScale: "20%",
		maxIconSize: 256,
		iconOffsetX: "10%",
		iconDist: "8%",
	},
	screens: {
		L: { x: -2560, y: -400, w: 2560, h: 2880, split: "v30%", grid: "10%", snap: ["20%", "80%"], inputs: ["h", "n"], ui: { scale: "30%", x: 300, y: 350 } },
		R: { x: 0, y: 0, w: 5120, h: 2088, split: "h", grid: "6%", snap: ["25%", "75%"], inputs: ["r", "t"], ui: { scale: "30%", x: 1080, y: 450, input: true } },
	},
	commands: [ ;
		{ command: "NOP", input: " `t" }, ;
		{ command: "comment", input: "[]" }, ;
		{ command: "resizeSplit", input: "-" }, ;
		{ command: "placeWindow", input: ".", name: "(current)" }, ;
		{ command: "placeWindow", input: "zzz", name: "zsh 1", run: "mintty.exe --class=mintty-1 --tabbar=4 -i /bin/zsh.exe,0 -e zsh", criteria: "ahk_exe i)\bmintty\. ahk_class i)^mintty-1", previewIcon: "c:\cygwin\bin\zsh.exe" }, ;
		{ command: "placeWindow", input: "zz", name: "zsh 3", run: "mintty.exe --class=mintty-3 --tabbar=4 -i /bin/zsh.exe,0 -e zsh", criteria: "ahk_exe i)\bmintty\. ahk_class i)^mintty-3", previewIcon: "c:\cygwin\bin\zsh.exe" }, ;
		{ command: "placeWindow", input: "z", name: "zsh 2", run: "mintty.exe --class=mintty-2 --tabbar=4 -i /bin/zsh.exe,0 -e zsh", criteria: "ahk_exe i)\bmintty\. ahk_class i)^mintty-2", previewIcon: "c:\cygwin\bin\zsh.exe" }, ;
		{ command: "placeWindow", input: "e", name: "Emacs", run: "notepad.exe", criteria: "ahk_exe i)\bemacs-w32\." }, ;
		{ command: "placeWindow", input: "n", name: "Notepad++", run: "notepad++.exe", criteria: "ahk_exe i)\bnotepad\+\+\." }, ;
		{ command: "placeWindow", input: "v", name: "VS Code", run: "C:\cygwin\bin\run.exe " . envGet("LOCALAPPDATA") . "\Programs\VSCode\code.exe", criteria: "ahk_class Chrome_WidgetWin_1 ahk_exe i)\bcode\." }, ;
		{ command: "placeWindow", input: "b", name: "Vivaldi", run: "vivaldi.exe", criteria: "ahk_exe i)\bvivaldi\." }, ;
		{ command: "placeWindow", input: "m", name: "Outlook", run: "outlook.exe", criteria: "ahk_exe i)\bms-teams\." }, ;
		{ command: "placeWindow", input: "c", name: "MS Teams", run: "ms-teams.exe", criteria: "ahk_exe i)\bms-teams\." }, ;
	],
}))