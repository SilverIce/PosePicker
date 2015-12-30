Scriptname FormReflection

; @plugin - esm/esp plugin file name with extension
; @withFormType - to select the forms with specific type identifier. See FormType.psc
Form[] function queryFormsFrom(String plugin, int withFormType, int maxFailedLookups = 1000) global native

string[] function listFilesInDirectory(String directoryPath, String fileExtension = "") global native
string function fileNameFromPath(String filePath) global native
string function replaceExtension(String filePath, String withExtension) global native

