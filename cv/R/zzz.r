.onLoad <- function(libname, pkgname) {
  loadModule("cvm", T)
}

.onUnload <- function (libpath) {
  library.dynam.unload("CVMatcher", libpath)
}
