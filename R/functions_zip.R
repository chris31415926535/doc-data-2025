# functions to zip data and save it appropriately for storage on github etc.


# walk all files in the output directory, zip them into subfolder "zips"
zip_files <- function(trigger) {
  # just something so we run it again if the files change
  trigger + 6

  files_to_zip <- list.files(
    path = here::here("output/"),
    pattern = "*.csv|*.geojson",
    full.names = TRUE,
    include.dirs = FALSE
  )

  purrr::walk(files_to_zip, do_zip_file)

  TRUE
}

# take a full path to a file, then zip it into a file in a subfolder "zips"
do_zip_file <- function(file_name_and_path) {
  # bit of a hack--filename is preceded by two forward slashes
  just_path <- stringr::str_remove(file_name_and_path, "(?<=/)/.*")
  just_name <- stringr::str_extract(file_name_and_path, "(?<=//).*")
  zip(
    files = file_name_and_path,
    zipfile = paste0(just_path, "/zips/", just_name, ".zip")
  )
}
