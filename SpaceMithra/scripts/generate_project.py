#!/usr/bin/env python3
"""Generate the dependency-free Xcode project deterministically."""
from pathlib import Path
import hashlib
root = Path(__file__).resolve().parents[1]
def ident(s): return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
objects = []
def obj(key, value):
    uid = ident(key); objects.append(f'{uid} = {{ {value} }};'); return uid
def quote(s): return '"' + str(s).replace('\\','\\\\').replace('"','\\"') + '"'
source_refs, source_builds = [], []
for p in sorted((root/'SpaceMithra').rglob('*.swift')):
    path = str(p.relative_to(root))
    ref = obj(path, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {quote(path)}; sourceTree = SOURCE_ROOT;')
    source_refs.append(ref)
    source_builds.append(obj('build'+path, f'isa = PBXBuildFile; fileRef = {ref};'))
resource = obj('catalog', 'isa = PBXFileReference; lastKnownFileType = text.json.xcstrings; path = SpaceMithra/Localization/Localizable.xcstrings; sourceTree = SOURCE_ROOT;')
icon = obj('icon', 'isa = PBXFileReference; lastKnownFileType = image.icns; path = SpaceMithra/Resources/AppIcon.icns; sourceTree = SOURCE_ROOT;')
icon_build = obj('iconBuild', f'isa = PBXBuildFile; fileRef = {icon};')
resource_build = obj('catalogBuild', f'isa = PBXBuildFile; fileRef = {resource};')
product = obj('product', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = SpaceMithra.app; sourceTree = BUILT_PRODUCTS_DIR;')
uitest_ref = obj('uitestfile', 'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SpaceMithraUITests/SmokeTests.swift; sourceTree = SOURCE_ROOT;')
uitest_build = obj('uitestbuild', f'isa = PBXBuildFile; fileRef = {uitest_ref};')
uitest_product = obj('uitestproduct', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = SpaceMithraUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
products = obj('products', f'isa = PBXGroup; name = Products; children = ({product},{uitest_product}); sourceTree = "<group>";')
group = obj('group', f'isa = PBXGroup; children = ({",".join(source_refs+[resource,icon,uitest_ref,products])}); sourceTree = "<group>";')
sources = obj('sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(source_builds)}); runOnlyForDeploymentPostprocessing = 0;')
resources = obj('resources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({resource_build},{icon_build}); runOnlyForDeploymentPostprocessing = 0;')
frameworks = obj('frameworks','isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
ui_sources = obj('uisources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({uitest_build}); runOnlyForDeploymentPostprocessing = 0;')
common = 'MACOSX_DEPLOYMENT_TARGET = 13.0; SDKROOT = macosx; SWIFT_VERSION = 6.0; CLANG_ENABLE_MODULES = YES;'
project_configs, target_configs, ui_configs = [], [], []
for mode in ['Debug','Release']:
    debug = mode == 'Debug'
    project_configs.append(obj('project'+mode, f'isa = XCBuildConfiguration; name = {mode}; buildSettings = {{ {common} SWIFT_OPTIMIZATION_LEVEL = {quote("-Onone" if debug else "-O")}; DEBUG_INFORMATION_FORMAT = {quote("dwarf" if debug else "dwarf-with-dsym")}; }};'))
    target_configs.append(obj('target'+mode, f'isa = XCBuildConfiguration; name = {mode}; buildSettings = {{ PRODUCT_NAME = SpaceMithra; PRODUCT_BUNDLE_IDENTIFIER = org.spacemithra.app; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_KEY_CFBundleDisplayName = SpaceMithra; INFOPLIST_KEY_CFBundleIconFile = AppIcon; INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.utilities"; INFOPLIST_KEY_NSPrincipalClass = NSApplication; INFOPLIST_KEY_NSHumanReadableCopyright = "Copyright 2026 SpaceMithra contributors"; INFOPLIST_KEY_NSDesktopFolderUsageDescription = "Scan Desktop only when you select it."; INFOPLIST_KEY_NSDocumentsFolderUsageDescription = "Scan Documents only when you select it."; INFOPLIST_KEY_NSDownloadsFolderUsageDescription = "Scan Downloads only when you select it."; ENABLE_HARDENED_RUNTIME = YES; ENABLE_APP_SANDBOX = NO; CODE_SIGN_STYLE = Automatic; MARKETING_VERSION = 0.1.0; CURRENT_PROJECT_VERSION = 1; OTHER_LDFLAGS = "-lsqlite3"; SWIFT_EMIT_LOC_STRINGS = NO; }};'))
    ui_configs.append(obj('ui'+mode, f'isa = XCBuildConfiguration; name = {mode}; buildSettings = {{ PRODUCT_NAME = SpaceMithraUITests; PRODUCT_BUNDLE_IDENTIFIER = org.spacemithra.uitests; GENERATE_INFOPLIST_FILE = YES; TEST_TARGET_NAME = SpaceMithra; CODE_SIGN_STYLE = Automatic; }};'))
def config_list(name, configs): return obj(name, f'isa = XCConfigurationList; buildConfigurations = ({",".join(configs)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
pc = config_list('pc', project_configs); tc = config_list('tc', target_configs); uc = config_list('uc', ui_configs)
target = obj('target', f'isa = PBXNativeTarget; name = SpaceMithra; productName = SpaceMithra; productType = "com.apple.product-type.application"; productReference = {product}; buildConfigurationList = {tc}; buildPhases = ({sources},{frameworks},{resources}); buildRules = (); dependencies = ();')
ui_target = obj('uitarget', f'isa = PBXNativeTarget; name = SpaceMithraUITests; productName = SpaceMithraUITests; productType = "com.apple.product-type.bundle.ui-testing"; productReference = {uitest_product}; buildConfigurationList = {uc}; buildPhases = ({ui_sources}); buildRules = (); dependencies = ();')
project = obj('project', f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2700; }}; buildConfigurationList = {pc}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en,si,ta,hi,ar,fr,"zh-Hans"); mainGroup = {group}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({target},{ui_target});')
path = root/'SpaceMithra.xcodeproj'; path.mkdir(exist_ok=True)
(path/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+f'\n}}; rootObject = {project}; }}\n')
schemes = path/'xcshareddata/xcschemes'; schemes.mkdir(parents=True, exist_ok=True)
ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="SpaceMithra.app" BlueprintName="SpaceMithra" ReferencedContainer="container:SpaceMithra.xcodeproj"/>'
uiref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ui_target}" BuildableName="SpaceMithraUITests.xctest" BlueprintName="SpaceMithraUITests" ReferencedContainer="container:SpaceMithra.xcodeproj"/>'
(schemes/'SpaceMithra.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry><BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">{uiref}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{uiref}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
print(path)
