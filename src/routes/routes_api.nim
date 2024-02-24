

import
  mummy,
  mummy_utils


import
  ../wg/wg_data


proc routesApiServer*(request: Request) =
  let wg = wgData()
  resp(Http200, ContentType.Json, (wg.wgserver))


proc routesApiStatus*(request: Request) =
  let wg = wgData()
  resp(Http200, ContentType.Json, (wg.wgstatus))