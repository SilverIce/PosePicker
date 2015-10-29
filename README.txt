## Pose Picker Concept

There are two pose slots. Each slot may contain one pose collection, you can select and put any pose collection into the slot.

- Edit-slot - to edit pose collection. (delete, duplicate, rename etc)
- View-slot - to view poses, add (favorite) or remove current pose into Edit-slot's pose collection

I have added bunch of hotkeys, everything must be pressed in conjunction with left Alt key:
 
- L - load poses from esp/esm, creates pose list, put in into the View-slot
- P - pick pose collection, put in into the 'view' slot
- left & right arrow keys - move back or forth, view poses from View-slot
- A - various actions to be performed on the pose list in the Edit-slot
- X - select pose list, put it into the Edit-slot
 
- G - fav. current pose. Add current pose into the pose list from Edit-slot
- U - unfav. current pose. Remove the pose from the pose list from Edit-slot
- F2 - dump poses and etc data into "Data/Scripts/Source/PSM_PosePickerStruct.json". I know that this is wrong location for such kind of files
- F3 - load, replace your data completely with the data from "Data/Scripts/Source/PSM_PosePickerStruct.json"

Just in case, JContainers 3.2.5, SKSE is required

## Legal stuff

I'm, Earen at <slifeleaf@gmail.com>, the author of the following mod. Don't reupload, sell the mod without my permission
