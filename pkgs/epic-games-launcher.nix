{
  lib,
  fetchurl,
  appimageTools,
  steam,
  glib-networking,
}:

let
  pname = "epic-games-launcher";
  # Version encoded in the AppImage CDN redirect target
  # (…/Builds/EGLv2/<version>/Linux/EpicGamesLauncher-x86_64.AppImage).
  version = "0.106.0+g0cb1183";

  src = fetchurl {
    name = "EpicGamesLauncher-x86_64.AppImage";
    url = "https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncher-x86_64.AppImage";
    hash = "sha256-QVwiWRVC6+ZOLoji5wXO5XabobLI1TTezuYu75jRwkg=";
  };

  appimageContents = appimageTools.extract { inherit pname version src; };
in
steam.buildRuntimeEnv {
  inherit pname version;

  # The launcher downloads GE-Proton and execs its `proton` script
  # (`#!/usr/bin/env python3`). That needs the same multiarch FHS Steam
  # uses: python3, 32-bit glibc, /lib64/ld-linux, Vulkan, and libGL.
  extraPkgs =
    pkgs:
    appimageTools.defaultFhsEnvArgs.targetPkgs pkgs
    ++ (with pkgs; [
      appimageTools.appimage-exec
      python3
      webkitgtk_4_1
      glib-networking
      libsoup_3
      libnotify
      libappindicator-gtk3
      libayatana-appindicator
      dconf
    ]);

  extraLibraries = pkgs: appimageTools.defaultFhsEnvArgs.multiPkgs pkgs;

  extraProfile = ''
    export GIO_EXTRA_MODULES=${glib-networking}/lib/gio/modules
  '';

  runScript = "appimage-exec.sh -w ${appimageContents} --";

  # Proton prefixes and shader caches live under /tmp during first run.
  privateTmp = false;

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/usr/share/applications/epic-games-launcher.desktop \
      $out/share/applications/epic-games-launcher.desktop
    substituteInPlace $out/share/applications/epic-games-launcher.desktop \
      --replace-fail 'Exec=EpicGamesLauncher %u' 'Exec=epic-games-launcher %u'

    for size in 32x32 128x128; do
      install -Dm444 ${appimageContents}/usr/share/icons/hicolor/$size/apps/EpicGamesLauncher.png \
        $out/share/icons/hicolor/$size/apps/EpicGamesLauncher.png
    done
    install -Dm444 ${appimageContents}/usr/share/icons/hicolor/256x256@2/apps/EpicGamesLauncher.png \
      $out/share/icons/hicolor/256x256@2/apps/EpicGamesLauncher.png
    install -Dm444 ${appimageContents}/epic-games-launcher.png \
      $out/share/icons/hicolor/256x256/apps/EpicGamesLauncher.png
  '';

  meta = {
    description = "Official Epic Games Launcher for Linux";
    homepage = "https://store.epicgames.com/download";
    downloadPage = "https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncher-x86_64.AppImage";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "epic-games-launcher";
  };
}
