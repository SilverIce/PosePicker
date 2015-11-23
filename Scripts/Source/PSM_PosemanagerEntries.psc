Scriptname PSM_PosemanagerEntries

import JMap
import MiscUtil

function Pose_setName(Idle pose, string name) global
	JFormDB.setStr(pose, ".PosePicker.name", name)
endfunction
string function Pose_getName(Idle pose) global
	return JFormDB.getStr(pose, ".PosePicker.name")
endfunction


;;;;;;;;;;;;
int function PoseListLightWeight_make(int jPoseList) global
	if !jPoseList
		return 0
	endif

	string filePath = PoseListLightWeight_getFilePath(jPoseList)
	JValue.writeToFile(jPoseList, filePath)

	int list = object()
	setStr(list, "name", PoseList_getName(jPoseList))
	setInt(list, "poseIdx", PoseList_poseIndex(jPoseList))
	return list
endfunction

int function PoseListLightWeight_getPoseList(int jPoseList) global
	if !jPoseList
		return 0
	endif

	int list = JValue.readFromFile(PoseListLightWeight_getFilePath(jPoseList))
	PoseList_setPoseIndex(list, PoseList_poseIndex(list))
	return list
endfunction

string function PoseListLightWeight_getFilePath(int jPoseList) global
	return "Data/PosePicker/PoseCollections/" + PoseList_getName(jPoseList) + ".json"
endfunction

;;;;;;;;;;;;;;;; PoseList

int function PoseList_make(string name) global
	int list = object()
	setStr(list, "name", name)
	setInt(list, "poseIdx", 0)
	setObj(list, "poses", JArray.object())
	return list
endfunction
int function PoseList_loadFromPlugin(string pluginName) global
	Form[] poses = FormReflection.queryFormsFrom(pluginName, withFormType = 78)
	if poses.Length == 0
		return 0
	endif

	int jPoses = PoseList_make(name = (pluginName + "-based list"))
	JArray_insertFormArray(PoseList_getList(jPoses), poses)
	return jPoses
endfunction
string function PoseList_getName(int list) global
	return getStr(list, "name")
endfunction
string function PoseList_describe(int list) global
	if list
		return PoseList_getName(list)+", "+PoseList_poseCount(list)+" poses"
	else
		return "'pose collection doesn't exist'"
	endif
endfunction
int function PoseList_getList(int list) global
	return getObj(list, "poses")
endfunction
int function PoseList_poseCount(int list) global
	return JValue.count(PoseList_getList(list))
endfunction
int function PoseList_findPose(int list, Idle pose) global
	return JArray.findForm(PoseList_getList(list), pose)
endfunction
function PoseList_setPoses(int list, Form[] poses) global
	setObj(list, "poses", JArray_insertFormArray(JArray.object(), poses))
endfunction
function PoseList_addPose(int list, Idle pose) global
	if PoseList_findPose(list, pose) == -1
		JArray.addForm(PoseList_getList(list), pose)
	endif
endfunction
function PoseList_removePose(int list, Idle pose) global
	int idx = PoseList_findPose(list, pose)
	if idx != -1
		JArray.eraseIndex(PoseList_getList(list), idx)
		if idx < PoseList_poseIndex(list)
			PoseList_setPoseIndex(list, PoseList_poseIndex(list) - 1)
		endif
	endif
endfunction

int function PoseList_poseIndex(int list) global
	return getInt(list, "poseIdx")
endfunction
int function PoseList_setPoseIndex(int list, int index) global
	int count = PoseList_poseCount(list)
	int idx = (index + count) % count
	setInt(list, "poseIdx", idx)
	return idx
endfunction
Idle function PoseList_currentPose(int list) global
	return JArray.getForm(PoseList_getList(list), PoseList_poseIndex(list)) as Idle
endfunction

;;;;;;;;;;;;; Key Handler

int function KHConf_getAltKeyCode(int jConfig) global
	return getInt(jConfig, "altKey")
endfunction

function KHConf_setAltKeyCode(int jConfig, int keyCode) global
	setInt(jConfig, "altKey", keyCode)
endfunction

int function KHConf_getKeyHandlers(int jConfig) global
	return getObj(jConfig, "handlers")
endfunction

string function KHConf_getKeyHandler(int jConfig, int keyCode) global
	return JValue.solveStr(jConfig, ".handlers[" + keyCode + "]")
endfunction

function KHConf_setKeyCodeForHandler(int jConfig, int keyCode, string handler) global
	int keys2handlers = getObj(jConfig, "handlers")
	int handlers = JIntMap.allValues(keys2handlers)
	int pairIdx = JArray.findStr(handlers, handler)

	;JValue.evalLuaInt(jConfig, "return jc.find(jobject.handlers, function(v) v ==  end)")

	if pairIdx != -1
		int oldKeyCode = JIntMap.getNthKey(keys2handlers, pairIdx);
		JIntMap.removeKey(keys2handlers, oldKeyCode)
		JIntMap.setStr(keys2handlers, keyCode, handler)

		int evt = ModEvent.Create("PSM_KHConf_setKeyCodeForHandler")
		ModEvent.PushInt(evt, jConfig)
		ModEvent.PushInt(evt, oldKeyCode)
		ModEvent.PushInt(evt, keyCode)
		ModEvent.Send(evt)
	endif
	JValue.zeroLifetime(handlers)
endfunction

int function KHConf_singleton(int jLocalObj) global
	return JSONFile_sync(jLocalObj, "Data/Scripts/Source/PSM_KeyHandlerConfig.json")
endfunction

;;;;;;;;;;;;;;;;;;; View & Edit context

int function CTX_singleton(int jLocalObj) global
	return JSONFile_syncLargeFile(jLocalObj, "Data/Scripts/Source/PSM_PosePickerStruct.json")
endfunction

function CTX_setViewSlot(int jCTX, int jPoses) global
	setObj(jCTX, "viewSlot", jPoses)
endfunction
int function CTX_getViewSlot(int jCTX) global
	return getObj(jCTX, "viewSlot")
endfunction
function CTX_setEditSlot(int jCTX, int jPoses) global
	setObj(jCTX, "editSlot", jPoses)
endfunction
int function CTX_getEditSlot(int jCTX) global
	return getObj(jCTX, "editSlot")
endfunction

int function CTX_getPoseCollections(int jCTX) global
	return getObj(jCTX, "poseCollections")
endfunction

int function CTX_dummyCollection(int jCTX) global
	return getObj(jCTX, "dummyCreateCollection")
endfunction

;;;;;;;;;;;;;;;;;; List of pose collections


string[] function Collections_getCollectionNames(int jCollections) global
	string lua = "return PosePicker.foldl(jobject, JArray.object(), function(pose, init) JArray.insert(init, pose.name); return init end)"
	string[] poseNames = JArray_toStringArray(JValue.evalLuaObj(jCollections, lua))
	return poseNames
endfunction

int function Collections_getNthPoseList(int jCollections, int idx) global
	int jPoses = JArray.getObj(jCollections, idx)
	return jPoses
endfunction

function Collections_addPoseCollection(int jCollections, int jPoses) global
	if jPoses && JArray.findObj(jCollections, jPoses) == -1
		JArray.addObj(jCollections, jPoses)
	endif
endfunction

function Collections_deleteCollection(int jCollections, int jPoses) global
	int idx = JArray.findObj(jCollections, jPoses)
	if idx != -1
		JArray.eraseIndex(jCollections, idx)
	endif
endfunction

;;;; Utils ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

string[] function getModList() global
	string[] mods = Utility.CreateStringArray(Game.GetModCount(), fill = "")
	int i = 0
	while i < Game.GetModCount()
		mods[i] = Game.GetModName(i)
		i += 1
	endwhile
	return mods
endfunction

string[] function JArray_toStringArray(int obj) global
	string[] mods = Utility.CreateStringArray(JArray.count(obj), fill = "")
	int i = 0
	while i < JArray.count(obj)
		mods[i] = JArray.getStr(obj, i)
		i += 1
	endwhile
	return mods
endfunction

int function JSONFileCache(string keyPath, string file, bool forceRefresh = false) global
	int jfile = JDB.solveObj(keyPath)
	if !jfile || forceRefresh
		jfile = JValue.readFromFile(file)
		JDB.solveObjSetter(keyPath, jfile, createMissingKeys = True)
	endif
	return jfile
endfunction

int function JArray_insertFormArray(int obj, Form[] forms, int insertAt = -1) global
	int i = 0
	while i < forms.Length
		JArray.addForm(obj, forms[i], addToIndex = insertAt)
		i += 1
	endwhile
	return obj
endfunction

;;;;;;;;;;;;;;;;;;;;;; JSONFile

; int function JSONFile_make(string filePath)
; 	return JValue.objectFromPrototype("{ \"filePath\": \""+ filePath +"\" }")
; endfunction

; int function JSONFile_root(int ijFile, int sessionUID)
; 	if getInt(ijFile, "tick") != sessionUID
; 		setInt(ijFile, "tick", sessionUID)
; 		setObj(ijFile, "root", JValue.readFromFile(getStr(ijFile, "filePath")))
; 	endif
; 	return getObj(ijFile, "root")
; endfunction


int function JSONFile_sync(int jLocalObj, string filePath) global

	int jConfigTemplate = JValue.readFromFile(filePath)

	if getFlt(jLocalObj, "fileVersion", -1.0) < getFlt(jConfigTemplate, "fileVersion")
		PrintConsole("Syncing " + filePath + ". Remove file chosen: " + jConfigTemplate)
		return jConfigTemplate
	elseif getFlt(jLocalObj, "fileVersion") > getFlt(jConfigTemplate, "fileVersion")
		JValue.writeToFile(jLocalObj, filePath)
	endif

	PrintConsole("Syncing " + filePath + ". Local file chosen: " + jLocalObj)
	JValue.zeroLifetime(jConfigTemplate)
	return jLocalObj

endfunction

int function JSONFile_syncLargeFile(int jLocalObj, string filePath) global

	string lightweightFilePath = filePath + ".filedate"
	int jFileDate = JValue.readFromFile(lightweightFilePath)
	int jSelectedObj = jLocalObj

	float localDate = JSONFile_modifyDate(jLocalObj)
	float fileDate = JSONFile_modifyDate(jFileDate)

	if localDate < fileDate
		
		int jRemoteFile = JValue.readFromFile(filePath)

		if JSONFile_modifyDate(jRemoteFile) > localDate
			PrintConsole("Syncing " + filePath + ". Remote file chosen: " + jRemoteFile)
			jSelectedObj = jRemoteFile
		endif

	elseif localDate > fileDate
		if !jFileDate
			jFileDate = object()
		endif
		setFlt(jFileDate, "fileVersion", localDate)
		JValue.writeToFile(jFileDate, lightweightFilePath)
		JValue.writeToFile(jLocalObj, filePath)
	endif

	JValue.zeroLifetime(jFileDate)

	PrintConsole("Syncing " + filePath + ". Local file chosen: " + jLocalObj)

	return jSelectedObj

endfunction

function JSONFile_onChanged(int jLocalObj) global
	setFlt(jLocalObj, "fileVersion", JValue.evalLuaFlt(0, "return os.time()"))
endfunction

float function JSONFile_modifyDate(int jLocalObj) global
	return getFlt(jLocalObj, "fileVersion")
endfunction