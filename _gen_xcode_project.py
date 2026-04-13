#!/usr/bin/env python3
"""One-off generator for SportCalendar.xcodeproj — run once, then delete if desired."""
import uuid

def uid():
    return uuid.uuid4().hex[:24].upper()

P = {}
P['sources_root'] = uid()
P['project'] = uid()
P['target'] = uid()
P['sources_phase'] = uid()
P['resources_phase'] = uid()
P['frameworks_phase'] = uid()
P['main_group'] = uid()
P['products_group'] = uid()
P['proj_config_list'] = uid()
P['tgt_config_list'] = uid()
P['debug_proj'] = uid()
P['release_proj'] = uid()
P['debug_tgt'] = uid()
P['release_tgt'] = uid()
P['product_app'] = uid()
P['info_plist'] = uid()

files = [
    ('App/AppState.swift', 'sourcecode.swift'),
    ('App/SportCalendarApp.swift', 'sourcecode.swift'),
    ('Config/APIConfig.swift', 'sourcecode.swift'),
    ('Models/BootstrapModels.swift', 'sourcecode.swift'),
    ('Models/CommunityHelpers.swift', 'sourcecode.swift'),
    ('Models/TabExtrasModels.swift', 'sourcecode.swift'),
    ('Services/APIClient.swift', 'sourcecode.swift'),
    ('Services/APIError.swift', 'sourcecode.swift'),
    ('Services/BootstrapCache.swift', 'sourcecode.swift'),
    ('Services/KeychainTokenStore.swift', 'sourcecode.swift'),
    ('Views/AppRootView.swift', 'sourcecode.swift'),
    ('Views/AuthView.swift', 'sourcecode.swift'),
    ('Views/CalendarTabView.swift', 'sourcecode.swift'),
    ('Views/CommunityTabView.swift', 'sourcecode.swift'),
    ('Views/CommunityMemberProfileView.swift', 'sourcecode.swift'),
    ('Views/CommunityScopeTabs.swift', 'sourcecode.swift'),
    ('Views/MainTabView.swift', 'sourcecode.swift'),
    ('Views/TabChrome.swift', 'sourcecode.swift'),
    ('Views/NutritionTabView.swift', 'sourcecode.swift'),
    ('Views/ProfileTabView.swift', 'sourcecode.swift'),
    ('Views/ProfileHelpers.swift', 'sourcecode.swift'),
    ('Views/WordsGameTabView.swift', 'sourcecode.swift'),
    ('Resources/Config.plist', 'text.plist.xml'),
]

file_refs = []
build_file_res = None

for rel_path, ftype in files:
    fr = uid()
    bf = uid()
    name = rel_path.split('/')[-1]
    file_refs.append((bf, fr, name, rel_path, ftype))
    if rel_path.endswith('Config.plist'):
        build_file_res = (bf, fr)

assert build_file_res

lines = []
lines.append('// !$*UTF8*$!')
lines.append('{')
lines.append('\tarchiveVersion = 1;')
lines.append('\tclasses = {')
lines.append('\t};')
lines.append('\tobjectVersion = 56;')
lines.append('\tobjects = {')

lines.append('\n/* Begin PBXBuildFile section */')
for bf, fr, name, path, ftype in file_refs:
    if path.endswith('Config.plist'):
        lines.append(f'\t\t{bf} /* {name} in Resources */ = {{isa = PBXBuildFile; fileRef = {fr} /* {name} */; }};')
    else:
        lines.append(f'\t\t{bf} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fr} /* {name} */; }};')
lines.append('/* End PBXBuildFile section */')

lines.append('\n/* Begin PBXFileReference section */')
lines.append(f'\t\t{P["product_app"]} /* SportCalendar.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = SportCalendar.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
lines.append(f'\t\t{P["info_plist"]} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};')
for bf, fr, name, path, ftype in file_refs:
    lines.append(f'\t\t{fr} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = {path}; sourceTree = "<group>"; }};')
lines.append('/* End PBXFileReference section */')

lines.append('\n/* Begin PBXFrameworksBuildPhase section */')
lines.append(f'\t\t{P["frameworks_phase"]} /* Frameworks */ = {{')
lines.append('\t\t\tisa = PBXFrameworksBuildPhase;')
lines.append('\t\t\tbuildActionMask = 2147483647;')
lines.append('\t\t\tfiles = (')
lines.append('\t\t\t);')
lines.append('\t\t\trunOnlyForDeploymentPostprocessing = 0;')
lines.append('\t\t};')
lines.append('/* End PBXFrameworksBuildPhase section */')

lines.append('\n/* Begin PBXGroup section */')
lines.append(f'\t\t{P["main_group"]} = {{')
lines.append('\t\t\tisa = PBXGroup;')
lines.append('\t\t\tchildren = (')
lines.append(f'\t\t\t\t{P["sources_root"]} /* Sources */,')
lines.append(f'\t\t\t\t{P["info_plist"]} /* Info.plist */,')
lines.append(f'\t\t\t\t{P["products_group"]} /* Products */,')
lines.append('\t\t\t);')
lines.append('\t\t\tsourceTree = "<group>";')
lines.append('\t\t};')

lines.append(f'\t\t{P["sources_root"]} /* Sources */ = {{')
lines.append('\t\t\tisa = PBXGroup;')
lines.append('\t\t\tchildren = (')
for bf, fr, name, path, ftype in file_refs:
    lines.append(f'\t\t\t\t{fr} /* {name} */,')
lines.append('\t\t\t);')
lines.append('\t\t\tpath = Sources/SportCalendar;')
lines.append('\t\t\tsourceTree = "<group>";')
lines.append('\t\t};')

lines.append(f'\t\t{P["products_group"]} /* Products */ = {{')
lines.append('\t\t\tisa = PBXGroup;')
lines.append('\t\t\tchildren = (')
lines.append(f'\t\t\t\t{P["product_app"]} /* SportCalendar.app */,')
lines.append('\t\t\t);')
lines.append('\t\t\tname = Products;')
lines.append('\t\t\tsourceTree = "<group>";')
lines.append('\t\t};')
lines.append('/* End PBXGroup section */')

lines.append('\n/* Begin PBXNativeTarget section */')
lines.append(f'\t\t{P["target"]} /* SportCalendar */ = {{')
lines.append('\t\t\tisa = PBXNativeTarget;')
lines.append('\t\t\tbuildConfigurationList = ' + P['tgt_config_list'] + ' /* Build configuration list for PBXNativeTarget "SportCalendar" */;')
lines.append('\t\t\tbuildPhases = (')
lines.append(f'\t\t\t\t{P["sources_phase"]} /* Sources */,')
lines.append(f'\t\t\t\t{P["frameworks_phase"]} /* Frameworks */,')
lines.append(f'\t\t\t\t{P["resources_phase"]} /* Resources */,')
lines.append('\t\t\t);')
lines.append('\t\t\tbuildRules = (')
lines.append('\t\t\t);')
lines.append('\t\t\tdependencies = (')
lines.append('\t\t\t);')
lines.append('\t\t\tname = SportCalendar;')
lines.append('\t\t\tproductName = SportCalendar;')
lines.append(f'\t\t\tproductReference = {P["product_app"]} /* SportCalendar.app */;')
lines.append('\t\t\tproductType = "com.apple.product-type.application";')
lines.append('\t\t};')
lines.append('/* End PBXNativeTarget section */')

lines.append('\n/* Begin PBXProject section */')
lines.append(f'\t\t{P["project"]} /* Project object */ = {{')
lines.append('\t\t\tisa = PBXProject;')
lines.append('\t\t\tattributes = {')
lines.append('\t\t\t\tBuildIndependentTargetsInParallel = 1;')
lines.append('\t\t\t\tLastSwiftUpdateCheck = 1500;')
lines.append('\t\t\t\tLastUpgradeCheck = 1500;')
lines.append('\t\t\t\tTargetAttributes = {')
lines.append(f'\t\t\t\t\t{P["target"]} = {{')
lines.append('\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;')
lines.append('\t\t\t\t\t};')
lines.append('\t\t\t\t};')
lines.append('\t\t\t};')
lines.append('\t\t\tbuildConfigurationList = ' + P['proj_config_list'] + ' /* Build configuration list for PBXProject "SportCalendar" */;')
lines.append('\t\t\tcompatibilityVersion = "Xcode 14.0";')
lines.append('\t\t\tdevelopmentRegion = en;')
lines.append('\t\t\thasScannedForEncodings = 0;')
lines.append('\t\t\tknownRegions = (')
lines.append('\t\t\t\ten,')
lines.append('\t\t\t\tBase,')
lines.append('\t\t\t);')
lines.append(f'\t\t\tmainGroup = {P["main_group"]};')
lines.append('\t\t\tpackageReferences = (')
lines.append('\t\t\t);')
lines.append(f'\t\t\tproductRefGroup = {P["products_group"]} /* Products */;')
lines.append('\t\t\tprojectDirPath = "";')
lines.append('\t\t\tprojectRoot = "";')
lines.append('\t\t\ttargets = (')
lines.append(f'\t\t\t\t{P["target"]} /* SportCalendar */,')
lines.append('\t\t\t);')
lines.append('\t\t};')
lines.append('/* End PBXProject section */')

lines.append('\n/* Begin PBXResourcesBuildPhase section */')
lines.append(f'\t\t{P["resources_phase"]} /* Resources */ = {{')
lines.append('\t\t\tisa = PBXResourcesBuildPhase;')
lines.append('\t\t\tbuildActionMask = 2147483647;')
lines.append('\t\t\tfiles = (')
lines.append(f'\t\t\t\t{build_file_res[0]} /* Config.plist in Resources */,')
lines.append('\t\t\t);')
lines.append('\t\t\trunOnlyForDeploymentPostprocessing = 0;')
lines.append('\t\t};')
lines.append('/* End PBXResourcesBuildPhase section */')

lines.append('\n/* Begin PBXSourcesBuildPhase section */')
lines.append(f'\t\t{P["sources_phase"]} /* Sources */ = {{')
lines.append('\t\t\tisa = PBXSourcesBuildPhase;')
lines.append('\t\t\tbuildActionMask = 2147483647;')
lines.append('\t\t\tfiles = (')
for bf, fr, name, path, ftype in file_refs:
    if path.endswith('Config.plist'):
        continue
    lines.append(f'\t\t\t\t{bf} /* {name} in Sources */,')
lines.append('\t\t\t);')
lines.append('\t\t\trunOnlyForDeploymentPostprocessing = 0;')
lines.append('\t\t};')
lines.append('/* End PBXSourcesBuildPhase section */')

lines.append('\n/* Begin XCBuildConfiguration section */')
lines.append(f'\t\t{P["debug_proj"]} /* Debug */ = {{')
lines.append('\t\t\tisa = XCBuildConfiguration;')
lines.append('\t\t\tbuildSettings = {')
lines.append('\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;')
lines.append('\t\t\t\tASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;')
lines.append('\t\t\t\tCLANG_ANALYZER_NONNULL = YES;')
lines.append('\t\t\t\tCLANG_ENABLE_MODULES = YES;')
lines.append('\t\t\t\tCOPY_PHASE_STRIP = NO;')
lines.append('\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;')
lines.append('\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;')
lines.append('\t\t\t\tENABLE_TESTABILITY = YES;')
lines.append('\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;')
lines.append('\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;')
lines.append('\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = ("DEBUG=1", "$(inherited)",);')
lines.append('\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;')
lines.append('\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;')
lines.append('\t\t\t\tONLY_ACTIVE_ARCH = YES;')
lines.append('\t\t\t\tSDKROOT = iphoneos;')
lines.append('\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";')
lines.append('\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";')
lines.append('\t\t\t};')
lines.append('\t\t\tname = Debug;')
lines.append('\t\t};')

lines.append(f'\t\t{P["release_proj"]} /* Release */ = {{')
lines.append('\t\t\tisa = XCBuildConfiguration;')
lines.append('\t\t\tbuildSettings = {')
lines.append('\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;')
lines.append('\t\t\t\tASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;')
lines.append('\t\t\t\tCLANG_ANALYZER_NONNULL = YES;')
lines.append('\t\t\t\tCLANG_ENABLE_MODULES = YES;')
lines.append('\t\t\t\tCOPY_PHASE_STRIP = NO;')
lines.append('\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";')
lines.append('\t\t\t\tENABLE_NS_ASSERTIONS = NO;')
lines.append('\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;')
lines.append('\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;')
lines.append('\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;')
lines.append('\t\t\t\tSDKROOT = iphoneos;')
lines.append('\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;')
lines.append('\t\t\t};')
lines.append('\t\t\tname = Release;')
lines.append('\t\t};')

lines.append(f'\t\t{P["debug_tgt"]} /* Debug */ = {{')
lines.append('\t\t\tisa = XCBuildConfiguration;')
lines.append('\t\t\tbuildSettings = {')
lines.append('\t\t\t\tCODE_SIGN_STYLE = Automatic;')
lines.append('\t\t\t\tCURRENT_PROJECT_VERSION = 1;')
lines.append('\t\t\t\tDEVELOPMENT_ASSET_PATHS = "";')
lines.append('\t\t\t\tENABLE_PREVIEWS = YES;')
lines.append('\t\t\t\tGENERATE_INFOPLIST_FILE = NO;')
lines.append('\t\t\t\tINFOPLIST_FILE = Info.plist;')
lines.append('\t\t\t\tINFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;')
lines.append('\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;')
lines.append('\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";')
lines.append('\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";')
lines.append('\t\t\t\tLD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/Frameworks");')
lines.append('\t\t\t\tMARKETING_VERSION = 1.0;')
lines.append('\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.sportcalendar.SportCalendar;')
lines.append('\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";')
lines.append('\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";')
lines.append('\t\t\t\tSUPPORTS_MACCATALYST = NO;')
lines.append('\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;')
lines.append('\t\t\t\tSWIFT_VERSION = 5.0;')
lines.append('\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";')
lines.append('\t\t\t};')
lines.append('\t\t\tname = Debug;')
lines.append('\t\t};')

lines.append(f'\t\t{P["release_tgt"]} /* Release */ = {{')
lines.append('\t\t\tisa = XCBuildConfiguration;')
lines.append('\t\t\tbuildSettings = {')
lines.append('\t\t\t\tCODE_SIGN_STYLE = Automatic;')
lines.append('\t\t\t\tCURRENT_PROJECT_VERSION = 1;')
lines.append('\t\t\t\tDEVELOPMENT_ASSET_PATHS = "";')
lines.append('\t\t\t\tENABLE_PREVIEWS = YES;')
lines.append('\t\t\t\tGENERATE_INFOPLIST_FILE = NO;')
lines.append('\t\t\t\tINFOPLIST_FILE = Info.plist;')
lines.append('\t\t\t\tINFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;')
lines.append('\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;')
lines.append('\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";')
lines.append('\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";')
lines.append('\t\t\t\tLD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/Frameworks");')
lines.append('\t\t\t\tMARKETING_VERSION = 1.0;')
lines.append('\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.sportcalendar.SportCalendar;')
lines.append('\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";')
lines.append('\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";')
lines.append('\t\t\t\tSUPPORTS_MACCATALYST = NO;')
lines.append('\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;')
lines.append('\t\t\t\tSWIFT_VERSION = 5.0;')
lines.append('\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";')
lines.append('\t\t\t};')
lines.append('\t\t\tname = Release;')
lines.append('\t\t};')
lines.append('/* End XCBuildConfiguration section */')

lines.append('\n/* Begin XCConfigurationList section */')
lines.append(f'\t\t{P["proj_config_list"]} /* Build configuration list for PBXProject "SportCalendar" */ = {{')
lines.append('\t\t\tisa = XCConfigurationList;')
lines.append('\t\t\tbuildConfigurations = (')
lines.append(f'\t\t\t\t{P["debug_proj"]} /* Debug */,')
lines.append(f'\t\t\t\t{P["release_proj"]} /* Release */,')
lines.append('\t\t\t);')
lines.append('\t\t\tdefaultConfigurationIsVisible = 0;')
lines.append('\t\t\tdefaultConfigurationName = Release;')
lines.append('\t\t};')
lines.append(f'\t\t{P["tgt_config_list"]} /* Build configuration list for PBXNativeTarget "SportCalendar" */ = {{')
lines.append('\t\t\tisa = XCConfigurationList;')
lines.append('\t\t\tbuildConfigurations = (')
lines.append(f'\t\t\t\t{P["debug_tgt"]} /* Debug */,')
lines.append(f'\t\t\t\t{P["release_tgt"]} /* Release */,')
lines.append('\t\t\t);')
lines.append('\t\t\tdefaultConfigurationIsVisible = 0;')
lines.append('\t\t\tdefaultConfigurationName = Release;')
lines.append('\t\t};')
lines.append('/* End XCConfigurationList section */')

lines.append('\t};')
lines.append(f'\trootObject = {P["project"]} /* Project object */;')
lines.append('}')

out = '\n'.join(lines)
import pathlib
path = pathlib.Path(__file__).resolve().parent / 'SportCalendar.xcodeproj' / 'project.pbxproj'
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(out, encoding='utf-8')
print('Wrote', path)
