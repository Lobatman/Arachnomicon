test_that("spp_norm padroniza grafia", {
  expect_equal(spp_norm("   ACTINOPUS   ANSELMOI "), "Actinopus anselmoi")
  expect_equal(spp_norm("LOXOSCELES intermedia"), "Loxosceles intermedia")
  expect_equal(spp_norm("actinopus"), "Actinopus")
})

test_that("spp_norm aceita vetores e preserva NA", {
  expect_equal(
    spp_norm(c("a b", "c  D", NA, "")),
    c("A b", "C d", NA, "")
  )
  expect_equal(spp_norm(character(0)), character(0))
})
