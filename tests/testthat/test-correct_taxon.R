fake_resolver <- function(name, lsid_input = NA_character_) {
  base <- list(
    fonte = "WSC/arakno", current_name = name, status = "ACCEPTED",
    synonym_of = NA_character_, family = "Ctenidae", lsid = NA_character_,
    gbif_usagekey = NA_character_, confidence = NA_character_,
    observation = NA_character_, lsid_input = lsid_input
  )
  if (name == "Nephila clavipes") {
    base$current_name <- "Trichonephila clavipes"
    base$status <- "SYNONYM"
    base$synonym_of <- "Trichonephila clavipes"
    base$family <- "Araneidae"
  }
  if (name == "Aranhus inventadus") {
    base[c("fonte", "current_name", "family")] <- NA_character_
    base$status <- "NOT_FOUND"
  }
  base
}

test_that("correct_taxon adiciona as colunas esperadas", {
  local_mocked_bindings(.resolve_nome_aranha = fake_resolver)
  df <- data.frame(Especie = c("  phoneutria NIGRIVENTER", "Nephila clavipes", NA))

  res <- correct_taxon(
    df,
    cache_file = tempfile(fileext = ".rds"),
    checkpoint_file = tempfile(fileext = ".rds"),
    verbose = FALSE,
    include_family = TRUE
  )

  expect_true(all(c(
    "Especie_normalizada", "Especie_match", "Fonte_taxonomia",
    "Status_taxonomico", "Sinonimo_de", "LSID", "GBIF_usageKey",
    "Confianca_match", "Observacao_taxonomia", "Familia"
  ) %in% names(res)))
  expect_equal(res$Especie_normalizada, c("Phoneutria nigriventer", "Nephila clavipes", ""))
  expect_equal(res$Especie_match, c("Phoneutria nigriventer", "Trichonephila clavipes", NA))
  expect_equal(res$Familia, c("Ctenidae", "Araneidae", NA))
  expect_equal(attr(res, "nomes_unicos"), 2)
})

test_that("correct_taxon reutiliza o cache", {
  local_mocked_bindings(.resolve_nome_aranha = fake_resolver)
  df <- data.frame(Especie = c("Phoneutria nigriventer", "phoneutria nigriventer"))
  cache <- tempfile(fileext = ".rds")
  cp <- tempfile(fileext = ".rds")

  res1 <- correct_taxon(df, cache_file = cache, checkpoint_file = cp, verbose = FALSE)
  res2 <- correct_taxon(df, cache_file = cache, checkpoint_file = cp, verbose = FALSE)

  expect_equal(attr(res1, "nomes_consultados"), 1)
  expect_equal(attr(res2, "nomes_consultados"), 0)
  expect_false(file.exists(cp))
})

test_that("correct_taxon valida as entradas", {
  expect_error(correct_taxon(list(Especie = "a")), "data.frame")
  expect_error(correct_taxon(data.frame(x = "a")), "Especie")
})

test_that("taxon_summary conta nomes nao encontrados como erro", {
  local_mocked_bindings(.resolve_nome_aranha = fake_resolver)
  df <- data.frame(Especie = c("Phoneutria nigriventer", "Nephila clavipes", "Aranhus inventadus"))
  res <- correct_taxon(
    df,
    cache_file = tempfile(fileext = ".rds"),
    checkpoint_file = tempfile(fileext = ".rds"),
    verbose = FALSE
  )

  s <- taxon_summary(res)
  expect_equal(s$n_especies_unicas, 2)
  expect_equal(s$n_sinonimos_corrigidos, 1)
  expect_equal(s$taxa_erro, 1 / 3)
})

test_that("correct_taxon resolve sinonimos no WSC (online)", {
  skip_on_cran()
  skip_if_offline()
  df <- data.frame(Especie = c("Nephila clavipes", "Phoneutria nigriventer"))

  res <- correct_taxon(
    df,
    cache_file = tempfile(fileext = ".rds"),
    checkpoint_file = tempfile(fileext = ".rds"),
    verbose = FALSE,
    include_family = TRUE
  )

  expect_equal(res$Especie_match, c("Trichonephila clavipes", "Phoneutria nigriventer"))
  expect_equal(res$Status_taxonomico, c("SYNONYM", "ACCEPTED"))
  expect_equal(res$Fonte_taxonomia, c("WSC/arakno", "WSC/arakno"))
  expect_equal(res$Familia, c("Araneidae", "Ctenidae"))
})
