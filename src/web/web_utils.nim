

import
  std/[
    locks,
    md5,
    os,
    strutils
  ]


import
  mummy, mummy/routers,
  mummy_utils


import
  ../globals

import
  ./web_password


type AuthenticatedHandler = proc(request: Request) {.gcsafe.}


var fakeSaltLock: Lock
{.gcsafe.}:
  var fakeSalt: string


initLock(fakeSaltLock)

proc getSalt(): string =
  withLock(fakeSaltLock):
    {.gcsafe.}:
      if fakeSalt.len == 0:
        fakeSalt = makeSalt()
      return fakeSalt


proc adminKeyRawGet*(): string =
  if not fileExists(defaultKeyPath / "admin.txt"):
    return ""
  return readFile(defaultKeyPath / "admin.txt").strip(chars = {'\n', ' '})


proc adminKeySet*(key: string) =
  let existKey = adminKeyRawGet()
  if existKey != "" and existKey != key:
    return
  writeFile(defaultKeyPath / "admin.txt", key)


proc adminKeyGet*(): string  =
  let key = adminKeyRawGet()
  if key.len == 0:
    return ""
  return getMD5(key & getSalt())


# proc accessCheck*() =
#   let pass = adminKeyGet()
#   if pass == "":
#     redirect("/login/create")
#   if request.cookies("pass") != pass:
#     redirect("/login")


proc toHandler*(wrapped: AuthenticatedHandler): RequestHandler =
  return proc(request: Request) =
    let pass = adminKeyGet()
    if pass == "":
      redirect("/login/create")
    elif request.cookies("pass") != pass:
      redirect("/login")
    else:
      wrapped(request)