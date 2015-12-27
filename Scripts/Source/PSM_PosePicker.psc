Scriptname PSM_PosePicker extends Quest

import Debug
import PSM_PosemanagerEntries
import MiscUtil

; Bool Property isActive
; 	Bool function get()
; 		return getState() != "Sleep"
; 	endfunction
; 	function set(Bool o)
; 		if o
; 			GoToState("")
; 		else
; 			GoToState("Sleep")
; 		endif
; 	endfunction
; endproperty

; Auto State Sleep
; 	Event OnBeginState()
; 		self.jKeyConf = 0
; 		self.jContext = 0
; 	EndEvent
; EndState

; Event OnBeginState()
; 	self.jKeyConf = KHConf_singleton()
; 	self.jContext = CTX_singleton()
; EndEvent

Event OnInit()
	; PrintConsole("iniiiiiiiiiiiiiiiiit")
	self.jContext = CTX_object()

	self.syncData()
EndEvent

;;;;;;;;;;;;;;;;; AutoSyncing

Event OnUpdate()
	self.syncData()
	_isSyncDelayed = False
EndEvent

function syncData()
	self.jKeyConf = KHConf_singleton(self.jKeyConf)
	CTX_syncActiveCollections(self.jContext)
	PrintConsole("Syncing data")
endfunction

bool _isSyncDelayed = False

function trySyncDataAfterDelay(float delay = 5.0)
	if _isSyncDelayed == False
		_isSyncDelayed = True
		self.RegisterForSingleUpdate(delay)
	endif
endfunction

;;;;;;;;;;;;;; Key Handling ;;;;

Int Property jKeyConf
	int function get()
		return _jKeyConf
	endfunction
	function set(int o)
		if o == _jKeyConf
			return
		endif
		_jKeyConf = JValue.releaseAndRetain(_jKeyConf, o)

		if o != 0
			self.listenKeys()
			self.RegisterForModEvent("KHConf_setKeyCodeForHandler", "OnKeyConfigKeyChange")
		else
			self.UnregisterForModEvent("KHConf_setKeyCodeForHandler")
			self.UnregisterForAllKeys()
		endif
	endfunction
endproperty
int _jKeyConf = 0

Event OnKeyConfigKeyChange(int jConfig, int oldKeyCode, int keyCode)
	self.UnregisterForKey(oldKeyCode)
	self.RegisterForKey(keyCode)
EndEvent

Event OnKeyDown(int keyCode)
	if !Input.IsKeyPressed(KHConf_getAltKeyCode(jKeyConf))
		return
	endif

	string handlerState = KHConf_getKeyHandler(jKeyConf, keyCode)
	PrintConsole("OnKeyDown: "+keyCode+":"+handlerState)
	if handlerState
		string prevState = self.GetState()
		self.GoToState(handlerState)
		self.handleKey(0)
		self.GoToState(prevState)

		self.trySyncDataAfterDelay()
	endif
EndEvent

Event OnKeyUp(int keyCode, float holdTime)
	if !Input.IsKeyPressed(KHConf_getAltKeyCode(jKeyConf))
		return
	endif

	string handlerState = KHConf_getKeyHandler(jKeyConf, keyCode)
	if handlerState
		string prevState = self.GetState()
		self.GoToState(handlerState)
		self.handleKeyUp(0, holdTime)
		self.GoToState(prevState)

		self.trySyncDataAfterDelay()
	endif
EndEvent

function listenKeys()
	PrintConsole("listenKeys begin")
	UnregisterForAllKeys()

	int handlers = KHConf_getKeyHandlers(jKeyConf)
	PrintConsole("PSM_PosemanagerEntries.keyCode2Handler: "+ handlers+" count "+JValue.count(handlers))

	int k = JIntMap.getNthKey(handlers, 0)
	while k
		RegisterForKey(k)
		PrintConsole("RegisterForKey: "+ k+":"+ JIntMap.getStr(handlers, k))
		k = JIntMap.nextKey(handlers, k)
	endwhile

	PrintConsole("listenKeys end")
endfunction 

function handleKey(int keyCode)
	Notification("Unhandled key " + keyCode)
endfunction
function handleKeyUp(int keyCode, float holdTime)
endfunction

;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Min. hold time to activate fast iteration
Float Property CHoldTime = 2.0 autoreadonly
; Skip N poses per second
Float Property CIterationRate = 20.0 autoreadonly

int function calculateAmountOfPosesToSkip(float buttonHoldTime)
	return ((buttonHoldTime - CHoldTime) * CIterationRate) as Int
endfunction

State KEY_NEXT_POSE
	function handleKey(int keyCode)
		self.currentPoseIdx += 1
	endfunction
	function handleKeyUp(int keyCode, float holdTime)
		if holdTime > HoldTime
			self.currentPoseIdx += self.calculateAmountOfPosesToSkip(buttonHoldTime = holdTime)
		endif
	endfunction
EndState
State KEY_PREV_POSE
	function handleKey(int keyCode)
		self.currentPoseIdx -= 1
	endfunction
	function handleKeyUp(int keyCode, float holdTime)
		if holdTime > CHoldTime
			self.currentPoseIdx -= self.calculateAmountOfPosesToSkip(buttonHoldTime = holdTime)
		endif
	endfunction
EndState
; Pick & View poses from collection
State KEY_VIEW_POSE_COLLECTION
	function handleKey(int keyCode)
		int jPoses = self.pickPoseList(headerText = "Pick a pose list to view it"\
			, suggestedListName = "Rename me"\
			, jCurrentSelectedCollection = self.jSourcePoseArray)

		if !jPoses
			return
		endif

		self.jSourcePoseArray = jPoses
	endfunction
EndState
; Activate pose list
State KEY_ACTIVATE_POSE_COLLECTION
	function handleKey(int keyCode)
		int jPoses = self.pickPoseList(headerText = "Pick a pose list to edit it"\
			, suggestedListName = "Rename me"\
			, jCurrentSelectedCollection = self.jActivePoses)

		if !jPoses
			return
		endif
		self.jActivePoses = jPoses
	endfunction
EndState
; Load poses from ESP
State KEY_LOAD_FROM_ESP 
	function handleKey(int keyCode)

		String[] modList = PSM_PosemanagerEntries.getModList()
		int selectedIdx = self.uilib.ShowList("Pick a plugin", asOptions = modList, aiStartIndex = -1, aiDefaultIndex = -1)
		if selectedIdx == -1
			return
		endif

		string modName = modList[selectedIdx]
		; int jPoses = self.pickPoseList(suggestedListName = (modName + " <- Rename Me"))
		; if !jPoses
		; 	Notification("No pose list selected")
		; 	return
		; endif

		int jPoses = PoseList_loadFromPlugin(modName)
		if !jPoses
			Notification("No poses in " + modName)
			return
		endif

		Notification("Press Alt-F to add a pose into current active pose collection")

		CTX_addPoseCollection(self.jContext, jPoses)
		self.jSourcePoseArray = jPoses

	endfunction
EndState

;;;;;;;;;;;;;;;;;;;;;

UILIB_1 Property uilib
	UILIB_1 function get()
		return (self as Form) as UILIB_1
	endfunction
endproperty

Int Property currentPoseIdx
	int function get()
		return PoseList_poseIndex(self.jSourcePoseArray)
	endfunction
	function set(int index)
		int idx = PoseList_setPoseIndex(self.jSourcePoseArray, index)

		string text = idx + "/" + PoseList_poseCount(self.jSourcePoseArray) + " of " + PoseList_getName(self.jSourcePoseArray)
		PrintConsole(text)

		Idle pose = PoseList_currentPose(self.jSourcePoseArray)
		Actor player = Game.GetPlayer()
		if pose && player && !player.IsOnMount()
			player.PlayIdle(pose)
		endif
	endfunction
endproperty

function notifyOfStatus()
	Notification("Viewing pose collection: " + PoseList_describe(self.jSourcePoseArray))
	Notification("Editing pose collection: " + PoseList_describe(self.jActivePoses))
endfunction

Int Property jActivePoses
	int function get()
		return CTX_getEditSlot(jContext)
	endfunction
	function set(int o)
		CTX_setEditSlot(jContext, o)
		self.notifyOfStatus()
	endfunction
endproperty

Int Property jActivePosesOrPickOne
	int function get()
		if !self.jActivePoses
			self.jActivePoses = self.pickPoseList(headerText = "Pick any pose list to edit it", suggestedListName = "A new list to edit")
		endif
		return self.jActivePoses
	endfunction
endproperty

Int Property jSourcePoseArray
	int function get()
		return CTX_getViewSlot(jContext)
	endfunction
	function set(int o)
		CTX_setViewSlot(jContext, o)
		self.notifyOfStatus()
	endfunction
endproperty

Int Property jContext
	int function get()
		return _jContext
	endfunction
	function set(int o)
		_jContext = JValue.releaseAndRetain(_jContext, o)
	endfunction
endproperty
int _jContext = 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

int function createPoseCollection(string title, string suggestedCollectionName = "Collection Name")

	string listName = self.uilib.ShowTextInput(title, suggestedCollectionName)

	if CTX_isCollectionWithNameExists(self.jContext, listName)
		Notification("No collection created")
		return 0
	endif
	
	int jPoses = PoseList_make(listName)
	CTX_addPoseCollection(self.jContext, jPoses)
	return jPoses
endfunction

int function pickPoseList(string headerText, string suggestedListName, int jCurrentSelectedCollection = 0)

	string[] poseListsNames = CTX_getCollectionNames(self.jContext)

	int iCurrPoseIdx = poseListsNames.Find(PoseList_getName(jCurrentSelectedCollection))

	int selectedIdx = uilib.ShowList(headerText, asOptions = poseListsNames, aiStartIndex = iCurrPoseIdx, aiDefaultIndex = -1)
	if selectedIdx == -1
		return 0
	endif

	int jPoses = CTX_getCollectionWithName(self.jContext, poseListsNames[selectedIdx])

	; if jPoses == CTX_dummyCollection(self.jContext)
	; 	jPoses = self.createPoseCollection(title = "Create new pose collection", suggestedCollectionName = "New Collection")
	; endif

	PrintConsole("pickPoseList: " + PoseList_describe(jPoses) + " picked")

	return jPoses
endfunction
; Dump data back
State KEY_SYNC_DATA
	function handleKey(int keyCode)
		self.trySyncDataAfterDelay()
		Notification("syncing done")
	endfunction
EndState
State KEY_PERFORM_ACTION
	function handleKey(int keyCode)

		string[] aactions = new string[4]
		aactions[0] = "Nothing"
		aactions[1] = "Create"
		aactions[2] = "Delete"
		aactions[3] = "Rename"

		int selectedIdx = self.uilib.ShowList(\
			"Perform action on " + PoseList_describe(self.jActivePoses)\
			, asOptions = aactions\
			, aiStartIndex = -1, aiDefaultIndex = 0)

		if selectedIdx == -1
			return
		endif

		string act = aactions[selectedIdx]
		if act == "Create"
			self.createPoseCollection(title = "Create New Pose Collection", suggestedCollectionName = "IDK")
		elseif act == "Delete"
			CTX_deleteCollection(self.jContext, self.jActivePoses)
		elseif act == "Nothing"
			;
		else
			Notification("Action "+act+" is not implemented yet")
		endif
	endfunction
EndState

State KEY_FAVORITE_POSE
	function handleKey(int keyCode)
		Idle pose = PoseList_currentPose(self.jSourcePoseArray)
		PoseList_addPose(self.jActivePosesOrPickOne, pose)
	endfunction
EndState
State KEY_UNFAVORITE_POSE
	function handleKey(int keyCode)
		Idle pose = PoseList_currentPose(self.jSourcePoseArray)
		PoseList_removePose(self.jActivePosesOrPickOne, pose)
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

