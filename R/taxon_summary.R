#FUNCAO taxon_summary

#' Resume qualidade da correção taxonômica.
#'
#' Calcula métricas simples a partir da saída de `correct_taxon()`.
#'
#' @param df data.frame retornado por `correct_taxon()`.
#' @param col_current nome da coluna com o nome taxonômico atualizado.
#' @param col_normalized nome da coluna com o nome normalizado de entrada.
#' @param col_status nome da coluna com status taxonômico.
#' @param col_synonym nome da coluna que indica o nome aceito quando há sinônimo.
#' @param col_source nome da coluna com a fonte taxonômica (WSC/GBIF).
#'
#' @return Um `data.frame` (1 linha) com:
#' \describe{
#'   \item{n_especies_unicas}{Número de espécies únicas após correção.}
#'   \item{n_sinonimos_corrigidos}{Número de registros de sinônimos corrigidos.}
#'   \item{taxa_erro}{Proporção de registros sem resolução taxonômica válida.}
#' }
#'
#' @examples
#' df_corrigido <- data.frame(
#'   Especie_normalizada = c("Actinopus anselmoi", "Phoneutria nigriventer", "Loxosceles intermedia"),
#'   Especie_atual = c("Actinopus anselmoi", "Phoneutria fera", "Loxosceles intermedia"),
#'   Fonte_taxonomia = c("WSC/arakno", "WSC/arakno", "GBIF/rgbif"),
#'   Status_taxonomico = c("accepted", "synonym", "accepted"),
#'   Sinonimo_de = c(NA, "Phoneutria fera", NA),
#'   stringsAsFactors = FALSE
#' )
#'
#' taxon_summary(df_corrigido)
#' @export
taxon_summary <- function(
    df,
    col_current = "Especie_atual",
    col_normalized = "Especie_normalizada",
    col_status = "Status_taxonomico",
    col_synonym = "Sinonimo_de",
    col_source = "Fonte_taxonomia"
) {
  if (!is.data.frame(df)) stop("`df` deve ser um data.frame.")

  required_cols <- c(col_current, col_normalized, col_status, col_synonym, col_source)
  missing_cols <- setdiff(required_cols, names(df))
  if (length(missing_cols) > 0) {
    stop(sprintf(
      "Colunas ausentes em `df`: %s.",
      paste(missing_cols, collapse = ", ")
    ))
  }

  cur <- trimws(as.character(df[[col_current]]))
  norm <- trimws(as.character(df[[col_normalized]]))
  status <- trimws(as.character(df[[col_status]]))
  syn <- trimws(as.character(df[[col_synonym]]))
  source <- trimws(as.character(df[[col_source]]))

  cur[is.na(cur)] <- ""
  norm[is.na(norm)] <- ""
  status[is.na(status)] <- ""
  syn[is.na(syn)] <- ""
  source[is.na(source)] <- ""

  n_especies_unicas <- length(unique(cur[nzchar(cur)]))

  sinonimo_por_status <- grepl("syn", status, ignore.case = TRUE)
  sinonimo_por_coluna <- nzchar(syn)
  n_sinonimos_corrigidos <- sum(sinonimo_por_status | sinonimo_por_coluna)

  sem_resolucao <- !nzchar(cur) | !nzchar(source)
  taxa_erro <- if (nrow(df) == 0) NA_real_ else sum(sem_resolucao) / nrow(df)

  data.frame(
    n_especies_unicas = n_especies_unicas,
    n_sinonimos_corrigidos = n_sinonimos_corrigidos,
    taxa_erro = taxa_erro,
    stringsAsFactors = FALSE
  )
}
