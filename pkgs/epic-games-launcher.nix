{
  lib,
  fetchurl,
  appimageTools,
}:

let
  pname = "epic-games-launcher";
  # Version encoded in the AppImage CDN redirect target
  # (…/Builds/EGLv2/<version>/Linux/EpicGamesLauncher-x86_64.AppImage).
  version = "0.95.1";

  src = fetchurl {
    name = "EpicGamesLauncher-x86_64.AppImage";
    url = "https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncher-x86_64.AppImage";
    hash = "sha256-wp0ccwRNhmJxkTcWUhTpaWtp/QJB90JrHjHSXVp2mW8=";
  };

  appimageContents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraPkgs =
    pkgs: with pkgs; [
      webkitgtk_4_1
      glib-networking
      libsoup_3
      libnotify
      libappindicator-gtk3
      libayatana-appindicator
      dconf
    ];

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
