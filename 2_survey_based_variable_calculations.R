
library(dplyr)
library(tidyr)

#LOADING MATCHED DATA SET

data <- read.csv("data_processed/survey_data_donations_matched_clean.csv")

data$ParticipantID <- as.character(data$ParticipantID)

#SELECTING THE 15 TTAS ITEMS
ttas_items <- data %>%
  select(Q17_1, Q17_2, Q18_1, Q18_2, Q19_1, Q19_2, Q19_3,
         Q20_1, Q20_2, Q21_1, Q21_2, Q21_3, Q21_4, Q22_1, Q22_2)

#CONVERTING TTAS ANSWERS TO NUMBERS
ttas_items <- ttas_items %>% mutate(across(everything(), ~as.numeric(.)))

#CALCULATING TTAS: AT LEAST 12 OF 15 ITEMS MUST BE ANSWERED
data <- data %>%
  mutate(
    ttas_items_answered = rowSums(!is.na(ttas_items)),
    ttas_score = ifelse(
      ttas_items_answered >= 12,
      rowMeans(ttas_items, na.rm = TRUE),
      NA_real_))

#RENAMING VARIABLES IN THE SURVEY AND CONVERTING TO NUMERIC
#Q8 = SELF-REPORTED TIKTOK USE; Q24 = AGE ; Q28 = TIKTOK EXPERIENCE IN MONTHS
data <- data %>%
  mutate(
    self_reported_use = as.numeric(Q8),
    age = as.numeric(Q24),
    tiktok_experience = as.numeric(Q28),
    gender = factor(
      Q26,
      levels = c(1, 2, 3, 4),
      labels = c("Male", "Female",
                 "Non-binary/Third gender", "Prefer not to say")))

#CHECKING IF ALL REMAINING PARTICIPANTS FIT THE ELIGIBILITY REQUIREMENTS
#CHECKING AGE AND TIKTOK EXPERIENCE
summary(data$age)
#Mean age of participants is 26.31.

summary(data$tiktok_experience)
#Mean TikTok experience of participants is 52.56.

sum(is.na(data$age) | data$age <18)
#No participant is below the age of 18.

sum(is.na(data$tiktok_experience) | data$tiktok_experience < 12)
#No participant had been using TikTok less than 12 months.

#CHECKING GENDER CODES
table(data$gender, useNA = "ifany")
#3 participants had disclosed their gender as Male and 13 participants had disclosed their gender as Female.

#CHECKING TTAS COMPLETENESS
sum(is.na(data$ttas_score))
#All TTAS scores are present.

#SAVING DATASET WITH SURVEY-BASED VARIABLES
write.csv(data,"data_processed/survey_variables_clean.csv",row.names = FALSE)
