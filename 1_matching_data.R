
library(dplyr)


#LOADING DATA
survey <- read.csv("data_raw/survey/survey.csv",stringsAsFactors = FALSE)

head(survey$ParticipantID)

survey$ParticipantID <- as.character(survey$ParticipantID)

#ACCESSING DANA DONATIONS
donation_files <- list.files("data_raw/donations",pattern = "\\.json$",full.names = TRUE)

donation_files

#EXTRACTING FILE PARTICIPANT ID FROM FILE NAMES
donations <- data.frame(donation_file = donation_files)

donations$ParticipantID <- basename(donations$donation_file)

#CLEANING PARTICIPANT ID NAMES FROM DATA DONATION FILE NAMES
donations$ParticipantID <- gsub("master_2121027_","",donations$ParticipantID)

donations$ParticipantID <- gsub("\\.json$","",donations$ParticipantID)

#CHECKING FOR DUPLICATE DONATION IDS
duplicate_donations <- donations %>% count(ParticipantID) %>% filter(n > 1)

print(duplicate_donations)
#No duplicate data donation packages are found.

#MATCHING SURVEY RESPONDENTS WITH THEIR DONATIONS
matched_data <- survey %>% left_join(donations, by = "ParticipantID")

#CHECKING WHICH SURVEY PARTICIPANTS DID NOT DONATE THEIR DATA
missing_donations <- matched_data %>%filter(is.na(donation_file))

nrow(missing_donations)

#24 survey participants could not be matched with their data donations.

sum(!is.na(matched_data$donation_file))
#22 survey participants could be matched with their data donations.

#CHECKING IF THERE ARE DONATIONS WITHOUT SURVEY
donations_without_survey <- donations %>%filter(!ParticipantID %in% survey$ParticipantID)

donations_without_survey
#There were 0 participants that donated data without doing the survey

#CHECKING IF THERE ARE ANY DUPLICATE PARTICIPANTS
duplicates <- matched_data %>% group_by(ParticipantID) %>% filter(n() > 1) %>%
  ungroup()
View(duplicates)
#There are 13 duplicate participants.

#REMOVING DUPLICATES AND KEEPING THE LATEST SURVEY RESPONSE
matched_data_clean <- matched_data %>% mutate(EndDate = as.POSIXct(EndDate, format = "%Y-%m-%d %H:%M:%S")) %>%
  group_by(ParticipantID) %>%
  slice_max(EndDate, n = 1, with_ties = FALSE) %>%
  ungroup()

#CHECKING IF REMOVAL WAS SUCCESSFUL
matched_data_clean %>% count(ParticipantID) %>%filter(n > 1)

#CHECKING HOW MANY PARTICIPANTS REMAIN
sum(!is.na(matched_data_clean$donation_file))
#16 participants remain after duplicate participants are removed.


#REMOVING SURVEY RESPONSES WITHOUT MATCHING DATA DONATIONS
matched_data_clean <- matched_data_clean %>% filter(!is.na(donation_file))

#VERIFYING THAT NO UNMATCHED RESPONSES REMAIN
sum(is.na(matched_data_clean$donation_file))

#CREATING OUTPUT DIRECTORY
dir.create(
  "data_processed",
  showWarnings = FALSE,
  recursive = TRUE
)

#SAVING CLEAN SURVEY DATA MATCHED WITH DATA DONATION PACKAGES
write.csv(
  matched_data_clean,
  "data_processed/survey_data_donations_matched_clean.csv",
  row.names = FALSE
)


