#' Obtém a família taxonômica de uma espécie de aranha.
#'
#' @param especie name da espécie (ex: "Actinopus anselmoi").
#' @return name da família ou `NA_character_` quando não encontrado.
#' @export
spider_family <- function(especie, lsid = NA_character_) {
  name <- spp_norm(as.character(especie)[1])
  if (!nzchar(name)) return(NA_character_)
  lsid <- .lsid_normalize(lsid[1])
  resolvido <- .resolve_nome_aranha(name, lsid_input = lsid)
  as.character(resolvido$family %||% NA_character_)
}
