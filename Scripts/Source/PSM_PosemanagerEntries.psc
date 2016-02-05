Scriptname PSM_PosemanagerEntries

import JMap
import Debug

function Pose_setName(Idle pose, string name) global
	JFormDB.setStr(pose, ".PosePicker.name", name)
endfunction
string function Pose_getName(Idle pose) global
	return JFormDB.getStr(pose, ".PosePicker.name")
endfunction


int function PoseList_make(string name) global
	int list = object()
	PoseList_setName(list, name)
	setInt(list, "poseIdx", 0)
	setObj(list, "poses", JArray.object())
	return list
endfunction
int function PoseList_loadFromPlugin(string pluginName) global
	Form[] poses = PSM_FormReflection.queryFormsFrom(pluginName, withFormType = 78, maxFailedLookups = 7000)
	if poses.Length == 0
		PrintConsole("PoseList_loadFromPlugin: no poses in " + pluginName)
		return 0
	endif

	int jPoses = PoseList_make("xx")
	PoseList_setExactName(jPoses, pluginName + "-based list")
	JArray_insertFormArray(PoseList_getList(jPoses), poses)
	return jPoses
endfunction
int function PoseList_loadFromFile(string collectionName) global
	int jPoses = JValue.readFromFile(__collectionNameToPath(collectionName))
	PrintConsole("PoseList_loadFromFile: loading " + collectionName + " at " + __collectionNameToPath(collectionName) + ": " + jPoses)

	if !jPoses
		PrintConsole("PoseList_loadFromFile: can't load " + collectionName + " at " + __collectionNameToPath(collectionName))
		return 0
	endif

	if !PoseList_isValid(jPoses)
		PrintConsole("PoseList_loadFromFile: pose forms in the collection can't be loaded. Loading failed")
		JValue.zeroLifetime(jPoses)
		return 0
	endif
	
	PoseList_setExactName(jPoses, collectionName)
	return jPoses
endfunction
bool function PoseList_isValid(int list) global
	return PoseList_findPose(list, None) == -1
endfunction
string function PoseList_filePath(int list) global
	return __collectionNameToPath(PoseList_getName(list))
endfunction
string function PoseList_getName(int list) global
	return getStr(list, "name")
endfunction
function PoseList_setExactName(int list, string name) global
	setStr(list, "name", name)
	JSONFile_onChanged(list)
endfunction
function PoseList_setName(int list, string name) global
	PoseList_setExactName(list, JString_normalizeString(name))
endfunction
string function PoseList_describe(int list) global
	if list
		return PoseList_getName(list)+", "+PoseList_poseCount(list)+" poses"
	else
		return "<No collection>"
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
	if pose && PoseList_findPose(list, pose) == -1
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
	;TraceConditional("invalid identifier", list == 0)
	int count = PoseList_poseCount(list)
	if count > 0
		int idx = (index + count) % count
		setInt(list, "poseIdx", idx)
		JSONFile_onChanged(list)
		return idx
	else
		return 0
	endif
endfunction
Idle function PoseList_currentPose(int list) global
	return JArray.getForm(PoseList_getList(list), PoseList_poseIndex(list)) as Idle
endfunction

;;;;;;;;;;;;;

; function tryInstallMod() global
; 	string userDir = JContainers.userDirectory()
; 	if JContainers.fileExistsAtPath(userDir + ".installed")
; 		return



;;;;;;;;;;;;; Key Handler

int function KHConf_getAltKeyCode(int jConfig) global
	return getInt(jConfig, "altKey")
endfunction

function KHConf_setAltKeyCode(int jConfig, int keyCode) global
	setInt(jConfig, "altKey", keyCode)
	JSONFile_onChanged(jConfig)
endfunction

int function KHConf_getKeyHandlers(int jConfig) global
	return getObj(jConfig, "handlers")
endfunction

string function KHConf_getKeyHandler(int jConfig, int keyCode) global
	return JValue.solveStr(jConfig, ".handlers[" + keyCode + "]")
endfunction

string function KHConf_EVENT_NAME() global
	return "PSM_KHConf_setKeyCodeForHandler"
endfunction
string function KHConf_FILE_PATH() global
	return "Data/PosePicker/KeyHandlerConfig.json"
endfunction

bool function KHConf_setKeyCodeForHandler(int jConfig, int keyCode, string handler) global

	int keys2handlers = getObj(jConfig, "handlers")
	; to prevent overwrite 
	if JIntMap.hasKey(keys2handlers, keyCode)
		return False
	endif

	int handlers = JIntMap.allValues(keys2handlers)
	int pairIdx = JArray.findStr(handlers, handler)

	if pairIdx != -1
		int oldKeyCode = JIntMap.getNthKey(keys2handlers, pairIdx)
		JIntMap.removeKey(keys2handlers, oldKeyCode)
		JIntMap.setStr(keys2handlers, keyCode, handler)
		JSONFile_onChanged(jConfig)

		int evt = ModEvent.Create(KHConf_EVENT_NAME())
		ModEvent.PushInt(evt, jConfig)
		ModEvent.PushInt(evt, oldKeyCode)
		ModEvent.PushInt(evt, keyCode)
		ModEvent.Send(evt)
	endif
	JValue.zeroLifetime(handlers)
	return True
endfunction

int function KHConf_singleton() global
	string path = ".PosePicker.KHConf"
	string fpath = KHConf_FILE_PATH()
	int jLocalObj = JDB.solveObj(path)
	int jRemote = JValue.readFromFile(fpath)

	if JSONFile_formatVersion(jLocalObj) != JSONFile_formatVersion(jRemote)
		JDB.solveObjSetter(path, jRemote, True)
		return jRemote
	elseif JSONFile_modifyDate(jLocalObj) > JSONFile_modifyDate(jRemote)
		JValue.writeToFile(jLocalObj, fpath)
	endif

	JValue.zeroLifetime(jRemote)
	;PrintConsole("KHConf_singleton: " + jLocalObj)
	return jLocalObj
endfunction

;;;;;;;;;;;;;;;;;;; View & Edit context

int function CTX_object() global
	return JValue.readFromFile("Data/PosePicker/PoserContext.json")
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

; int function CTX_dummyCollection(int jCTX) global
; 	return getObj(jCTX, "dummyCreateCollection")
; endfunction

;;; IO

int function CTX_getObjectsToSync(int jCTX) global
	return getObj(jCTX, "objectsToSync")
endfunction

function CTX_rememberActiveCollections(int jCTX) global
	int jObjectsToSync = CTX_getObjectsToSync(jCTX)

	int jView = CTX_getViewSlot(jCTX)
	if jView
		JIntMap.setObj(jObjectsToSync, jView, jView)
	endif
	int jEdit = CTX_getEditSlot(jCTX)
	if jEdit && jEdit != jView
		JIntMap.setObj(jObjectsToSync, jEdit, jEdit)
	endif
endfunction

function CTX_syncCollections(int jCTX) global
	int jObjectsToSync = CTX_getObjectsToSync(jCTX)
	int k = JIntMap.getNthKey(jObjectsToSync, 0)
	while k
		int o = JIntMap.getObj(jObjectsToSync, k)
		k = JIntMap.nextKey(jObjectsToSync, k)
		;PrintConsole("syncing " + PoseList_describe(o))
		JSONFile_syncInplace(o, PoseList_filePath(o))
	endwhile
	JIntMap.clear(jObjectsToSync)
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

;;;;;; IO end

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
	string[] poseNames = PSM_FormReflection.listFilesInDirectory(__collectionsPath(), __poseFileExt())
	Int i = 0
	while i < poseNames.Length
		poseNames[i] = PSM_FormReflection.replaceExtension(PSM_FormReflection.fileNameFromPath(poseNames[i]), "")
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
	PrintConsole("deleting collection at " + PoseList_filePath(jPoses))
	JContainers.removeFileAtPath(PoseList_filePath(jPoses))
endfunction

bool function CTX_renameCollection(int jCTX, int jPoses, string newName) global
	string normalizedName = JString_normalizeString(newName)

	if 0 == jPoses || newName == "" || True == CTX_isCollectionWithNameExists(jCTX, normalizedName)
		return False
	endif

	;PrintConsole("deleting collection at " + PoseList_filePath(jPoses))
	JContainers.removeFileAtPath(PoseList_filePath(jPoses))
	PoseList_setName(jPoses, normalizedName)
	JValue.writeToFile(jPoses, PoseList_filePath(jPoses))
	return True
endfunction

;;;; Utils ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

function PrintConsole(string text) global
	PSM_FormReflection.logConsole("[PosePicker] " + text)
endfunction

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

string function JString_normalizeString(string value) global
	int jargs = object()
	setStr(jargs, "str", value)
	string normalized = JValue.evalLuaStr(jargs, "return string.gsub(jobject.str, '%W', ' ')", value)
	JValue.zeroLifetime(jargs)
	return normalized
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

; function JSONFile_flush(int ijFile)
; 	int synced = JSONFile_sync(getObj(ijFile,"root"), getStr(ijFile,"filePath"))
; 	setObj(ijFile, "root", synced)
; endfunction

;;;;

int function __packSyncArgs(int jLocalObj, string filePath) global
	int jargs = object()
	setObj(jargs,"localObj",jLocalObj)
	setStr(jargs,"filePath",filePath)
	return jargs
endfunction

int function JSONFile_sync(int jLocalObj, string filePath) global
	int jargs = __packSyncArgs(jLocalObj, filePath)
	int jSelectedObj = JValue.evalLuaObj(jargs, "return PosePicker.syncJSONFile(jobject.localObj, jobject.filePath)")
	JValue.zeroLifetime(jargs)
	; int jSelectedObj = JLua.evalLuaObj("return PosePicker.syncJSONFile(args.localObj, args.filePath)",\
	; 	JLua.setObj("localObj",jLocalObj, JLua.setStr("filePath",filePath))\
	; )
	return jSelectedObj
endfunction

function JSONFile_syncInplace(int jLocalObj, string filePath) global
	int jargs = __packSyncArgs(jLocalObj, filePath)
	JValue.evalLuaInt(jargs, "return PosePicker.syncJSONFileInplace(jobject.localObj, jobject.filePath)")
	JValue.zeroLifetime(jargs)
	; JLua.evalLuaInt("PosePicker.syncJSONFileInplace(args.localObj, args.filePath)",\
	; 	JLua.setObj("localObj",jLocalObj, JLua.setStr("filePath",filePath))\
	; )
endfunction

; int function JSONFile_syncLargeFile(int jLocalObj, string filePath) global
; 	int jargs = __packSyncArgs(jLocalObj, filePath)
; 	int jSelectedObj = JValue.evalLuaObj(jargs, "return PosePicker.syncLargeJSONFile(jobject.localObj, jobject.filePath)")
; 	JValue.zeroLifetime(jargs)
; 	; int jSelectedObj = JLua.evalLuaObj("return PosePicker.syncLargeJSONFile(args.localObj, args.filePath)",\
; 	; 	JLua.setObj("localObj",jLocalObj, JLua.setStr("filePath",filePath))\
; 	; )
; 	return jSelectedObj
; endfunction

function JSONFile_onChanged(int jLocalObj) global
	setFlt(jLocalObj, "fileVersion", JValue.evalLuaFlt(0, "return os.time()"))
endfunction

float function JSONFile_modifyDate(int jLocalObj) global
	return getFlt(jLocalObj, "fileVersion")
endfunction

float function JSONFile_formatVersion(int jLocalObj) global
	return getFlt(jLocalObj, "formatVersion")
endfunction