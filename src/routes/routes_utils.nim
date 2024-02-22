

import
  mummy,
  mummy_utils


import
  ../wg/wg_configs


proc routesWgAction*(request: Request) =
  if @"action" == "restart":
    wgRestart()
  elif @"action" == "stop":
    wgStop()
  elif @"action" == "start":
    wgStart()
  else:
    resp(Http400, "Action not found")

  redirect("/")