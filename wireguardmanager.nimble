# Package

version       = "0.1.3"
author        = "ThomasTJdev"
description   = "Cli manager for wireguard"
license       = "MIT"
srcDir        = "src"
bin           = @["wireguardmanager"]


# Dependencies

requires "nim >= 1.6.0"
requires "mummy >= 0.3.0"
requires "mummy_utils >= 0.1.0"
requires "qrgen == 3.1.0"
requires "https://github.com/ThomasTJdev/bcryptnim == 0.2.1"