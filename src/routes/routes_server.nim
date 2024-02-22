
import
  std/[
    json,
    os,
    strutils,
    tables,
    times
  ]

import
  mummy,
  mummy_utils


import
  ../globals,
  ../wg/wg_configs,
  ../wg/wg_status


include
  "../nimf/utils.nimf",
  "../nimf/index_server.nimf"


proc mainServer*(request: Request) =
  resp htmlMain(htmlServer())


proc mainAddServer*(request: Request) =
  if fileExists(defaultWgInstancePath):
    resp "Server file already exists"
  resp htmlMain(htmlAddServer())


proc mainServerConfig*(request: Request) =
  let
    config = readFile(defaultWgInstancePath)
    keyPriv = keyGet("server_priv.key")
    keyPub  = keyGet("server_pub.key")
  resp(Http200, htmlMain(htmlServerConfig(@"ident", "Server", config, keyPriv, keyPub)))


proc mainServerEdit*(request: Request) =
  let newConfig = @"config"
  if newConfig == "":
    resp(Http400, "Config is empty")

  discard existsOrCreateDir(defaultBackupPath)

  moveFile(defaultWgInstancePath, defaultBackupPath / "server.conf." & $toInt(epochTime()))

  writeFile(defaultWgInstancePath, newConfig)

  wgRestart()

  redirect("/server")



#
# Add server
#
proc actionAddServer*(request: Request) =
  discard existsOrCreateDir(defaultKeyPath)
  let path = defaultKeyPath / "server"

  let keyPriv = keyPriv(path)
  let keyPub  = keyPub(path)

  confCreateServer(
    defaultWgInstancePath,
    keyPriv,
    @"address",
    @"port",
    @"device"
  )

  redirect("/server")

