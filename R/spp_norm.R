#' Padroniza nomes científicos
#'
#' Normaliza nomes científicos removendo espaços extras,
#' convertendo todo o texto para minúsculo e aplicando
#' capitalização correta ao gênero.
#'
#' @param x Vetor de caracteres contendo nomes científicos.
#'
#' @return Um vetor de caracteres, do mesmo tamanho de `x`, com os nomes
#'   padronizados. Valores `NA` são mantidos como `NA`.
#'
#' @details
#' A função:
#' \itemize{
#'   \item Remove espaços no início e no fim;
#'   \item Substitui múltiplos espaços por um único espaço;
#'   \item Converte o texto para minúsculo;
#'   \item Capitaliza apenas a primeira letra do gênero.
#' }
#'
#' @examples
#' spp_norm("   ACTINOPUS   ANSELMOI ")
#' # "Actinopus anselmoi"
#'
#' spp_norm(c("LOXOSCELES intermedia", "phoneutria  nigriventer"))
#' # "Loxosceles intermedia" "Phoneutria nigriventer"
#'
#' @export
spp_norm <- function(x) {
  x <- as.character(x)
  vapply(x, .spp_norm_one, character(1), USE.NAMES = FALSE)
}

.spp_norm_one <- function(x) {
  if (is.na(x)) return(NA_character_)
  x <- trimws(x)
  x <- gsub("\\s+", " ", x)
  x <- tolower(x)
  if (!nzchar(x)) return("")
  paste0(toupper(substr(x, 1, 1)), substr(x, 2, nchar(x)))
}
