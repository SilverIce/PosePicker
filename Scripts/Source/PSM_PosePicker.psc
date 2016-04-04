Scriptname PSM_PosePicker extends Quest

import Debug
import PSM_PosemanagerEntries
import JContainers_DomainExample

Bool Property isActive
	Bool function get()
		return _isActive
	endfunction
	function set(Bool o)
		_isActive = o
		if o
			self.jKeyConf = KHConf_singleton()
			self.jContext = CTX_object()
			self.syncData()
			self.GoToState("")
		else
			self.syncData()
			self.jKeyConf = 0
			self.jContext = 0
			self.UnregisterForUpdate()
			self.GoToState("Sleep")
		endif
	endfunction
endproperty
Bool _isActive = False

Auto State Sleep
	function OnPlayerLoadGame()
	endfunction
	Event OnUpdate()
	EndEvent
EndState

function OnPlayerLoadGame()
	if !(JContainers.APIVersion() == 3 && JContainers.featureVersion() >= 2)
		Debug.MessageBox("PosePicker won't approve any JContainers version below 3.2")
	endif
	self.trySyncDataAfterDelay(0.5)
endfunction

;;;;;;;;;;;;;;;;; AutoSyncing

Event OnUpdate()
	self.syncData()
EndEvent

function syncData()
	;Debug.TraceStack("syncData stack")
	self.jKeyConf = KHConf_singleton()
	CTX_syncCollections(self.jContext)
	_isSyncDelayed = False
	PrintConsole("Synced data")
endfunction

bool _isSyncDelayed = False

function trySyncDataAfterDelay(float delay = 5.0)
	if _isSyncDelayed == False
		_isSyncDelayed = True
		CTX_rememberActiveCollections(self.jContext)
		self.RegisterForSingleUpdate(delay)
	else
		;PrintConsole("sync was already scheduled")
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

		_jKeyConf = JValue_releaseAndRetain(_jKeyConf, o, "PSM_PosePicker")

		if o != 0
			self.listenKeys()
			self.RegisterForModEvent(KHConf_EVENT_NAME(), "OnKeyConfigKeyChange")
		else
			self.UnregisterForModEvent(KHConf_EVENT_NAME())
			self.UnregisterForAllKeys()
		endif
	endfunction
endproperty
int _jKeyConf = 0

Event OnKeyConfigKeyChange(int jConfig, int oldKeyCode, int keyCode)
	PrintConsole("OnKeyConfigKeyChange: oldKeyCode "+oldKeyCode+" keyCode "+keyCode)
	self.UnregisterForKey(oldKeyCode)
	self.RegisterForKey(keyCode)
EndEvent

Event OnKeyDown(int keyCode)
	if !Input.IsKeyPressed(KHConf_getAltKeyCode(jKeyConf))
		return
	endif

	string handlerState = KHConf_getKeyHandler(jKeyConf, keyCode)
	;PrintConsole("OnKeyDown: "+keyCode+":"+handlerState)
	if handlerState
		string prevState = self.GetState()
		self.GoToState(handlerState)
		self.handleKey(keyCode)
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
	PrintConsole("PSM_PosemanagerEntries.keyCode2Handler: "+ handlers+" count "+JValue_count(handlers))

	int k = JIntMap_getNthKey(handlers, 0)
	while k
		RegisterForKey(k)
		PrintConsole("RegisterForKey: "+ k+":"+ JIntMap_getStr(handlers, k))
		k = JIntMap_nextKey(handlers, k)
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
;int KEY_LOAD_FROM_ESP_handleKey_lastIndex = -1
State KEY_LOAD_FROM_ESP 
	function handleKey(int keyCode)

		string partOfName = self.uilib.ShowTextInput(asTitle = "Filter plugins by name", asInitialText = "")

		int jModList = JValue_retain(PSM_PosemanagerEntries.getModList(), tag = "PSM_PosePicker")
		int i = 0
		while i < JArray_count(jModList)
			String modName = JArray_getStr(jModList, i)
			if StringUtil.Find(modName, partOfName) == -1
				JArray_eraseIndex(jModList, i)
			else
				i += 1
			EndIf
		endwhile

		int selectedIdx = self.uilib.ShowList(\
			"Pick a plugin"\
			, asOptions = JArray_toStringArray(jModList)\
			, aiStartIndex = -1\
			, aiDefaultIndex = -1)

		string modName = JArray_getStr(jModList, selectedIdx)
		jModList = JValue_release(jModList)

		if selectedIdx == -1
			return
		endif

		int jPoses = PoseList_loadFromPlugin(modName)
		if !jPoses
			Notification("No poses in " + modName)
			return
		endif

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

Actor _lastSelectedActor

Actor function pickPoseTargetActor()
	Actor consoleRef = Game.GetCurrentConsoleRef() as Actor
	if consoleRef != None
		_lastSelectedActor = consoleRef
		return consoleRef
	elseif _lastSelectedActor != None
		return _lastSelectedActor
	else
		_lastSelectedActor = Game.GetPlayer()
		return _lastSelectedActor
	endif
endfunction

Int Property currentPoseIdx
	int function get()
		return PoseList_poseIndex(self.jSourcePoseArray)
	endfunction
	function set(int index)
		int idx = PoseList_setPoseIndex(self.jSourcePoseArray, index)

		string text = idx + "/" + PoseList_poseCount(self.jSourcePoseArray) + " of " + PoseList_getName(self.jSourcePoseArray)
		PrintConsole(text)

		Idle pose = PoseList_currentPose(self.jSourcePoseArray)
		Actor player = pickPoseTargetActor()
		if pose && player && !player.IsOnMount()
			player.PlayIdle(pose)
		endif
	endfunction
endproperty

function notifyOfStatus()
	; Notification("Viewing pose collection: " + PoseList_describe(self.jSourcePoseArray))
	; Notification("Editing pose collection: " + PoseList_describe(self.jActivePoses))
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
		_jContext = JValue_releaseAndRetain(_jContext, o, "PSM_PosePicker")
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

	int jPoseListnames = JValue_retain(JArray_objectWithStrings(CTX_getCollectionNames(self.jContext)), tag = "PSM_PosePicker")
	JArray_addStr(jPoseListnames, "Create new collection", 0)

	;; Reorder names, so jCurrentSelectedCollection always at 1-st index
	int iCurrnameCollIdx = JArray_findStr(jPoseListnames, PoseList_getName(jCurrentSelectedCollection), 0)
	if iCurrnameCollIdx != -1
		JArray_swapItems(jPoseListnames, 1, iCurrnameCollIdx)
	endif
	;;

	int selectedIdx = uilib.ShowList(headerText\
		, asOptions = JArray_toStringArray(jPoseListnames)\
		, aiStartIndex = JArray_findStr(jPoseListnames, PoseList_getName(jCurrentSelectedCollection), 0)\
		, aiDefaultIndex = -1)

	string selectedPoseListname = JArray_getStr(jPoseListnames, selectedIdx)
	jPoseListnames = JValue_release(jPoseListnames)

	if selectedIdx == -1
		return 0
	endif

	int jPoses = 0

	if selectedIdx == 0
		jPoses = self.createPoseCollection(title = "Create new pose collection", suggestedCollectionName = "")
	else
		jPoses = CTX_getCollectionWithName(self.jContext, selectedPoseListname)
	endif

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
State KEY_DUMP
	function handleKey(int keyCode)
		JValue_writeToFile(self.jContext, __collectionsPath() + "__dump.json")
	endfunction
EndState
State KEY_PERFORM_ACTION
	function handleKey(int keyCode)

		int jActionTarget = self.jActivePoses
		if !jActionTarget
			return
		endif

		string[] aactions = new string[6]
		aactions[0] = "Nothing"
		aactions[1] = "Create"
		aactions[2] = "Delete"
		aactions[3] = "Rename"
		aactions[4] = "Copy"
		aactions[5] = "Sort by ID"

		int selectedIdx = self.uilib.ShowList(\
			"Perform action on " + PoseList_describe(jActionTarget)\
			, asOptions = aactions\
			, aiStartIndex = -1, aiDefaultIndex = 0)

		if selectedIdx == -1
			return
		endif

		string act = aactions[selectedIdx]
		if act == "Create"
			self.createPoseCollection(title = "Create New Pose Collection", suggestedCollectionName = "")
		elseif act == "Delete"
			CTX_deleteCollection(self.jContext, jActionTarget)
		elseif act == "Nothing"
			;
		elseif act == "Rename"
			string newName = self.uilib.ShowTextInput(asTitle = "Rename collection", asInitialText = PoseList_getName(jActionTarget))
			if !CTX_renameCollection(self.jContext, jActionTarget, newName)
				Notification("Can't rename the collection")
			endif
		elseif act == "Copy"
			string newName = CTX_chooseNewCollectionName(\
					self.jContext\
					, self.uilib.ShowTextInput(\
						asTitle = "Name new collection"\
						, asInitialText = (PoseList_getName(jActionTarget) + " copy"))\
				)

			if newName == ""
				Notification("Can't choose this name")
				return
			endif

			int jCopy = JValue_deepCopy(jActionTarget)
			PoseList_setName(jCopy, newName)
			CTX_addPoseCollection(self.jContext, jCopy)
		elseif act == "Sort by ID"
			Idle pose = PoseList_currentPose(jActionTarget)
			JArray_sort(PoseList_getList(jActionTarget))
			PoseList_setPoseIndex(jActionTarget, PoseList_findPose(jActionTarget, pose))
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
State KEY_VISIT_NEARBY
	function handleKey(int keyCode)
		Idle pose = PoseList_currentPose(self.jSourcePoseArray)
		if pose
			Int modId = Math.RightShift(pose.GetFormID(), 32 - 8)
			;PrintConsole("KEY_VISIT_NEARBY modId " + modId)
			String modName = Game.GetModName(modId)
			;PrintConsole("KEY_VISIT_NEARBY modName " + modName)
			Int jnewPoses = PoseList_loadFromPlugin(pluginName = modName)
			if jnewPoses
				PoseList_setName(jnewPoses, "VISIT_NEARBY")
				PoseList_setPoseIndex(jnewPoses, PoseList_findPose(jnewPoses, pose))
				;PrintConsole("KEY_VISIT_NEARBY jnewPoses " + jnewPoses)
				self.jActivePoses = self.jSourcePoseArray
				self.jSourcePoseArray = jnewPoses
			else
				Notification("No poses in " + modName)
			endif
		endif
	endfunction
EndState
State key_swap_view_edit
	function handleKey(int keyCode)
		CTX_swapSlots(self.jContext)
	endfunction
EndState

function KEY_ROTATE_ACTOR_rotate(Actor target, float byDelta, int whileKeyPressed)
	;PrintConsole("KEY_ROTATE_ACTOR_rotate begin, target="+target)
	;Actor akTarget = self.pickPoseTargetActor()
	Float zAngle = target.GetAngleZ()
	ConsoleUtil.SetSelectedReference(target)

	while Input.IsKeyPressed(whileKeyPressed)
		zAngle += byDelta
		ConsoleUtil.ExecuteCommand("setangle z " + zAngle)
		;PrintConsole("setangle z " + zAngle)
		Utility.Wait(0.05)
	endwhile
	;PrintConsole("KEY_ROTATE_ACTOR_rotate end")
EndFunction

State key_rotate_actor_right
	function handleKey(int keyCode)

		;int kSlotMask30 = 0x00000001 ; HEAD
		;int msnIndex = 1
		; 9 - string - ShaderTexture (index 0-8)
		;int ikey = 9
		;int slotMask = 0x00000008
; Function AddSkinOverrideString(ObjectReference ref, bool isFemale, bool firstPerson, int slotMask, int key, int index, string value, bool persist) native global
		;NiOverride.AddSkinOverrideString(Game.GetPlayer(), true, false, kSlotMask30, ikey, msnIndex, "textures\\customraces\\test.dds", false)

		self.KEY_ROTATE_ACTOR_rotate(target = self.pickPoseTargetActor(), byDelta = 7.0, whileKeyPressed = keyCode)
	endfunction
EndState
State key_rotate_actor_left
	function handleKey(int keyCode)
		self.KEY_ROTATE_ACTOR_rotate(target = self.pickPoseTargetActor(), byDelta = -7.0, whileKeyPressed = keyCode)
	endfunction
EndState
State KEY_TFC
	function handleKey(int keyCode)

		; UIExtensions.GetMenu("UIListMenu", reset = true)

		;Debug.ToggleMenus()
		ConsoleUtil.ExecuteCommand("tfc")
; Valid keys
; ID - TYPE - Name
; 0 - int - ShaderEmissiveColor
; 1 - float - ShaderEmissiveMultiple
; 2 - float - ShaderGlossiness
; 3 - float - ShaderSpecularStrength
; 4 - float - ShaderLightingEffect1
; 5 - float - ShaderLightingEffect2
; 6 - TextureSet - ShaderTextureSet
; 7 - int - ShaderTintColor
; 8 - float - ShaderAlpha
; 9 - string - ShaderTexture (index 0-8)
; 20 - float - ControllerStartStop (-1.0 for stop, anything else indicates start time)
; 21 - float - ControllerStartTime
; 22 - float - ControllerStopTime
; 23 - float - ControllerFrequency
; 24 - float - ControllerPhase

		; TextureSet ts = Game.GetFormFromFile(aiFormID = 0x3b521, asFilename = "Skyrim.esm") as TextureSet

		; Notification("ts " + ts)

		; bool pisFemale = true
		; string pnode = "FemaleHead.nif"
		; int pkey = 6
		; int pindex = -1
		; TextureSet pvalue = ts
		; bool ppersist = True

		; NiOverride.AddNodeOverrideTextureSet(ref = Game.GetPlayer()\
		; 	, isFemale = pisFemale\
		; 	, node = pnode\
		; 	, key = pkey\
		; 	, index = pindex\
		; 	, value = pvalue\
		; 	, persist = ppersist\
		; )

		; NiOverride.ApplyNodeOverrides(Game.GetPlayer())

		; TextureSet out = NiOverride.GetNodeOverrideTextureSet(ref = Game.GetPlayer()\
		; 	, isFemale = pisFemale\
		; 	, node = pnode\
		; 	, key = pkey\
		; 	, index = pindex\
		; )

		; Notification("out " + out)
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

