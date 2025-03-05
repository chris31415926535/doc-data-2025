## PROCESS RAW PHYSICIAN DATA TO DETERMINE THOSE (LIKELY TO BE)
## PROVIDING COMPREHENSIVE FAMILY MEDICAL SERVICES TO THE COMMUNITY

.data <- rlang::.data

docs_create_shape_with_ontario_filter <- function(docs, ontario) {
  # remove docs without any lats or lons (there should be 3)
  docs_forshp <- dplyr::filter(docs, !is.na(.data$lat) & !is.na(.data$lon))

  # create a shape object
  docs_shp <- sf::st_as_sf(docs_forshp, crs = "WGS84", coords = c("lon", "lat"), remove = FALSE)

  inontario <- sf::st_contains(ontario, docs_shp) |>
    as.matrix() |>
    as.vector()

  docs_shp |>
    dplyr::mutate(filter_inontario = inontario)
}


load_ontario <- function(filepath) {
  sf::read_sf(filepath) |>
    dplyr::filter(.data$PRNAME == "Ontario") |>
    sf::st_transform(crs = "WGS84") |>
    sf::st_make_valid()
}



# SET ALL FILTERS SO THAT TRUE IS INCLUDE, FALSE IS EXCLUDE!!!!
docs_create_filters <- function(doc_data_raw, ontario_shp) {
  excluded_institutions <- get_excluded_institutions_regex()


  docs_filters <- doc_data_raw |>
    ## filter: only those with active status (otherwise inactive, suspended, or deceased)
    dplyr::mutate(filter_active = stringr::str_detect(tolower(.data$registration_status), "^active")) |>
    ## filter already there: remove those without primary practice locations in Ontario

    ## filter: remove those who list a specialty that is NOT family medicine
    dplyr::mutate(
      filter_spec_fammed_or_not_listed = (stringr::str_detect(tolower(.data$specialties), "family medicine")) |
        (stringr::str_detect(tolower(.data$specialties), "no speciality"))
    ) |>
    ## filter: remove those without an independent or restricted practice certificate
    dplyr::mutate(cert_indepdent_practice = stringr::str_detect(tolower(.data$registration_history), "independent practice certificate")) |> # nolint: line_length_linter.
    dplyr::mutate(cert_restricted = stringr::str_detect(.data$registration_history, "Restricted")) |>
    dplyr::mutate(filter_cert_indep_or_restricted = .data$cert_indepdent_practice | .data$cert_restricted) |>
    dplyr::select(-"cert_indepdent_practice", -"cert_restricted") |>
    # filter: remove those who have no listed specialty and graduated >=2019
    dplyr::mutate(specialty_listed = stringr::str_detect(tolower(.data$specialties), "no speciality reported")) |>
    dplyr::mutate(
      medical_school = stringr::str_extract(.data$training, "(?<=Medical School: ).*"),
      postgrad = stringr::str_extract(.data$training, stringr::regex("(?<=Postgraduate Training:).*", dotall = TRUE))
    ) |>
    dplyr::mutate(
      grad_year = stringr::str_extract(.data$medical_school, "\\d\\d\\d\\d") |> as.numeric(), .before = 1
    ) |>
    dplyr::mutate(
      years_since_grad = lubridate::year(Sys.Date()) - .data$grad_year,
      years_since_grad_fct = dplyr::case_when(
        years_since_grad < 1 ~ "<1",
        years_since_grad <= 5 ~ "1-5",
        years_since_grad <= 10 ~ "6-10",
        years_since_grad <= 20 ~ "11-20",
        years_since_grad <= 30 ~ "20-30",
        years_since_grad > 30 ~ "31+",
      ) |> factor(levels = c("<1", "1-5", "6-10", "11-20", "20-30", "31+"))
    ) |>
    dplyr::mutate(
      filter_not_nospecialty_gradlastfiveyears = !(
        (.data$grad_year >= (lubridate::year(Sys.Date()) - 5)) & # nolint: indentation_linter.
          stringr::str_detect(tolower(.data$specialties), "no spec"))
    ) |>
    # filter: remove those who list postgraduate training NOT in family medicine
    dplyr::mutate(
      filter_postgrad_fammed_or_not_listed = !(!is.na(.data$postgrad) &
        !stringr::str_detect(tolower(.data$postgrad), "family medicine")) # nolint: indentation_linter.
    ) |>
    # filter: those working in excluded settings/institutions based on location name
    dplyr::mutate(
      filter_excluded_institution = !stringr::str_detect(tolower(.data$primary_location), excluded_institutions)
    ) |>
    # Some physicians have no specialty reported BUT a "practice restriction" that lets them practice family medicine independently # nolint: line_length_linter.
    # filter: those with practice restrictions that DO NOT let them practice independently in family medicine
    # all of these regex weirdnesses are for specific people. e.g. cpso 144135 "may medicine independently in family medicine" # nolint: line_length_linter.
    # some just say generically can only practice where they're experienced, shouldn't rule those out
    dplyr::mutate(
      filter_excl_nonfammed_practice_restrictions = (
        stringr::str_detect(tolower(.data$practice_restrictions), "terms: na") |
          # (
          # stringr::str_detect(tolower(.data$practice_restrictions), "restricted") &
          stringr::str_detect(
            tolower(.data$practice_restrictions),
            "(may practi(c|s)e family medicine)|(may (practi(c|s)e )*(medicine )*independently in family medicine)|(educated and experienced)" # nolint: line_length_linter.
          )
      )
    ) |>
    # Filter: those who WERE independent but their CURRENT registration is restricted
    dplyr::mutate(
      filter_not_cert_changed_from_indep_to_restricted = !(
        stringr::str_detect(tolower(.data$registration_class), "restricted")) & # nolint: indentation_linter.
        stringr::str_detect(tolower(.data$registration_history), "independent")
    )


  ## Filter: only docs with primary locations in Ontario. Removes docs without lat/lon coords
  docs_shp_filters <- docs_create_shape_with_ontario_filter(docs_filters, ontario_shp)

  ## FINALLY APPLY THE FILTERS TO CREATE A FACTOR COLUMN
  docs_shp_filters_classified <- dplyr::mutate(docs_shp_filters,
    doc_type = dplyr::if_all(dplyr::starts_with("filter")) |>
      factor(levels = c(TRUE, FALSE), labels = c("family", "other"))
  )

  return(docs_shp_filters_classified)
}

# nolint start
# docs_shp_filters <- docs_create_filters(docs_data_addnl)
# show_filter_counts(docs_shp_filters)
# nolint end

show_filter_counts <- function(docs_shp_filters,
                               filter_names = c(
                                 "filter_inontario",
                                 "filter_cert_indep_or_restricted",
                                 "filter_spec_fammed_or_not_listed",
                                 "filter_not_nospecialty_post2018grad",
                                 "filter_postgrad_fammed_or_not_listed",
                                 "filter_excluded_institution",
                                 "filter_not_cert_changed_from_indep_to_restricted",
                                 "filter_excl_nonfammed_practice_restrictions"
                               )) {
  step_num <- 1
  results <- dplyr::tibble(step = step_num, filter_name = "initial", included = nrow(docs_shp_filters), excluded = 0)

  then <- docs_shp_filters |>
    sf::st_drop_geometry()

  for (filter_name in filter_names) {
    step_num <- step_num + 1

    now <- then |>
      dplyr::filter(!!rlang::sym(filter_name))

    result <- dplyr::tibble(
      step = step_num,
      filter_name = filter_name,
      included = nrow(now),
      excluded = nrow(then) - nrow(now)
    )
    results <- dplyr::bind_rows(results, result)

    then <- now
  } # end for (filter_name in filter_names)

  # nolint start
  filter_descriptions <- dplyr::tribble(
    ~filter_name, ~description,
    "initial", "Initial data set collected from CPSO",
    "filter_inontario", "Exclude physicians with primary practice locations outside of Ontario",
    "filter_cert_indep_or_restricted", "Exclude physicians without Restricted or Indepedent Practice Certificates",
    "filter_spec_fammed_or_not_listed", "Exclude physicians who list a specialty that does not include Family Medicine",
    "filter_not_nospecialty_post2018grad", "Exclude physcians who graduated after 2018 AND who have No Specialty Listed",
    "filter_postgrad_fammed_or_not_listed", "Exclude physicians who list postgraduate training that does not include Family Medicine",
    "filter_excluded_institution", "Exclude physicians with primary practice locations in excluded institutions/settings based on keywords (e.g. 'sports medicine', 'anaesthesiology')",
    "filter_not_cert_changed_from_indep_to_restricted", "Exclude physicians who previously had independent practice certificates and now have restricted practice certificates",
    "filter_excl_nonfammed_practice_restrictions", "Exclude physicians who have practice restrictions that do not specify that they can practice family medicine independently"
  )
  # nolint end

  result_description <- dplyr::left_join(results, filter_descriptions, by = c("filter_name"))

  return(result_description)
}


# return regex of excluded institutions
get_excluded_institutions_regex <- function() {
  excluded_institutions_vector <-
    c(
      "875 carling", "addiction services", "addiction treatment",
      "anaesthesia", "anesthesia", "anesthesiology", "armoury", "athlete's care", "avantderm",
      "bethany lodge", "c a m h", "c f b", "c m p a", "camh", "canadian forces",
      "care of the elderly",
      "cancer", "cardiac", "cardiology", "casey house", "centre for addiction",
      "cf health services", "cfb", "cfs", "chartwell", "chronic headache",
      "civil aviation medicine", "cmpa", "complex continuing care",
      "coroner", "correctional centre", "cosmedx", "cosmetic", "cpm ottawa",
      "defense", "departement d'urgence",
      "dept of obstetrics", "dept of surgery", "department of surgery", "surgery department",
      "dermatology", "detention", "diagnostic imaging",
      "digestive health", "division of emergency", "dnd", "department of emergency",
      "emerg dept", "emergency department", "emergency dept", "emergency medicine",
      "emergency room", "emergency services", "er dept", "er department",
      "endocrinology", "endoscopy", "extendicare", "fertility centre",
      "geriatric", "global health",
      "general internal med", "health canada", "health care ethics",
      "heart institut", "hematology", "hospice", "hospital emergency",
      "hospitalist",
      "hyperbaric",
      "department of emergency services",
      "internal medicine",
      "inovo", "ltc facility", "lyte medical", "manulife", "med oncology",
      "medical imaging", "medical oncology", "medical policy", "medical protective",
      "methadone", "migration health branch", "national defence", "neupath centre for pain and spine",
      "newyoumedspa", "occupational health and safety", "of mental health",
      "omers, 100 adelaide", "oncology", "ontario shores", "operating room",
      "ophthalmic", "orthopaedic", "orthopedic", "ottawa public health",
      "pain care", "pain centre", "pain clinic", "pain management",
      "palliative", "palliative care", "physio", "postgraduate", "protection association",
      "psychiatry", "public health agency of canada", "pure spa", "raam clinic",
      "radiology",
      "radiologist", "rapson pain", "rbc insurance", "regen medical",
      "rehabilitation center", "research", "respirology", "retirement",
      "royal ottawa mental health centre",
      "savesight vision", "sexual health", "shouldice hospital", "sport",
      "start clinic", "substance use and concurrent", "suds clinic",
      "svcs", "temmy latner centre", "the institute of human mechanics",
      "thhn", "transport canada", "travel clinic", "travel medicine",
      "vein", "weight management clinic",
      "ori, 865 yorkmills rd, suite 20"
    )

  paste0(excluded_institutions_vector, collapse = "|")
}





#####

# newdocs <- dplyr::filter(docs_shp_filters, years_since_grad <= 5)


# newdocs |> dplyr::filter(stringr::str_detect(tolower(.data$specialties), "no spec"))
