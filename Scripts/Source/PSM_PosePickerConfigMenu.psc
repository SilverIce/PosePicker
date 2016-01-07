Scriptname PSM_PosePickerConfigMenu extends SKI_ConfigBase

import Debug
import PSM_PosemanagerEntries

int jKeyOption2Handler = 0
int jConfig = 0

PSM_PosePicker Property autosaverAlias
	PSM_PosePicker function get()
		return (self as Quest) as PSM_PosePicker
	endfunction
endproperty

UILIB_1 Property uilib
	UILIB_1 function get()
		return (self as Form) as UILIB_1
	endfunction
endproperty

event OnConfigClose()
	JValue.cleanPool("PSM_PosePickerConfigMenu")
	jKeyOption2Handler = 0
	jConfig = 0
EndEvent

event OnConfigInit()
    Pages = new string[1]
    Pages[0] = ""
    ;Pages[0] = "Hotkeys"
endEvent

event OnPageReset(string page)
    self.SetCursorFillMode(LEFT_TO_RIGHT)
    self.SetCursorPosition(0) ; Can be removed because it starts at 0 anyway

    ;if page == ""
    	;AddToggleOptionST(string a_stateName, string a_text, bool a_checked, int a_flags = 0)
    	self.AddToggleOptionST("SKI_ToggleEnableMod", "Mod enabled", autosaverAlias.isActive)
    	self.AddEmptyOption()
   ; elseif page == "Hotkeys"
    	;self.AddHeaderOption("Hotkeys")
    	;self.AddHeaderOption("")

    	jConfig = JValue.addToPool(KHConf_singleton(), "PSM_PosePickerConfigMenu")

    	self.AddHeaderOption("Hotkeys")
    	self.AddHeaderOption("")

    	self.AddKeyMapOptionST("SKI_SetControlKey", "Control Key", KHConf_getAltKeyCode(jConfig))
		self.AddEmptyOption()

    	;self.AddEmptyOption()
    	;self.AddEmptyOption()

    	jKeyOption2Handler = JValue.addToPool(JIntMap.object(), "PSM_PosePickerConfigMenu")

    	int jHandlers = KHConf_getKeyHandlers(jConfig)

    	int keyCode = JIntMap.getNthKey(jHandlers, 0)
    	while keyCode
    		string handler = JIntMap.getStr(jHandlers, keyCode)
    		int option = self.AddKeyMapOption(handler, keyCode)

    		JIntMap.setStr(jKeyOption2Handler, option, handler)

    		keyCode = JIntMap.nextKey(jHandlers, keyCode)
    	endwhile
    ;endif

endEvent

Event OnOptionKeyMapChange(int a_option, int a_keyCode, string a_conflictControl, string a_conflictName)
	string handler = JIntMap.getStr(jKeyOption2Handler, a_option)

	if KHConf_setKeyCodeForHandler(jConfig, a_keyCode, handler)
		self.SetKeyMapOptionValue(a_option, a_keyCode)
	else
		self.ShowMessage("The key conflicts with other PosePicker's keys")
	endif
EndEvent

State SKI_ToggleEnableMod
	Event OnSelectST()
		;PrintConsole("SKI_ToggleEnableMod: OnSelectST")
		
		bool inversed = !autosaverAlias.isActive
		autosaverAlias.isActive = inversed
		self.SetToggleOptionValueST(inversed)
	EndEvent
	Event OnHighlightST()
		self.SetInfoText("Mod active: "+autosaverAlias.isActive+". It's best to deactivate the mod before uninstalling!")
	EndEvent
EndState

State SKI_SetControlKey
	Event OnKeyMapChangeST(int a_keyCode, string a_conflictControl, string a_conflictName)
		KHConf_setAltKeyCode(KHConf_singleton(), a_keyCode)
		self.SetKeyMapOptionValueST(a_keyCode)
	EndEvent
EndState


