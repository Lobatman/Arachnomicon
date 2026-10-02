#' Obtém a família taxonômica de uma espécie de aranha
#'
#' Consulta o World Spider Catalog (via `arakno`) e, quando necessário, o GBIF
#' (via `rgbif`) para obter a família de uma espécie. Para sinônimos, retorna a
#' família do nome aceito.
#'
#' @param especie Nome da espécie (ex.: `"Actinopus anselmoi"`). Apenas o
#'   primeiro elemento é usado.
#' @param lsid LSID opcional da espécie. Apenas o primeiro elemento é usado.
#'
#' @return Nome da família ou `NA_character_` quando não encontrado.
#'
#' @examples
#' \dontrun{
#' spider_family("Phoneutria nigriventer")
#' # "Ctenidae"
#' }
#'
#' @seealso \code{\link{correct_taxon}}
#' @export
spider_family <- function(especie, lsid = NA_character_) {
  name <- spp_norm(as.character(especie)[1])
  if (is.na(name) || !nzchar(name)) return(NA_character_)
  lsid <- .lsid_normalize(lsid[1])
  resolvido <- .resolve_nome_aranha(name, lsid_input = lsid)
  as.character(resolvido$family %||% NA_character_)
}
