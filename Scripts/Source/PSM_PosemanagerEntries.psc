Scriptname PSM_PosemanagerEntries

import JMap

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
string function PoseList_getName(int list) global
	return getStr(list, "name")
endfunction
string function PoseList_describe(int list) global
	if list
		return PoseList_getName(list)+", "+JValue.count(PoseList_getList(list))+" poses"
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
	int count = JValue.count(PoseList_getList(list))
	int idx = (index + count) % count
	setInt(list, "poseIdx", idx)
	return idx
endfunction
Idle function PoseList_currentPose(int list) global
	return JArray.getForm(PoseList_getList(list), PoseList_poseIndex(list)) as Idle
endfunction

; Globals

; int function getCurrentPoseList() global
; 	return JDB.solveInt(".PosePicker.currentPoseLis")
; endfunction
; function setCurrentPoseList(int jlist) global
; 	JDB.solveIntSetter(".PosePicker.currentPoseLis", jlist, createMissingKeys = true)
; endfunction

int function root(bool forceLoadFromFile = false) global
	return JSONFileCache(".PosePicker", "Data/Scripts/Source/PSM_PosePickerStruct.json", forceRefresh = forceLoadFromFile)
endfunction

function dumpRoot() global
	JValue.writeToFile(root(), "Data/Scripts/Source/PSM_PosePickerStruct.json")
endfunction

int function getPoseLists() global
	return JValue.solveObj(root(), ".poseLists")
endfunction

int function keyCode2Handler() global
	return JValue.solveObj(root(), ".keyCode2Handler")
endfunction

string[] function getPoseListsNames() global
	string lua = "return PosePicker.foldl(jobject, JArray.object(), function(pose, init) JArray.insert(init, pose.name); return init end)"
	string[] poseNames = JArray_toStringArray(JValue.evalLuaObj(getPoseLists(), lua))
	return poseNames
endfunction

int function dummyPoseCollection() global
	return JValue.solveObj(root(), ".dummyCreateCollection")
endfunction

int function getNthPoseList(int idx) global
	int jPoses = JArray.getObj(getPoseLists(), idx)
	return jPoses
endfunction

function addPoseCollection(int jPoses) global
	if jPoses && JArray.findObj(getPoseLists(), jPoses) == -1
		JArray.addObj(getPoseLists(), jPoses)
	endif
endfunction

function deletePoseCollection(int jPoses) global
	int idx = JArray.findObj(getPoseLists(), jPoses)
	if idx != -1
		JArray.eraseIndex(getPoseLists(), idx)
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

