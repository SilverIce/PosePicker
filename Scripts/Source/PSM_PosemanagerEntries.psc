Scriptname PSM_PosemanagerEntries

;import JMap
import Debug
import JContainers_DomainExample

function Pose_setName(Idle pose, string name) global
	JFormDB.setStr(pose, ".PosePicker.name", name)
endfunction
string function Pose_getName(Idle pose) global
	return JFormDB.getStr(pose, ".PosePicker.name")
endfunction


int function PoseList_make(string name) global
	int list = JMap_object()
	PoseList_setName(list, name)
	JMap_setInt(list, "poseIdx", 0)
	JMap_setObj(list, "poses", JArray_object())
	; this way it will have higher mod. time than any already existing collection
	JSONFile_onChanged(list)
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
	int jPoses = JValue_readFromFile(__collectionNameToPath(collectionName))
	PrintConsole("PoseList_loadFromFile: loading " + collectionName + " at " + __collectionNameToPath(collectionName) + ": " + jPoses)

	if !jPoses
		PrintConsole("PoseList_loadFromFile: can't load " + collectionName + " at " + __collectionNameToPath(collectionName))
		return 0
	endif

	if !PoseList_isValid(jPoses)
		PrintConsole("PoseList_loadFromFile: pose forms in the collection can't be loaded. Loading failed")
		JValue_zeroLifetime(jPoses)
		return 0
	endif
	
	PoseList_setExactName(jPoses, collectionName)
	return jPoses
endfunction
bool function PoseList_dump(int jPoses) global
	if PoseList_isValid(jPoses)
		string filePath = __collectionNameToPath(PoseList_getName(jPoses))
		JValue_writeToFile(jPoses, filePath)
		return true
	endif
	return false
endfunction
bool function PoseList_isValid(int list) global
	return PoseList_findPose(list, None) == -1
endfunction
string function PoseList_filePath(int list) global
	return __collectionNameToPath(PoseList_getName(list))
endfunction
string function PoseList_getName(int list) global
	return JMap_getStr(list, "name")
endfunction
function PoseList_setExactName(int list, string name) global
	JMap_setStr(list, "name", name)
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
	return JMap_getObj(list, "poses")
endfunction
int function PoseList_poseCount(int list) global
	return JValue_count(PoseList_getList(list))
endfunction
int function PoseList_findPose(int list, Idle pose) global
	return JArray_findForm(PoseList_getList(list), pose)
endfunction
function PoseList_setPoses(int list, Form[] poses) global
	JMap_setObj(list, "poses", JArray_insertFormArray(JArray_object(), poses))
	JSONFile_onChanged(list)
endfunction
function PoseList_addPose(int list, Idle pose) global
	if pose && PoseList_findPose(list, pose) == -1
		JArray_addForm(PoseList_getList(list), pose)
		JSONFile_onChanged(list)
	endif
endfunction
function PoseList_removePose(int list, Idle pose) global
	int idx = PoseList_findPose(list, pose)
	if idx != -1
		JArray_eraseIndex(PoseList_getList(list), idx)
		if idx < PoseList_poseIndex(list)
			PoseList_setPoseIndex(list, PoseList_poseIndex(list) - 1)
		endif
		JSONFile_onChanged(list)
	endif
endfunction

int function PoseList_poseIndex(int list) global
	return JMap_getInt(list, "poseIdx")
endfunction
int function PoseList_setPoseIndex(int list, int index) global
	;TraceConditional("invalid identifier", list == 0)
	int count = PoseList_poseCount(list)
	if count > 0
		int idx = (index + count) % count
		JMap_setInt(list, "poseIdx", idx)
		JSONFile_onChanged(list)
		return idx
	else
		return 0
	endif
endfunction
Idle function PoseList_currentPose(int list) global
	return JArray_getForm(PoseList_getList(list), PoseList_poseIndex(list)) as Idle
endfunction

;;;;;;;;;;;;;

; function tryInstallMod() global
; 	string userDir = JContainers.userDirectory()
; 	if JContainers.fileExistsAtPath(userDir + ".installed")
; 		return



;;;;;;;;;;;;; Key Handler

int function KHConf_getAltKeyCode(int jConfig) global
	return JMap_getInt(jConfig, "altKey")
endfunction

function KHConf_setAltKeyCode(int jConfig, int keyCode) global
	JMap_setInt(jConfig, "altKey", keyCode)
	JSONFile_onChanged(jConfig)
endfunction

int function KHConf_getKeyHandlers(int jConfig) global
	return JMap_getObj(jConfig, "handlers")
endfunction

string function KHConf_getKeyHandler(int jConfig, int keyCode) global
	return JValue_solveStr(jConfig, ".handlers[" + keyCode + "]")
endfunction

string function KHConf_EVENT_NAME() global
	return "PSM_KHConf_setKeyCodeForHandler"
endfunction
string function KHConf_FILE_PATH() global
	return "Data/PosePicker/KeyHandlerConfig.json"
endfunction

bool function KHConf_setKeyCodeForHandler(int jConfig, int keyCode, string handler) global

	int keys2handlers = JMap_getObj(jConfig, "handlers")
	; to prevent overwrite 
	if JIntMap_hasKey(keys2handlers, keyCode)
		return False
	endif

	int handlers = JIntMap_allValues(keys2handlers)
	int pairIdx = JArray_findStr(handlers, handler)

	if pairIdx != -1
		int oldKeyCode = JIntMap_getNthKey(keys2handlers, pairIdx)
		JIntMap_removeKey(keys2handlers, oldKeyCode)
		JIntMap_setStr(keys2handlers, keyCode, handler)
		JSONFile_onChanged(jConfig)

		int evt = ModEvent.Create(KHConf_EVENT_NAME())
		ModEvent.PushInt(evt, jConfig)
		ModEvent.PushInt(evt, oldKeyCode)
		ModEvent.PushInt(evt, keyCode)
		ModEvent.Send(evt)
	endif
	JValue_zeroLifetime(handlers)
	return True
endfunction

int function KHConf_singleton() global
	string path = ".PosePicker.KHConf"
	string fpath = KHConf_FILE_PATH()
	int jLocalObj = JDB_solveObj(path)
	int jRemote = JValue_readFromFile(fpath)

	if JSONFile_formatVersion(jLocalObj) != JSONFile_formatVersion(jRemote)
		JDB_solveObjSetter(path, jRemote, True)
		return jRemote
	elseif JSONFile_modifyDate(jLocalObj) > JSONFile_modifyDate(jRemote)
		JValue_writeToFile(jLocalObj, fpath)
	endif

	JValue_zeroLifetime(jRemote)
	;PrintConsole("KHConf_singleton: " + jLocalObj)
	return jLocalObj
endfunction

;;;;;;;;;;;;;;;;;;; View & Edit context

int function CTX_object() global
	return JValue_readFromFile("Data/PosePicker/PoserContext.json")
endfunction

function CTX_setViewSlot(int jCTX, int jPoses) global
	JMap_setObj(jCTX, "viewSlot", jPoses)
	Notification("Viewing pose collection: " + PoseList_describe(jPoses))
endfunction

int function CTX_getViewSlot(int jCTX) global
	return JMap_getObj(jCTX, "viewSlot")
endfunction
function CTX_setEditSlot(int jCTX, int jPoses) global
	JMap_setObj(jCTX, "editSlot", jPoses)
	Notification("Editing pose collection: " + PoseList_describe(jPoses))
endfunction
int function CTX_getEditSlot(int jCTX) global
	return JMap_getObj(jCTX, "editSlot")
endfunction

function CTX_swapSlots(int jCTX) global
	int o = CTX_getViewSlot(jCTX)
	CTX_setViewSlot(jCTX, CTX_getEditSlot(jCTX))
	CTX_setEditSlot(jCTX, o)
endfunction

; int function CTX_dummyCollection(int jCTX) global
; 	return getObj(jCTX, "dummyCreateCollection")
; endfunction

;;; IO

int function CTX_getObjectsToSync(int jCTX) global
	return JMap_getObj(jCTX, "objectsToSync")
endfunction

function CTX_rememberActiveCollections(int jCTX) global
	int jObjectsToSync = CTX_getObjectsToSync(jCTX)

	int jView = CTX_getViewSlot(jCTX)
	if jView
		JIntMap_setObj(jObjectsToSync, jView, jView)
	endif
	int jEdit = CTX_getEditSlot(jCTX)
	if jEdit && jEdit != jView
		JIntMap_setObj(jObjectsToSync, jEdit, jEdit)
	endif
endfunction

function CTX_syncCollections(int jCTX) global
	int jObjectsToSync = CTX_getObjectsToSync(jCTX)
	int k = JIntMap_getNthKey(jObjectsToSync, 0)
	while k
		int o = JIntMap_getObj(jObjectsToSync, k)
		k = JIntMap_nextKey(jObjectsToSync, k)
		;PrintConsole("syncing " + PoseList_describe(o))
		if PoseList_isValid(o)
			JSONFile_syncInplace(o, PoseList_filePath(o))
		endif
	endwhile
	JIntMap_clear(jObjectsToSync)
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
	PoseList_dump(jPoses)
endfunction

bool function CTX_isCollectionWithNameExists(int jCTX, string name) global
	return JContainers.fileExistsAtPath(__collectionNameToPath(name))
endfunction

string function CTX_chooseNewCollectionName(int jCTX, string name) global
	string normalizedName = JString_normalizeString(name)
	if "" == normalizedName || True == CTX_isCollectionWithNameExists(jCTX, normalizedName)
		return ""
	endif
	return normalizedName
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
	string normalizedName = CTX_chooseNewCollectionName(jCTX, newName)

	if 0 == jPoses || "" == normalizedName
		return False
	endif

	;PrintConsole("deleting collection at " + PoseList_filePath(jPoses))
	JContainers.removeFileAtPath(PoseList_filePath(jPoses))
	PoseList_setName(jPoses, normalizedName)
	PoseList_dump(jPoses)
	return True
endfunction

;;;; Utils ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

function PrintConsole(string text) global
	PSM_FormReflection.logConsole("[PosePicker] " + text)
endfunction

int function getModList() global
	int jmods = JArray_objectWithSize(Game.GetModCount())
	int i = 0
	while i < Game.GetModCount()
		JArray_setStr(jmods, i, Game.GetModName(i))
		i += 1
	endwhile
	return jmods
endfunction

string[] function JArray_toStringArray(int obj) global
	string[] mods = Utility.CreateStringArray(JArray_count(obj), fill = "")
	int i = 0
	while i < JArray_count(obj)
		mods[i] = JArray_getStr(obj, i)
		i += 1
	endwhile
	return mods
endfunction

string function JString_normalizeString(string value) global
	int jargs = JMap_object()
	JMap_setStr(jargs, "str", value)
	string normalized = JValue_evalLuaStr(jargs, "return string.gsub(jobject.str, '%W', ' ')", value)
	JValue_zeroLifetime(jargs)
	return normalized
endfunction

; int function JSONFileCache(string keyPath, string file, bool forceRefresh = false) global
; 	int jfile = JDB_solveObj(keyPath)
; 	if !jfile || forceRefresh
; 		jfile = JValue_readFromFile(file)
; 		JDB_solveObjSetter(keyPath, jfile, createMissingKeys = True)
; 	endif
; 	return jfile
; endfunction

int function JArray_insertFormArray(int obj, Form[] forms, int insertAt = -1) global
	int i = 0
	while i < forms.Length
		JArray_addForm(obj, forms[i], addToIndex = insertAt)
		i += 1
	endwhile
	return obj
endfunction

;;;;;;;;;;;;;;;;;;;;;; JSONFile

; int function JSONFile_make(string filePath)
; 	return JValue_objectFromPrototype("{ \"filePath\": \""+ filePath +"\" }")
; endfunction

; int function JSONFile_root(int ijFile, int sessionUID)
; 	if getInt(ijFile, "tick") != sessionUID
; 		setInt(ijFile, "tick", sessionUID)
; 		setObj(ijFile, "root", JValue_readFromFile(getStr(ijFile, "filePath")))
; 	endif
; 	return getObj(ijFile, "root")
; endfunction

; function JSONFile_flush(int ijFile)
; 	int synced = JSONFile_sync(getObj(ijFile,"root"), getStr(ijFile,"filePath"))
; 	setObj(ijFile, "root", synced)
; endfunction

;;;;

int function __packSyncArgs(int jLocalObj, string filePath) global
	int jargs = JMap_object()
	JMap_setObj(jargs,"localObj",jLocalObj)
	JMap_setStr(jargs,"filePath",filePath)
	return jargs
endfunction

int function JSONFile_sync(int jLocalObj, string filePath) global
	int jargs = __packSyncArgs(jLocalObj, filePath)
	int jSelectedObj = JValue_evalLuaObj(jargs, "return PosePicker.syncJSONFile(jobject.localObj, jobject.filePath)")
	JValue_zeroLifetime(jargs)
	; int jSelectedObj = JLua.evalLuaObj("return PosePicker.syncJSONFile(args.localObj, args.filePath)",\
	; 	JLua.setObj("localObj",jLocalObj, JLua.setStr("filePath",filePath))\
	; )
	return jSelectedObj
endfunction

function JSONFile_syncInplace(int jLocalObj, string filePath) global
	int jargs = __packSyncArgs(jLocalObj, filePath)
	JValue_evalLuaInt(jargs, "return PosePicker.syncJSONFileInplace(jobject.localObj, jobject.filePath)")
	JValue_zeroLifetime(jargs)
	; JLua.evalLuaInt("PosePicker.syncJSONFileInplace(args.localObj, args.filePath)",\
	; 	JLua.setObj("localObj",jLocalObj, JLua.setStr("filePath",filePath))\
	; )
endfunction

; int function JSONFile_syncLargeFile(int jLocalObj, string filePath) global
; 	int jargs = __packSyncArgs(jLocalObj, filePath)
; 	int jSelectedObj = JValue_evalLuaObj(jargs, "return PosePicker.syncLargeJSONFile(jobject.localObj, jobject.filePath)")
; 	JValue_zeroLifetime(jargs)
; 	; int jSelectedObj = JLua.evalLuaObj("return PosePicker.syncLargeJSONFile(args.localObj, args.filePath)",\
; 	; 	JLua.setObj("localObj",jLocalObj, JLua.setStr("filePath",filePath))\
; 	; )
; 	return jSelectedObj
; endfunction

function JSONFile_onChanged(int jLocalObj) global
	JMap_setFlt(jLocalObj, "fileVersion", JValue_evalLuaFlt(0, "return os.time()"))
endfunction

float function JSONFile_modifyDate(int jLocalObj) global
	return JMap_getFlt(jLocalObj, "fileVersion")
endfunction

float function JSONFile_formatVersion(int jLocalObj) global
	return JMap_getFlt(jLocalObj, "formatVersion")
endfunction