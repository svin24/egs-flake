# epic-games-launcher

Nix flake wrapping the official Epic Games Launcher Linux AppImage.

Upstream ships a GTK 3 / WebKitGTK AppImage. This flake extracts it, runs it
inside an FHS environment, and installs a desktop entry plus icons.

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

The launcher is unfree. Enable `nixpkgs.config.allowUnfree`.

## Update

The installer URL always points at the current AppImage. When Epic ships a new
build, `nix build` will fail the hash check. Prefetch the new file, put the SRI
hash in `pkgs/epic-games-launcher.nix`, and bump `version` to match the CDN
path (`…/Builds/EGLv2/<version>/Linux/…`).

```bash
nix-prefetch-url --name EpicGamesLauncher-x86_64.AppImage \
  https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncher-x86_64.AppImage
nix hash convert --hash-algo sha256 --to sri <base32>
```
