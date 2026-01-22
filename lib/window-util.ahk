#include %A_SCRIPTDIR%/lib/util.ahk

class WindowUtil {
	static moveWindowToPos(windowId, pos, errorHandler := false) {
		try {
			if (winGetMinMax(windowId) > 0) {
				winRestore(windowId)
			}
			return winMove(pos.x, pos.y, pos.w, pos.h, windowId)
		} catch Error as e {
			if (errorHandler) {
				errorHandler('ERROR moving window ' windowId ': ' e.message)
			} else {
				throw e
			}
		}
	}

	; Actual sendMessage and GetClassLong logic and magic numbers taken from
	; https://www.autohotkey.com/board/topic/116614-iswitchw-plus-groupedahk-alttab-replacement-window-switcher/
	static getWindowIcon(winId) {
		static getIcon_sm := Util.addPrintDebugN((winId, iconType) => sendMessage(0x7F, iconType, 0, , winId), 'getIcon_sm') ; 0x7F = WM_GETICON
		static getIcon_gcl := Util.addPrintDebugN((winId, arg) => dllCall("GetClassLong", "uint", winId, "int", arg), 'getIcon_gcl')
		return getIcon_sm(winId, 1) || getIcon_sm(winId, 2) || getIcon_sm(winId, 0) || getIcon_gcl(winId, -14) || getIcon_gcl(winId, -34)
	}
}