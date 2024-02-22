

import
  std/[
    json,
    os,
    strutils,
    tables,
    times
  ]


import
  mummy, mummy/routers,
  mummy_utils


import
  ./globals,
  ./wg/wg_configs,
  ./wg/wg_status


import
  ./routes/routes_api,
  ./routes/routes_login,
  ./routes/routes_peer,
  ./routes/routes_server,
  ./routes/routes_utils


import
  ./web/web_utils

#
# nimf
#
include
  nimf/[
    "utils.nimf",
    "index_status.nimf"
  ]




#
# Routes
#
var router: Router
router.get("/css/styles.css", proc(request: Request) = sendFile("src/public/styles.css"))

#
# Login
#
router.get("/login", routesLoginNow)
router.post("/login", routesLoginDo)

router.get("/login/create", routesLoginCreate)
router.post("/login/create", routesLoginCreateDo)

#
# Status
#
proc mainStatus(request: Request) =
  resp htmlMain(htmlStatus())

router.get("/", proc(request: Request) = redirect("/status"))
router.get("/status", mainStatus)

#
# Management routes
#
router.post("/status/@action", routesWgAction.toHandler())

#
# Server routes
#
router.get("/server", mainServer.toHandler())
router.get("/server/add", mainAddServer.toHandler())
router.post("/server/add", actionAddServer.toHandler())
router.get("/server/config", mainServerConfig.toHandler())
router.post("/server/edit", mainServerEdit.toHandler())

#
# Peer routes
#
router.get("/peer/add", mainAddPeer.toHandler())
router.post("/peer/add", actionAddPeer.toHandler())
router.get("/peer/qr", mainPeerQR.toHandler())
router.get("/peer/config", mainPeerConfig.toHandler())
router.get("/peer/delete", mainPeerDelete.toHandler())
router.post("/peer/delete", mainPeerDeleteDo.toHandler())
router.post("/peer/edit", mainPeerEdit.toHandler())

#
# Inline routes
#
router.get("/api/server", routesApiServer.toHandler())
router.get("/api/status", routesApiStatus.toHandler())


#[
sysctl -w net.ipv4.ip_forward=1
]#



#
# Serve
#
let server = newServer(router)
echo "Serving on http://localhost:8080"
server.serve(Port(8080))
