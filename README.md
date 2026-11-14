# MasterThesis
This repository is an R-based data processing and analysis repository for my Master's thesis called "Beyond Screen Time: Self-Reported and Trace-Based Measures of Compulsive TikTok Use".

This thesis investigates how compulsive TikTok use is reflected in users' behavioral patterns, going beyond traditional screen-time measures to examine session duration, time between sessions, and content diversity. By combining self-reported survey responses with anonymized TikTok data donations and video metadata, the study reconstructs users'  platform activity and examines how compulsive use moderates relationships between behavioral engagement measures. In addition, this thesis explores if self-reported and trace-based TikTok use measures show different associations with compulsive use. This repository includes R and Python scripts for data matching, cleaning, session calculation, metadata enrichment, variable calculation, descriptive analysis and hypothesis testing. 
Please find below all the information necessary to replicate this Master's thesis:

## Repository Structure

```text

MasterThesis/
|
|-- 1_matching_data.R
|-- 2_survey_based_variable_calculations.R
|-- 3_trace_based_variable_calculations.R
|-- 4_data_enrichment_with_pyktok.py
|-- 5_calculating_content_diversity.R
|-- 6_preparing_analysis_data.R
|-- 7_descriptive_analysis.R
|-- 8_model_testing.R
|
|-- data_raw/
|
|-- data_processed/
|
`-- results/

```

### Some notes about the Repository Structure:

*data_raw/survey/* contains the raw Qualtrics survey export.

*data_raw/donations/* contains the anonymized TikTok JSON data donations from participants.

*data_processed/* contains datasets generated after cleaning, transforming, and combining the raw data.

*results/* contains the 2 folders inside. *results/descriptives_outputs* contains all figures and tables created for reporting. *results/regression_outputs* contains the results of hypothesis testing.

This project uses R and Python for processing TikTok data donations,calculating behavioral variables, enriching video metadata,
performing descriptive analyses, and testing hypotheses.

### Required R packages:

The following R packages are required:

- dplyr
- tidyr
- jsonlite
- ggplot2
- gt
- psych
- webshot2
- fixest

Install all required R packages by running:

```r
install.packages(c(
  "dplyr",
  "tidyr",
  "jsonlite",
  "ggplot2",
  "gt",
  "psych",
  "webshot2",
  "fixest"
))
```

### Required Python packages:

The Python metadata enrichment script requires:

- requests
- beautifulsoup4

Install the required packages using:

```bash
python3 -m pip install requests beautifulsoup4
```

### Additional Requirements:

- R and Python must be installed.
- Google Chrome or another compatible Chromium browser may be
  required to export formatted gt tables as PNG images.
- An internet connection is required for retrieving TikTok video metadata.

To replicate this study, please clone the repository, install the required packages, maintain the folder structure shown above, and run the R and Python scripts from the project root directory. 
