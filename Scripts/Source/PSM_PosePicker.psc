Scriptname PSM_PosePicker extends Quest

import Debug
import PSM_PosemanagerEntries
import MiscUtil

Event OnInit()
	init()
EndEvent

; Event OnPlayerLoadGame()
; 	init()
; EndEvent

function init()
	Notification("PSM_PosePicker init")

	listenKeys()

	PrintConsole("init finit")
endfunction

function listenKeys()
	PrintConsole("listenKeys begin")
	UnregisterForAllKeys()

	int handlers = PSM_PosemanagerEntries.keyCode2Handler()
	PrintConsole("PSM_PosemanagerEntries.keyCode2Handler: "+ handlers+" count "+JValue.count(handlers))

	int keyCodes = JIntMap.allKeys(handlers)
	;PrintConsole("JIntMap.nextKey(handlers): "+ keyCode)
	while JValue.count(keyCodes) > 0
		int keyCode = JArray.getInt(keyCodes, -1)
		JArray.eraseIndex(keyCodes, -1)
		RegisterForKey(keyCode)
		PrintConsole("RegisterForKey: "+ keyCode+":"+ JIntMap.getStr(handlers, keyCode))
		;keyCode = JIntMap.nextKey(handlers, keyCode)
	endwhile

	; _idles = FormReflection.queryFormsFrom("Halo's Poser.esp", withFormType = 78)
	; _currentIdx = 0
	; Notification(_idles.Length + " Halo's anims found")
	PrintConsole("listenKeys end")
endfunction

Event OnKeyDown(int keyCode)

	if !Input.IsKeyPressed(KEY_LEFT_ALT)
		return
	endif

	string handlerState = JIntMap.getStr(PSM_PosemanagerEntries.keyCode2Handler(), keyCode)

	PrintConsole("OnKeyDown: "+keyCode+":"+handlerState)

	if keyCode == KEY_F3
		handlerState = "KEY_F3"
	endif

	GoToState(handlerState)
	handleKey(keyCode)
	GoToState("")

EndEvent

function handleKey(int keyCode)
	Notification("Unhandled key " + keyCode)
endfunction

State KEY_RIGHT_ARROW
	function handleKey(int keyCode)
		;Idle anim = self.currentPose
		self.currentPoseIdx += 1
		;if anim
		;	Game.GetPlayer().PlayIdle(anim)
		;endif
	endfunction
EndState
State KEY_LEFT_ARROW
	function handleKey(int keyCode)
		;Idle anim = self.currentPose
		self.currentPoseIdx -= 1
		;if anim
		;	Game.GetPlayer().PlayIdle(anim)
		;endif
	endfunction
EndState
; Pick & View poses from collection
State KEY_P
	function handleKey(int keyCode)
		int jPoses = self.pickPoseList(headerText = "Pick a pose list to view it", suggestedListName = "Rename me")
		if !jPoses
			return
		endif

		self.viewPoseList(sourcePoseArray = PoseList_getList(jPoses))
	endfunction
EndState
; Activate pose list
State KEY_X
	function handleKey(int keyCode)
		int jPoses = self.pickPoseList(headerText = "Pick a pose list to edit it", suggestedListName = "Rename me")
		if !jPoses
			return
		endif
		self.jActivePoses = jPoses
	endfunction
EndState
; Load poses from ESP
State KEY_L 
	function handleKey(int keyCode)

		String[] modList = PSM_PosemanagerEntries.getModList()
		int selectedIdx = ((self as Form) as UILIB_1).ShowList("Pick a plugin", asOptions = modList, aiStartIndex = 0, aiDefaultIndex = 0)
		if selectedIdx == -1
			return
		endif

		string modName = modList[selectedIdx]
		; int jPoses = self.pickPoseList(suggestedListName = (modName + " <- Rename Me"))
		; if !jPoses
		; 	Notification("No pose list selected")
		; 	return
		; endif

		Form[] poses = FormReflection.queryFormsFrom(modName, withFormType = 78)
		if poses.Length == 0
			Notification("No poses in " + modName)
			return
		endif

		Notification("Press Alt-F to add pose into current active pose collection")

		int jsourcePoses = JArray_insertFormArray(JArray.object(), poses)

		self.viewPoseList(sourcePoseArray = jsourcePoses)
		; select active pose list

	endfunction
EndState

function viewPoseList(int sourcePoseArray)
	self.jSourcePoseArray = sourcePoseArray
	self.currentPoseIdx = 0
endfunction

;;;;;;;;;;;;;;;;;;;;;


Int Property currentPoseIdx
	int function get()
		return _currentPoseIdx % JValue.count(self.jSourcePoseArray)
	endfunction
	function set(int o)
		_currentPoseIdx = (o + JValue.count(self.jSourcePoseArray)) % JValue.count(self.jSourcePoseArray)

		Idle pose = JArray.getForm(self.jSourcePoseArray, _currentPoseIdx) as Idle
		if pose
			Game.GetPlayer().PlayIdle(pose)
		endif
	endfunction
endproperty
int _currentPoseIdx = 0

Idle Property currentPose
	Idle function get()
		return JArray.getForm(self.jSourcePoseArray, self.currentPoseIdx) as Idle
	endfunction
endproperty

Int Property jActivePoses
	int function get()
		return _jActivePoses
	endfunction
	function set(int o)
		_jActivePoses = JValue.releaseAndRetain(_jActivePoses, o)
		Notification("Current active pose collection: " + PoseList_describe(o))
	endfunction
endproperty
int _jActivePoses = 0

Int Property jActivePosesOrPickOne
	int function get()
		if !self.jActivePoses
			self.jActivePoses = self.pickPoseList(suggestedListName = "Active Pose Collection")
		endif
		return self.jActivePoses
	endfunction
endproperty

Int Property jSourcePoseArray
	int function get()
		return _jSourcePoseArray
	endfunction
	function set(int o)
		_jSourcePoseArray = JValue.releaseAndRetain(_jSourcePoseArray, o)
	endfunction
endproperty
int _jSourcePoseArray = 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

int function createPoseCollection(string title, string suggestedCollectionName)
	string listName = ((self as Form) as UILIB_1).ShowTextInput(title, suggestedCollectionName)
	
	int jPoses = PoseList_make(listName)
	PSM_PosemanagerEntries.addPoseCollection(jPoses)
	return jPoses
endfunction

int function pickPoseList(string headerText = "Pick a pose list", string suggestedListName)

	; if JValue.count(PSM_PosemanagerEntries.getPoseLists()) == 0
	; 	return createPoseCollection(title = "At least one pose list must be created", suggestedCollectionName = suggestedListName)
	; endif

	string[] poseListsNames = PSM_PosemanagerEntries.getPoseListsNames()
	int iCurrPoseIdx = poseListsNames.Find(PoseList_getName(self.jActivePoses))

	if iCurrPoseIdx == -1
		iCurrPoseIdx = 0
	endif

	int selectedIdx = ((self as Form) as UILIB_1).ShowList(headerText, asOptions = poseListsNames, aiStartIndex = iCurrPoseIdx, aiDefaultIndex = iCurrPoseIdx)
	if selectedIdx == -1
		return 0
	endif

	int jPoses = PSM_PosemanagerEntries.getNthPoseList(selectedIdx)
	if jPoses == PSM_PosemanagerEntries.dummyPoseCollection()
		jPoses = self.createPoseCollection("Crete Pose Collection", "Rename me")
	endif

	return jPoses
endfunction
; Dump data back
State KEY_F2
	function handleKey(int keyCode)
		PSM_PosemanagerEntries.dumpRoot()
		Notification("dumped collections into the file")
	endfunction
EndState
State KEY_F3
	function handleKey(int keyCode)
		PSM_PosemanagerEntries.root(forceLoadFromFile = True)
		self.listenKeys();
		Notification("loaded collections from the file")
	endfunction
EndState
State KEY_A
	function handleKey(int keyCode)

		string[] aactions = new string[3]
		aactions[0] = "Create"
		aactions[1] = "Delete"
		aactions[2] = "Rename"

		int selectedIdx = ((self as Form) as UILIB_1).ShowList("Perform action on active pose", asOptions = aactions, aiStartIndex = 0, aiDefaultIndex = 0)
		if selectedIdx == -1
			return
		endif

		string act = aactions[selectedIdx]
		if act == "Create"
			self.createPoseCollection(title = "Create Pose Collection", suggestedCollectionName = "IDK")
		elseif act == "Delete"
			PSM_PosemanagerEntries.deletePoseCollection(self.jActivePoses)
		else
			Notification("Action "+act+" is not implemented yet")
		endif
	endfunction
EndState

State KEY_G
	function handleKey(int keyCode)
		Idle pose = self.currentPose
		if pose
			PoseList_addPose(self.jActivePosesOrPickOne, pose)
		endif
	endfunction
EndState
State KEY_U
	function handleKey(int keyCode)
		Idle pose = self.currentPose
		if pose
			PoseList_removePose(self.jActivePosesOrPickOne, pose)
		endif
	endfunction
EndState

; I had an idea of pose manager with pursuies me for so long.
; Yesterday I have found a way to pick all idles (poses) from ESPs.
; Basically this is just a draft for some blog and the mod itself is in the similar 'draft stage'.
; Need to think about functionality first, not hurry up with implementation.

; Basically, what functionality I have in mind right now:

; - pick ESP/ESM and apply its poses by pressing left or right arrow keys (Alt key must be hold). 
; - Mark a pose as favourive with Alt-F
; - In case no favourite pose list created yet, it asks you to create one, will make it _active_, fav. poses will go into that list
; - Create as much pose lists as you can
; - Fav. poses will go into _active_ pose list
; - Pick any pose list and apply poses
; - Assign name to a pose
; - -The target to -

; Tiny tech details:
; - I dont want to go for MCM each time I need to change something, so there must be as much hotkeys as possible
; - Alt can be changed to any other key, as well as other keys
; - Ofc, the data must be shareable between play throughs, users etc

; The problemshhh
; - You will never know whether the pose is stand or anything as the pose information is spread like a shit across bunch of forms in the ESP. Idle's editor name is useless "FNISIDleDuplicate00XXX" in most cases (I use "Halo's poser.esp")
; - The data is shareable, but I don't believe in community-generated list of poses. Most of you will start with zero pose lists
; - I'd like to use some UI element to display current pose name. Debug.Notification is way too slow
; - There will be plenty of dummy T-poses in "Halo's poser.esp", don't give up and continue press '->' key

; Any idea is welcomed, but don't expect I'll implement everything you will suggest


int property KEY_ESCAPE = 0x01 autoreadonly
int property KEY_1 = 0x02 autoreadonly
int property KEY_2 = 0x03 autoreadonly
int property KEY_3 = 0x04 autoreadonly
int property KEY_4 = 0x05 autoreadonly
int property KEY_5 = 0x06 autoreadonly
int property KEY_6 = 0x07 autoreadonly
int property KEY_7 = 0x08 autoreadonly
int property KEY_8 = 0x09 autoreadonly
int property KEY_9 = 0x0A autoreadonly
int property KEY_0 = 0x0B autoreadonly
int property KEY_MINUS = 0x0C autoreadonly
int property KEY_EQUALS = 0x0D autoreadonly
int property KEY_BACKSPACE = 0x0E autoreadonly
int property KEY_TAB = 0x0F autoreadonly
int property KEY_Q = 0x10 autoreadonly
int property KEY_W = 0x11 autoreadonly
int property KEY_E = 0x12 autoreadonly
int property KEY_R = 0x13 autoreadonly
int property KEY_T = 0x14 autoreadonly
int property KEY_Y = 0x15 autoreadonly
int property KEY_U = 0x16 autoreadonly
int property KEY_I = 0x17 autoreadonly
int property KEY_O = 0x18 autoreadonly
int property KEY_P = 0x19 autoreadonly
int property KEY_LEFT_BRACKET = 0x1A autoreadonly
int property KEY_RIGHT_BRACKET = 0x1B autoreadonly
int property KEY_ENTER = 0x1C autoreadonly
int property KEY_LEFT_CONTROL = 0x1D autoreadonly
int property KEY_A = 0x1E autoreadonly
int property KEY_S = 0x1F autoreadonly
int property KEY_D = 0x20 autoreadonly
int property KEY_F = 0x21 autoreadonly
int property KEY_G = 0x22 autoreadonly
int property KEY_H = 0x23 autoreadonly
int property KEY_J = 0x24 autoreadonly
int property KEY_K = 0x25 autoreadonly
int property KEY_L = 0x26 autoreadonly
int property KEY_SEMICOLON = 0x27 autoreadonly
int property KEY_APOSTROPHE = 0x28 autoreadonly
int property KEY_TILDE = 0x29 autoreadonly
int property KEY_LEFT_SHIFT = 0x2A autoreadonly
int property KEY_BACK_SLASH = 0x2B autoreadonly
int property KEY_Z = 0x2C autoreadonly
int property KEY_X = 0x2D autoreadonly
int property KEY_C = 0x2E autoreadonly
int property KEY_V = 0x2F autoreadonly
int property KEY_B = 0x30 autoreadonly
int property KEY_N = 0x31 autoreadonly
int property KEY_M = 0x32 autoreadonly
int property KEY_COMMA = 0x33 autoreadonly
int property KEY_PERIOD = 0x34 autoreadonly
int property KEY_FORWARD_SLASH = 0x35 autoreadonly
int property KEY_RIGHT_SHIFT = 0x36 autoreadonly
int property KEY_NUM_MULTIPLY = 0x37 autoreadonly
int property KEY_LEFT_ALT = 0x38 autoreadonly
int property KEY_SPACEBAR = 0x39 autoreadonly
int property KEY_CAPS_LOCK = 0x3A autoreadonly
int property KEY_F1 = 0x3B autoreadonly
int property KEY_F2 = 0x3C autoreadonly
int property KEY_F3 = 0x3D autoreadonly
int property KEY_F4 = 0x3E autoreadonly
int property KEY_F5 = 0x3F autoreadonly
int property KEY_F6 = 0x40 autoreadonly
int property KEY_F7 = 0x41 autoreadonly
int property KEY_F8 = 0x42 autoreadonly
int property KEY_F9 = 0x43 autoreadonly
int property KEY_F10 = 0x44 autoreadonly
int property KEY_NUM_LOCK = 0x45 autoreadonly
int property KEY_SCROLL_LOCK = 0x46 autoreadonly
int property KEY_NUM7 = 0x47 autoreadonly
int property KEY_NUM8 = 0x48 autoreadonly
int property KEY_NUM9 = 0x49 autoreadonly
int property KEY_NUM_MINUS = 0x4A autoreadonly
int property KEY_NUM4 = 0x4B autoreadonly
int property KEY_NUM5 = 0x4C autoreadonly
int property KEY_NUM6 = 0x4D autoreadonly
int property KEY_NUM_PLUS = 0x4E autoreadonly
int property KEY_NUM1 = 0x4F autoreadonly
int property KEY_NUM2 = 0x50 autoreadonly
int property KEY_NUM3 = 0x51 autoreadonly
int property KEY_NUM0 = 0x52 autoreadonly
int property KEY_NUM_DOT = 0x53 autoreadonly
int property KEY_F11 = 0x57 autoreadonly
int property KEY_F12 = 0x58 autoreadonly
int property KEY_NUM_ENTER = 0x9C autoreadonly
int property KEY_RIGHT_CONTROL = 0x9D autoreadonly
int property KEY_NUM_DIVIDE = 0xB5 autoreadonly
int property KEY_RIGHT_ALT = 0xB8 autoreadonly
int property KEY_HOME = 0xC7 autoreadonly
int property KEY_UP_ARROW = 0xC8 autoreadonly
int property KEY_PG_UP = 0xC9 autoreadonly
int property KEY_LEFT_ARROW = 0xCB autoreadonly
int property KEY_RIGHT_ARROW = 0xCD autoreadonly
int property KEY_END = 0xCF autoreadonly
int property KEY_DOWN_ARROW = 0xD0 autoreadonly
int property KEY_PG_DOWN = 0xD1 autoreadonly
int property KEY_INSERT = 0xD2 autoreadonly
int property KEY_DELETE = 0xD3 autoreadonly
int property KEY_LEFT_MOUSE_BUTTON = 0x100 autoreadonly
int property KEY_RIGHT_MOUSE_BUTTON = 0x101 autoreadonly
int property KEY_MIDDLE_MOUSE_BUTTON = 0x102 autoreadonly
int property KEY_MOUSE_BUTTON3 = 0x103 autoreadonly
int property KEY_MOUSE_BUTTON4 = 0x104 autoreadonly
int property KEY_MOUSE_BUTTON5 = 0x105 autoreadonly
int property KEY_MOUSE_BUTTON6 = 0x106 autoreadonly
int property KEY_MOUSE_BUTTON7 = 0x107 autoreadonly
int property KEY_MOUSE_WHEEL_UP = 0x108 autoreadonly
int property KEY_MOUSE_WHEEL_DOWN = 0x109 autoreadonly
