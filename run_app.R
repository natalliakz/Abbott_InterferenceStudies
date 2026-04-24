# Abbott ICH Q2 Interference Study Analyzer - Launcher
# Run with: Rscript run_app.R

# Check for required packages
required_packages <- c("shiny", "bslib", "dplyr", "ggplot2", "plotly", "gtsummary", "gt", "readr", "bsicons")
missing <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]

if (length(missing) > 0) {
  message("Missing packages: ", paste(missing, collapse = ", "))
  message("Run 'Rscript install_packages.R' first.")
  quit(status = 1)
}

message("========================================")
message("Abbott ICH Q2 Interference Study Analyzer")
message("========================================")
message("")
message("Starting Shiny app on port 8050...")
message("Open your browser to: http://localhost:8050")
message("")
message("Press Ctrl+C to stop the server.")
message("")

shiny::runApp("app.R", port = 8050, launch.browser = FALSE, host = "0.0.0.0")
