# 2025 ONTARIO PHYSICIAN DATA

## Overview

This targets workflow uses the R language for statistical computing to process data from the CPSO (College of Physicians and Surgeons of Ontario) website for ALL available physician information. Data was collected in early January 2025 from publicly available sources in a separate project.

This repository includes the raw data collected (in a compressed RDS format), a geocoded version with active physicians localized to latitude/longitude coordinates (in GeoJson format), and a plaintext version that can be loaded using Excel or any other software (in CSV format).

## Data processing

The raw data has been processed to estimate which physicians are providing comprehensive family medicine
services to the community in Ontario. There is no easy way to determine this in Ontario: physicians with a specialtyin Family Medicine may not provide such services (e.g. they may work in sports medicine, or in a government agency), and physicians with "No Specialty" listed on the register may provide these services (e.g. because they registered with the CPSO prior to the requirement to register a specialty).

Using only public data, and so without access to billing data or other information, we have to use heuristics to make an informed guess about which physicians are doing family medicine in Ontario.

The present algorithm marks physicians as "family physicians" if they meet all of the following criteria:

1. Primary practice location in Ontario;
1. Specialty of "Family Medicine" or "No Specialty Listed";
1. Have practice certificates of type "Independent Practice" or "Restricted";
1. If they have "No Specialty Listed," they graduated more than 5 years ago;
1. Did not complete postgraduate training in a discipline other than Family Medicine;
1. Do not practice in an excluded institution based on keyword searches (e.g. "sports medicine");
1. Do not have a practice restriction that does not allow them to practice family medicine;
1. Have not had their registration class changed from "Independent" to "Restricted."

Physicians who meet all these criteria are assigned type "family," and those who do not are assigned type "other." This is because these criteria do not distinguish between physicians whose primary activity is practicing specialist medicine (e.g. cardiac surgery) and those whose primary activity is not practicing medicine (e.g. working with Health Canada).

## Working with the data and column definitions

The full data set, including inactive and retired physicians, is included as an RDS file. You can load it in the R Language for Statistical Computing. It is also included in a .zip file in the outputs directory. (As an uncompressed CSV, it's too big to host on GitHub).

The column names should hopefully be self explanatory, although I intend to document them more fully as time permits.

The "type" column indicates each physician's estimated type (family/other) as defined above, and columns whose names start with "filter" are boolean operationalizations of the filtering steps outlined above. Physicians are marker "family" if all "filter" columns are TRUE.

## Data sources

Physician data is from [the CPSO's online physician register](https://register.cpso.on.ca/).

Provincial boundary is from [Statistics Canada's 2021 administrative boundaries dataset](https://www12.statcan.gc.ca/census-recensement/alternative_alternatif.cfm?l=eng&dispext=zip&teng=lpr_000a21a_e.zip&k=%20%20%20%20%202712&loc=//www12.statcan.gc.ca/census-recensement/2021/geo/sip-pis/boundary-limites/files-fichiers/lpr_000a21a_e.zip).

## For more information, error reports, questions...

Please contact Christopher Belanger at cbela092@uottawa.ca.
