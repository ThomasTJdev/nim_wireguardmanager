
import
  std/[
    json,
    tables
  ]


type
  WGglobal* = ref object
    wgstatus*: JsonNode
    wgserver*: JsonNode
    wgconfigs*: Table[string, JsonNode]
    wgconfignames*: Table[string, string]
    wgconfigfiles*: Table[string, JsonNode]


const
  defaultPath* = "/etc/wireguard"
  defaultKeyPath* = defaultPath & "/keys"
  defaultConfigPath* = defaultPath & "/configs"
  defaultBackupPath* = defaultPath & "/backups"

  defaultWgInstance* = "wg0"
  defaultWgInstancePath* = defaultPath & "/" & defaultWgInstance & ".conf"

const
  defaultPort*    = "51820"
  interfaceName*  = "eth0"
  defaultDns*     = "8.8.8.8"
  defaultIpStart* = "10.6.0."
  peerAllowedIPs* = "0.0.0.0/0"