

import
  std/[
    json,
    md5,
    os,
    osproc,
    strutils,
    tables
  ]

import
  ../globals

type
  WGglobal* = ref object
    wgstatus*: JsonNode
    wgserver*: JsonNode
    wgconfigs*: Table[string, JsonNode]
    wgconfignames*: Table[string, string]


proc wgStatusToJson*(data: string, serverName = "", singleConfig = false, singleConfigName = ""): JsonNode =

  result = parseJson("[]")

  if data == "":
    return result

  var dataSplit: seq[string]
  #
  # The files are different, and is our split
  #
  if serverName != "": # wg0.conf
    dataSplit = data.split("[")
  elif singleConfig:
    dataSplit = data.split("||")
  else:
    # wg show
    dataSplit = data.split("peer: ")
    echo dataSplit

  let isServerConf = (serverName != "")

  for itemNr in 0..dataSplit.high:
    let item = dataSplit[itemNr]
    if item == "":
      continue

    var obj = %* {}
    if singleConfig:
      obj["type"] = "config".newJString()

    let lineSplit = item.split("\n")

    for lineNr in 0..lineSplit.high:
      let line = lineSplit[lineNr].strip()

      if not singleConfig and (line.startsWith("interface") or line.startsWith("Interface]")):
        obj["type"] = "interface".newJString()
        if line.startsWith("interface"):
          obj["ident"] = (getMD5(line.split(": ")[1])).newJString()
        elif serverName != "":
          obj["ident"] = getMD5(serverName).newJString()
      elif isServerConf and lineNr == 0 and line.startsWith("Peer]"):
        obj["type"] = "peer".newJString()
      elif not singleConfig and not isServerConf and lineNr == 0:
        obj["type"] = "peer".newJString()
        obj["ident"] = getMD5(line).newJString()
        obj["peer"] = line.newJString()
      elif not singleConfig and line.startsWith("PublicKey"):
        obj["ident"] = getMD5(line.split(" = ")[1]).newJString()


      let lineSplit = line.split(":")
      if not singleConfig and lineSplit.len() == 2:
        obj[lineSplit[0].strip()] = lineSplit[1].strip().newJString()
      else:
        let lineEqSplit = line.split(" = ")
        if lineEqSplit.len() == 2:
          obj[lineEqSplit[0].strip()] = lineEqSplit[1].strip().newJString()

    if not obj.hasKey("type"):
      continue

    if singleConfig:
      obj["ident"] = getMD5(readFile(defaultKeyPath / (singleConfigName & "_pub.key")).replace("\n", "").strip(chars = {'\n',' '})).newJString()

    if not obj.hasKey("ident"):
      obj["ident"] = "2FUCK".newJString()
    result.add(obj)

  return result



proc wgStatus*(): string =
  let data = execCmdEx("wg show")
  if data.exitCode != 0:
    return "Error: " & data.output
  return data.output



proc wgData*(): WGglobal =
  let wgstatus = wgStatusToJson(wgStatus())
  let wgserver =
      if not fileExists(defaultWgInstancePath):
        %* []
      else:
        wgStatusToJson(readFile(defaultWgInstancePath), serverName = defaultWgInstance)

  var
    wgconfigs: Table[string, JsonNode]
    wgconfignames: Table[string, string]
    hasConfigs = false

  for file in walkDir(defaultConfigPath):
    if file.kind == pcFile and file.path.endsWith(".conf"):
      var tmp = wgStatusToJson(readFile(file.path), singleConfig = true, singleConfigName = splitFile(file.path).name)
      tmp[0]["file"] = (splitFile(file.path).name & ".conf").newJString()
      wgconfigs[tmp[0]["ident"].getStr()] = tmp[0]
      wgconfignames[tmp[0]["ident"].getStr()] = splitFile(file.path).name
      hasConfigs = true
  if not hasConfigs:
    wgconfigs[""] = %* {"type": "empty".newJString()}

  when defined(dev):
    echo "\n------------------- Wireguard Data"
    echo "Status =>"
    echo pretty(wgstatus)
    echo "Server =>"
    echo pretty(wgserver)
    echo "Configs =>"
    for k, v in wgconfigs:
      echo pretty(v)
    echo "Config Names =>"
    for k, v in wgconfignames:
      echo v & " ==> " & k

  return WGglobal(
      wgstatus: wgstatus,
      wgserver: wgserver,
      wgconfigs: wgconfigs,
      wgconfignames: wgconfignames
    )