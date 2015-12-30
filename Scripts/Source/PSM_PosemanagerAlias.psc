Scriptname PSM_PosemanagerAlias extends ReferenceAlias 

Event OnPlayerLoadGame()

	if !(JContainers.APIVersion() == 3 ||  JContainers.featureVersion() < 3)
		Debug.MessageBox("PosePicker won't like any JC version below 3.3")
	endif

	PSM_PosePicker qst = self.GetOwningQuest() as PSM_PosePicker
	qst.trySyncDataAfterDelay(0.5)
EndEvent
