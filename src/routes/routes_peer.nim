
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
  ../wg/wg_data,
  ../wg/wg_configs,
  ../wg/wg_status


import
  QRgen


include
  "../nimf/utils.nimf",
  "../nimf/index_peer.nimf"


#
# Peer management
#
proc mainAddPeer*(request: Request) =
  resp htmlMain(htmlAddPeer())


proc mainPeerDelete*(request: Request) =
  if @"ident" == "":
    resp(Http400, "Ident is empty")

  let wg = wgData()
  resp htmlMain(htmlDeletePeer(@"ident", wg.wgconfignames[@"ident"]))


proc mainPeerDeleteDo*(request: Request) =
  let wg = wgData()
  if wg.wgconfignames.hasKey(@"ident"):
    confDeletePeer(@"ident", wg.wgconfignames[@"ident"])
    redirect("/server")
  else:
    resp(Http400, "Ident not found")


proc mainPeerQR*(request: Request) =
  let ident = @"ident"
  if ident == "":
    resp(Http400, "Ident is empty")

  let wg = wgData()

  for k, v in wg.wgconfignames:
    if k == ident:
      let myQR = newQR(readFile(defaultConfigPath / v & ".conf"))
      if @"raw" == "true":
        resp(myQR.printSVG())
      else:
        resp(htmlMain("<h2 style=\"width: 300px;text-align:center;\">" & v & "</h2><div style=\"width: 300px;height: 300px;\">" & myQR.printSVG() & "</div>"))

  resp(Http400, "Ident not found")


proc mainPeerConfig*(request: Request) =
  let ident = @"ident"
  if ident == "":
    resp(Http400, "Ident is empty")

  let wg = wgData()

  var
    fileName: string
    config: string
    keyPriv, keyPub: string

  for k, v in wg.wgconfignames:
    if k == ident:
      config = (readFile(defaultConfigPath / v & ".conf"))
      fileName = v

  try:
    keyPriv = keyGet(fileName & "_priv.key")
    keyPub  = keyGet(fileName & "_pub.key")
  except:
    keyPriv = "<file_not_found>"
    keyPub = "<file_not_found>"

  if @"raw" == "true":
    resp(Http200, %* {
      "keys": {
        "priv": keyPriv,
        "pub": keyPub
      },
      "config": config
    })
  else:
    resp(Http200, htmlMain(htmlPeerConfig(ident, fileName, config, keyPriv, keyPub)))


proc mainPeerEdit*(request: Request) =
  let ident = @"ident"
  if ident == "":
    resp(Http400, "Ident is empty")

  let wg = wgData()

  if not wg.wgconfignames.hasKey(ident):
    resp(Http400, "Ident not found")

  let newConfig = @"config"
  if newConfig == "":
    resp(Http400, "Config is empty")

  discard existsOrCreateDir(defaultBackupPath)

  moveFile(defaultConfigPath / wg.wgconfignames[ident] & ".conf", defaultBackupPath / wg.wgconfignames[ident] & ".conf." & $toInt(epochTime()))

  writeFile(defaultConfigPath / wg.wgconfignames[ident] & ".conf", newConfig)

  wgRestart()

  redirect("/server")


#
# Add peer
#
proc actionAddPeer*(request: Request) =
  discard existsOrCreateDir(defaultConfigPath)
  let name = @"name".replace(" ", "_")
  if name == "":
    resp(Http400, "Name is empty")

  let pathKeys = defaultKeyPath / name & "_peer"
  let path     = defaultConfigPath

  let keyPriv = keyPriv(pathKeys)
  let keyPub  = keyPub(pathKeys)
  let keyPreshared = keyPreshared()

  let serverKeyPub = keyGet("server_pub.key")

  #
  # Create config
  #
  let configPath = confCreatePeer(
    path, name, keyPriv, @"address", @"dns",
    serverKeyPub, keyPreshared,
    @"endpointAddress", @"endpointPort", @"allowedIPs"
  )

  #
  # Parse config file
  #
  let configJson = wgStatusToJson(readFile(configPath), singleConfig = true, singleConfigName = name & "_peer")

  #
  # Add to server
  #
  confCreatePeerServer(
    defaultWgInstancePath,
    keyPub,
    keyPreshared,
    configJson[0]["Address"].getStr()
  )

  redirect("/server")


