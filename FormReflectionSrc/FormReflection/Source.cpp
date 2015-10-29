/*
Primitive example which shows how to use SKSE messaging API and interact with JContainers API

Plugin obtains some JC functionality and registers a function (sortByName) which sorts an jarray of forms by their names
*/


#include "common/IPrefix.h"

#include <ShlObj.h>
#include <assert.h>
#include <cstdint>

#include "skse/PluginAPI.h"
#include "skse/skse_version.h"
#include "skse/GameForms.h"
#include "skse/PapyrusNativeFunctions.h"
#include "skse/PapyrusForm.h"
#include "skse/GameData.h"

#include "collections/form_handling.h"
#include "util/stl_ext.h"

class VMClassRegistry;

#define PLUGIN_NAME "FormReflection"

namespace form_handling = collections::form_handling;

namespace {

    static PluginHandle					g_pluginHandle = kPluginHandle_Invalid;
    static SKSEPapyrusInterface			* g_papyrus = NULL;

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
    static VMResultArray<TESForm*> queryFormsFrom(StaticFunctionTag*, BSFixedString sourcePlugin, UInt32 formType) {

        const auto dh = DataHandler::GetSingleton();

        VMResultArray<TESForm*> forms;

        uint32_t formIdLow = 0;
        const auto modIdx = dh->GetModIndex(sourcePlugin.data);

        for (uint32_t formIdLow = 0, failedLookups = 0; formIdLow <= 0x00ffffff || failedLookups > 500; ++formIdLow) {
        
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

        _MESSAGE("queryFormsFrom: %u forms of type %u found", forms.size(), formType);

        return forms;
    }

    bool registerAllFunctions(VMClassRegistry *registry) {

        auto funcName = "queryFormsFrom";
        auto className = PLUGIN_NAME;

        registry->RegisterFunction(
            new NativeFunction2 <StaticFunctionTag, VMResultArray<TESForm*>, BSFixedString, UInt32>
            (funcName, className, queryFormsFrom, registry)
        );

        //registry->SetFunctionFlags(className, funcName, VMClassRegistry::kFunctionFlag_NoWait);

        _MESSAGE("registering functions");

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
