#include "common/IPrefix.h"

#include <ShlObj.h>
#include <assert.h>
#include <cstdint>
#include <boost/filesystem.hpp>
#include <boost/algorithm/string.hpp>

#include "skse/PluginAPI.h"
#include "skse/skse_version.h"
#include "skse/GameForms.h"
#include "skse/PapyrusNativeFunctions.h"
#include "skse/PapyrusForm.h"
#include "skse/GameData.h"

#include "collections/form_handling.h"
//#include "util/stl_ext.h"

class VMClassRegistry;

#define PLUGIN_NAME "PSM_FormReflection"

namespace form_handling = collections::form_handling;

namespace {

    static PluginHandle					g_pluginHandle = kPluginHandle_Invalid;
    static SKSEPapyrusInterface			* g_papyrus = NULL;

    bool isEmptyString(const BSFixedString& str) {
        return !str.data || '\0' == *str.data;
    }


/*
    static VMResultArray<TESForm*> queryIDLEForms(StaticFunctionTag*, BSFixedString sourcePlugin) {

        const auto dh = DataHandler::GetSingleton();
        
        VMResultArray<TESForm*> forms;
        forms.reserve(dh->idleForms.count / 0xff); // dumb approximation

        DYNAMIC_CAST

        const auto modIdx = dh->GetModIndex(sourcePlugin.data);
        if (modIdx != 0xff) {

            for (uint32_t i = 0; i < dh->idleForms.count; ++i) {

                auto form = dh->idleForms[i];
                if (form && form_handling::mod_index(util::to_enum<collections::FormId>(form->formID)) == modIdx) {
                    forms.push_back(form);
                }
            }
        }
        
        return forms;
    }
*/
    static VMResultArray<TESForm*> queryFormsFrom(StaticFunctionTag*, BSFixedString sourcePlugin, UInt32 formType, UInt32 maxFailedLookups) {

        if (isEmptyString(sourcePlugin)) {
            _MESSAGE("queryFormsFrom: invalid `sourcePlugin` parameter passed");
            return VMResultArray<TESForm*>();
        }

        const auto dh = DataHandler::GetSingleton();
        const auto modIdx = dh->GetModIndex(sourcePlugin.data);

        if (modIdx == decltype(modIdx)(-1)) {
            _MESSAGE("queryFormsFrom: sourcePlugin `%s` is not loaded?", sourcePlugin.data);
            return VMResultArray<TESForm*>();
        }

        VMResultArray<TESForm*> forms;

        for (uint32_t formIdLow = 0, failedLookups = 0; true; ++formIdLow) {

            bool stopCycle = formIdLow > 0x00ffffff /*|| failedLookups > maxFailedLookups*/;
            if (stopCycle) {
                //_MESSAGE("queryFormsFrom: formIdLow %u failedLookups %u", formIdLow, failedLookups);
                break;
            }

            TESForm* form = LookupFormByID((uint32_t)form_handling::construct(modIdx, formIdLow));
            if (!form) {
                ++failedLookups;
                continue;
            }

            failedLookups = 0;

            static_assert(78 == TESIdleForm::kTypeID, "");

            if (form->formType == formType) {
                forms.push_back(form);
            }
        }

        _MESSAGE("queryFormsFrom: %u forms of type %u in `%s` found", forms.size(), formType, sourcePlugin.data);

        return forms;
    }

    namespace fs = boost::filesystem;

    static VMResultArray<BSFixedString> listFilesInDirectory(StaticFunctionTag*, BSFixedString dirPath, BSFixedString fileExtension) {
        if (!dirPath.data || !*dirPath.data) {
            return VMResultArray<BSFixedString>();
        }

        VMResultArray<BSFixedString> files;


        try {
            const std::string fileExt = fileExtension.data ? fileExtension.data : "";
            fs::path p(dirPath.data);
            for (fs::directory_iterator it(p), end = fs::directory_iterator(); it != end; ++it) {
                if (fs::is_directory(it->path())) {
                    continue;
                }

                auto fPath = it->path().filename().generic_string();
                if (fileExt.empty() || boost::iends_with(fPath, fileExt)) {
                    files.emplace_back(fPath.c_str());
                }
            }
        }
        catch (const fs::filesystem_error& exc) {
            _MESSAGE("listFilesInDirectory error: %s", exc.what());
        }

        return files;
    }

    BSFixedString fileNameFromPath(StaticFunctionTag*, BSFixedString dirPath) {
        if (isEmptyString(dirPath)) {
            return BSFixedString();
        }
        fs::path p(dirPath.data);
        return p.filename().generic_string().c_str();
    }

    BSFixedString replaceExtension(StaticFunctionTag*, BSFixedString filePath, BSFixedString withExtension) {
        if (isEmptyString(filePath)) {
            return BSFixedString();
        }
        fs::path p(filePath.data);
        p.replace_extension(isEmptyString(withExtension) ? fs::path() : fs::path(withExtension.data));
        return p.generic_string().c_str();
    }

    void logConsole(StaticFunctionTag*, BSFixedString text) {
        if (text.data) {
            char textData[1024] = { '\0' };
            strncpy_s(textData, text.data, sizeof(textData) - 1);
            Console_Print(textData);
        }
    }

    template<size_t ParamCnt>
    struct native_function_selector;

#define MAKE_ME_HAPPY(N)\
    template<> struct native_function_selector<N> {\
        template<class... Params> using function = ::NativeFunction ## N <::StaticFunctionTag, Params...>;\
            };

    MAKE_ME_HAPPY(0);
    MAKE_ME_HAPPY(1);
    MAKE_ME_HAPPY(2);
    MAKE_ME_HAPPY(3);
    MAKE_ME_HAPPY(4);
    MAKE_ME_HAPPY(5);
    MAKE_ME_HAPPY(6);

#undef  MAKE_ME_HAPPY


    template <class R, class... Params>
    void registerFunction(const char* funcName, R(*funcPtr)(StaticFunctionTag*, Params ...), VMClassRegistry *registry) {

        registry->RegisterFunction(
            new typename native_function_selector<sizeof... (Params)>::function <R, Params ...>(
                funcName, PLUGIN_NAME, funcPtr, registry
            )
        );

        registry->SetFunctionFlags(PLUGIN_NAME, funcName, VMClassRegistry::kFunctionFlag_NoWait);
    }

    bool registerAllFunctions(VMClassRegistry *registry) {

        registerFunction("queryFormsFrom", queryFormsFrom, registry);
        registerFunction("listFilesInDirectory", listFilesInDirectory, registry);
        registerFunction("fileNameFromPath", fileNameFromPath, registry);
        registerFunction("replaceExtension", replaceExtension, registry);
        registerFunction("logConsole", logConsole, registry);

        return true;
    }
}

extern "C" {

    __declspec(dllexport) bool SKSEPlugin_Query(const SKSEInterface * skse, PluginInfo * info)
    {
        gLog.OpenRelative(CSIDL_MYDOCUMENTS, "\\My Games\\Skyrim\\SKSE\\"PLUGIN_NAME".log");
        gLog.SetPrintLevel(IDebugLog::kLevel_Error);
        gLog.SetLogLevel(IDebugLog::kLevel_DebugMessage);

        // populate info structure
        info->infoVersion = PluginInfo::kInfoVersion;
        info->name = PLUGIN_NAME;
        info->version = 1;

        // store plugin handle so we can identify ourselves later
        g_pluginHandle = skse->GetPluginHandle();

        if (skse->isEditor) {
            _MESSAGE("loaded in editor, marking as incompatible");
            return false;
        }
        else if (skse->runtimeVersion != RUNTIME_VERSION_1_9_32_0) {
            _MESSAGE("unsupported runtime version %08X", skse->runtimeVersion);
            return false;
        }

        g_papyrus = (SKSEPapyrusInterface *)skse->QueryInterface(kInterface_Papyrus);

        if (!g_papyrus) {
            _MESSAGE("couldn't get papyrus interface");
            return false;
        }


        return true;
    }

    __declspec(dllexport) bool SKSEPlugin_Load(const SKSEInterface * skse) {

        g_papyrus->Register(registerAllFunctions);

        _MESSAGE("plugin loaded");

        return true;
    }
}

//////////////////////////////////////////////////////////////////////////
// boost 'fix'
//////////////////////////////////////////////////////////////////////////

static void init_boost() {
    boost::filesystem::path p("dummy");
}

BOOL APIENTRY DllMain(HMODULE /* hModule */,
    DWORD  ul_reason_for_call,
    LPVOID /* lpReserved */)
{
    switch (ul_reason_for_call)
    {
    case DLL_PROCESS_ATTACH:
        init_boost();
        break;
    case DLL_THREAD_ATTACH:
    case DLL_THREAD_DETACH:
    case DLL_PROCESS_DETACH:
        break;
    }
    return TRUE;
}
