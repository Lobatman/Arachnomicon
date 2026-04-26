#' Get Spider Family
#'
#' Returns the taxonomic family of a spider species.
#'
#' @param especie Species name.
#' @param lsid Optional LSID.
#' @return Character with family name.
#' @export
spider_family <- function(especie, lsid = NA_character_) {
  name <- spp_norm(as.character(especie)[1])
  if (!nzchar(name)) return(NA_character_)
  lsid <- .lsid_normalize(lsid[1])
  resolvido <- .resolve_nome_aranha(name, lsid_input = lsid)
  as.character(resolvido$family %||% NA_character_)
}
