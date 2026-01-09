# PROJECT:  iv-cbv-payroll
# AUTHOR:   A.Chafetz | CMS
# PURPOSE:  initial munging of Mixpanel json data
# LICENSE:  MIT
# DATE:     2025-12-11
# UPDATED:  2026-01-08

# DEPENDENCIES ------------------------------------------------------------

library(tidyverse)
library(here)
library(arrow, warn.conflicts = FALSE)
library(jsonlite, warn.conflicts = FALSE)

# GLOBAL VARIABLES --------------------------------------------------------

#identify json files
paths <- list.files(here("app/analytics"), "mixpanel.*json", full.names = TRUE)

#print paths
basename(paths)

# IMPORT FUNCTION ---------------------------------------------------------

# function to read the JSON file & convert to tibble, keeping properties as a nest list
# read_mp <- function(path) {
#   json <- readr::read_lines(path) |> purrr::map(jsonlite::fromJSON)

#   df <-
#     tibble::tibble(
#       event = purrr::map_chr(json, ~ .x$event),
#       properties = purrr::map(json, ~ .x$properties),
#       timestamp = purrr::map_chr(json, ~ .x$timestamp)
#     )

#   return(df)
# }

# IMPORT ------------------------------------------------------------------

#read in data (November pilot)
# df_import <- paths |>
#   str_subset("2025-11") |>
#   read_mp()

#read in all pilot data
# df_import <- paths |> map(read_mp) |> list_rbind()

#read in data (November pilot)
# df_import <- paths |>
#   str_subset("2025-11") |>
#   read_json_arrow()

#read in all pilot data
df_import <- paths |> map(read_json_arrow) |> list_rbind()

# MUNGE -------------------------------------------------------------------

#convert time to a time variable and identify pilot period
df_import <- df_import |>
  mutate(
    timestamp = as_datetime(timestamp),
    pilot = case_match(
      month(timestamp),
      c(5, 6) ~ "May 2025",
      c(8, 9) ~ "Aug 2025",
      c(11, 12) ~ "Nov 2025"
    ),
    pilot = factor(pilot, c("May 2025", "Aug 2025", "Nov 2025")),
  )

# extract applicant and flow ids from the nested properties list
df_import <- df_import %>%
  mutate(
    distinct_id = properties$distinct_id,
    cbv_flow_id = properties$cbv_flow_id,
  )

#extract type from event to make events generic
df_import <- df_import |>
  mutate(
    provider = str_extract(event, "Pinwheel|Argyle"),
    event = str_remove(event, "Pinwheel|Argyle")
  )

#grab additional property variables needed in analysis
df_import <- df_import |>
  mutate(
    device_type = properties$device_type,
    origin = properties$origin,
    employer_name = properties$employment_employer_name
  )

# SUBSET ------------------------------------------------------------------

#fill missing client_agency_ids and then filter out those that are not LA
df_import <- df_import |>
  mutate(client_agency_id = properties$client_agency_id) |>
  group_by(distinct_id) |>
  fill(client_agency_id, .direction = "downup") |>
  ungroup() |>
  filter(client_agency_id == "la_ldh") |>
  select(-client_agency_id)

#drop page view events - no property data useful in analysis
df_import <- df_import |>
  filter(event != "CbvPageView")

#remove events without CBV flow id (case workers + timeouts)
df_import <- df_import |>
  filter(!is.na(cbv_flow_id))
# filter(!is.na(cbv_flow_id) | event != "CaseworkerInvitedApplicantToFlow")

#convert distinct_id to applicant from caseworker to determine number invited
# df_import <- df_import |>
#   filter(event == "CaseworkerInvitedApplicantToFlow") |>
#   mutate(distinct_id = paste0("applicant-",properties$cbv_applicant_id)) |>
#   count(pilot)

# TIDY --------------------------------------------------------------------

#reorder variables
df_import <- df_import |>
  relocate(distinct_id, cbv_flow_id, timestamp, pilot, .before = everything())

#arrange time descending (most recent events on top by user)
df_import <- df_import |>
  arrange(distinct_id, desc(timestamp))

#drop properties nested tibble to save as a parquest file
df_import <- df_import |>
  select(-properties)

# EXPORT ------------------------------------------------------------------

df_import |>
  write_parquet(here("app/analytics/mixpanel_la_pilots.parquet"))
