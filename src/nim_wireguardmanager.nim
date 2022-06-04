import
  std/os,
  std/osproc,
  std/strutils


const
  defaultPort = "51820"
  interfaceName = "eth0" #enp88s0
  defaultDns = "8.8.8.8"
  peerAllowedIPs = "0.0.0.0/0"

const wg0conf = """# Main wg0 configuration file
[Interface]
PrivateKey = $1
Address = $2/24
ListenPort = $3
SaveConfig = false
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $4 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $4 -j MASQUERADE

"""

const peerToServerConf = """# Peer configuration for server
# $1
[Peer]
PublicKey = $2
PresharedKey = $3
AllowedIPs = $4
"""

const peerConf = """# Peer configuration file
[Interface]
PrivateKey = $1
Address = $2/32
DNS = $3

[Peer]
PublicKey = $4
PresharedKey = $5
Endpoint = $6:$7
AllowedIPs = $8

"""


proc keyPriv(filepath: string): string =
  let (s, _) = execCmdEx("wg genkey | sudo tee " & filepath & "_priv.key")
  return s

proc keyPub(filepath: string): string =
  let (s, _) = execCmdEx("cat " & filepath & "_priv.key | wg pubkey | sudo tee " & filepath & "_pub.key")
  return s

proc keyPreshared(): string =
  let (s, _) = execCmdEx("wg genpsk")
  return s


proc confCreateServer(path, keyPriv, ip, port, ethName: string): string =
  writeFile(path / "wg0.conf", wg0conf.format(keyPriv, ip, port, ethName))


proc confCreatePeerServer(serverConfPath, name, peerKeyPub, preSharedKey, peerAllowedIP: string): string =
  var f = open(serverConfPath, fmAppend)
  f.write(
      peerToServerConf.format(
          name,
          peerKeyPub,
          preSharedKey,
          peerAllowedIP
      )
    )


proc confCreatePeer(filename, keyPriv, peerIP, dns, serverKeyPub, preSharedKey, endpointIP, endpointPort, allowedIPs: string): string =
  writeFile(filename & "_peer.conf", peerConf.format(
      keyPriv,
      peerIP,
      dns,
      serverKeyPub,
      preSharedKey,
      endpointIP,
      endpointPort,
      allowedIPs
    ))


proc peerQR(filepath: string): string =
  let (s, _) = execCmdEx("qrencode -t ansiutf8 < " & filepath & "_peer.conf")
  return s


proc remember() =
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