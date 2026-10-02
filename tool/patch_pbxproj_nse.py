#!/usr/bin/env python3
"""Wire the SolarMediaNotification NSE + PrivacyInfo + entitlements into the
Runner pbxproj. Preserves the Rust 'Build Solar Math' phase and force_load
flags untouched. Follows pbxproj_nse_integration.mdc checklist.
"""
import sys

P = "ios/Runner.xcodeproj/project.pbxproj"
raw = open(P, "rb").read()
assert raw[:3] != b"\xef\xbb\xbf", "unexpected BOM"
txt = raw.decode("utf-8").replace("\r\n", "\n")

# --- UUIDs (24 hex, DD-prefixed, collision-free) ---
NSE_TARGET   = "DD0000000000000000000001"
NSE_APPEX    = "DD0000000000000000000002"
NSE_GROUP    = "DD0000000000000000000003"
NSE_SWIFT    = "DD0000000000000000000004"
NSE_PLIST    = "DD0000000000000000000005"
NSE_SWIFT_BF = "DD0000000000000000000006"
NSE_SOURCES  = "DD0000000000000000000007"
NSE_FRAMEW   = "DD0000000000000000000008"
NSE_RESRC    = "DD0000000000000000000009"
NSE_CFGLIST  = "DD000000000000000000000A"
NSE_CFG_DBG  = "DD000000000000000000000B"
NSE_CFG_REL  = "DD000000000000000000000C"
NSE_CFG_PRO  = "DD000000000000000000000D"
EMBED_PHASE  = "DD000000000000000000000E"
NSE_APPEX_BF = "DD000000000000000000000F"
NSE_DEP      = "DD0000000000000000000010"
NSE_PROXY    = "DD0000000000000000000011"
PRIV_REF     = "DD0000000000000000000020"
PRIV_BF      = "DD0000000000000000000021"
ENT_REF      = "DD0000000000000000000030"

RUNNER_TARGET = "97C146ED1CF9000F007C117D"
RUNNER_GROUP  = "97C146F01CF9000F007C117D"
MAIN_GROUP    = "97C146E51CF9000F007C117D"
PRODUCTS_GRP  = "97C146EF1CF9000F007C117D"
RUNNER_RESRC  = "97C146EC1CF9000F007C117D"
PROJECT_OBJ   = "97C146E61CF9000F007C117D"
RUNNER_CFGS   = ["97C147061CF9000F007C117D",  # Debug
                 "97C147071CF9000F007C117D",  # Release
                 "249021D4217E4FDB00AE95B9"]  # Profile

assert NSE_TARGET not in txt, "patch appears already applied"


def inject(anchor, addition, after=True):
    global txt
    idx = txt.find(anchor)
    assert idx != -1, f"anchor not found: {anchor[:60]!r}"
    if after:
        pos = idx + len(anchor)
        txt = txt[:pos] + addition + txt[pos:]
    else:
        txt = txt[:idx] + addition + txt[idx:]


# 1. PBXBuildFile
inject(
    "/* Begin PBXBuildFile section */\n",
    f"\t\t{NSE_SWIFT_BF} /* NotificationService.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {NSE_SWIFT} /* NotificationService.swift */; }};\n"
    f"\t\t{NSE_APPEX_BF} /* SolarMediaNotification.appex in Embed App Extensions */ = {{isa = PBXBuildFile; fileRef = {NSE_APPEX} /* SolarMediaNotification.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};\n"
    f"\t\t{PRIV_BF} /* PrivacyInfo.xcprivacy in Resources */ = {{isa = PBXBuildFile; fileRef = {PRIV_REF} /* PrivacyInfo.xcprivacy */; }};\n",
)

# 2. PBXContainerItemProxy
inject(
    "/* Begin PBXContainerItemProxy section */\n",
    f"\t\t{NSE_PROXY} /* PBXContainerItemProxy */ = {{\n"
    f"\t\t\tisa = PBXContainerItemProxy;\n"
    f"\t\t\tcontainerPortal = {PROJECT_OBJ} /* Project object */;\n"
    f"\t\t\tproxyType = 1;\n"
    f"\t\t\tremoteGlobalIDString = {NSE_TARGET};\n"
    f"\t\t\tremoteInfo = SolarMediaNotification;\n"
    f"\t\t}};\n",
)

# 3. PBXCopyFilesBuildPhase — Embed App Extensions
inject(
    "/* Begin PBXCopyFilesBuildPhase section */\n",
    f"\t\t{EMBED_PHASE} /* Embed App Extensions */ = {{\n"
    f"\t\t\tisa = PBXCopyFilesBuildPhase;\n"
    f"\t\t\tbuildActionMask = 2147483647;\n"
    f"\t\t\tdstPath = \"\";\n"
    f"\t\t\tdstSubfolderSpec = 13;\n"
    f"\t\t\tfiles = (\n"
    f"\t\t\t\t{NSE_APPEX_BF} /* SolarMediaNotification.appex in Embed App Extensions */,\n"
    f"\t\t\t);\n"
    f"\t\t\tname = \"Embed App Extensions\";\n"
    f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
    f"\t\t}};\n",
)

# 4. PBXFileReference
inject(
    "/* Begin PBXFileReference section */\n",
    f"\t\t{NSE_APPEX} /* SolarMediaNotification.appex */ = {{isa = PBXFileReference; explicitFileType = \"wrapper.app-extension\"; includeInIndex = 0; path = SolarMediaNotification.appex; sourceTree = BUILT_PRODUCTS_DIR; }};\n"
    f"\t\t{NSE_SWIFT} /* NotificationService.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = NotificationService.swift; sourceTree = \"<group>\"; }};\n"
    f"\t\t{NSE_PLIST} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};\n"
    f"\t\t{PRIV_REF} /* PrivacyInfo.xcprivacy */ = {{isa = PBXFileReference; lastKnownFileType = text.xml; path = PrivacyInfo.xcprivacy; sourceTree = \"<group>\"; }};\n"
    f"\t\t{ENT_REF} /* Runner.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = Runner.entitlements; sourceTree = \"<group>\"; }};\n",
)

# 5. PBXFrameworksBuildPhase — NSE empty frameworks
inject(
    "/* Begin PBXFrameworksBuildPhase section */\n",
    f"\t\t{NSE_FRAMEW} /* Frameworks */ = {{\n"
    f"\t\t\tisa = PBXFrameworksBuildPhase;\n"
    f"\t\t\tbuildActionMask = 2147483647;\n"
    f"\t\t\tfiles = (\n"
    f"\t\t\t);\n"
    f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
    f"\t\t}};\n",
)

# 6. PBXGroup — NSE group (inside the section)
inject(
    "/* Begin PBXGroup section */\n",
    f"\t\t{NSE_GROUP} /* SolarMediaNotification */ = {{\n"
    f"\t\t\tisa = PBXGroup;\n"
    f"\t\t\tchildren = (\n"
    f"\t\t\t\t{NSE_SWIFT} /* NotificationService.swift */,\n"
    f"\t\t\t\t{NSE_PLIST} /* Info.plist */,\n"
    f"\t\t\t);\n"
    f"\t\t\tpath = SolarMediaNotification;\n"
    f"\t\t\tsourceTree = \"<group>\";\n"
    f"\t\t}};\n",
)

# 6b. main group gets the NSE group as a child
inject(
    f"\t\t\t\t331C8082294A63A400263BE5 /* RunnerTests */,\n",
    f"\t\t\t\t{NSE_GROUP} /* SolarMediaNotification */,\n",
)

# 6c. Products group gets the appex
inject(
    f"\t\t\t\t331C8081294A63A400263BE5 /* RunnerTests.xctest */,\n",
    f"\t\t\t\t{NSE_APPEX} /* SolarMediaNotification.appex */,\n",
)

# 6d. Runner group gets PrivacyInfo + entitlements
inject(
    f"\t\t\t\t74858FAD1ED2DC5600515810 /* Runner-Bridging-Header.h */,\n",
    f"\t\t\t\t{PRIV_REF} /* PrivacyInfo.xcprivacy */,\n"
    f"\t\t\t\t{ENT_REF} /* Runner.entitlements */,\n",
)

# 7. PBXNativeTarget — add NSE target + wire Runner embed phase & dependency
inject(
    "/* Begin PBXNativeTarget section */\n",
    f"\t\t{NSE_TARGET} /* SolarMediaNotification */ = {{\n"
    f"\t\t\tisa = PBXNativeTarget;\n"
    f"\t\t\tbuildConfigurationList = {NSE_CFGLIST} /* Build configuration list for PBXNativeTarget \"SolarMediaNotification\" */;\n"
    f"\t\t\tbuildPhases = (\n"
    f"\t\t\t\t{NSE_SOURCES} /* Sources */,\n"
    f"\t\t\t\t{NSE_FRAMEW} /* Frameworks */,\n"
    f"\t\t\t\t{NSE_RESRC} /* Resources */,\n"
    f"\t\t\t);\n"
    f"\t\t\tbuildRules = (\n"
    f"\t\t\t);\n"
    f"\t\t\tdependencies = (\n"
    f"\t\t\t);\n"
    f"\t\t\tname = SolarMediaNotification;\n"
    f"\t\t\tproductName = SolarMediaNotification;\n"
    f"\t\t\tproductReference = {NSE_APPEX} /* SolarMediaNotification.appex */;\n"
    f"\t\t\tproductType = \"com.apple.product-type.app-extension\";\n"
    f"\t\t}};\n",
)

# Runner: add Embed App Extensions phase BEFORE Thin Binary. Placing it
# after Thin Binary creates a dependency cycle (ProcessInfoPlistFile ->
# ExtractAppIntentsMetadata -> copy appex -> Thin Binary -> Info.plist).
inject(
    "\t\t\t\t3B06AD1E1E4923F5004D2608 /* Thin Binary */,\n",
    f"\t\t\t\t{EMBED_PHASE} /* Embed App Extensions */,\n",
    after=False,
)

# Runner: add dependency on the NSE (so it builds first)
runner_block = txt[txt.find(f"{RUNNER_TARGET} /* Runner */ = {{"):]
dep_anchor = "\t\t\tdependencies = (\n"
# the first 'dependencies = (' after the Runner target header
r_idx = txt.find(f"{RUNNER_TARGET} /* Runner */ = {{")
d_idx = txt.find(dep_anchor, r_idx)
pos = d_idx + len(dep_anchor)
txt = (txt[:pos] +
       f"\t\t\t\t{NSE_DEP} /* PBXTargetDependency */,\n" +
       txt[pos:])

# 8. PBXProject — TargetAttributes + targets list
inject(
    "\t\t\t\tTargetAttributes = {\n",
    f"\t\t\t\t\t{NSE_TARGET} = {{\n"
    f"\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;\n"
    f"\t\t\t\t\t}};\n",
)
inject(
    f"\t\t\t\t331C8080294A63A400263BE5 /* RunnerTests */,\n",
    f"\t\t\t\t{NSE_TARGET} /* SolarMediaNotification */,\n",
)

# 9. PBXResourcesBuildPhase — NSE empty + PrivacyInfo into Runner Resources
inject(
    "/* Begin PBXResourcesBuildPhase section */\n",
    f"\t\t{NSE_RESRC} /* Resources */ = {{\n"
    f"\t\t\tisa = PBXResourcesBuildPhase;\n"
    f"\t\t\tbuildActionMask = 2147483647;\n"
    f"\t\t\tfiles = (\n"
    f"\t\t\t);\n"
    f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
    f"\t\t}};\n",
)
# PrivacyInfo into Runner's Resources phase (anchor on its LaunchScreen entry)
inject(
    "\t\t\t\t97C147011CF9000F007C117D /* LaunchScreen.storyboard in Resources */,\n",
    f"\t\t\t\t{PRIV_BF} /* PrivacyInfo.xcprivacy in Resources */,\n",
)

# 10. PBXSourcesBuildPhase — NSE sources
inject(
    "/* Begin PBXSourcesBuildPhase section */\n",
    f"\t\t{NSE_SOURCES} /* Sources */ = {{\n"
    f"\t\t\tisa = PBXSourcesBuildPhase;\n"
    f"\t\t\tbuildActionMask = 2147483647;\n"
    f"\t\t\tfiles = (\n"
    f"\t\t\t\t{NSE_SWIFT_BF} /* NotificationService.swift in Sources */,\n"
    f"\t\t\t);\n"
    f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
    f"\t\t}};\n",
)

# 11. PBXTargetDependency
inject(
    "/* Begin PBXTargetDependency section */\n",
    f"\t\t{NSE_DEP} /* PBXTargetDependency */ = {{\n"
    f"\t\t\tisa = PBXTargetDependency;\n"
    f"\t\t\ttarget = {NSE_TARGET} /* SolarMediaNotification */;\n"
    f"\t\t\ttargetProxy = {NSE_PROXY} /* PBXContainerItemProxy */;\n"
    f"\t\t}};\n",
)

# 12. XCBuildConfiguration — three NSE configs
common = (
    "\t\t\t\tCLANG_ENABLE_MODULES = YES;\n"
    "\t\t\t\tCODE_SIGN_STYLE = Automatic;\n"
    # Hardcoded: $(FLUTTER_BUILD_NUMBER/NAME) are NOT defined for the NSE
    # target (no Flutter xcconfig base) -> empty CFBundleVersion -> the
    # simulator rejects the appex ("bundleVersion must be set"). Keep these
    # in lockstep with pubspec version (1.0.0+1) and the Runner app.
    "\t\t\t\tCURRENT_PROJECT_VERSION = 1;\n"
    "\t\t\t\tDEVELOPMENT_TEAM = 48UP4UDWV7;\n"
    "\t\t\t\tGENERATE_INFOPLIST_FILE = YES;\n"
    "\t\t\t\tINFOPLIST_FILE = SolarMediaNotification/Info.plist;\n"
    "\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 15.0;\n"
    "\t\t\t\tMARKETING_VERSION = 1.0.0;\n"
    "\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.solargleam.gleamgame.SolarMediaNotification;\n"
    "\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";\n"
    "\t\t\t\tSKIP_INSTALL = YES;\n"
    "\t\t\t\tSWIFT_VERSION = 5.0;\n"
    "\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";\n"
)
nse_dbg = (
    f"\t\t{NSE_CFG_DBG} /* Debug */ = {{\n"
    f"\t\t\tisa = XCBuildConfiguration;\n"
    f"\t\t\tbuildSettings = {{\n" + common +
    "\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;\n"
    "\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";\n"
    f"\t\t\t}};\n"
    f"\t\t\tname = Debug;\n"
    f"\t\t}};\n"
)
nse_rel = (
    f"\t\t{NSE_CFG_REL} /* Release */ = {{\n"
    f"\t\t\tisa = XCBuildConfiguration;\n"
    f"\t\t\tbuildSettings = {{\n" + common +
    "\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;\n"
    "\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-O\";\n"
    f"\t\t\t}};\n"
    f"\t\t\tname = Release;\n"
    f"\t\t}};\n"
)
nse_pro = (
    f"\t\t{NSE_CFG_PRO} /* Profile */ = {{\n"
    f"\t\t\tisa = XCBuildConfiguration;\n"
    f"\t\t\tbuildSettings = {{\n" + common +
    "\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;\n"
    "\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-O\";\n"
    f"\t\t\t}};\n"
    f"\t\t\tname = Profile;\n"
    f"\t\t}};\n"
)
inject("/* Begin XCBuildConfiguration section */\n", nse_dbg + nse_rel + nse_pro)

# 13. XCConfigurationList — NSE list
inject(
    "/* Begin XCConfigurationList section */\n",
    f"\t\t{NSE_CFGLIST} /* Build configuration list for PBXNativeTarget \"SolarMediaNotification\" */ = {{\n"
    f"\t\t\tisa = XCConfigurationList;\n"
    f"\t\t\tbuildConfigurations = (\n"
    f"\t\t\t\t{NSE_CFG_DBG} /* Debug */,\n"
    f"\t\t\t\t{NSE_CFG_REL} /* Release */,\n"
    f"\t\t\t\t{NSE_CFG_PRO} /* Profile */,\n"
    f"\t\t\t);\n"
    f"\t\t\tdefaultConfigurationIsVisible = 0;\n"
    f"\t\t\tdefaultConfigurationName = Release;\n"
    f"\t\t}};\n",
)

# 14. CODE_SIGN_ENTITLEMENTS on the three Runner configs only
for uid in RUNNER_CFGS:
    marker = f"{uid} /* "
    i = txt.find(marker)
    assert i != -1, f"runner cfg {uid} not found"
    anchor = "\t\t\t\tDEVELOPMENT_TEAM = 48UP4UDWV7;\n"
    a = txt.find(anchor, i)
    assert a != -1 and a - i < 2000, f"team anchor missing in {uid}"
    pos = a + len(anchor)
    txt = (txt[:pos] +
           "\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n" +
           txt[pos:])

open(P, "wb").write(txt.encode("utf-8"))
print("pbxproj patched")
