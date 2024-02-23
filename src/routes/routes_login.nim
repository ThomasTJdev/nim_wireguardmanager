


import
  mummy,
  mummy_utils


import
  ../web/web_utils


include
  "../nimf/utils.nimf",
  "../nimf/index_login.nimf"


proc routesLoginNow*(request: Request) =
  let pass = adminKeyGet()
  if pass == "":
    redirect("/login/create")
  if request.cookies("pass") == pass:
    redirect("/")

  resp htmlMain(htmlLogin())


proc routesLoginDo*(request: Request) =
  let pass = adminKeyGet()
  if pass == "":
    redirect("/login/create")
  elif @"pass" == adminKeyRawGet():
    var headers: HttpHeaders
    setCookie("pass", pass, secure = false)
    redirect("/")
  else:
    redirect("/login")


proc routesLoginCreate*(request: Request) =
  let pass = adminKeyGet()
  if pass != "":
    redirect("/login")
  resp htmlMain(htmlLoginCreate())


proc routesLoginCreateDo*(request: Request) =
  let pass = adminKeyGet()
  if pass != "" and request.cookies("pass") != pass:
    redirect("/login")
  let passUser = @"pass"
  if passUser == "":
    redirect("/login/create")
  adminKeySet(passUser)
  redirect("/login")