# Quick launcher for the R Shiny app
# Run with: Rscript run_app.R

message("Starting Abbott ICH Q2 Interference Analyzer...")
message("Open browser to: http://localhost:8050")

shiny::runApp("app.R", port = 8050, launch.browser = FALSE)
