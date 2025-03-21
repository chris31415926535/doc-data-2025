## FUNCTIONS TO APPLY HAND-CODED FIXES AFTER AUTO-PROCESSING


.data <- rlang::.data

# Consolidate manually verified doctor statuses. Provided by the Ottawa Neighbourhood Study.
handcode_ons <- function(doc_shp) {
  validated_docs <- readxl::read_xlsx("input/docs-classified-2024-02-29 validated fhts.xlsx") |>
    suppressWarnings()



  # take validated set of docs, remove any that are not in the new dataset, se;ect just cpso and coded doc type
  forjoin <- validated_docs |>
    dplyr::filter(.data$cpso %in% doc_shp$cpso) |>
    dplyr::transmute(
      .data$cpso, .data$family_physician,
      filter_hand_coded = TRUE,
      doc_type_validated = factor(.data$family_physician, levels = c(FALSE, TRUE), labels = c("other", "family"))
    ) |>
    dplyr::select("cpso", "filter_hand_coded", "doc_type_validated")


  docs_hand_coded <- doc_shp |>
    dplyr::mutate(filter_hand_coded = FALSE) |>
    sf::st_drop_geometry() |>
    # dplyr::select(cpso, doc_type) |>
    dplyr::rows_update(dplyr::rename(forjoin, doc_type = "doc_type_validated"), by = "cpso") |>
    sf::st_as_sf(coords = c("lon", "lat"), crs = "WGS84", remove = FALSE)

  docs_hand_coded
} # end function handcode_ons()
