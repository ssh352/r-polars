test_df = data.frame(
  "col_int" = 1L:10L,
  "col_dbl" = (1:10) / 10,
  "col_chr" = letters[1:10],
  "col_lgl" = rep_len(c(TRUE, FALSE, NA), 10)
)

make_as_polars_df_cases = function() {
  tibble::tribble(
    ~.test_name, ~x,
    "data.frame", test_df,
    "polars_lf", pl$LazyFrame(test_df),
    "polars_group_by", pl$DataFrame(test_df)$group_by("col_int"),
    "polars_lazy_group_by", pl$LazyFrame(test_df)$group_by("col_int"),
    "polars_rolling_group_by", pl$DataFrame(test_df)$rolling("col_int", period = "1i"),
    "polars_lazy_rolling_group_by", pl$LazyFrame(test_df)$rolling("col_int", period = "1i"),
    "polars_group_by_dynamic", pl$DataFrame(test_df)$group_by_dynamic("col_int", every = "1i"),
    "polars_lazy_group_by_dynamic", pl$LazyFrame(test_df)$group_by_dynamic("col_int", every = "1i"),
    "arrow Table", arrow::as_arrow_table(test_df),
    "arrow RecordBatch", arrow::as_record_batch(test_df),
  )
}

patrick::with_parameters_test_that("as_polars_df S3 methods",
  {
    skip_if_not_installed("arrow")

    pl_df = as_polars_df(x)
    expect_s3_class(pl_df, "RPolarsDataFrame")

    actual = as.data.frame(pl_df)
    expected = as.data.frame(pl$DataFrame(test_df))

    expect_equal(actual, expected)
  },
  .cases = make_as_polars_df_cases()
)


test_that("as_polars_lf S3 method", {
  skip_if_not_installed("arrow")
  at = arrow::as_arrow_table(test_df)
  expect_s3_class(as_polars_lf(at), "RPolarsLazyFrame")
})


make_rownames_cases = function() {
  tibble::tribble(
    ~.test_name, ~x, ~rownames,
    "mtcars - NULL", mtcars, NULL,
    "mtcars - foo", mtcars, "foo",
    "trees - foo", trees, "foo",
    "matrix - NULL", matrix(1:4, nrow = 2), NULL,
    "matrix - foo", matrix(1:4, nrow = 2), "foo",
  )
}


patrick::with_parameters_test_that("rownames option of as_polars_df",
  {
    pl_df = as_polars_df(x, rownames = rownames)
    expect_s3_class(pl_df, "RPolarsDataFrame")

    actual = as.data.frame(pl_df)
    expected = as.data.frame(x) |>
      tibble::as_tibble(rownames = rownames) |>
      as.data.frame()

    expect_equal(actual, expected)
  },
  .cases = make_rownames_cases()
)


test_that("as_polars_df throws error when rownames is not a single string or already used", {
  expect_error(as_polars_df(mtcars, rownames = "cyl"), "already used")
  expect_error(as_polars_df(mtcars, rownames = c("cyl", "disp")), "must be a single string")
  expect_error(as_polars_df(mtcars, rownames = 1), "must be a single string")
  expect_error(as_polars_df(mtcars, rownames = NA_character_), "must be a single string")
  expect_error(
    as_polars_df(data.frame(a = 1, a = 2, check.names = FALSE), rownames = "a_1"),
    "already used"
  )
})


test_that("as_polars_df throws error when make_names_unique = FALSE and there are duplicated column names", {
  expect_error(
    as_polars_df(data.frame(a = 1, a = 2, check.names = FALSE), make_names_unique = FALSE),
    "not allowed"
  )
})


make_as_polars_series_cases = function() {
  tibble::tribble(
    ~.test_name, ~x, ~expected_name,
    "vector", 1, "",
    "Series", pl$Series(1, "foo"), "foo",
    "Expr", pl$lit(1)$alias("foo"), "foo",
    "list", list(1:4), "",
    "data.frame", data.frame(x = 1, y = letters[1]), "",
    "POSIXlt", as.POSIXlt("1900-01-01"), "",
    "arrow Array", arrow::arrow_array(1), "",
    "arrow ChunkedArray", arrow::chunked_array(1), "",
  )
}


patrick::with_parameters_test_that("as_polars_series S3 methods",
  {
    skip_if_not_installed("arrow")

    pl_series = as_polars_series(x)
    expect_s3_class(pl_series, "RPolarsSeries")

    expect_identical(length(pl_series), 1L)
    expect_equal(pl_series$name, expected_name)

    pl_series = as_polars_series(x, name = "bar")
    expect_equal(pl_series$name, "bar")
  },
  .cases = make_as_polars_series_cases()
)


test_that("tests for vctrs_rcrd", {
  skip_if_not_installed("vctrs")
  skip_if_not_installed("tibble")

  latlon = function(lat, lon) {
    vctrs::new_rcrd(list(lat = lat, lon = lon), class = "earth_latlon")
  }

  format.earth_latlon = function(x, ..., formatter = deg_min) {
    x_valid = which(!is.na(x))

    lat = vctrs::field(x, "lat")[x_valid]
    lon = vctrs::field(x, "lon")[x_valid]

    ret = rep(NA_character_, vec_size(x))
    ret[x_valid] = paste0(formatter(lat, "lat"), " ", formatter(lon, "lon"))

    ret
  }

  deg_min = function(x, direction) {
    pm = if (direction == "lat") c("N", "S") else c("E", "W")

    sign = sign(x)
    x = abs(x)
    deg = trunc(x)
    x = x - deg
    min = round(x * 60)

    # Ensure the columns are always the same width so they line up nicely
    ret = sprintf("%d°%.2d'%s", deg, min, ifelse(sign >= 0, pm[[1]], pm[[2]]))
    format(ret, justify = "right")
  }

  vec = latlon(c(32.71, 2.95), c(-117.17, 1.67))

  expect_identical(length(as_polars_series(vec)), 2L)

  # TODO: this should work
  # https://github.com/pola-rs/r-polars/issues/575
  # pl$DataFrame(foo = vec)

  expect_identical(
    dim(as_polars_df(tibble::tibble(foo = vec))),
    c(2L, 1L)
  )
})


test_that("from arrow Table and ChunkedArray", {
  skip_if_not_installed("arrow")

  # support plain chunked Table
  l = list(
    df1 = data.frame(val = c(1, 2, 3), blop = c("a", "b", "c")),
    df2 = data.frame(val = c(4, 5, 6), blop = c("a", "b", "c"))
  )
  at = lapply(l, arrow::as_arrow_table) |> do.call(what = rbind)

  # chunked conversion
  expect_identical(
    as_polars_df.ArrowTabular(at)$to_list(),
    as.list(at)
  )
  expect_identical(
    lapply(at$columns, \(x) as_polars_series.ChunkedArray(x)$to_r()),
    unname(as.list(at))
  )

  # no rechunk
  expect_identical(
    lapply(at$columns, \(x) length(as_polars_series.ChunkedArray(x, rechunk = FALSE)$chunk_lengths())),
    lapply(at$columns, \(x) x$num_chunks)
  )
  expect_error(expect_identical(
    lapply(at$columns, \(x) length(as_polars_series.ChunkedArray(x, rechunk = TRUE)$chunk_lengths())),
    lapply(at$columns, \(x) x$num_chunks)
  ))
  expect_identical(
    as_polars_df.ArrowTabular(at, rechunk = FALSE)$
      select(pl$all()$map_batches(\(s) s$chunk_lengths()))$
      to_list() |>
      lapply(length) |>
      unname(),
    lapply(at$columns, \(x) x$num_chunks)
  )

  expect_error(expect_identical(
    as_polars_df.ArrowTabular(at, rechunk = TRUE)$
      select(pl$all()$map_batches(\(s) s$chunk_lengths()))$
      to_list() |>
      lapply(length) |>
      unname(),
    lapply(at$columns, \(x) x$num_chunks)
  ))


  # #not supported yet
  # #chunked data with factors
  l = list(
    df1 = data.frame(factor = factor(c("apple", "apple", "banana"))),
    df2 = data.frame(factor = factor(c("apple", "apple", "clementine")))
  )
  at = lapply(l, arrow::arrow_table) |> do.call(what = rbind)
  df = as_polars_df.ArrowTabular(at)
  expect_identical(as.data.frame(at), as.data.frame(df))

  # chunked data with factors and regular integer32
  at2 = lapply(l, \(df) {
    df$value = 1:3
    df
  }) |>
    lapply(arrow::arrow_table) |>
    do.call(what = rbind)
  df2 = as_polars_df.ArrowTabular(at2)
  expect_identical(as.data.frame(at2), as.data.frame(df2))


  # use schema override
  df = as_polars_df.ArrowTabular(
    arrow::arrow_table(iris),
    schema_overrides = list(Sepal.Length = pl$Float32, Species = pl$String)
  )
  iris_str = iris
  iris_str$Species = as.character(iris_str$Species)
  expect_error(expect_equal(df$to_list(), as.list(iris_str)))
  expect_equal(df$to_list(), as.list(iris_str), tolerance = 0.0001)

  # change column name via char schema
  char_schema = names(iris)
  char_schema[1] = "Alice"
  expect_identical(
    as_polars_df.ArrowTabular(
      arrow::arrow_table(iris),
      schema = char_schema
    )$columns,
    char_schema
  )
})


test_that("can convert an arrow Table contains dictionary<large_string, uint32> type, issue #725", {
  skip_if_not_installed("arrow")

  da_string = arrow::Array$create(
    factor(c("x", "y", "z"))
  )

  da_large_string = da_string$cast(
    arrow::dictionary(
      index_type = arrow::uint32(),
      value_type = arrow::large_utf8()
    )
  )

  at = arrow::arrow_table(foo = da_string, bar = da_large_string)
  ps = as_polars_series.Array(da_large_string)
  pdf = as_polars_df.ArrowTabular(at)

  expect_s3_class(ps, "RPolarsSeries")
  expect_equal(ps$to_r(), factor(c("x", "y", "z")))
  expect_s3_class(pdf, "RPolarsDataFrame")
  expect_equal(
    pdf$to_data_frame(),
    data.frame(
      foo = factor(c("x", "y", "z")),
      bar = factor(c("x", "y", "z"))
    )
  )
})
