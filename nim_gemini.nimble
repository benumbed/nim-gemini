# Package

version       = "0.1.0"
author        = "Benumbed"
description   = "Gemini client/server utilities written in Nim"
license       = "BSD-3-Clause"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["nim_gemini"]



# Dependencies

requires "nim >= 1.2.0"
requires "chronicles"