# MasterThesis
This repository is an R-based data processing and analysis repository for my Master's thesis examining Self-Reported and Trace-Based Measures of Compulsive TikTok Use.

Please find below all the information necessary to replicate this Master's thesis:

## Repository Structure

MasterThesis/
|
|-- data_raw/
|   |-- survey/
|   |   `-- Master Thesis_September 18, 2026_20.59.csv
|   |
|   `-- donations/
|       |-- master_2121027_47.json
|       |-- master_2121027_103.json
|       |-- master_2121027_215.json
|       `-- ...
|
|-- data_processed/
|
`-- analysis.R

Some notes about the Repository Structure:

*data_raw/survey/* contains the raw Qualtrics survey export.
*data_raw/donations/* contains the anonymized TikTok JSON data donations from participants.
*data_processed/* contains datasets generated after cleaning, transforming, and combining the raw data.
*analysis.R* contains the R code for importing, cleaning, processing, constructing variables, and analyzing the data.

The project requires the following R packages: "tidyverse", "jsonlite", "lubridate","psych".

To replicate this study, please clone the repository, install the required packages, maintain the folder structure shown above, and run analysis.R from the project root directory. 
