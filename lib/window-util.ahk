#include %A_SCRIPTDIR%/lib/util.ahk

moveWindowToPos(windowId, pos) {
	try {
		return winMove(pos.x, pos.y, pos.w, pos.h, windowId)
	} catch Error as e {
		; TODO This should not need to know such GUI internals
		if (gl.screensManager.screenWithInput.gui) {
			gl.screensManager.screenWithInput.gui.statusBar.setText('ERROR moving window: ' e.message)
		} else {
			throw e
		}
	}
}

winSetMinMax(windowId, value) {
	try {
		switch (value) {
			case -1: winMinimize(windowId)
			case +1: winMaximize(windowId)
			default: winRestore(windowId)
		}
	} catch Error as e {
		; TODO This should not need to know such GUI internals
		gl.screensManager.screenWithInput.gui.statusBar.setText('ERROR setting window min/max/restored state: ' e.message
		)
	}
}

getNormalWindowIds() {
	printDebugF('my window ids: {}', () => arrayMap(gl.screensManager.screens, s => s.gui.gui.hwnd))
	results := []
	for wid_ in winGetList() {
		wid := wid_ ; workaround for Autohotkey bug? Loop variable does not exist in the printDebugF closure, but this copy does.
		title := winGetTitle(wid)
		include := title !== '' ; TODO: better criterium to exclude non-window results like Shell_TrayWnd?
		printDebugF('winGetList(): id: {}, processName: {}, class: {}, title: {}, include: {}', () =>
			[wid, winGetProcessName(wid), winGetClass(wid), title, include])
		if (include) {
			results.push(wid)
		}
	}
	return results
}

; Actual sendMessage and GetClassLong logic and magic numbers taken from
; https://www.autohotkey.com/board/topic/116614-iswitchw-plus-groupedahk-alttab-replacement-window-switcher/
getWindowIcon(winId) {
	static getIcon_sm := addPrintDebugN((winId, iconType) => sendMessage(0x7F, iconType, 0, , winId), 'getIcon_sm') ; 0x7F = WM_GETICON
	static getIcon_gcl := addPrintDebugN((winId, arg) => dllCall("GetClassLong", "uint", winId, "int", arg), 'getIcon_gcl')
	return getIcon_sm(winId, 1) || getIcon_sm(winId, 2) || getIcon_sm(winId, 0) || getIcon_gcl(winId, -14) || getIcon_gcl(winId, -34)
}
