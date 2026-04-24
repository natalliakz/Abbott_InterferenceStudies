# Install required R packages for Abbott Interference Study Analyzer
# Run this script once before using the app

message("Installing required packages...")

packages <- c(
  "shiny",
  "bslib",
  "dplyr",
  "tidyr",
  "ggplot2",
  "plotly",
  "gtsummary",
  "gt",
  "readr",
  "purrr",
  "broom",
  "bsicons",
  "scales"
)

# Install missing packages
installed <- rownames(installed.packages())
to_install <- packages[!packages %in% installed]

if (length(to_install) > 0) {
  message(sprintf("Installing: %s", paste(to_install, collapse = ", ")))
  install.packages(to_install, repos = "https://cloud.r-project.org")
} else {
  message("All packages already installed!")
}

# Verify installation
message("\nVerifying packages...")
for (pkg in packages) {
  if (requireNamespace(pkg, quietly = TRUE)) {
    message(sprintf("  %s: OK", pkg))
  } else {
    message(sprintf("  %s: FAILED", pkg))
  }
}

message("\nDone! You can now run: shiny::runApp('app.R')")
