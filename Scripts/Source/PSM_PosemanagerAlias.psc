Scriptname PSM_PosemanagerAlias extends ReferenceAlias 

Event OnPlayerLoadGame()
	PSM_PosePicker qst = self.GetOwningQuest() as PSM_PosePicker
	qst.trySyncDataAfterDelay(0.5)
EndEvent
