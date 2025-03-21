library(readxl)
library(sf)
options(width = 160)


targets::tar_load(doc_shp)
targets::tar_load(doc_data_raw)

validated_docs <- readxl::read_xlsx("input/docs-classified-2024-02-29 validated fhts.xlsx")

doc_shp |>
  dplyr::filter(cpso %in% validated_docs$cpso)

doc_data_raw |>
  dplyr::filter(cpso %in% validated_docs$cpso)



# take validated set of docs, remove any that are not in the new dataset, se;ect just cpso and coded doc type
forjoin <- validated_docs |>
  dplyr::filter(.data$cpso %in% doc_shp$cpso) |>
  dplyr::transmute(
    cpso, family_physician,
    filter_hand_coded = TRUE,
    doc_type_validated = factor(.data$family_physician, levels = c(FALSE, TRUE), labels = c("other", "family"))
  ) |>
  dplyr::select(cpso, filter_hand_coded, doc_type_validated)


# check agreement...
dplyr::select(doc_shp, cpso, doc_type) |>
  dplyr::left_join(forjoin, by = "cpso") |>
  dplyr::filter(!is.na(doc_type_validated)) |>
  sf::st_drop_geometry() |>
  dplyr::select(doc_type, doc_type_validated) |>
  table() |>
  prop.table(margin = 1)


dplyr::left_join(forjoin, by = "cpso") |>
  dplyr::filter(!is.na(doc_type_validated)) |>
  dplyr::select(doc_type, doc_type_validated) |>
  table() |>
  prop.table(margin = 1)



docs_hand_coded <- doc_shp |>
  dplyr::mutate(filter_hand_coded = FALSE) |>
  sf::st_drop_geometry() |>
  # dplyr::select(cpso, doc_type) |>
  dplyr::rows_update(dplyr::rename(forjoin, doc_type = doc_type_validated), by = "cpso") |>
  sf::st_as_sf(coords = c("lon", "lat"), crs = "WGS84", remove = FALSE)
