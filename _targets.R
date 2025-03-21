# 2025 ONTARIO PHYSICIAN DATA PROCESSING

# This targets workflow uses the R language for statistical computing to process data from
# the CPSO (College of Physicians and Surgeons of Ontario) website for ALL available
# physician information. Data was collected in early January 2025 in a separate project.

# Provincial boundary is from Statistics Canada's 2021 administrative boundaries dataset:
# https://www12.statcan.gc.ca/census-recensement/alternative_alternatif.cfm?l=eng&dispext=zip&teng=lpr_000a21a_e.zip&k=%20%20%20%20%202712&loc=//www12.statcan.gc.ca/census-recensement/2021/geo/sip-pis/boundary-limites/files-fichiers/lpr_000a21a_e.zip # nolint

library(targets)
library(dplyr)
library(sf)

source("R/functions_filter.R")
source("R/functions_zip.R")
source("R/functions_handcode.R")


list(
  # Load raw physician data (compressed R data format) and Ontario provincial boundaries.
  targets::tar_target(doc_data_raw, readRDS("input/doc-data-geocoded-2025-01-20.Rds")),
  targets::tar_target(ontario_shp, load_ontario("input/lpr_000a21a_e_ontario.geojson")),

  # Process raw data to estimate which physicians are providing comprehensive family medicine services to the community.
  targets::tar_target(doc_shp, docs_create_filters(doc_data_raw, ontario_shp)),


  # Do any hand-coding. Right now single function from ONS hand-verified docs from Ottawa region
  targets::tar_target(docs_handcoded_shp, handcode_ons(doc_shp)),

  # Save output to file in csv and json formats.
  # The geojson file has a subset of columns to stay under GitHub's 100MB limit.
  # The CSV file contains all columns, some of which are redundant.
  targets::tar_target(save_output, {
    docs_handcoded_shp |>
      dplyr::select(
        -"training", -"postgrad", -"public_notifications", -"medical_school", -dplyr::starts_with("filter")
      ) |>
      sf::write_sf(
        layer = "physicians",
        here::here(sprintf("output/docs-ontario-processed-%s.geojson", Sys.Date())),
        append = FALSE,
        delete_dsn = TRUE
      )
    readr::write_csv(sf::st_drop_geometry(docs_handcoded_shp), here::here(sprintf("output/docs-ontario-processed-%s.csv", Sys.Date()))) # nolint: line_length_linter.

    # return a random number to trigger zipping the files
    runif(n = 1)
  }),
  targets::tar_target(zip_files_for_distribution, zip_files(save_output)),
  NULL
)
