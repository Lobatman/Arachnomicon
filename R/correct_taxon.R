# Distancia de edicao maxima (em caracteres) para aceitar a correcao de grafia
# sugerida pelo WSC. Acima disso, a sugestao costuma ser outra especie.
.max_misspelling_dist <- 2

# Registro do WSC (familia e LSID) para um nome valido. O `arakno` guarda a
# tabela do WSC no ambiente global (`wscData`) ao chamar `arakno::wsc()`.
.wsc_record <- function(name) {
  d <- tryCatch(get("wscData", envir = globalenv()), error = function(e) NULL)
  if (!is.data.frame(d) || is.na(name)) return(NULL)

  subsp <- as.character(d$subspecies)
  subsp[is.na(subsp)] <- ""
  i <- which(d$name == name & !nzchar(subsp))
  if (length(i) > 0) {
    return(list(family = as.character(d$family[i[1]]),
                lsid = as.character(d$species_lsid[i[1]])))
  }

  i <- which(d$genus == name)
  if (length(i) > 0) {
    return(list(family = as.character(d$family[i[1]]), lsid = NA_character_))
  }

  NULL
}

.query_wsc_arakno <- function(name) {
  if (!requireNamespace("arakno", quietly = TRUE)) return(NULL)

  out <- try(arakno::checkNames(name), silent = TRUE)
  if (inherits(out, "try-error")) return(NULL)

  if (is.character(out)) {
    # "All taxa OK!": o nome existe como valido no WSC.
    best <- name
    note <- "Ok"
    alt <- NA_character_
  } else if (is.data.frame(out) && nrow(out) > 0) {
    best <- as.character(out[1, 2])
    note <- as.character(out[1, 3])
    alt <- as.character(out[1, 4])
  } else {
    return(NULL)
  }

  res <- list(
    fonte = "WSC/arakno",
    current_name = NA_character_,
    status = NA_character_,
    synonym_of = NA_character_,
    family = NA_character_,
    lsid = NA_character_,
    observation = NA_character_
  )

  if (identical(note, "Ok")) {
    res$current_name <- name
    res$status <- "ACCEPTED"
  } else if (note %in% c("Synonym", "Nomenclature change")) {
    res$current_name <- best
    res$status <- "SYNONYM"
    res$synonym_of <- best
    res$observation <- paste0("WSC: ", note)
  } else if (identical(note, "Misspelling")) {
    dist <- utils::adist(name, best)[1, 1]
    if (dist > .max_misspelling_dist) {
      return(list(
        fonte = NA_character_,
        current_name = NA_character_,
        observation = sprintf(
          "WSC: nome n\u00e3o encontrado (sugest\u00e3o mais pr\u00f3xima: %s)", best
        )
      ))
    }
    res$current_name <- best
    res$status <- "MISSPELLING"
    res$observation <- sprintf("WSC: grafia corrigida para %s (dist\u00e2ncia %d)", best, dist)
  } else {
    return(NULL)
  }

  if (!is.na(alt) && nzchar(alt)) {
    res$observation <- .paste_obs(res$observation, paste0("WSC: alternativas: ", alt))
  }

  rec <- .wsc_record(res$current_name)
  if (!is.null(rec)) {
    res$family <- rec$family
    res$lsid <- rec$lsid
  }

  res
}

.query_gbif <- function(name) {
  if (!requireNamespace("rgbif", quietly = TRUE)) return(NULL)

  out <- try(
    rgbif::name_backbone(name = name, rank = "species", strict = FALSE, verbose = FALSE),
    silent = TRUE
  )
  if (inherits(out, "try-error") || !is.data.frame(out) || nrow(out) == 0) return(NULL)

  col <- function(nm) {
    if (nm %in% names(out)) as.character(out[[nm]][1]) else NA_character_
  }

  match_type <- col("matchType")
  if (is.na(match_type) || match_type %in% c("NONE", "HIGHERRANK")) {
    return(list(
      fonte = NA_character_,
      current_name = NA_character_,
      family = col("family"),
      observation = sprintf(
        "GBIF: sem correspond\u00eancia em n\u00edvel de esp\u00e9cie (matchType = %s)", match_type
      )
    ))
  }

  # Para sinonimos, o campo `species` do GBIF traz a especie aceita.
  current_name <- col("species") %||% col("canonicalName") %||% name
  status <- col("status")
  is_synonym <- !is.na(status) && grepl("SYNONYM", status)

  list(
    fonte = "GBIF/rgbif",
    current_name = current_name,
    status = status,
    synonym_of = if (is_synonym) current_name else NA_character_,
    family = col("family"),
    lsid = NA_character_,
    gbif_usagekey = col("usageKey"),
    confidence = col("confidence"),
    observation = if (identical(match_type, "FUZZY")) {
      "GBIF: correspond\u00eancia aproximada (FUZZY)"
    } else {
      NA_character_
    }
  )
}

.resolve_nome_aranha <- function(name, lsid_input = NA_character_) {
  res <- list(
    fonte = NA_character_,
    current_name = NA_character_,
    status = NA_character_,
    synonym_of = NA_character_,
    family = NA_character_,
    lsid = NA_character_,
    gbif_usagekey = NA_character_,
    confidence = NA_character_,
    observation = NA_character_,
    lsid_input = lsid_input
  )

  wsc <- .query_wsc_arakno(name)
  gbif <- .query_gbif(name)

  wsc_ok <- !is.null(wsc) && !is.na(wsc$current_name)
  gbif_ok <- !is.null(gbif) && !is.na(gbif$current_name)

  # WSC tem prioridade para o nome aceito de aranhas; GBIF e usado quando o
  # WSC nao resolve o nome.
  principal <- if (wsc_ok) wsc else if (gbif_ok) gbif else NULL
  if (!is.null(principal)) {
    for (nm in c("fonte", "current_name", "status", "synonym_of")) {
      res[[nm]] <- principal[[nm]] %||% NA_character_
    }
  } else {
    res$status <- "NOT_FOUND"
  }

  # Campos complementares: WSC primeiro, depois GBIF.
  for (src in list(wsc, gbif)) {
    for (nm in c("family", "lsid", "gbif_usagekey", "confidence")) {
      if (is.na(res[[nm]]) && !is.null(src[[nm]])) res[[nm]] <- src[[nm]]
    }
  }

  divergencia <- if (wsc_ok && gbif_ok && !identical(wsc$current_name, gbif$current_name)) {
    sprintf("GBIF indica: %s (%s)", gbif$current_name, gbif$status)
  } else {
    NA_character_
  }
  res$observation <- .paste_obs(wsc$observation, gbif$observation, divergencia)

  if (!is.na(lsid_input) && nzchar(lsid_input)) {
    if (is.na(res$lsid) || !nzchar(res$lsid)) {
      res$lsid <- lsid_input
    } else if (!identical(res$lsid, lsid_input)) {
      res$observation <- .paste_obs(
        res$observation,
        paste0("LSID input difere do retorno (input=", lsid_input, ").")
      )
    }
  }

  res
}



#' Corrige nomenclatura taxonômica de aranhas usando WSC (arakno) e GBIF (rgbif)
#'
#' Esta função padroniza e atualiza nomes de espécies de aranhas a partir de um
#' `data.frame`, consultando o World Spider Catalog (via pacote `arakno`) e o
#' GBIF (via pacote `rgbif`). O WSC tem prioridade para nomes aceitos, família
#' e LSID; o GBIF é usado quando o WSC não resolve o nome e complementa a
#' chave e a confiança do match no GBIF.
#'
#' A função utiliza um sistema de cache persistente (`.rds`) para evitar consultas
#' repetidas e um mecanismo de checkpoint para retomar execuções interrompidas.
#'
#' @param df `data.frame` contendo a coluna com os nomes das espécies.
#' @param col_species `character`. Nome da coluna com os nomes das espécies.
#'   Default é `"Especie"`.
#' @param cache_file `character`. Caminho para o arquivo `.rds` usado como cache
#'   persistente das consultas. Default é `"cache_taxonomia_aranhas.rds"`.
#' @param checkpoint_file `character`. Caminho para o arquivo `.rds` usado como
#'   checkpoint para retomada em caso de interrupção. Default é
#'   `"checkpoint_taxonomia_aranhas.rds"`.
#' @param batch_size `numeric`. Número de consultas entre salvamentos do cache
#'   e checkpoint. Default é `100`.
#' @param sleep_s `numeric`. Tempo (em segundos) de pausa entre consultas, útil
#'   para evitar limites de requisição (rate limit). Default é `0`.
#' @param verbose `logical`. Se `TRUE`, exibe barra de progresso e estimativas
#'   de tempo. Default é `TRUE`.
#' @param include_family `logical`. Se `TRUE`, adiciona a coluna `Familia` ao
#'   resultado final. Default é `FALSE`.
#' @param col_lsid `character` ou `NULL`. Nome da coluna contendo LSIDs já
#'   conhecidos para auxiliar na resolução taxonômica. Default é `NULL`.
#'
#' @return Um `data.frame` com as colunas originais acrescidas de:
#' \describe{
#'   \item{Especie_normalizada}{Nome padronizado (capitalização e espaços corrigidos).}
#'   \item{Especie_match}{Nome aceito atual da espécie. `NA` quando o nome não
#'     foi encontrado.}
#'   \item{Fonte_taxonomia}{Fonte do nome aceito (`"WSC/arakno"` ou `"GBIF/rgbif"`).}
#'   \item{Status_taxonomico}{Status do nome informado: `ACCEPTED`, `SYNONYM`,
#'     `MISSPELLING` (grafia corrigida pelo WSC), `NOT_FOUND` ou outro status
#'     retornado pelo GBIF.}
#'   \item{Sinonimo_de}{Nome aceito quando o nome informado é sinônimo ou
#'     combinação antiga.}
#'   \item{LSID}{LSID do WSC para o nome aceito (quando disponível).}
#'   \item{GBIF_usageKey}{Identificador único do GBIF para o nome informado.}
#'   \item{Confianca_match}{Nível de confiança do match no GBIF.}
#'   \item{Observacao_taxonomia}{Observações adicionais do processo de resolução.}
#'   \item{Familia}{Família taxonômica (opcional, se `include_family = TRUE`).}
#'   \item{LSID_input}{LSID fornecido no input (se `col_lsid` for usado).}
#' }
#'
#' Além disso, o objeto retornado contém atributos:
#' \describe{
#'   \item{tempo_execucao_seg}{Tempo total de execução (em segundos).}
#'   \item{nomes_unicos}{Número de nomes únicos processados.}
#'   \item{nomes_consultados}{Número de consultas realizadas (excluindo cache).}
#' }
#'
#' @details
#' \strong{Fluxo da função:}
#' \enumerate{
#'   \item Normaliza os nomes das espécies (função `spp_norm()`).
#'   \item Remove duplicatas (nome + LSID).
#'   \item Consulta o WSC (`arakno::checkNames()`).
#'   \item Consulta o GBIF (`rgbif::name_backbone()`).
#'   \item Armazena resultados em cache e checkpoint.
#'   \item Reconstrói o `data.frame` final com os resultados.
#' }
#'
#' \strong{Prioridade de dados:}
#' \itemize{
#'   \item Nome aceito, família e LSID: WSC (quando disponível).
#'   \item Nome aceito quando o WSC não resolve o nome: GBIF.
#'   \item Chave e confiança do GBIF: GBIF.
#' }
#'
#' Correções de grafia sugeridas pelo WSC só são aceitas quando diferem do
#' nome informado em até 2 caracteres; caso contrário, a sugestão é registrada
#' em `Observacao_taxonomia`.
#'
#' Na primeira consulta da sessão, o `arakno` baixa a tabela completa do WSC
#' e a guarda no ambiente global como `wscData`.
#'
#' @examples
#' \dontrun{
#' df <- data.frame(
#'   Especie = c("actinopus anselmoi", "Phoneutria nigriventer", "loxosceles intermedia")
#' )
#'
#' resultado <- correct_taxon(df)
#'
#' # Incluindo família
#' resultado2 <- correct_taxon(df, include_family = TRUE)
#'
#' # Usando LSID prévio
#' df$LSID_input <- c(NA, "urn:lsid:example:1", NA)
#' resultado3 <- correct_taxon(df, col_lsid = "LSID_input")
#' }
#'
#' @seealso
#' \code{\link{spider_family}}, \code{\link{taxon_summary}},
#' \code{\link[rgbif]{name_backbone}}, \code{\link[arakno]{checkNames}}
#'
#' @importFrom utils txtProgressBar setTxtProgressBar
#' @export
#'
#' @author
#' Victor Lobato dos Santos
#'
correct_taxon <- function(
    df,
    col_species = "Especie",
    cache_file = "cache_taxonomia_aranhas.rds",
    checkpoint_file = "checkpoint_taxonomia_aranhas.rds",
    batch_size = 100,
    sleep_s = 0,
    verbose = TRUE,
    include_family = FALSE,
    col_lsid = NULL
) {
  if (!is.data.frame(df)) stop("`df` deve ser um data.frame.")
  if (!col_species %in% names(df)) {
    stop(sprintf("Coluna `%s` n\u00e3o encontrada em `df`.", col_species))
  }

  input <- as.character(df[[col_species]])
  input[is.na(input)] <- ""
  input_norm <- spp_norm(input)
  lsid_input <- rep(NA_character_, length(input_norm))
  if (!is.null(col_lsid)) {
    if (!col_lsid %in% names(df)) {
      stop(sprintf("Coluna `%s` n\u00e3o encontrada em `df`.", col_lsid))
    }
    lsid_input <- vapply(df[[col_lsid]], .lsid_normalize, character(1), USE.NAMES = FALSE)
  }

  pairs <- data.frame(
    name = input_norm[nzchar(input_norm)],
    lsid = lsid_input[nzchar(input_norm)],
    stringsAsFactors = FALSE
  )
  pairs <- unique(pairs)
  keys <- mapply(.cache_key, pairs$name, pairs$lsid, USE.NAMES = FALSE)
  pairs$key <- as.character(keys)

  cache <- list()
  if (file.exists(cache_file)) {
    tmp <- readRDS(cache_file)
    if (is.list(tmp)) cache <- tmp
  }

  results <- cache
  pending <- setdiff(pairs$key, names(results))

  if (file.exists(checkpoint_file)) {
    cp <- readRDS(checkpoint_file)
    if (is.list(cp)) {
      if (!is.null(cp$results) && is.list(cp$results)) results <- cp$results
      if (!is.null(cp$pending)) pending <- intersect(cp$pending, pairs$key)
      pending <- union(pending, setdiff(pairs$key, names(results)))
    }
  }

  n_total <- length(pending)
  t0 <- Sys.time()

  if (verbose) {
    message(sprintf(
      "Iniciando resolu\u00e7\u00e3o taxon\u00f4mica: %d nomes \u00fanicos pendentes.", n_total
    ))
  }

  if (n_total > 0 && verbose) {
    pb <- txtProgressBar(min = 0, max = n_total, style = 3)
  }

  for (i in seq_along(pending)) {
    chave <- pending[[i]]
    idx <- match(chave, pairs$key)
    nm <- pairs$name[[idx]]
    ls <- pairs$lsid[[idx]]
    results[[chave]] <- .resolve_nome_aranha(nm, lsid_input = ls)

    if (n_total > 0 && verbose) {
      setTxtProgressBar(pb, i)
      if (i %% max(1, floor(n_total / 20)) == 0 || i == n_total) {
        elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
        rate <- i / max(elapsed, 1e-6)
        eta <- (n_total - i) / max(rate, 1e-6)
        message(sprintf("  %d/%d | %.2f nomes/s | ETA ~ %.1fs", i, n_total, rate, eta))
      }
    }

    if (i %% batch_size == 0 || i == n_total) {
      saveRDS(results, cache_file)
      cp <- list(
        results = results,
        pending = if (i < n_total) pending[(i + 1):n_total] else character(0),
        updated_on = Sys.time()
      )
      saveRDS(cp, checkpoint_file)
    }

    if (sleep_s > 0) Sys.sleep(sleep_s)
  }

  if (n_total > 0 && verbose) close(pb)

  saveRDS(results, cache_file)
  if (file.exists(checkpoint_file)) file.remove(checkpoint_file)

  extract <- function(name, lsid, campo) {
    if (!nzchar(name)) return(NA_character_)
    k <- .cache_key(name, lsid)
    x <- results[[k]]
    if (is.null(x) || is.null(x[[campo]]) || is.na(x[[campo]])) return(NA_character_)
    as.character(x[[campo]])
  }

  output <- df
  output$Especie_normalizada <- input_norm
  output$Especie_match <- mapply(extract, input_norm, lsid_input, MoreArgs = list(campo = "current_name"), USE.NAMES = FALSE)
  output$Fonte_taxonomia <- mapply(extract, input_norm, lsid_input, MoreArgs = list(campo = "fonte"), USE.NAMES = FALSE)
  output$Status_taxonomico <- mapply(extract, input_norm, lsid_input, MoreArgs = list(campo = "status"), USE.NAMES = FALSE)
  output$Sinonimo_de <- mapply(extract, input_norm, lsid_input, MoreArgs = list(campo = "synonym_of"), USE.NAMES = FALSE)
  output$LSID <- mapply(extract, input_norm, lsid_input, MoreArgs = list(campo = "lsid"), USE.NAMES = FALSE)
  output$GBIF_usageKey <- mapply(extract, input_norm, lsid_input, MoreArgs = list(campo = "gbif_usagekey"), USE.NAMES = FALSE)
  output$Confianca_match <- mapply(extract, input_norm, lsid_input, MoreArgs = list(campo = "confidence"), USE.NAMES = FALSE)
  output$Observacao_taxonomia <- mapply(extract, input_norm, lsid_input, MoreArgs = list(campo = "observation"), USE.NAMES = FALSE)
  if (isTRUE(include_family)) {
    output$Familia <- mapply(extract, input_norm, lsid_input, MoreArgs = list(campo = "family"), USE.NAMES = FALSE)
  }
  if (!is.null(col_lsid)) {
    output$LSID_input <- lsid_input
  }

  attr(output, "tempo_execucao_seg") <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  attr(output, "nomes_unicos") <- nrow(pairs)
  attr(output, "nomes_consultados") <- n_total

  output
}
