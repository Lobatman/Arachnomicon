`%||%` <- function(a, b) if (!is.null(a) && !is.na(a)) a else b

spp_norm <- function(x) {
  x <- trimws(x)
  x <- gsub("\\s+", " ", x)
  x <- tolower(x)

  parts <- strsplit(x, " ", fixed = TRUE)[[1]]
  if (length(parts) >= 1 && nzchar(parts[1])) {
    parts[1] <- paste0(toupper(substr(parts[1], 1, 1)), substr(parts[1], 2, nchar(parts[1])))
  }

  if (length(parts) > 1) {
    parts[-1] <- tolower(parts[-1])
  }

  paste(parts, collapse = " ")
}

.lsid_normalize <- function(x) {
  x <- trimws(as.character(x))
  x[is.na(x)] <- ""
  if (!nzchar(x)) return(NA_character_)
  x
}

.cache_key <- function(name, lsid = NA_character_) {
  if (is.null(lsid) || is.na(lsid) || !nzchar(lsid)) return(paste0("NAME::", name))
  paste0("NAME::", name, "||LSID::", lsid)
}
