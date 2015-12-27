Scriptname PSM_PosemanagerEntries

import JMap
import MiscUtil

function Pose_setName(Idle pose, string name) global
	JFormDB.setStr(pose, ".PosePicker.name", name)
endfunction
string function Pose_getName(Idle pose) global
	return JFormDB.getStr(pose, ".PosePicker.name")
endfunction


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
int function PoseList_loadFromFile(string collectionName) global
	int jPoses = JValue.readFromFile(__collectionNameToPath(collectionName))
	PrintConsole("PoseList_loadFromFile: loading " + collectionName + " at " + __collectionNameToPath(collectionName) + ": " + jPoses)
	if !jPoses
		PrintConsole("PoseList_loadFromFile: can't load " + collectionName + " at " + __collectionNameToPath(collectionName))
	endif
	PoseList_setName(jPoses, collectionName)
	return jPoses
endfunction
string function PoseList_filePath(int list) global
	return __collectionNameToPath(PoseList_getName(list))
endfunction
string function PoseList_getName(int list) global
	return getStr(list, "name")
endfunction
function PoseList_setName(int list, string name) global
	setStr(list, "name", name)
	JSONFile_onChanged(list)
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
	JSONFile_onChanged(list)
endfunction
function PoseList_addPose(int list, Idle pose) global
	if PoseList_findPose(list, pose) == -1
		JArray.addForm(PoseList_getList(list), pose)
		JSONFile_onChanged(list)
	endif
endfunction
function PoseList_removePose(int list, Idle pose) global
	int idx = PoseList_findPose(list, pose)
	if idx != -1
		JArray.eraseIndex(PoseList_getList(list), idx)
		if idx < PoseList_poseIndex(list)
			PoseList_setPoseIndex(list, PoseList_poseIndex(list) - 1)
		endif
		JSONFile_onChanged(list)
	endif
endfunction

int function PoseList_poseIndex(int list) global
	return getInt(list, "poseIdx")
endfunction
int function PoseList_setPoseIndex(int list, int index) global
	int count = PoseList_poseCount(list)
	int idx = (index + count) % count
	setInt(list, "poseIdx", idx)
	JSONFile_onChanged(list)
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

int function CTX_object() global
	return JValue.readFromFile("Data/Scripts/Source/PSM_PosePickerStruct.json")
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

int function CTX_dummyCollection(int jCTX) global
	return getObj(jCTX, "dummyCreateCollection")
endfunction

;;; IO

function CTX_syncActiveCollections(int jCTX) global
	int jView = CTX_getViewSlot(jCTX)
	if jView
		CTX_setViewSlot(jCTX, JSONFile_sync(jView, PoseList_filePath(jView)))
	endif

	int jEdit = CTX_getEditSlot(jCTX)
	if jEdit && jEdit != jView
		CTX_setEditSlot(jCTX, JSONFile_sync(jEdit, PoseList_filePath(jEdit)))
	endif
endfunction

int function CTX_getCollectionWithName(int jCTX, string name) global
	if name == PoseList_getName( CTX_getViewSlot(jCTX) )
		return CTX_getViewSlot(jCTX)
	elseif name == PoseList_getName( CTX_getEditSlot(jCTX) )
		return CTX_getEditSlot(jCTX)
	else
		return PoseList_loadFromFile(name)
	endif
endfunction

;;;;;;
string function __poseFileExt() global
	return ".json"
endfunction
string function __collectionsPath() global
	return "Data/PosePicker/PoseCollections/"
endfunction
string function __collectionNameToPath(string name) global
	if name != ""
		return __collectionsPath() + name + __poseFileExt()
	else
		return ""
	endif
endfunction

string[] function CTX_getCollectionNames(int jCTX) global
	; I'd return just a list of files in some directory
	string[] poseNames = FormReflection.listFilesInDirectory(__collectionsPath(), __poseFileExt())
	Int i = 0
	while i < poseNames.Length
		poseNames[i] = FormReflection.replaceExtension(FormReflection.fileNameFromPath(poseNames[i]), "")
		i += 1
	endwhile
	return poseNames
endfunction

function CTX_addPoseCollection(int jCTX, int jPoses) global
	JValue.writeToFile(jPoses, PoseList_filePath(jPoses))
endfunction

bool function CTX_isCollectionWithNameExists(int jCTX, string name) global
	return JContainers.fileExistsAtPath(__collectionNameToPath(name))
endfunction

function CTX_deleteCollection(int jCTX, int jPoses) global
	if CTX_getEditSlot(jCTX) == jPoses
		CTX_setEditSlot(jCTX, 0)
	endif
	if CTX_getViewSlot(jCTX) == jPoses
		CTX_setViewSlot(jCTX, 0)
	endif
	JContainers.removeFileAtPath(PoseList_filePath(jPoses))
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

; int function JSONFileCache(string keyPath, string file, bool forceRefresh = false) global
; 	int jfile = JDB.solveObj(keyPath)
; 	if !jfile || forceRefresh
; 		jfile = JValue.readFromFile(file)
; 		JDB.solveObjSetter(keyPath, jfile, createMissingKeys = True)
; 	endif
; 	return jfile
; endfunction

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
	int jTransport = object()
	setObj(jTransport, "jLocalObj", jLocalObj)
	setStr(jTransport, "filePath", filePath)
	int jSelectedObj = JValue.evalLuaObj(jTransport, "return PosePicker.syncJSONFile(jobject.jLocalObj, jobject.filePath)", jLocalObj)
	JValue.zeroLifetime(jTransport)
	return jSelectedObj
endfunction

int function JSONFile_syncLargeFile(int jLocalObj, string filePath) global
	int jTransport = object()
	setObj(jTransport, "jLocalObj", jLocalObj)
	setStr(jTransport, "filePath", filePath)
	int jSelectedObj = JValue.evalLuaObj(jTransport, "return PosePicker.syncLargeJSONFile(jobject.jLocalObj, jobject.filePath)", jLocalObj)
	JValue.zeroLifetime(jTransport)
	return jSelectedObj
endfunction

function JSONFile_onChanged(int jLocalObj) global
	setFlt(jLocalObj, "fileVersion", JValue.evalLuaFlt(0, "return os.time()"))
endfunction

float function JSONFile_modifyDate(int jLocalObj) global
	return getFlt(jLocalObj, "fileVersion")
endfunction