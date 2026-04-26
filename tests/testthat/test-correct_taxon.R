test_that("correct_taxon runs", {
  df <- data.frame(
    Especie = c("actinopus anselmoi")
  )

  res <- correct_taxon(df)

  expect_true("Especie_atual" %in% names(res))
})
