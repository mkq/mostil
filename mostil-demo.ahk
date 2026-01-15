#ErrorStdOut UTF-8
#Warn All, StdOut
#SingleInstance force
traySetIcon("shell32.dll", 251)
#include %A_SCRIPTDIR%/mostil.ahk

hotkey("!f5", Mostil.start({
	debug: false,
	closeOnFocusLost: false,
	; When a window has been moved into a tile, but its position (any border) changes externally by more than this many
	; pixels, the tile disowns it.
	matchWindowPositionTolerance: 16,
	gui: {
		maxIconCount: 5,
		iconScale: "20%",
		maxIconSize: 256,
		iconOffsetX: "10%",
		iconDist: "8%",
	},
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
		L: { x: -1920, y: 20, w: 1920, h: 1080, split: "v38%", grid: "10%", snap: ["20%", "90%"], inputs: ["a", "b"], ui: { x: -1900, y: 20, scale: 90 } },
		R: { x: 0, y: 0, w: 2560, h: 1366, split: "h", grid: "7%", snap: ["25%", "75%"], inputs: ["c", "d"], ui: { input: true } },
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
	;   Limitation: Because comments obey the general command parsing rules, they cannot occur inside another command.
	;   For example, if comment is bound to "[]" and "ab" is a valid command, "a[comment]b" is different (invalid or
	;   two commands "a" and "b", depending on other config).
	;   Parameters: anything printable is allowed between start and end of comment.
	commands: [ ;
		{ command: "NOP", input: " `t" }, ;
		{ command: "comment", input: "[]" }, ;
		{ command: "resizeSplit", input: "-" }, ;
		{ command: "placeWindow", input: ".", name: "(current)" }, ;
		{ command: "placeWindow", input: "zz", name: "zsh 2", run: "mintty.exe --class=mintty-2 --tabbar=4 -i /bin/zsh.exe,0 -e zsh", criteria: "ahk_exe i)\bmintty\. ahk_class i)^mintty-2", previewIcon: "c:\cygwin\bin\zsh.exe" }, ;
		{ command: "placeWindow", input: "z", name: "zsh 1", run: "mintty.exe --class=mintty-1 --tabbar=4 -i /bin/zsh.exe,0 -e zsh", criteria: "ahk_exe i)\bmintty\. ahk_class i)^mintty-1", previewIcon: "c:\cygwin\bin\zsh.exe" }, ;
		{ command: "placeWindow", input: "e", name: "Notepad", run: "notepad.exe", criteria: "ahk_exe i)\bnotepad.exe$" }, ;
		{ command: "placeWindow", input: "c", name: "CalculatorC", run: "calc.exe", criteria: "Calculator ahk_class i)^ApplicationFrameWindow$ ahk_exe i)\bApplicationFrameHost\." }, ;
		{ command: "placeWindow", input: "T", name: "Task Manager", run: "taskmgr.exe", criteria: "Task Manager ahk_class i)^TaskManagerWindow$ ahk_exe i)\btaskmgr\." }, ;
	],
}))