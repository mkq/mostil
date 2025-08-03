#ErrorStdOut UTF-8
#Warn All, StdOut
#SingleInstance force
traySetIcon("shell32.dll", 251)
#include %A_SCRIPTDIR%/mostil.ahk

hotkey("!f5", Mostil.start({
	debug: true,
	closeOnFocusLost: false,
	; hotkey to open the dialog:
	; screens (or any screen area to manage): A map from screen name to config object. Config attributes:
	; - x, y, w, h: coordinates (top left corner, width, height)
	; - split: Each one is an area of two tiles, either "v" (top / bottom) or "h" (left / right).
	;   Optionally, a suffix defines the default split ratio in pixels or percent; e.g. "v480" or "v33%"
	;   means the upper tile's default height is 480 pixels or 33% of the screen high, resp.
	; - grid: step size in pixels or percent when moving the split
	; - snap: array of [min, max] split value, each in pixels or percent: When moving the split to anything less than
	;   min, it snaps to 0% (i.e. the bottom or right window takes the full screen).
	;   Simalar for greater than max.
	; - inputs: array of two input strings to select the [1] upper / left and [2] lower / right tile of the screen.
	;   This applies to moving a window to a tile and moving the split. These must consist of printable keys
	;   suitable for inside a combobox.
	; - ui: nested object:
	;   - x, y: preview GUI position (top-left corner); default: like the screen
	;   - scale: preview GUI scale relative to the screen; default: "100%"
	;   - input: boolean whether this is the preview UI with input controls; at most one screen may have input: true;
	screens: {
		;Q: { x: -2560, y: -200, w: 2560, h: 2880, split: "v60%", grid: "10%", snap: ["30%", "70%"], inputs: ["h", "n"] },
		;W: { x:     0, y:    0, w: 5120, h: 2160, split: "h38%", grid: "12%", snap: ["20%", "51%"], inputs: ["r", "t"] },
		L: { x: 0, y: 0, w: 800, h: 600, split: "h38%", grid: "10%", snap: ["20%", "90%"], inputs: ["a", "b"] },
		R: { x: 0, y: 600, w: 1050, h: 750, split: "v", grid: "7%", snap: ["25%", "75%"], inputs: ["c", "d"], ui: { input: true } },
		;F: { x:     0, y:    0, w: 3838, h: 2080, split: "v0",   inputs: ["↑", "f"], ui: { x: 2900, y: 1500, scale: 20 } },
	},
	; A command is selected by typing its input character sequence, immediately followed by as many
	; parameters as it accepts.
	; Command types:
	; - "placeWindow" moves a window to a tile and focuses it, optionally launching a program if no matching window
	;   exists.
	;   Without parameter, the window is just focused.
	;   Otherwise requires one parameter: the target tile (i.e. an element of a screen's input attribute).
	;   Config attributes:
	;   * criteria: how to find the window; without criteria, the most recently active window is used
	;   * run: command to launch if no such window exists
	; - "resizeSplit" moves the border between two tiles of a screen.
	;   Requires at least one parameter which is either
	;   * the target screen and direction (together given as an element of a screen's inputs attribute; e.g.
	;     the input to place a window in the left tile of a horizontal screen is used for moving that screen's
	;     split left) or
	;   * the last character of the input bound to "resizeSplit" to reset all splits to their default values.
	;   Further parameters: All subsequent valid inputs are treated as resizeSplit parameters, even if they
	;   could also be the beginning of a new command.
	; - "comment": do nothing. They are used to embed comments in a command sequence to have a readable drop-down
	;   history. Its input actually configures two inputs: The character to start and the character to end a comment.
	;   They may be equal (in which case no nested comments are possible). Two equal characters may also be written as
	;   a single char string, e.g. `input: "/"` is equivalent to `input: "//"`.
	;   Parameters: anything printable is allowed between start and end of comment
	commands: [ ;
		{ command: "comment", input: "[]" }, ;
		{ command: "resizeSplit", input: "-" }, ;
		{ command: "placeWindow", input: ".", name: "(current)" }, ;
		{ command: "placeWindow", input: "zzz", name: "zsh 3", run: "mintty.exe --class=mintty-3 --tabbar=4 -i /bin/zsh.exe,0 -e zsh", criteria: "ahk_exe i)\bmintty\. ahk_class i)^mintty-3", previewIcon: "c:\cygwin\bin\zsh.exe" }, ;
		{ command: "placeWindow", input: "zz", name: "zsh 2", run: "mintty.exe --class=mintty-2 --tabbar=4 -i /bin/zsh.exe,0 -e zsh", criteria: "ahk_exe i)\bmintty\. ahk_class i)^mintty-2", previewIcon: "c:\cygwin\bin\zsh.exe" }, ;
		{ command: "placeWindow", input: "z", name: "zsh 1", run: "mintty.exe --class=mintty-1 --tabbar=4 -i /bin/zsh.exe,0 -e zsh", criteria: "ahk_exe i)\bmintty\. ahk_class i)^mintty-1", previewIcon: "c:\cygwin\bin\zsh.exe" }, ;
		{ command: "placeWindow", input: "e", name: "Notepad", run: "notepad.exe", criteria: "ahk_exe i)\bnotepad.exe$" }, ;
		{ command: "placeWindow", input: "c", name: "Calculator", run: "calc.exe", criteria: "Calculator ahk_class i)^ApplicationFrameWindow$ ahk_exe i)\bApplicationFrameHost\." }, ;
		{ command: "placeWindow", input: "T", name: "Task Manager", run: "taskmgr.exe", criteria: "Task Manager ahk_class i)^TaskManagerWindow$ ahk_exe i)\btaskmgr\." }, ;
		{ command: "placeWindow", input: "da", name: "Deezer", criteria: "ahk_exe i)\bdeezer\." }, ;
		{ command: "placeWindow", input: "db", name: "Vivaldi", run: "vivaldi.exe", criteria: "ahk_exe i)\bvivaldi\." }, ;
		{ command: "placeWindow", input: "xxx", name: "Test 3", run: "mintty.exe --class=Test3 -t 'Test 3' -e sleep infinity", criteria: "ahk_exe i)\bmintty\. ahk_class i)^Test3$" }, ;
		{ command: "placeWindow", input: "xx", name: "Test 2", run: "mintty.exe --class=Test2 -t 'Test 2' -e sleep infinity", criteria: "ahk_exe i)\bmintty\. ahk_class i)^Test2$", previewIcon: '[184]shell32.dll' }, ;
		{ command: "placeWindow", input: "x", name: "Test 1", run: "mintty.exe --class=Test1 -t 'Test 1' -e sleep infinity", criteria: "ahk_exe i)\bmintty\. ahk_class i)^Test1$", previewIcon: '[174]shell32.dll' }, ;
		{ command: "placeWindow", input: "E", name: "Test (error: command does not yield matching window)", run: "mintty.exe --class=TestE -t 'Test Error' -e sleep infinity", criteria: "ahk_exe i)\bmintty\. ahk_class i)^Test_Error$", previewIcon: '[174]shell32.dll' }, ;
	],
}))