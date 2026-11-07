{
  lib,
  fetchurl,
  stdenvNoCC,
  dpkg,
  steam,
  glib-networking,
}:

let
  pname = "epic-games-launcher";
  # Version encoded in the .deb CDN redirect target
  # (…/Builds/EGLv2/<version>/Linux/EpicGamesLauncher-x86_64.deb).
  version = "0.113.0+g2164614";

  src = fetchurl {
    name = "EpicGamesLauncher-x86_64.deb";
    url = "https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncher-x86_64.deb";
    hash = "sha256-iE3vjeJHvCeb6lcb5vXexsVIGslMwGr2K1d2JL5WwgE=";
  };

  # Native Linux launcher extracted from Epic's .deb. Kept unpatched so it
  # resolves libraries through the Steam multiarch FHS below (same approach
  # Heroic uses for Proton).
  unwrapped = stdenvNoCC.mkDerivation {
    pname = "${pname}-unwrapped";
    inherit version src;

    nativeBuildInputs = [ dpkg ];

    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;
    dontPatchELF = true;

    unpackPhase = ''
      runHook preUnpack
      dpkg-deb -x $src .
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -a usr/. $out/
      runHook postInstall
    '';

    meta = {
      mainProgram = "EpicGamesLauncher";
      platforms = [ "x86_64-linux" ];
    };
  };
in
steam.buildRuntimeEnv {
  inherit pname version;

  # The launcher downloads GE-Proton and execs its `proton` script
  # (`#!/usr/bin/env python3`). That needs the same multiarch FHS Steam
  # uses: python3, 32-bit glibc, /lib64/ld-linux, Vulkan, and libGL.
  extraPkgs =
    pkgs:
    with pkgs;
    [
      unwrapped
      python3
      webkitgtk_4_1
      glib-networking
      libsoup_3
      libnotify
      libappindicator-gtk3
      libayatana-appindicator
      dconf
      gtk3
      gdk-pixbuf
      cairo
      pango
      at-spi2-atk
      dbus
    ];

  extraProfile = ''
    export GIO_EXTRA_MODULES=${glib-networking}/lib/gio/modules
  '';

  runScript = "${unwrapped}/bin/EpicGamesLauncher";

  # Proton prefixes and shader caches live under /tmp during first run.
  privateTmp = false;

  extraInstallCommands = ''
    install -Dm444 ${unwrapped}/share/applications/epic-games-launcher.desktop \
      $out/share/applications/epic-games-launcher.desktop
    substituteInPlace $out/share/applications/epic-games-launcher.desktop \
      --replace-fail 'Exec=EpicGamesLauncher %u' 'Exec=epic-games-launcher %u'

    for size in 32x32 128x128; do
      install -Dm444 ${unwrapped}/share/icons/hicolor/$size/apps/EpicGamesLauncher.png \
        $out/share/icons/hicolor/$size/apps/EpicGamesLauncher.png
    done
    install -Dm444 ${unwrapped}/share/icons/hicolor/256x256@2/apps/EpicGamesLauncher.png \
      $out/share/icons/hicolor/256x256@2/apps/EpicGamesLauncher.png
  '';

  meta = {
    description = "Official Epic Games Launcher for Linux";
    homepage = "https://launcher.epicgames.com/";
    downloadPage = "https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncher-x86_64.deb";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "epic-games-launcher";
  };
}
