#ErrorStdOut UTF-8
#Warn All, StdOut
#include %A_SCRIPTDIR%/mostil.ahk

main() {
	Util.printDebug('{}', IntOrPercentage.parse('10%', 0, '10%'))
	Util.printDebug('{}', IntOrPercentage.parse('10%', 200, '10% (/200)'))
	Util.printDebug('{}', IntOrPercentage.parse(10, 200, '10/200)'))

	app := Mostil({
		debug: true,
		closeOnFocusLost: false,
		gui: {
			maxIconCount: 5,
			iconScale: "12%",
			maxIconSize: 128,
			iconOffsetX: 10,
			iconDist: '7%',
		},
		screens: {
			A: { x: 2840, y: 200, w: 1000, h: 1200, split: "v44%", grid: "10%", snap: ["20%", "90%"], inputs: ["a", "b"] }
		},
		commands: [ ;
			{ command: "comment", input: "[]" }, ;
			{ command: "resizeSplit", input: "-" }, ;
			{ command: "placeWindow", input: ".", name: "(current)" }, ;
		],
	})

	scr := app.screensManager.screens[1]
	errorHandler := msg => app.handleError_(msg)
	scr.show(app, errorHandler)
	tileWindows := [
		Tile.Window(0, Icon.fromFile('C:\Windows\System32\notepad.exe'), '1'),
		Tile.Window(0, Icon.fromFile('C:\Windows\regedit.exe'), '2'),
		Tile.Window(0, Icon.fromFile('C:\Windows\System32\shell32.dll', 42), '3'), ; tree
		Tile.Window(0, Icon.fromFile('C:\Windows\System32\shell32.dll', 41), '4'), ; DVD
		Tile.Window(0, Icon.fromFile('C:\Windows\System32\shell32.dll', 32), '5'), ; trash
		Tile.Window(0, Icon.fromFile('C:\Windows\System32\shell32.dll', 28), '6'), ; power off
	]
	for twi, tw in tileWindows {
		scr.tiles[1].addWindow(tw)
	}
	sleep(2000)
	undo := app.screensManager.moveWindowToTile(tileWindows[4], scr.tiles[2], errorHandler)
	sleep(2000)
	undo()

	scr.hide()
	scr.show(app, errorHandler)
}
main()