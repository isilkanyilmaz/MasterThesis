
library(dplyr)
library(jsonlite)

# LOADING SURVEY DATA AND CREATING OUTPUT FOLDER
matched_data <- read.csv("data_processed/survey_variables_clean.csv",
                         stringsAsFactors = FALSE)
matched_data$ParticipantID <- as.character(matched_data$ParticipantID)

dir.create("data_processed", recursive = TRUE,
           showWarnings = FALSE)

# PREPARING DATA-REQUEST DATES AND TIME ZONES
matched_data$request_date <- as.Date(substr(matched_data$Q34_1, 1, 10))
matched_data$timezone <- NA_character_
matched_data$timezone[which(matched_data$Q31 == 1)] <- "Europe/Amsterdam"
matched_data$timezone[which(matched_data$Q31 == 2)] <- "Europe/Istanbul"
matched_data$timezone[which(matched_data$Q31 == 3)] <- "America/Toronto"

# PREPARING EMPTY LISTS FOR ALL PARTICIPANTS
all_events <- list()
all_sessions <- list()
all_traces <- list()
all_coverage <- list()

# GOING THROUGH EACH PARTICIPANT'S DONATION
for (i in 1:nrow(matched_data)) {

  participant_id <- matched_data$ParticipantID[i]
  donation_file <- matched_data$donation_file[i]
  request_date <- matched_data$request_date[i]
  timezone <- matched_data$timezone[i]

  #SKIPPING MISSING DONATION FILES
  if (is.na(donation_file) || !file.exists(donation_file)) {
    print(paste("Missing donation:", participant_id))
    next
  }

  #READING THE VIEWING HISTORY FROM THE JSON FILE AND PRINTING PARTICIPANTS
  #WITH MISSING FILES
  donation <- fromJSON(donation_file)
  history_list <- donation$tiktok_video_browsing_history

  if (is.null(history_list) || length(history_list) == 0) {
    print(paste("No viewing history:", participant_id))
    next
  }

  history <- history_list[[1]]

  if (!is.data.frame(history) || nrow(history) == 0) {
    print(paste("Empty viewing history:", participant_id))
    next
  }

  if (!all(c("Time and Date", "Video watched") %in% names(history))) {
    print(paste("Missing history columns:", participant_id))
    next
  }

  #CONVERTING VIEWING TIMES TO UTC AND SORTING FROM FIRST TO LAST
  history$timestamp <- as.POSIXct(history[["Time and Date"]],
                                  format = "%Y-%m-%d %H:%M:%S UTC", tz = "UTC")
  history <- history %>%
    filter(!is.na(timestamp)) %>%
    arrange(timestamp)

  if (nrow(history) == 0) next

  #EXTRACTING VIDEO URLS AND VIDEO IDS
  history$video_url <- as.character(history[["Video watched"]])
  history$video_id <- NA_character_
  valid_urls <- !is.na(history$video_url) &
    grepl("/video/[0-9]+", history$video_url)
  history$video_id[valid_urls] <- sub(".*?/video/([0-9]+).*", "\\1",
                                      history$video_url[valid_urls])


  # A NEW SESSION STARTS WHEN THE GAP BETWEEN VIDEOS IS OVER 105 SECONDS.
  history <- history %>%
    mutate(
      gap_seconds = as.numeric(difftime(timestamp, lag(timestamp), units = "secs")),
      new_session = is.na(gap_seconds) | gap_seconds > 105,
      session_id = cumsum(new_session)
    )

  full_sessions <- history %>%
    group_by(session_id) %>%
    summarise(
      session_start = min(timestamp),
      session_end = max(timestamp),
      videos_watched = n(),
      .groups = "drop"
    ) %>%
    arrange(session_start)

  #SESSION DURATION CALCULATIONS
  #SESSIONS WITH ONLY ONE VIDEO RECEIVES A DURATION OF ONE MINUTE.
  full_sessions$session_duration <- as.numeric(difftime(
    full_sessions$session_end, full_sessions$session_start, units = "mins"))
  full_sessions$session_duration[full_sessions$videos_watched == 1] <- 1

  #TIME BETWEEN SESSIONS CALCULTAIONS
  full_sessions$time_between_sessions <- as.numeric(difftime(
    lead(full_sessions$session_start), full_sessions$session_end, units = "mins"))

  full_sessions$ParticipantID <- participant_id
  full_sessions$ttas_score <- matched_data$ttas_score[i]
  full_sessions$content_diversity <- NA_real_

  full_sessions <- full_sessions %>%
    mutate(session_start = as.character(session_start),
           session_end = as.character(session_end)) %>%
    select(ParticipantID, session_id, session_start, session_end,
           session_duration, time_between_sessions, videos_watched,
           ttas_score, content_diversity)

  events <- history %>%
    mutate(ParticipantID = participant_id,
           timestamp = as.character(timestamp)) %>%
    select(ParticipantID, session_id, timestamp, video_url, video_id)

  all_sessions[[length(all_sessions) + 1]] <- full_sessions
  all_events[[length(all_events) + 1]] <- events

  #14-DAY VIEWING HISTORY (FOR TRACE-BASED TIKTOK USE)
  videos_14_days <- NA_integer_

  if (!is.na(request_date) && !is.na(timezone)) {

    short_history <- history
    short_history$viewing_date <- as.Date(short_history$timestamp, tz = timezone)

    short_history <- short_history %>%
      filter(viewing_date >= request_date - 13,
             viewing_date <= request_date) %>%
      arrange(timestamp)

    videos_14_days <- nrow(short_history)

    if (videos_14_days > 0) {
      #CALCULATING SESSIONS AGAIN FOR 14-DAY OBSERVATION WINDOW
      short_history <- short_history %>%
        mutate(
          gap_seconds = as.numeric(difftime(timestamp, lag(timestamp), units = "secs")),
          new_session = is.na(gap_seconds) | gap_seconds > 105,
          session_id = cumsum(new_session)
        )

      short_sessions <- short_history %>%
        group_by(session_id) %>%
        summarise(
          session_start = min(timestamp),
          session_end = max(timestamp),
          videos_watched = n(),
          .groups = "drop"
        )

      short_sessions$session_duration <- as.numeric(difftime(
        short_sessions$session_end, short_sessions$session_start, units = "mins"))
      short_sessions$session_duration[short_sessions$videos_watched == 1] <- 1

      #CALCULATING TRACE-BASED TIKTOK USE
      trace_row <- data.frame(
        ParticipantID = participant_id,
        trace_based_use = sum(short_sessions$session_duration) / 14,
        number_of_sessions = nrow(short_sessions),
        number_of_videos = nrow(short_history),
        days_with_activity = n_distinct(short_history$viewing_date),
        first_viewing_date = as.character(min(short_history$viewing_date)),
        last_viewing_date = as.character(max(short_history$viewing_date))
      )

      all_traces[[length(all_traces) + 1]] <- trace_row
    }
  }

  #RECORDING HOW MUCH HISTORY EACH PARTICIPANT DONATED
  coverage_row <- data.frame(
    ParticipantID = participant_id,
    total_views = nrow(history),
    full_history_sessions = nrow(full_sessions),
    views_14_days = videos_14_days,
    first_recorded_utc = as.character(min(history$timestamp)),
    last_recorded_utc = as.character(max(history$timestamp)),
    observation_span_days = as.numeric(difftime(
      max(history$timestamp), min(history$timestamp), units = "days"))
  )

  all_coverage[[length(all_coverage) + 1]] <- coverage_row
}

# COMBINING DATA FROM ALL PARTICIPANTS
if (length(all_sessions) == 0) stop("No usable viewing histories found.")

viewing_events <- bind_rows(all_events)
sessions <- bind_rows(all_sessions)
coverage_table <- bind_rows(all_coverage)

#KEEPING AN EMPTY DATASET WITH THE CORRECT COLUMNS IF THERE ARE NO 14-DAY TRACES.
participant_traces <- data.frame(
  ParticipantID = character(), trace_based_use = numeric(),
  number_of_sessions = integer(), number_of_videos = integer(),
  days_with_activity = integer(), first_viewing_date = character(),
  last_viewing_date = character()
)
if (length(all_traces) > 0) participant_traces <- bind_rows(all_traces)

#CHECKING OUTPUTS FOR REPORTING
print(nrow(viewing_events))
#There are 563,613 viewing events.

print(nrow(sessions))
#There are 29198 sessions.

print(nrow(participant_traces))
#12  participants had usable viewing records.

# SAVING THE SAME FOUR FILES AS THE ORIGINAL SCRIPT
write.csv(viewing_events, "data_processed/viewing_events.csv", row.names = FALSE)
write.csv(sessions, "data_processed/sessions.csv", row.names = FALSE)
write.csv(participant_traces, "data_processed/participant_traces.csv", row.names = FALSE)
write.csv(coverage_table, "data_processed/history_coverage.csv", row.names = FALSE)
