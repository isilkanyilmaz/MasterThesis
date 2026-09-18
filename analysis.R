# 1. PACKAGES AND FILE PATHS
library(tidyverse)
library(jsonlite)
library(lubridate)
library(psych)

STUDENT_NUMBER <- "2121027"

SURVEY_FILE <- "data_raw/survey/Master Thesis_September 18, 2026_20.59.csv"
DONATION_DIR <- "data_raw/donations"

dir.create("data_processed", showWarnings = FALSE)

# 2. IMPORTING AND CLEANING THE SURVEY
survey_raw <- read_csv(
  SURVEY_FILE,
  col_types = cols(.default = col_character()),
  show_col_types = FALSE)

survey <- survey_raw %>%
# Converting Qualtrics answers to start with R_
  filter(str_detect(ResponseId, "^R_")) %>%
  
# Converting empty strings to NA
  mutate(
    across(
      everything(),
      ~ na_if(str_trim(.x), "")))

#3. RECODING SURVEY VARIABLES
#Standardizing ParticipantID column and turning it into text
survey <- survey %>%
  mutate(
    participant_id = str_trim(as.character(ParticipantID)))
#checking for duplicate survey IDs
survey_id_check <- survey %>%
  count(participant_id, name = "n_survey_responses") %>%
  filter(n_survey_responses > 1)

survey_id_check
#this will be inspected if it returns row values, 
#if rows zero than it is not problematic 
survey <- survey %>%
  mutate(
    finished_num = parse_double(Finished),
    progress_num = parse_double(Progress),
    recorded_datetime = ymd_hms(
      RecordedDate,
      tz = "Europe/Amsterdam",
      quiet = TRUE)) %>%
  arrange(
    participant_id,
    desc(finished_num),
    desc(progress_num),
    desc(recorded_datetime)) %>%
  group_by(participant_id) %>%
  slice(1) %>%
  ungroup()
#used to make sure that no ParticipantID was generated twice
#recoding eligibility questions
CONSENT_YES <- "1"
AGE18_YES <- "4"
TIKTOK_OVER_MONTH_YES <- "1"
DONATION_REQUESTED_YES <- "1"
survey <- survey %>%
  mutate(
    age = parse_double(Q24),
    tiktok_experience_months = parse_double(Q28),
    self_reported_use_min_day = parse_double(Q8),
    
    consent_ok = Q1 == CONSENT_YES,
    age_screen_ok = Q9 == AGE18_YES,
    experience_screen_ok = Q35 == TIKTOK_OVER_MONTH_YES,
    donation_requested_ok = Q36 == DONATION_REQUESTED_YES,
    
    age_value_ok = !is.na(age) & age >= 18,
    experience_value_ok =
      !is.na(tiktok_experience_months) &
      tiktok_experience_months >= 1)
#handling participant TimeZone entries
#using TimeZone to ensure days are correctly divided for the rest of the calculations
resolve_timezone <- function(x) {
  
  x <- str_to_upper(str_trim(x))
  
  case_when(
    x %in% c(
      "CET",
      "CEST",
      "EUROPE/AMSTERDAM",
      "EUROPE/BERLIN"
    ) ~ "Europe/Amsterdam",
    
    x %in% c("UTC", "GMT") ~ "UTC",
    
    x %in% c("EET", "EEST") ~ "Europe/Helsinki",
    
    TRUE ~ "Europe/Amsterdam"
  )
}

survey <- survey %>%
  mutate(analysis_tz = resolve_timezone(Q31))
#4. CREATING THE 14-DAY OBSERVATION PERIOD
#each participant's day may end on different UTC data so need to convert days
#according to TimZone survey replies
safe_local_date <- function(datetime_utc, timezone) {
  
  if (is.na(datetime_utc) || is.na(timezone)) {
    return(NA_character_)
  }
  
  format(
    with_tz(datetime_utc, tzone = timezone),
    "%Y-%m-%d"
  )
}

survey <- survey %>%
  mutate(
    request_datetime_utc =
      ymd_hms(Q34_1, tz = "UTC", quiet = TRUE),
    
    request_date_chr =
      map2_chr(
        request_datetime_utc,
        analysis_tz,
        safe_local_date),observation_end_date = ymd(request_date_chr),
    
# inclusive 14-day period:
# end date + preceding 13 days
    observation_start_date =
      observation_end_date - days(13))

#5.CALCULATING TTAS SCORE ITEMS
ttas_salience_items <- c(
  "Q17_1",
  "Q17_2")

ttas_mood_items <- c(
  "Q18_1",
  "Q18_2")

ttas_tolerance_items <- c(
  "Q19_1",
  "Q19_2",
  "Q19_3")

ttas_withdrawal_items <- c(
  "Q20_1",
  "Q20_2")

ttas_conflict_items <- c(
  "Q21_1",
  "Q21_2",
  "Q21_3",
  "Q21_4")

ttas_relapse_items <- c(
  "Q22_1",
  "Q22_2")

ttas_items <- c(
  ttas_salience_items,
  ttas_mood_items,
  ttas_tolerance_items,
  ttas_withdrawal_items,
  ttas_conflict_items,
  ttas_relapse_items)

#converting items to 1-5

parse_likert <- function(x) {
  
  value <- parse_double(x)
  
  ifelse(
    value %in% 1:5,
    value,
    NA_real_
  )
}

survey <- survey %>%
  mutate(
    across(
      all_of(ttas_items),
      parse_likert))
#adding in the rule that TTAS can be calculated 
#when at least 12 of the 15 items are answered
#if one to three are missing, 
#using the respondent's mean over the available items

survey <- survey %>%
  mutate(
    ttas_n_answered =
      rowSums(!is.na(across(all_of(ttas_items)))),
    
    ttas_score =
      if_else(
        ttas_n_answered >= 12,
        rowMeans(
          across(all_of(ttas_items)),
          na.rm = TRUE
        ),
        NA_real_))
#calculating exploratory TTAS factors

survey <- survey %>%
  mutate(
    ttas_salience =
      rowMeans(
        across(all_of(ttas_salience_items)),
        na.rm = FALSE),
    
    ttas_mood_modification =
      rowMeans(
        across(all_of(ttas_mood_items)),
        na.rm = FALSE),
    
    ttas_tolerance =
      rowMeans(
        across(all_of(ttas_tolerance_items)),
        na.rm = FALSE),
    
    ttas_withdrawal =
      rowMeans(
        across(all_of(ttas_withdrawal_items)),
        na.rm = FALSE),
    
    ttas_conflict =
      rowMeans(
        across(all_of(ttas_conflict_items)),
        na.rm = FALSE),
    
    ttas_relapse =
      rowMeans(
        across(all_of(ttas_relapse_items)),
        na.rm = FALSE))

