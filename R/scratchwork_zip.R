files_to_zip <- list.files(
  path = here::here("output/"),
  pattern = "*.csv|*.geojson",
  full.names = TRUE,
  include.dirs = FALSE
)
