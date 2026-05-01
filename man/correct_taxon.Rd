#' Resolve taxonomic names of spiders
#'
#' Standardizes and updates spider species names using data from
#' the World Spider Catalogue (WSC) and GBIF.
#'
#' @param df A data.frame containing species names.
#' @param col_species Character. Column name with species names.
#' @param include_family Logical. If TRUE, returns family information.
#'
#' @return A data.frame with standardized taxonomy information.
#'
#' @details
#' The function performs:
#' \itemize{
#'   \item Name normalization
#'   \item Query to WSC
#'   \item Complement with GBIF
#' }
#'
#' @examples
#' df <- data.frame(Especie = c("actinopus anselmoi"))
#' correct_taxon(df)
#'
#' @export
correct_taxon <- function(df, col_species = "Especie", include_family = FALSE) {
  # código
}
devtools::document()
