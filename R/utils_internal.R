`%||%` <- function(a, b) {
  if (!is.null(a) && length(a) > 0 && !is.na(a[1])) a else b
}

.lsid_normalize <- function(x) {
  x <- trimws(as.character(x))
  x[is.na(x)] <- ""
  if (!nzchar(x)) return(NA_character_)
  x
}

# O prefixo de versao invalida caches gravados por versoes anteriores do
# pacote, cujos resultados tinham outra estrutura.
.cache_key <- function(name, lsid = NA_character_) {
  if (is.null(lsid) || is.na(lsid) || !nzchar(lsid)) return(paste0("v2::NAME::", name))
  paste0("v2::NAME::", name, "||LSID::", lsid)
}

.paste_obs <- function(...) {
  x <- unlist(list(...))
  x <- x[!is.na(x) & nzchar(x)]
  if (length(x) == 0) return(NA_character_)
  paste(x, collapse = "; ")
}
