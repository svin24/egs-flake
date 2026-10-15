# epic-games-launcher

Nix flake wrapping the official Epic Games Launcher Linux AppImage.

Upstream ships a GTK 3 / WebKitGTK AppImage. Windows titles are launched
through GE-Proton that the client downloads itself. This flake extracts the
AppImage and runs it in Steam's multiarch FHS environment (the same wrapper
Heroic uses), so Proton can find `python3`, 32-bit glibc, and the dynamic
linker.

## Run

```bash
nix run github:svin24/egs-flake
```

From this repo:

```bash
nix run
```

## Install

NixOS / Home Manager, with this flake as an input:

```nix
{
  inputs.egs-flake.url = "github:svin24/egs-flake";
}

# then, with allowUnfree:
environment.systemPackages = [
  inputs.egs-flake.packages.${pkgs.system}.epic-games-launcher
];
```

Or add the overlay:

```nix
nixpkgs.overlays = [ inputs.egs-flake.overlays.default ];
environment.systemPackages = [ pkgs.epic-games-launcher ];
```

The launcher is unfree. Enable `nixpkgs.config.allowUnfree`. The Steam FHS
wrapper also pulls in Steam's unfree runtime libraries.

## Update

The installer URL always points at the current AppImage. The version is the
`Builds/EGLv2/<version>/` segment of the CDN redirect.

`.github/workflows/update-appimage.yml` follows that redirect every 8 hours
(00:00, 08:00, and 16:00 UTC). GitHub may start the run later than the cron
time. When the version changes, the workflow downloads the AppImage, writes
the version and SRI hash into `pkgs/epic-games-launcher.nix`, and opens a
pull request from `appimage-update`. It does not push to the default branch.
A second run while that pull request is still open does not download the
AppImage again.

When Epic ships a new build before that pull request is merged, `nix build`
fails the hash check. Prefetch the new file, put the SRI hash in
`pkgs/epic-games-launcher.nix`, and bump `version` to the full CDN path
(`…/Builds/EGLv2/<version>/Linux/…`).

```bash
nix-prefetch-url --name EpicGamesLauncher-x86_64.AppImage \
  https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncher-x86_64.AppImage
nix hash convert --hash-algo sha256 --to sri <base32>
```
