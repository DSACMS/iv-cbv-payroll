# PROJECT:  iv-cbv-payroll
# AUTHOR:   A.Chafetz | CMS
# REF ID:   b150156c
# PURPOSE:  visualize applicant journeys (tabular)
# LICENSE:  MIT
# DATE:     2026-01-12
# UPDATED:  2026-01-22

# DEPENDENCIES ------------------------------------------------------------

library(tidyverse)
library(here)
library(arrow, warn.conflicts = FALSE)
library(glitr)
library(gt)
library(systemfonts)

# GLOBAL VARIABLES --------------------------------------------------------

ref_id <- "b150156c" #a reference to be places in viz captions

#default viz/table caption
default_caption <- str_glue(
  "Source: Louisiana 2025 EMMY Pilot Mixpanel Data [accessed 2025-12-19] | Ref id: {ref_id}"
)

#identify paths for json data for each of the three periods
mp_path <- list.files(
  here("app/analytics"),
  "mixpanel.*parquet",
  full.names = TRUE
)


# IMPORT ------------------------------------------------------------------

df_mp <- read_parquet(mp_path)


# SET COLORS ---------------------------------------------------------------

#set DSAC colors
dsac_color <- c(
  "#103D68",
  "#136A5D",
  "#6A1344",
  "#EFAC2F",
  "#63789D",
  "#C1C9D7",
  "#5A9088",
  "#D9E8E5",
  "#842F66",
  "#123054"
)

dsac_color_name <- c(
  "navy",
  "teal",
  "cranberry",
  "gold",
  "light_navy",
  "pale_navy",
  "light_teal",
  "pale_teal",
  "light_cranberry",
  "dark_navy"
)

dsac_color <- setNames(dsac_color, dsac_color_name)

rm(dsac_color_name)

# FUNCTIONS ---------------------------------------------------------------

#clean event names for viz to add space and remove repetitive "applicant" text
clean_events <- function(df) {
  df |>
    dplyr::mutate(
      event_clean = event |>
        stringr::str_replace_all("(?<!^)([A-Z])", " \\1") |>
        stringr::str_remove("Applicant ") |>
        stringr::str_remove(" Or Platform Item") |>
        stringr::str_replace("M F A", "MFA") |>
        stringr::str_replace("C B V", "CBV"),
      .after = event
    )
}

follow_applicant <- function(df, applicant, pilot_pd = "Nov 2025") {
  df_viz <- df |>
    filter(
      distinct_id == applicant,
      pilot == pilot_pd,
      !event %in%
        c("ApplicantClickedCBVInvitationLink", "ApplicantClickedGenericLink")
    )

  df_viz <- df_viz |>
    mutate(
      flow_date = str_glue("CBV Flow: {cbv_flow_id} [{as_date(timestamp)}]")
    ) |>
    distinct(flow_date, timestamp, event, employer_name)

  df_viz <- df_viz |>
    mutate(
      employer_name = ifelse(
        event == "ApplicantFinishedSync" & is.na(employer_name),
        "[missing!]",
        employer_name
      ),
      status = case_when(
        str_detect(event, "Failed") ~ "exclamation-triangle",
        str_detect(event, "Error") ~ "xmark",
        employer_name == "[missing!]" ~ "exclamation-triangle",
        event == "ApplicantViewedAgreement" ~ "circle-play",
        event == "ApplicantAgreed" ~ "circle-right",
        event == "ApplicantSelectedEmployerOrPlatformItem" ~ "square-check",
        event == "ApplicantAttemptedLogin" ~ "door-closed",
        event == "ApplicantSucceededWithLogin" ~ "handshake",
        event == "ApplicantViewedPaymentDetails" ~ "magnifying-glass",
        event == "ApplicantAccessedMissingResultsPage" ~ "exclamation-triangle",
        event == "ApplicantSharedIncomeSummary" ~ "flag-checkered",
        event == "ApplicantSearchedForEmployer" ~ "binoculars",
        str_detect(event, "Help") ~ "circle-question"
      )
    ) |>
    clean_events() |>
    select(-c(event))

  df_viz |>
    gt(groupname_col = "flow_date") |>
    cols_move(status, after = timestamp) |>
    fmt_datetime(
      columns = c(timestamp),
      format = "%I:%M:%S %p"
    ) |>
    sub_missing(missing_text = "") |>
    fmt_icon(
      columns = c(status),
      fill_color = list(
        "exclamation-triangle" = dsac_color['gold'],
        "xmark" = dsac_color['light_cranberry'],
        "flag-checkered" = dsac_color['light_navy'],
        "binoculars" = "#909090",
        "circle-play" = "#909090",
        "circle-right" = "#909090",
        "square-check" = "#909090",
        "circle-question" = "#909090",
        "door-closed" = "#909090",
        "handshake" = "#909090",
        "magnifying-glass" = "#909090"
      ),
      height = "1.5em"
    ) |>
    cols_align(columns = c(status), align = "center") |>
    tab_options(column_labels.hidden = TRUE) |>
    tab_style(
      style = list(
        cell_fill(color = "#E5E5E5"),
        cell_text(weight = "bold")
      ),
      locations = cells_row_groups()
    )
}

# VIZ  -----------------------------------------------------------------

v_test <- df_mp |>
  filter(pilot == "Nov 2025") |>
  distinct(distinct_id) |>
  slice_sample(n = 10) |>
  pull()

follow_applicant(df_mp, v_test[1])
