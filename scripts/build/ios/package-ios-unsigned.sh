#!/bin/bash
# CI variant of package-ios-zh.sh: assemble an UNSIGNED .ipa without game assets.
#
# Differences to package-ios-zh.sh:
#   - xcodebuild runs with code signing disabled (no Apple ID / team needed)
#   - no codesign / entitlements step at all — the IPA is signed later by the
#     user's sideloading tool (Sideloadly / AltStore), which re-signs everything
#   - game data is NOT bundled (injected into the IPA afterwards); fonts and
#     config files ARE staged into GameData/ so the injection only adds .big files
#   - output: build/ios-package/GeneralsXZH-unsigned.ipa
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build/ios-vulkan"
IOS_DIR="${PROJECT_ROOT}/ios"
DERIVED="${IOS_DIR}/build"
OUT_DIR="${PROJECT_ROOT}/build/ios-package"
APP_NAME="GeneralsXZH"

GAME_BIN="${BUILD_DIR}/GeneralsMD/GeneralsXZH.app/GeneralsXZH"
DXVK_BUILD="${BUILD_DIR}/_deps/dxvk-build-macos"

if [[ ! -f "${GAME_BIN}" ]]; then
    echo "ERROR: engine binary not found at ${GAME_BIN} — build the ios-vulkan preset first."
    exit 1
fi

echo "==> Generating Xcode project (xcodegen)"
(cd "${IOS_DIR}" && xcodegen generate --quiet)

echo "==> Building provisioning shell app (unsigned)"
xcodebuild -project "${IOS_DIR}/${APP_NAME}.xcodeproj" \
    -scheme "${APP_NAME}" -configuration Release \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "${DERIVED}" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    DEVELOPMENT_TEAM="" \
    build | tail -3

SHELL_APP="${DERIVED}/Build/Products/Release-iphoneos/${APP_NAME}.app"
if [[ ! -d "${SHELL_APP}" ]]; then
    echo "ERROR: shell app not produced at ${SHELL_APP}"
    exit 1
fi

echo "==> Assembling final app"
rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}"
cp -R "${SHELL_APP}" "${OUT_DIR}/"
APP="${OUT_DIR}/${APP_NAME}.app"

# Replace stub executable with the engine
cp "${GAME_BIN}" "${APP}/${APP_NAME}"

# Embed runtime dylibs
mkdir -p "${APP}/Frameworks"
for lib in \
    "${DXVK_BUILD}/src/d3d8/libdxvk_d3d8.0.dylib" \
    "${DXVK_BUILD}/src/d3d9/libdxvk_d3d9.0.dylib" \
    "${BUILD_DIR}/_deps/sdl3-build/libSDL3.0.dylib" \
    "${BUILD_DIR}/_deps/sdl3_image-build/libSDL3_image.0.dylib" \
    "${BUILD_DIR}/_deps/openal_soft-build/libopenal.1.24.2.dylib" \
    "${BUILD_DIR}/libgamespy.dylib"; do
    if [[ -f "${lib}" ]]; then
        cp "${lib}" "${APP}/Frameworks/"
        echo "    embedded $(basename "${lib}")"
    else
        case "$(basename "${lib}")" in
            libgamespy.dylib)
                echo "    (skip, optional: $(basename "${lib}"))" ;;
            *)
                echo "ERROR: required dylib not built: ${lib}"
                exit 1 ;;
        esac
    fi
done

# openal-soft's install name is libopenal.1.dylib; the embedded file must match it
if [[ -f "${APP}/Frameworks/libopenal.1.24.2.dylib" ]]; then
    mv "${APP}/Frameworks/libopenal.1.24.2.dylib" "${APP}/Frameworks/libopenal.1.dylib"
fi

# MoltenVK: DXVK dlopens @executable_path/Frameworks/MoltenVK.framework/MoltenVK.
MVK_FRAMEWORK="${GX_MOLTENVK:-${HOME}/GeneralsX/MoltenVK/MoltenVK/MoltenVK/dynamic/MoltenVK.xcframework/ios-arm64/MoltenVK.framework}"
if [[ -d "${MVK_FRAMEWORK}" ]]; then
    cp -R "${MVK_FRAMEWORK}" "${APP}/Frameworks/"
    echo "    embedded MoltenVK.framework"
else
    echo "ERROR: MoltenVK.framework not found at ${MVK_FRAMEWORK}"
    echo "  Run scripts/build/ios/fetch-moltenvk.sh first."
    exit 1
fi

# GameData skeleton: fonts + config only. The actual game .big files are
# injected into the IPA afterwards (Payload/GeneralsXZH.app/GameData/).
FONTS_SRC="${GX_FONTS:-${HOME}/GeneralsX/ios-staging/fonts}"
CONFIG_SRC="${GX_CONFIG:-${IOS_DIR}/config}"
mkdir -p "${APP}/GameData/fonts"
if [[ -d "${FONTS_SRC}" ]]; then
    cp "${FONTS_SRC}"/*.ttf "${APP}/GameData/fonts/"
else
    echo "ERROR: fonts not staged at ${FONTS_SRC} — run scripts/build/ios/stage-fonts.sh first."
    exit 1
fi
for cfg in dxvk.conf Options.ini; do
    if [[ ! -f "${CONFIG_SRC}/${cfg}" ]]; then
        echo "ERROR: ${CONFIG_SRC}/${cfg} missing (should ship with the repo in ios/config/)"
        exit 1
    fi
done
cp "${CONFIG_SRC}/dxvk.conf" "${APP}/GameData/dxvk.conf"
cp "${CONFIG_SRC}/Options.ini" "${APP}/GameData/DefaultOptions.ini"

# Loose icon PNGs alongside the compiled asset catalog (see package-ios-zh.sh)
ICON_SRC="${IOS_DIR}/Stub/Assets.xcassets/AppIcon.appiconset/icon.png"
if [[ -f "${ICON_SRC}" ]]; then
    sips -z 120 120 "${ICON_SRC}" --out "${APP}/AppIcon60x60@2x.png"  >/dev/null
    sips -z 152 152 "${ICON_SRC}" --out "${APP}/AppIcon76x76@2x.png"  >/dev/null
    sips -z 167 167 "${ICON_SRC}" --out "${APP}/AppIcon83.5x83.5@2x.png" >/dev/null
    echo "    icon PNG fallbacks added"
fi

# Point the executable's rpath at the embedded frameworks
install_name_tool -add_rpath "@executable_path/Frameworks" "${APP}/${APP_NAME}" 2>/dev/null || true

echo "==> Packaging unsigned IPA"
cd "${OUT_DIR}"
rm -rf Payload
mkdir Payload
cp -R "${APP_NAME}.app" Payload/
zip -qry "${APP_NAME}-unsigned.ipa" Payload
du -sh "${APP_NAME}-unsigned.ipa"
echo "==> IPA ready: ${OUT_DIR}/${APP_NAME}-unsigned.ipa"
