#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon

; Windows opens Start when the Windows key is pressed and released on its own, which happens
; constantly when Super is muscle memory from a Linux desktop. Sending an unassigned virtual key
; (vkE8) while Win is held makes Windows treat the press as a combination, so Start stays shut,
; while real shortcuts such as Win+L still reach Windows because the `~` passes Win through.
~LWin::Send "{Blind}{vkE8}"
~RWin::Send "{Blind}{vkE8}"
