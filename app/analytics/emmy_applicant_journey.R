# PROJECT:  iv-cbv-payroll
# AUTHOR:   A.Chafetz | CMS
# REF ID:   456b1dc1
# PURPOSE:  visualize applicant journeys
# LICENSE:  MIT
# DATE:     2026-01-16
# UPDATED:  2026-01-22

# DEPENDENCIES ------------------------------------------------------------

library(tidyverse)
library(here)
library(arrow, warn.conflicts = FALSE)
library(glitr)
library(systemfonts)


# GLOBAL VARIABLES --------------------------------------------------------

ref_id <- "456b1dc1" #a reference to be places in viz captions

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


# SET KEY EVENTS -----------------------------------------------------------

v_steps <- c(
  "ApplicantViewedAgreement",
  "ApplicantAgreed",
  "ApplicantSelectedEmployerOrPlatformItem",
  "ApplicantAttemptedLogin",
  "ApplicantSucceededWithLogin",
  "ApplicantViewedPaymentDetails",
  "ApplicantSharedIncomeSummary"
)

v_steps_clean_alt <-
  tibble(event = v_steps) |>
  clean_events() |>
  pull()

v_steps_breaks_alt <- str_replace_all(v_steps_clean_alt, " ", "\n")


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

munge_journey <- function(df, applicant, pilot_pd = "Nov 2025") {
  df_story <- df |>
    dplyr::filter(
      distinct_id == applicant,
      pilot == pilot_pd
    ) |>
    dplyr::distinct(pilot, distinct_id, cbv_flow_id, timestamp, event, provider)

  df_story <- df_story |>
    dplyr::distinct(pilot, distinct_id, cbv_flow_id, ) |>
    tidyr::crossing(event = factor(v_steps, v_steps)) |>
    dplyr::arrange(cbv_flow_id, dplyr::desc(event)) |>
    dplyr::mutate(event = as.character(event)) |>
    dplyr::anti_join(
      df_story,
      by = dplyr::join_by(pilot, distinct_id, cbv_flow_id, event)
    ) |>
    dplyr::bind_rows(df_story)

  # df_story <- df_needed |>
  #   bind_rows(df_story)

  df_story <- df_story |>
    clean_events() |>
    dplyr::mutate(
      is_primary = event %in% v_steps,
      primary_event = dplyr::case_when(is_primary ~ event_clean),
    ) |>
    dplyr::group_by(cbv_flow_id) |>
    tidyr::fill(primary_event, .direction = "down") |>
    dplyr::ungroup() |>
    dplyr::group_by(cbv_flow_id, primary_event) |>
    dplyr::mutate(row = dplyr::row_number()) |>
    dplyr::ungroup() |>
    dplyr::mutate(
      primary_event = factor(primary_event, v_steps_clean_alt),
      plot_primary = dplyr::case_when(is_primary & row == 1 ~ row),
      plot_secondary = dplyr::case_when(row != 1 ~ row)
    )

  #Icon list - https://fontawesome.com/v4/cheatsheet/
  df_story <- df_story |>
    dplyr::mutate(
      fa_icon = dplyr::case_when(
        stringr::str_detect(event, "Failed") ~ "\uf071", #fa-exclamation-triangle
        stringr::str_detect(event, "Error") ~ "\uf00d", #fa-times
        event == "ApplicantViewedAgreement" ~ "\uf144", #fa-play-circle
        event == "ApplicantAgreed" ~ "\uf061", # fa-arrow-right
        event == "ApplicantSelectedEmployerOrPlatformItem" ~ "\uf00c", #fa-check
        event == "ApplicantAttemptedLogin" ~ "\uf023", #fa-lock
        event == "ApplicantSucceededWithLogin" ~ "\uf2b5", #fa-handshake-o
        event == "ApplicantViewedPaymentDetails" ~ "\uf002", #fa-search
        event == "ApplicantAccessedMissingResultsPage" ~ "\uf071", #fa-exclamation-triangle
        event == "ApplicantSharedIncomeSummary" ~ "\uf11e", #fa-flag-checkered
        event == "ApplicantSearchedForEmployer" ~ "\uf1e5", #fa-binoculars,
        stringr::str_detect(event, "Time") ~ "\uf254", #fa-hourglass,
        stringr::str_detect(event, "Help") ~ "\uf128" #fa-question,
      ),
      fill_color = ifelse(
        row == 1 & !is.na(timestamp),
        dsac_color['light_navy'],
        "#e0e0e0"
      ),
      icon_color = dplyr::case_when(
        is_primary & row == 1 ~ "white",
        str_detect(event, "Failed|Error|Help") ~ dsac_color['light_cranberry'],
        TRUE ~ "#909090"
      ),
      icon_size = ifelse(is_primary & row == 1, 6, 4),
      icon_vjust = ifelse(is_primary & row == 1, .5, -.8)
    )

  return(df_story)
}

plot_journey <- function(df, export = FALSE) {
  df_viz <- df |>
    dplyr::filter(!is.na(primary_event))

  v <- df_viz |>
    ggplot(aes(y = forcats::fct_rev(primary_event))) +
    geom_blank(aes(x = 10)) +
    geom_line(aes(row), color = "#909090") +
    geom_line(
      aes(x = 1, group = cbv_flow_id),
      na.rm = TRUE,
      color = "#909090"
    ) +
    geom_point(aes(plot_secondary), na.rm = TRUE, size = 4, color = "#909090") +
    geom_point(aes(plot_primary, color = fill_color), na.rm = TRUE, size = 11) +
    geom_text(
      aes(
        x = row,
        label = fa_icon,
        color = icon_color,
        vjust = icon_vjust,
        size = icon_size
      ),
      na.rm = TRUE,
      family = "Font Awesome 7 Free",
      fontface = "bold"
    ) +
    facet_grid(~cbv_flow_id) +
    scale_color_identity() +
    scale_size_identity() +
    scale_x_reverse() +
    scale_y_discrete(
      labels = rev(v_steps_breaks_alt),
      position = "right"
    ) +
    coord_cartesian(clip = "off") +
    si_style_nolines() +
    labs(
      x = NULL,
      y = NULL,
      caption = default_caption
    ) +
    theme(
      axis.text.x = element_blank(),
      axis.text.y = element_markdown(hjust = 0),
      strip.text = element_text(hjust = 1),
      panel.spacing = unit(.2, "lines")
    )

  if (export == TRUE) {
    glitr::si_save(
      glue("app/analytics/story_nov_{unique(df_story$distinct_id)}.png"),
      width = 6.73,
      height = 5.54
    )
  }

  return(v)
}


# PLOT  ---------------------------------------------------------------

v_test <- df_mp |>
  filter(pilot == "Nov 2025") |>
  distinct(distinct_id) |>
  slice_sample(n = 10) |>
  pull()

df_mp |>
  munge_journey("applicant-545499") |>
  plot_journey(export = FALSE)
