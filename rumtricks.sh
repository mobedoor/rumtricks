#!/bin/bash
[ "$EUID" = "0" ] && exit
# All operations are relative to rumtricks' location
cd "$(dirname "$(realpath "$0")")" || exit 1

# Use default prefix if nothing is exported
[ -z "$WINEPREFIX" ] && export WINEPREFIX="$HOME/.wine"

# Use 64bit prefix if nothing is exported
[ -z "$WINEARCH" ] && export WINEARCH="win64"

# General
RUMTRICKS_LOGFILE="$WINEPREFIX/rumtricks.log"
BASE_URL="https://johncena141.eu.org:8141/johncena141/rumtricks/media/branch/main/archives"
DOWNLOAD_LOCATION="${XDG_CACHE_HOME:-$HOME/.cache}/rumtricks"; mkdir -p "$DOWNLOAD_LOCATION"

# Wine: don't complain about mono/gecko
export WINEDLLOVERRIDES="mscoree=d;mshtml=d"
export WINEDEBUG="-all"

# blame dxvk I guess?
wine() { "$WINE" $@; }; wine64() { "$WINE64" $@; }; wineboot() { "$WINEBOOT" $@; }
export -f wine wine64 wineboot

# Pre execution checks
pre-checks() {
    # Validate if zstd is installed
    if ! command -v zstd &>/dev/null; then
        echo "RMT-ERROR: Missing zstd package. zstd is not installed, please follow our requirements."
        exit 1
    fi
}

print-usage() {
    # Display Help
    echo "Usage: rumtricks.sh [OPTION] [COMMAND]"
    echo
    echo "Options:"
    echo "  -h, --help     Print this Help."
    echo "  -v, --verbose  Verbose mode."
    echo "  -u, --update   Update rumstricks.sh."
    echo "  -l, --list     List all available COMMANDs."
    echo "  -c, --cache    Download and cache all COMMANDs. if no COMMAND is specified, all will be cached."
}

print-commands() {
    echo "Available commands:"
    echo "cinepak        Cinepak Codec"
    echo "corefonts      Microsoft Core fonts"
    echo "directshow     Microsoft DirectShow runtime (amstream and quartz)"
    echo "directplay     Microsoft Directplay"
    echo "directx        Microsoft DirectX End-User Runtime (June 2010)"
    echo "dxvk           Vulkan-based translation layer for Direct3D 9/10/11"
    echo "dxvk-async     dxvk with async patches"
    echo "dxvk-custom    install any dxvk version (usage: ./rumtricks.sh dxvk-custom <<< \"0.54\")"
    echo "dotnet35       Microsoft .NET 3.5"
    echo "isolation        Isolating the prefix by removing symbolinks to \$HOME"
    echo "mf             Microsoft Media Foundation"
    echo "mono           Open-source and cross-platform implementation of the .NET Framework"
    echo "physx          Nvidia PhysX"
    echo "quicktime      Apple QuickTime"
    echo "vcrun2003      Microsoft Visual C++ 2003 Redistributable"
    echo "vcrun2005      Microsoft Visual C++ 2005 Redistributable"
    echo "vcrun2008      Microsoft Visual C++ 2008 Redistributable"
    echo "vcrun2010      Microsoft Visual C++ 2010 Redistributable"
    echo "vcrun2012      Microsoft Visual C++ 2012 Redistributable"
    echo "vcrun2013      Microsoft Visual C++ 2013 Redistributable"
    echo "vcrun2015      Microsoft Visual C++ 2015 Redistributable"
    echo "vcrun2017      Microsoft Visual C++ 2017 Redistributable"
    echo "vcrun2019      Microsoft Visual C++ 2019 Redistributable"
    echo "vkd3d          Direct3D 12 API on top of Vulkan"
    echo "win10          Set wineprefix version Windows to 10"
    echo "win81          Set wineprefix version Windows to 8.1"
    echo "win8           Set wineprefix version to Windows 8"
    echo "win7           Set wineprefix version to Windows 7"
    echo "win2008r2      Set wineprefix version to Windows 2008 R2"
    echo "win2008        Set wineprefix version to Windows 2008"
    echo "winvista       Set wineprefix version to Windows Vista"
    echo "win2003        Set wineprefix version to Windows 2003"
    echo "winxp          Set wineprefix version to Windows XP"
    echo "winme          Set wineprefix version to Windows ME (32bit only)"
    echo "win2k          Set wineprefix version to Windows 2000 (32bit only)"
    echo "win98          Set wineprefix version to Windows 98 (32bit only)"
    echo "winnt40        Set wineprefix version to Windows NT 4.0 (32bit only)"
    echo "win95          Set wineprefix version to Windows 95 (32bit only)"
    echo "winnt351       Set wineprefix version to Windows NT 3.51 (32bit only)"
    echo "win31          Set wineprefix version to Windows 3.1 (32bit only)"
    echo "win30          Set wineprefix version to Windows 3.0 (32bit only)"
    echo "win20          Set wineprefix version to Windows 2.0 (32bit only)"
    echo
}

download() {
    cd "$DOWNLOAD_LOCATION"
    command -v curl >/dev/null 2>&1 && curl --etag-save $DOWNLOAD_LOCATION/${1##*/}.etag --etag-compare $DOWNLOAD_LOCATION/${1##*/}.etag -LO "$1"
    cd "$OLDPWD"
    $only_cache && return
    cp "$DOWNLOAD_LOCATION/${1##*/}" "./"
}

regedit() {
    echo "RMT: Adding registry." && "$WINE" regedit "$1" &
    "$WINE64" regedit "$1" && "$WINESERVER" -w
}

extract() {
    echo "RMT: Extracting $1." && tar -xvf "$1" &>/dev/null
}

update() {
    echo "RMT: Applying ${FUNCNAME[1]}." && DISPLAY="" "$WINE" wineboot && "$WINESERVER" -w
}

applied() {
    echo "${FUNCNAME[1]}" >>"$RUMTRICKS_LOGFILE"
    echo "RMT: ${FUNCNAME[1]} applied."
}

check() {
    echo "$1  ${FUNCNAME[1]}.tar.zst" | sha256sum -c -
    [ $? -ne 1 ] || { echo "RMT-ERROR: Archive is corrupted, skipping." && rm "${FUNCNAME[1]}".tar.zst && return 1; }
}

status() {
    [[ ! -f "$RUMTRICKS_LOGFILE" || -z "$(awk "/^${FUNCNAME[1]}\$/ {print \$1}" "$RUMTRICKS_LOGFILE" 2>/dev/null)" ]] || { echo "RMT: ${FUNCNAME[1]} present." && return 1; }
}

regsvr32() {
    echo "RMT: Registering DLLs."
    for i in "$@"; do
        "$WINE" regsvr32 /s "$i" &
        "$WINE64" regsvr32 /s "$i"
    done
    "$WINESERVER" -w
}

wine-tkg() {
    [ -x "/bin/wine-tkg" ] && echo "RMT: Detected wine-tkg installed on system." && exit || echo "RMT: wine-tkg not detected on system."
    [ -x "$BINDIR/wine/bin/wine" ]  && echo "RMT: wine-tkg found on relative path." && exit || echo "RMT: wine-tkg not found on relative path, downloading."
    latest_release="$(curl -s https://api.github.com/repos/jc141x/wine-tkg-git/releases | jq '[.[] | select(.tag_name | test(".*[^LoL]$"))][0]')"
    download_url="$(echo "$latest_release" | awk -F '["]' '/"browser_download_url":/ && /tar.lzma/ {print $4}')"
    [ ! -f "wine-tkg.tar.lzma" ] && echo "RMT: wine-tkg.tar.lzma not found, downloading" && curl -L "$download_url" -o "wine-tkg.tar.lzma"
    [ ! -f "wine-tkg.tar.lzma" ] && echo "RMT: Download failed, check internet connection" && exit || echo "RMT: wine-tkg.tar.lzma downloaded"
    echo "RMT: Extracting wine-tkg" && tar -xvf "wine-tkg.tar.lzma" && mv "wine" "$BINDIR/wine"
}

wine-ge() {
    [ -x "/bin/wine-ge" ] && echo "RMT: Detected wine-ge installed on system." && exit || echo "RMT: wine-ge not detected on system."
    [ -x "$BINDIR/wine/bin/wine" ]  && echo "RMT: wine-ge found on relative path." && exit || echo "RMT: wine-ge not found on relative path, downloading."
    latest_release="$(curl -s https://api.github.com/repos/jc141x/wine-ge-custom/releases | jq '[.[] | select(.tag_name | test(".*[^LoL]$"))][0]')"
    download_url="$(echo "$latest_release" | awk -F '["]' '/"browser_download_url":/ && /tar.lzma/ {print $4}')"
    [ ! -f "wine-ge.tar.lzma" ] && echo "RMT: wine-ge.tar.lzma not found, downloading" && curl -L "$download_url" -o "wine-ge.tar.lzma"
    [ ! -f "wine-ge.tar.lzma" ] && echo "RMT: Download failed, check internet connection" && exit || echo "RMT: wine-ge.tar.lzma downloaded"
    echo "RMT: Extracting wine-ge" && tar -xvf "wine-ge.tar.lzma" && mv "wine" "$BINDIR/wine"
}

wine-tkg-nomingw() {
    [ -x "/bin/wine-tkg-nomingw" ] && echo "RMT: Detected wine-tkg-nomingw installed on system." && exit || echo "RMT: wine-tkg-nomingw not detected on system."
    [ -x "$BINDIR/wine/bin/wine" ]  && echo "RMT: wine-tkg-nomingw found on relative path." && exit || echo "RMT: wine-tkg-nomingw not found on relative path, downloading."
    latest_release="$(curl -s https://api.github.com/repos/jc141x/wine-tkg-nomingw/releases | jq '[.[] | select(.tag_name | test(".*[^LoL]$"))][0]')"
    download_url="$(echo "$latest_release" | awk -F '["]' '/"browser_download_url":/ && /tar.lzma/ {print $4}')"
    [ ! -f "wine-tkg-nomingw.tar.lzma" ] && echo "RMT: wine-tkg-nomingw.tar.lzma not found, downloading" && curl -L "$download_url" -o "wine-tkg-nomingw.tar.lzma"
    [ ! -f "wine-tkg-nomingw.tar.lzma" ] && echo "RMT: Download failed, check internet connection" && exit || echo "RMT: wine-tkg-nomingw.tar.lzma downloaded"
    echo "RMT: Extracting wine-tkg-nomingw" && tar -xvf "wine-tkg-nomingw.tar.lzma" && mv "wine" "$BINDIR/wine"
}

isolation() {
    $only_cache && return
    status || return
    update
    echo "RMT: Isolating prefix."
    cd "$WINEPREFIX/drive_c/users/${USER}" || exit
    for entry in *; do
        if [ -L "$entry" ] && [ -d "$entry" ]; then
            rm -f "$entry"
            mkdir -p "$entry"
        fi
    done
    rm -rf "$PWD/AppData/Roaming/Microsoft/Windows/Templates"
    mkdir -p "$PWD/AppData/Roaming/Microsoft/Windows/Templates"
    cd "$OLDPWD" || exit
    applied
}

directx() {
    status || return
    update
    [ ! -f "directx.tar.zst" ] && download "$BASE_URL/directx.tar.zst"
    $only_cache && return
    check 1e5c94ab1a4546ecc0281bc0c491178d77650cb2fc59460f03ebd5762af0d9f6 || return
    extract directx.tar.zst
    cp -r "$PWD"/directx/files/drive_c/windows/* "$WINEPREFIX/drive_c/windows/"
    regedit "$PWD"/directx/directx.reg
    _dlls=(
        xactengine2_0.dll xactengine2_1.dll xactengine2_2.dll xactengine2_3.dll xactengine2_4.dll xactengine2_5.dll xactengine2_6.dll xactengine2_7.dll xactengine2_8.dll xactengine2_9.dll xactengine2_10.dll # xactengine 2.x
        xactengine3_0.dll xactengine3_1.dll xactengine3_2.dll xactengine3_3.dll xactengine3_4.dll xactengine3_5.dll xactengine3_6.dll xactengine3_7.dll # xactengine 3.x
        xaudio2_0.dll xaudio2_1.dll xaudio2_2.dll xaudio2_3.dll xaudio2_4.dll xaudio2_5.dll xaudio2_6.dll xaudio2_7.dll # xaudio
    )
    regsvr32 ${_dlls[@]}
    rm -rf "$PWD"/directx
    applied
}

vcrun2003() {
    status || return
    update
    [ ! -f "vcrun2003.tar.zst" ] && download "$BASE_URL/vcrun2003.tar.zst"
    $only_cache && return
    check 6af8efa5829b489b70a72b0e13510e9a1e3f92e700fca6d27140483d15364244 || return
    extract vcrun2003.tar.zst
    cp -r "$PWD"/vcrun2003/files/drive_c/windows/* "$WINEPREFIX/drive_c/windows/"
    rm -rf "$PWD"/vcrun2003
    applied
}

vcrun2005() {
    status || return
    update
    [ ! -f "vcrun2005.tar.zst" ] && download "$BASE_URL/vcrun2005.tar.zst"
    $only_cache && return
    check 8d365bd38ddf341cec4f93b6a89027fe3d7065797e6062aa7b5b5cad7ef98099 || return
    extract vcrun2005.tar.zst
    cp -r "$PWD"/vcrun2005/files/drive_c/* "$WINEPREFIX/drive_c/"
    regedit "$PWD"/vcrun2005/vcrun2005.reg
    rm -rf "$PWD"/vcrun2005
    applied
}

vcrun2008() {
    status || return
    update
    [ ! -f "vcrun2008.tar.zst" ] && download "$BASE_URL/vcrun2008.tar.zst"
    $only_cache && return
    check 38cf9eb253324ef27ccf3b4e47e3281287acf9e1db48a19bc21c226d53cf8299 || return
    extract vcrun2008.tar.zst
    cp -r "$PWD"/vcrun2008/files/drive_c/* "$WINEPREFIX/drive_c/"
    regedit "$PWD"/vcrun2008/vcrun2008.reg
    rm -rf "$PWD"/vcrun2008
    applied
}

vcrun2010() {
    status || return
    update
    [ ! -f "vcrun2010.tar.zst" ] && download "$BASE_URL/vcrun2010.tar.zst"
    $only_cache && return
    check 5ba7ffed884cb25ef77f9f2470a85a31743f79ca1610b6d7cbeda31ce0ac3a35 || return
    extract vcrun2010.tar.zst
    cp -r "$PWD"/vcrun2010/files/drive_c/windows/* "$WINEPREFIX/drive_c/windows/"
    regedit "$PWD"/vcrun2010/vcrun2010.reg
    rm -rf "$PWD"/vcrun2010
    applied
}

vcrun2012() {
    status || return
    update
    [ ! -f "vcrun2012.tar.zst" ] && download "$BASE_URL/vcrun2012.tar.zst"
    $only_cache && return
    check 561716aaee554ab34eb79111c6a0e1aeff6394d0d534450a25c34d8e30609640 || return
    extract vcrun2012.tar.zst
    cp -r "$PWD"/vcrun2012/files/drive_c/windows/* "$WINEPREFIX/drive_c/windows/"
    regedit "$PWD"/vcrun2012/vcrun2012.reg
    rm -rf "$PWD"/vcrun2012
    applied
}

vcrun2013() {
    status || return
    update
    [ ! -f "vcrun2013.tar.zst" ] && download "$BASE_URL/vcrun2013.tar.zst"
    $only_cache && return
    check a9e4a474a433b03feaf1f520d3941d2a5946b07b7700fd3a22dff025b883997d || return
    extract vcrun2013.tar.zst
    cp -r "$PWD"/vcrun2013/files/drive_c/windows/* "$WINEPREFIX/drive_c/windows/"
    regedit "$PWD"/vcrun2013/vcrun2013.reg
    rm -rf "$PWD"/vcrun2013
    applied
}

vcrun2015() {
    status || return
    update
    [ ! -f "vcrun2015.tar.zst" ] && download "$BASE_URL/vcrun2015.tar.zst"
    $only_cache && return
    check 51c9364e4791d7dddcba8fc01cfba1e8dd25da40d8df86b9c012446b573ffd5a || return
    extract "vcrun2015.tar.zst"
    cp -r "$PWD"/vcrun2015/files/drive_c/windows/* "$WINEPREFIX/drive_c/windows/"
    regedit "$PWD"/vcrun2015/vcrun2015.reg
    rm -rf "$PWD"/vcrun2015
    applied
}

vcrun2017() {
    status || return
    update
    [ ! -f "vcrun2017.tar.zst" ] && download "$BASE_URL/vcrun2017.tar.zst"
    $only_cache && return
    check b76a4ac0a4231594816aad58f676ee68da12d0e7ef47e2fdd1ce1e4249ddc5df || return
    extract vcrun2017.tar.zst
    cp -r "$PWD"/vcrun2017/drive_c/windows/* "$WINEPREFIX/drive_c/windows/"
    regedit "$PWD"/vcrun2017/vcrun2017.reg
    rm -rf "$PWD"/vcrun2017
    applied
}

vcrun2019() {
    status || return
    update
    [ ! -f "vcrun2019.tar.zst" ] && download "$BASE_URL/vcrun2019.tar.zst"
    $only_cache && return
    check 0a04b662319a9344f42efc70168990b0085b9e42fea43568ab224b73b2ca08bb || return
    extract vcrun2019.tar.zst
    cp -r "$PWD"/vcrun2019/files/drive_c/windows/* "$WINEPREFIX/drive_c/windows/"
    regedit "$PWD"/vcrun2019/vcrun2019.reg
    rm -rf "$PWD"/vcrun2019
    applied
}

mf() {
    status || return
    update
    [ ! -f "mf.tar.zst" ] && download "$BASE_URL/mf.tar.zst"
    $only_cache && return
    check 42612d19396d791576de9e56ca30de5ae0cd5afd0ba2ac9d411347a2efe5114c || return
    extract "mf.tar.zst"
    cp -r "$PWD"/mf/files/drive_c/windows/* "$WINEPREFIX/drive_c/windows/"
    regedit "$PWD"/mf/mf.reg
    regsvr32 colorcnv.dll msmpeg2adec.dll msmpeg2vdec.dll
    rm -rf "$PWD"/mf
    applied
}

physx() {
    status || return
    update
    [ ! -f "physx.tar.zst" ] && download "$BASE_URL/physx.tar.zst"
    $only_cache && return
    check eb275e31687173f3accada30c0c8af6456977ac94b52a0fdd17cbbdd5d68f488 || return
    extract physx.tar.zst
    cp -r "$PWD"/physx/files/drive_c/* "$WINEPREFIX/drive_c/"
    regedit "$PWD"/physx/physx.reg
    rm -rf "$PWD"/physx
    applied
}

github_dxvk() {
    DL_URL="$(curl -s https://api.github.com/repos/jc141x/dxvk/releases/latest | awk -F '["]' '/"browser_download_url":/ {print $4}')"
    DXVK="$(basename "$DL_URL")"
    [ ! -f "$DXVK" ] && download "$DL_URL"
    $only_cache && return
    extract "$DXVK" || { rm "$DXVK" && echo "RMT-ERROR: Failed to extract dxvk, skipping." && return 1; }
    cd "${DXVK//.tar.gz/}" || exit
    DISPLAY="" ./setup_dxvk.sh install && "$WINESERVER" -w
    cd "$OLDPWD" || exit
    rm -rf "${DXVK//.tar.gz/}"
}

dxvk() {
    $only_cache && return
    DXVKVER="$(curl -s -m 5 https://api.github.com/repos/jc141x/dxvk/releases/latest | awk -F '["/]' '/"browser_download_url":/ {print $11}' | cut -c 2-)"
    SYSDXVK="$(command -v setup_dxvk 2>/dev/null)"
    dxvk() {
        update
        [ -n "$SYSDXVK" ] && echo "RMT: Using local dxvk." && DISPLAY="" "$SYSDXVK" install --symlink && "$WINESERVER" -w && applied
        [ -z "$SYSDXVK" ] && echo "RMT: Using dxvk from github." && github_dxvk && echo "$DXVKVER" >"$WINEPREFIX/.dxvk"
    }
    [[ ! -f "$WINEPREFIX/.dxvk" && -z "$(status)" ]] && dxvk
    [[ -f "$WINEPREFIX/.dxvk" && -n "$DXVKVER" && "$DXVKVER" != "$(awk '{print $1}' "$WINEPREFIX/.dxvk")" ]] && { rm -f dxvk-*.tar.gz || true; } && echo "updating dxvk" && dxvk
    echo "RMT: dxvk is up-to-date."
}

dxvk-async() {
    DXVKVER="$(curl -s -m 5 https://api.github.com/repos/Sporif/dxvk-async/releases/latest | awk -F '["/]' '/"browser_download_url":/ {print $11}')"
    dxvk-async() {
        update
        DL_URL="$(curl -s https://api.github.com/repos/Sporif/dxvk-async/releases/latest | awk -F '["]' '/"browser_download_url":/ {print $4}')"
        DXVK="$(basename "$DL_URL")"
        [ ! -f "$DXVK" ] && download "$DL_URL"
        $only_cache && return
        extract "$DXVK" || { rm "$DXVK" && echo "RMT-ERROR: Failed to extract dxvk, skipping." && return 1; }
        cd "${DXVK//.tar.gz/}" || exit
        chmod +x ./setup_dxvk.sh && DISPLAY="" ./setup_dxvk.sh install && "$WINESERVER" -w
        cd "$OLDPWD" || exit
        rm -rf "${DXVK//.tar.gz/}"
        applied
        echo "$DXVKVER" >"$WINEPREFIX/.dxvk-async"
    }
    [[ -z "$(status)" ]] && dxvk-async
    [[ -f "$WINEPREFIX/.dxvk-async" && -n "$DXVKVER" && "$DXVKVER" != "$(awk '{print $1}' "$WINEPREFIX/.dxvk-async")" ]] && { rm -f dxvk-async-*.tar.gz || true; } && echo "updating dxvk-async" && dxvk-async
    echo "RMT: dxvk-async is up-to-date."
}

dxvk-custom() {
    $only_cache && return
    status || return
    update
    read -r -p "What version do you want? (0.54, 1.8.1, etc.): " DXVKVER
    DL_URL="https://github.com/doitsujin/dxvk/releases/download/v$DXVKVER/dxvk-$DXVKVER.tar.gz"
    DXVK="$(basename "$DL_URL")"
    [ ! -f "$DXVK" ] && download "$DL_URL"
    extract "$DXVK" || { rm "$DXVK" && echo "ERROR: Failed to extract dxvk-custom, skipping." && return 1; }
    cd "${DXVK//.tar.gz/}" || exit
    [ -f setup_dxvk.sh ] && DISPLAY="" ./setup_dxvk.sh install && "$WINESERVER" -w
    [ ! -f setup_dxvk.sh ] && cd x32 && ./setup_dxvk.sh && "$WINESERVER" -w && cd ..
    [ ! -f setup_dxvk.sh ] && [ "$WINEARCH" = "win64" ] && cd x64 && ./setup_dxvk.sh && "$WINESERVER" -w && cd ..
    cd ..
    rm -rf "${DXVK//.tar.gz/}"
    applied
}

wmp11() {
    status || return
    mf
    update
    [ ! -f "wmp11.tar.zst" ] && download "$BASE_URL/wmp11.tar.zst"
    $only_cache && return
    check 7e68b15655c450a1912e0d5f1fc21c66ee2037d676da1949c6ee93a00d792a3c || return
    extract wmp11.tar.zst
    cp -r "$PWD"/wmp11/files/drive_c/* "$WINEPREFIX/drive_c/"
    regedit "$PWD"/wmp11/wmp11.reg
    regsvr32 dispex.dll jscript.dll scrobj.dll scrrun.dll vbscript.dll wshcon.dll wshext.dll
    rm -rf "$PWD"/wmp11
    applied
}

mono() {
    MONOVER="$(curl -s https://api.github.com/repos/madewokherd/wine-mono/releases/latest | awk -F '["]' '/"browser_download_url":/ {print $4}' | awk -F '[-]' '/.msi/ {print $6}')"
    mono() {
        update
        DL_URL="$(curl -s https://api.github.com/repos/madewokherd/wine-mono/releases/latest | awk -F '["]' '/"browser_download_url":/ {print $4}' | awk '/msi/ {print $0}')"
        MONO="$(basename "$DL_URL")"
        [ ! -f "$MONO" ] && download "$DL_URL"
        $only_cache && return
        remove-mono
        "$WINE" msiexec /i "$MONO"
        applied
        echo "$MONOVER" >"$WINEPREFIX/.mono"
    }
    [[ -z "$(awk '/mono/ {print $1}' "$RUMTRICKS_LOGFILE" 2>/dev/null)" ]] && mono
    [[ -f "$WINEPREFIX/.mono" && -n "$MONOVER" && "$MONOVER" != "$(awk '{print $1}' "$WINEPREFIX/.mono")" ]] && { rm -f wine-mono-*.msi || true; } && echo "RMT: Updating mono" && mono
    echo "RMT: Mono is up-to-date."
}

remove-mono() {
    $only_cache && return
    for i in $("$WINE" uninstaller --list | awk -F '[|]' '/Wine Mono/ {print $1}'); do "$WINE" uninstaller --remove "$i"; done
}

github_vkd3d() {
    DL_URL="$(curl -s https://api.github.com/repos/jc141x/vkd3d-proton/releases/latest | awk -F '["]' '/"browser_download_url":/ {print $4}')"
    VKD3D="$(basename "$DL_URL")"
    [ ! -f "$VKD3D" ] && download "$DL_URL"
    $only_cache && return
    extract "$VKD3D" || { rm "$VKD3D" && echo "RMT-ERROR: Failed to extract vkd3d, skipping." && return 1; }
    cd "${VKD3D//.tar.zst/}" || exit
    DISPLAY="" ./setup_vkd3d_proton.sh install && "$WINESERVER" -w
    cd "$OLDPWD" || exit
    rm -rf "${VKD3D//.tar.zst/}"
}

vkd3d() {
    $only_cache && return
    VKD3DVER="$(curl -s -m 5 https://api.github.com/jc141x/vkd3d-proton/releases/latest | awk -F '["/]' '/"browser_download_url":/ {print $11}' | cut -c 2-)"
    SYSVKD3D="$(command -v setup_vkd3d_proton)"
    vkd3d() {
        update
        [ -n "$SYSVKD3D" ] && echo "RMT: Using local vkd3d." && DISPLAY="" "$SYSVKD3D" install --symlink && "$WINESERVER" -w && applied
        [ -z "$SYSVKD3D" ] && echo "RMT: Using vkd3d from github." && github_vkd3d && echo "$VKD3DVER" >"$WINEPREFIX/.vkd3d"
    }
    [[ ! -f "$WINEPREFIX/.vkd3d" && -z "$(status)" ]] && vkd3d
    [[ -f "$WINEPREFIX/.vkd3d" && -n "$VKD3DVER" && "$VKD3DVER" != "$(awk '{print $1}' "$WINEPREFIX/.vkd3d")" ]] && { rm -f vkd3d-proton-*.tar.zst || true; } && echo "updating vkd3d" && vkd3d
    echo "RMT: vkd3d is up-to-date."
}

directshow() {
    status || return
    update
    [ ! -f "directshow.tar.zst" ] && download "$BASE_URL/directshow.tar.zst"
    $only_cache && return
    check 5fb584ca65c8f8fc6b4910210f355c002fa12dfd4186805ef6e7708e41595e32 || return
    extract directshow.tar.zst
    cp -r "$PWD"/directshow/files/drive_c/windows/* "$WINEPREFIX/drive_c/windows/"
    regedit "$PWD"/directshow/directshow.reg
    regsvr32 amstream.dll qasf.dll qcap.dll qdvd.dll qedit.dll quartz.dll
    rm -rf "$PWD"/directshow
    applied
}

cinepak() {
    status || return
    update
    [ ! -f "cinepak.tar.zst" ] && download "$BASE_URL/cinepak.tar.zst"
    $only_cache && return
    check fb1daa15378f8a70a90617044691e1c5318610939adc0e79ad365bdb31513a38 || return
    extract cinepak.tar.zst
    cp -r "$PWD"/cinepak/files/drive_c/windows/* "$WINEPREFIX/drive_c/windows/"
    regedit "$PWD"/cinepak/cinepak.reg
    rm -rf "$PWD"/cinepak
    applied
}

corefonts() {
    status || return
    update
    [ ! -f "corefonts.tar.zst" ] && download "$BASE_URL/corefonts.tar.zst"
    $only_cache && return
    check fb6a4fffaae3c5ae849c0bb5ebf1ed7649ea521fab171166c35f6068b87dc80f || return
    extract corefonts.tar.zst
    cp -r "$PWD"/corefonts/files/drive_c/windows/* "$WINEPREFIX/drive_c/windows/"
    regedit "$PWD"/corefonts/corefonts.reg
    rm -rf "$PWD"/corefonts
    applied
}

quicktime() {
    status || return
    update
    [ ! -f "quicktime.tar.zst" ] && download "$BASE_URL/quicktime.tar.zst"
    $only_cache && return
    check 5adc5d05c94339d17814cb1a831c994e2b14ba9fbda0339d2add19c856f483a6 || return
    extract quicktime.tar.zst
    cp -r "$PWD"/quicktime/files/drive_c/* "$WINEPREFIX/drive_c/"
    regedit "$PWD"/quicktime/quicktime.reg
    rm -rf "$PWD"/quicktime
    applied
}

directplay() {
    status || return
    update
    [ ! -f "directplay.tar.zst" ] && download "$BASE_URL/directplay.tar.zst"
    $only_cache && return
    check 8e4c467685011ac0818b99333061758f69cc5f0bd0680b83a507c8a6765c79fd || return
    extract directplay.tar.zst
    cp -r "$PWD"/directplay/files/drive_c/windows/syswow64/* "$WINEPREFIX/drive_c/windows/syswow64"
    regedit "$PWD"/directplay/directplay.reg
    regsvr32 dplayx.dll dpnet.dll dpnhpast.dll dpnhupnp.dll
    rm -rf "$PWD"/directplay
    applied
}

dotnet35() {
    status || return
    remove-mono
    update
    [ ! -f "dotnet35.tar.zst" ] && download "$BASE_URL/dotnet35.tar.zst"
    $only_cache && return
    check 146f567c0b4ee080600d2cd7343238058e28008fc0c7d80d968da8611e63563a || return
    extract dotnet35.tar.zst
    cp -r "$PWD"/dotnet35/files/drive_c/* "$WINEPREFIX/drive_c/"
    regedit "$PWD"/dotnet35/dotnet35.reg
    rm -rf "$PWD/dotnet35"
    applied
}

win10() {
    $only_cache && return
    status || return
    update
    "$WINE" winecfg -v win10
    applied
}

win81() {
    $only_cache && return
    status || return
    update
    "$WINE" winecfg -v win81
    applied
}

win8() {
    $only_cache && return
    status || return
    update
    "$WINE" winecfg -v win8
    applied
}

win2008r2() {
    $only_cache && return
    status || return
    update
    "$WINE" winecfg -v win2008r2
    applied
}

win2008() {
    $only_cache && return
    status || return
    update
    "$WINE" winecfg -v win2008
    applied
}

win7() {
    $only_cache && return
    status || return
    update
    "$WINE" winecfg -v win7
    applied
}

winvista() {
    $only_cache && return
    status || return
    update
    "$WINE" winecfg -v vista
    applied
}

win2003() {
    $only_cache && return
    status || return
    update
    "$WINE" winecfg -v win2003
    applied
}

winxp() {
    $only_cache && return
    status || return
    update
    [ "$WINEARCH" = "win64" ] && "$WINE" winecfg -v winxp64
    [ "$WINEARCH" = "win32" ] && "$WINE" winecfg -v winxp
    applied
}

win2k() {
    $only_cache && return
    status || return
    update
    "$WINE" winecfg -v win2k
    applied
}

winme() {
    $only_cache && return
    status || return
    update
    "$WINE" winecfg -v winme
    applied
}

win98() {
    $only_cache && return
    status || return
    update
    "$WINE" winecfg -v win98
    applied
}

win95() {
    $only_cache && return
    status || return
    update
    "$WINE" winecfg -v win95
    applied
}

win98() {
    $only_cache && return
    status || return
    update
    "$WINE" winecfg -v win98
    applied
}

winnt40() {
    $only_cache && return
    status || return
    update
    "$WINE" winecfg -v nt40
    applied
}

winnt351() {
    $only_cache && return
    status || return
    update
    "$WINE" winecfg -v nt351
    applied
}

win31() {
    $only_cache && return
    status || return
    update
    "$WINE" winecfg -v win31
    applied
}

win30() {
    $only_cache && return
    status || return
    update
    "$WINE" winecfg -v win30
    applied
}

win20() {
    $only_cache && return
    status || return
    update
    "$WINE" winecfg -v win20
    applied
}

all() {
    $only_cache || (echo "Only use all with --cache" && return)
    echo "Downloading all"
    for x in $(print-commands | tail -n +2 | grep -oE "^(\S+)\s")
    do
        $x
    done
}

## Main ##
pre-checks

# Transform long options to short ones
for arg in "$@"; do
    shift
    case "$arg" in
    "--help") set -- "$@" "-h" ;;
    "--list") set -- "$@" "-l" ;;
    "--update") set -- "$@" "-u" ;;
    "--verbose") set -- "$@" "-v" ;;
    "--cache") set -- "$@" "-c" ;;
    *) set -- "$@" "$arg" ;;
    esac
done

# Default values
verbose=false
only_cache=false

# Parsing paramater using getopts
OPTIND=1
while getopts "hvluc" opt; do
    case "$opt" in
    "h")
        print-usage
        exit 0
        ;;
    "l")
        print-commands
        exit 0
        ;;
    "u")
        update-self
        ;;
    "v") verbose=true ;;
    "c") only_cache=true ;;
    "?")
        print-usage >&2
        exit 1
        ;;
    esac
done
shift $(expr $OPTIND - 1) # remove options from positional parameters

for i in "$@"; do
    # Check if function exists
    if type "$i" &>/dev/null; then
        "$i"
    else
        echo "WARN: Command: '$i' does not exists. Try another command/option."
        echo
        print-usage
    fi
done

if [ $# -eq 0 ]; then
    $only_cache && all
fi