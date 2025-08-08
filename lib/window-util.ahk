#include %A_SCRIPTDIR%/lib/util.ahk

class WindowUtil {
	static moveWindowToPos(windowId, pos, errorHandler := false) {
		try {
			return winMove(pos.x, pos.y, pos.w, pos.h, windowId)
		} catch Error as e {
			if (errorHandler) {
				errorHandler('ERROR moving window ' windowId ': ' e.message)
			} else {
				throw e
			}
		}
	}

	static winSetMinMax(windowId, value, errorHandler := false) {
		try {
			switch (value) {
				case -1: winMinimize(windowId)
				case +1: winMaximize(windowId)
				default: winRestore(windowId)
			}
		} catch Error as e {
			if (errorHandler) {
				errorHandler('ERROR moving window' windowId ': ' e.message)
			} else {
				throw e
			}
		}
	}

	static getNormalWindowIds() {
		results := []
		for wid_ in winGetList() {
			wid := wid_ ; workaround for Autohotkey bug? Loop variable does not exist in the printDebugF closure, but this copy does.
			title := winGetTitle(wid)
			include := title !== '' ; TODO: better criterium to exclude non-window results like Shell_TrayWnd?
			Util.printDebugF('winGetList(): id: {}, processName: {}, class: {}, title: {}, include: {}', () =>
				[wid, winGetProcessName(wid), winGetClass(wid), title, include])
			if (include) {
				results.push(wid)
			}
		}
		return results
	}

	; The most recently active window which does not belong to this app.
	static getActiveOtherWindow(screensMgr) {
		myWindowIds := Util.arrayMap(screensMgr.screens, s => s.gui.gui.hwnd)
		Util.printDebugF('my window ids: {}', () => [Util.dump(myWindowIds)])
		windowId := 0
		for wid in WindowUtil.getNormalWindowIds() {
			if (Util.arrayIndexOf(myWindowIds, wid) == 0) {
				windowId := wid
				break
			}
		}
		Util.printDebug('MRU window: {}', windowId)
		return windowId
	}

	; Actual sendMessage and GetClassLong logic and magic numbers taken from
	; https://www.autohotkey.com/board/topic/116614-iswitchw-plus-groupedahk-alttab-replacement-window-switcher/
	static getWindowIcon(winId) {
		static getIcon_sm := Util.addPrintDebugN((winId, iconType) => sendMessage(0x7F, iconType, 0, , winId), 'getIcon_sm') ; 0x7F = WM_GETICON
		static getIcon_gcl := Util.addPrintDebugN((winId, arg) => dllCall("GetClassLong", "uint", winId, "int", arg), 'getIcon_gcl')
		return getIcon_sm(winId, 1) || getIcon_sm(winId, 2) || getIcon_sm(winId, 0) || getIcon_gcl(winId, -14) || getIcon_gcl(winId, -34)
	}
}