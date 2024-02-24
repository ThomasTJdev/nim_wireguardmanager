

import
  std/[
    json,
    os,
    strutils,
    tables
  ]

import
  ../globals,
  ./wg_status



proc wgData*(): WGglobal =
  #
  # Current status
  #
  let wgstatus = wgStatusToJson(wgStatus())

  #
  # Server (interface) file
  #
  let wgserver =
      if not fileExists(defaultWgInstancePath):
        %* []
      else:
        wgStatusToJson(readFile(defaultWgInstancePath), serverName = defaultWgInstance)

  var
    wgconfigs: Table[string, JsonNode]
    wgconfignames: Table[string, string]
    wgconfigfiles: Table[string, JsonNode]
    hasConfigs = false

  #
  # Individual config files
  # - Requires config file and key files to have similar names
  #
  for file in walkDir(defaultConfigPath):
    if file.kind != pcFile or not file.path.endsWith(".conf"):
      continue

    var tmp = wgStatusToJson(
        readFile(file.path),
        singleConfig = true,
        singleConfigName = splitFile(file.path).name
      )

    if tmp.len() == 0 or not tmp[0].hasKey("ident"):
      echo "Config not created"
      continue
    tmp[0]["file"] = (splitFile(file.path).name & ".conf").newJString()
    wgconfigs[tmp[0]["ident"].getStr()] = tmp[0]
    wgconfignames[tmp[0]["ident"].getStr()] = splitFile(file.path).name
    hasConfigs = true

  if not hasConfigs:
    wgconfigs[""] = %* {"type": "empty".newJString()}

  wgconfigfiles = wgFileValidation()

  #
  # Print dev
  #
  when defined(dev):
    echo "\n------------------- Wireguard Data"
    echo ""
    echo "Status =>"
    echo pretty(wgstatus)
    echo ""
    echo "Server =>"
    echo pretty(wgserver)
    echo ""
    echo "Configs =>"
    for k, v in wgconfigs:
      echo pretty(v)
    echo ""
    echo "Config Names =>"
    for k, v in wgconfignames:
      echo v & " ==> " & k
    echo ""
    echo "Config files =>"
    for k, v in wgconfigfiles:
      echo k & " ==> " & pretty(v)


  return WGglobal(
      wgstatus: wgstatus,
      wgserver: wgserver,
      wgconfigs: wgconfigs,
      wgconfignames: wgconfignames,
      wgconfigfiles: wgconfigfiles
    )