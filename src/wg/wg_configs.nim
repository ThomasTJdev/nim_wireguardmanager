

import
  std/[
    json,
    os,
    osproc,
    strutils,
    tables,
    times
  ]

import
  ../globals,
  ./wg_data



const wg0conf = """[Interface]
PrivateKey = $1
Address = $2
ListenPort = $3
SaveConfig = false
PreUp = sysctl -w net.ipv4.ip_forward=1
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $4 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $4 -j MASQUERADE"""

const peerToServerConf = """[Peer]
PublicKey = $1
PresharedKey = $2
AllowedIPs = $3"""

const peerConf = """[Interface]
PrivateKey = $1
Address = $2
DNS = $3

[Peer]
PublicKey = $4
PresharedKey = $5
Endpoint = $6:$7
AllowedIPs = $8"""


#
# Core
#
proc wgRestart*() =
  ## Restart WireGuard
  discard execCmdEx("systemctl restart wg-quick@wg0")

proc wgStop*() =
  ## Stop WireGuard
  discard execCmdEx("systemctl stop wg-quick@wg0")

proc wgStart*() =
  ## Start WireGuard
  discard execCmdEx("systemctl start wg-quick@wg0")


#
# General keys
#
proc keyGet*(filepath: string): string =
  ## Get a private key
  return readFile(defaultKeyPath / filepath).strip(chars = {'\n',' '})


proc keyPriv*(filepath: string): string =
  ## Generate a private key
  let (s, _) = execCmdEx("wg genkey | sudo tee " & filepath & "_priv.key")
  return s.replace("\n", "").strip(chars = {'\n',' '})


proc keyPub*(filepath: string): string =
  ## Generate a public key
  let (s, _) = execCmdEx("cat " & filepath & "_priv.key | wg pubkey | sudo tee " & filepath & "_pub.key")
  return s.replace("\n", "").strip(chars = {'\n',' '})


proc keyPreshared*(): string =
  ## Generate a pre-shared key
  let (s, _) = execCmdEx("wg genpsk")
  return s.replace("\n", "").strip(chars = {'\n',' '})


#
# Server
#
proc confCreateServer*(serverConfPath, keyPriv, ip, port, ethName: string) =
  ## Server: Creates a server configuration file
  writeFile(serverConfPath, wg0conf.format(keyPriv, ip, port, ethName))

  wgRestart()


proc confCreatePeerServer*(serverConfPath, peerKeyPub, preSharedKey, peerAllowedIP: string) =
  ## Server: Adds a peer to the server configuration file
  let server = readFile(serverConfPath)

  let peerData = peerToServerConf.format(
      peerKeyPub,
      preSharedKey,
      peerAllowedIP
    )

  writeFile(serverConfPath, server & "\n\n" & peerData)

  wgRestart()


#
# Peer
#
proc confCreatePeer*(
    path, filename, keyPriv, peerIP, dns,
    serverKeyPub, preSharedKey,
    endpointIP, endpointPort, allowedIPs: string
  ): string =
  ## Peer: Creates a peer configuration file
  let fullPath = path / filename & "_peer.conf"
  writeFile(fullPath, peerConf.format(
      keyPriv,
      peerIP,
      dns,
      serverKeyPub,
      preSharedKey,
      endpointIP,
      endpointPort,
      allowedIPs
    ))
  return fullPath


proc confActivatePeer*(peerIdent: string) =
  ## Peer: Deactivates a peer
  let wg = wgData()
  var
    peerIsPresent = false
  for item in wg.wgserver:
    if item["type"].getStr() == "interface":
      continue
    elif item["ident"].getStr() != peerIdent:
      peerIsPresent = true
      break

  if not peerIsPresent:
    return


  #
  # Add existing peer to server configuration
  #
  var
    newServerConf: string
    newPeerConf: string

  newServerConf = readFile(defaultWgInstancePath)

  if not wg.wgconfigs.hasKey(peerIdent):
    return

  newPeerConf.add("\n[Peer]\n")
  for k, v in pairs(wg.wgconfigs[peerIdent]):
    if k in ["PublicKey", "PresharedKey"]:
      newPeerConf.add(k & " = " & v.getStr() & "\n")
    elif k == "Address":
      newPeerConf.add("AllowedIPs = " & v.getStr() & "\n")


  #
  # Save new server configuration
  discard existsOrCreateDir(defaultBackupPath)
  moveFile(defaultWgInstancePath, defaultBackupPath / defaultWgInstance & ".conf." & $toInt(epochTime()))

  writeFile(defaultWgInstancePath, (newServerConf & newPeerConf).replace("\n\n\n\n", "\n\n"))

  wgRestart()


proc confDeactivatePeer*(peerIdent: string) =
  ## Peer: Deactivates a peer
  let wg = wgData()
  var newServerConf: string
  for item in wg.wgserver:
    #
    # Interface
    #
    # => Always add interface to configuration
    if item["type"].getStr() == "interface":
      newServerConf = "[Interface]\n"
      for k, v in pairs(item):
        if k notin ["type", "ident"]:
          newServerConf.add(k & " = " & v.getStr() & "\n")
    else:
      #
      # Peer
      #
      # => If not the peer to deactivate, add to server configuration
      if item["ident"].getStr() != peerIdent:
        newServerConf.add("\n[Peer]\n")
        for k, v in pairs(item):
          if k notin ["type", "ident"]:
            newServerConf.add(k & " = " & v.getStr() & "\n")

  #
  # Save new server configuration
  #
  discard existsOrCreateDir(defaultBackupPath)
  moveFile(defaultWgInstancePath, defaultBackupPath / defaultWgInstance & ".conf." & $toInt(epochTime()))

  writeFile(defaultWgInstancePath, newServerConf.replace("\n\n\n\n", "\n\n"))

  wgRestart()


proc confDeletePeer*(peerIdent, peerName: string) =
  ## Peer: Deletes a peer configuration file

  #
  # This removes it from the server block
  #
  confDeactivatePeer(peerIdent)

  #
  # Remove peer configuration
  #
  let
    confPath = defaultConfigPath / peerName & ".conf"
    keyPriv  = defaultKeyPath / peerName & "_priv.key"
    keyPub   = defaultKeyPath / peerName & "_pub.key"

  # discard tryRemoveFile(confPath)
  # discard tryRemoveFile(keyPriv)
  # discard tryRemoveFile(keyPub)
  moveFile(confPath, defaultBackupPath / peerName & ".conf." & $toInt(epochTime()))
  moveFile(keyPriv, defaultBackupPath / peerName & "_priv.key." & $toInt(epochTime()))
  moveFile(keyPub, defaultBackupPath / peerName & "_pub.key." & $toInt(epochTime()))

  wgRestart()


#
# Other
#
proc peerQR(filepath: string): string =
  ## Print QR to terminal
  let (s, _) = execCmdEx("qrencode -t ansiutf8 < " & filepath & "_peer.conf")
  return s


proc remember() =
  ## Remember
  echo """
$ nano /etc/sysctl.conf
# Remove comment
net.ipv4.ip_forward=1
# Reload
$ sysctl -p
$ systemctl enable wg-quick@wg0.service
$ systemctl restart wg-quick@wg0
$ wg
"""