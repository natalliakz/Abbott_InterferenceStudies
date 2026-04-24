# Abbott Manufacturing: ICH Q2 Interference Study Analyzer
# R Shiny Application with gtsummary for GxP-Compliant Reporting
#
# This project contains synthetic data created for demonstration purposes only.

library(shiny)
library(bslib)
library(dplyr)
library(tidyr)
library(ggplot2)
library(plotly)
library(gtsummary)
library(gt)
library(readr)
library(purrr)
library(broom)

# Configuration
ABBOTT_COLORS <- list(
  primary = "#003087",
  secondary = "#00A3E0",
  success = "#00843D",

  warning = "#FF6D00",
  danger = "#C8102E",
  light = "#F5F5F5"
)

# Load data
load_data <- function() {
  # Handle different execution contexts (shiny::runApp, source, etc.)
  if (exists("shiny.appfile")) {
    data_path <- file.path(dirname(get("shiny.appfile", envir = .GlobalEnv)), "data")
  } else {
    data_path <- "data"
  }

  if (!file.exists(file.path(data_path, "interference_studies.csv"))) {
    system(paste("python", file.path(data_path, "generate_data.py")))
  }

  studies <- read_csv(file.path(data_path, "interference_studies.csv"), show_col_types = FALSE) |>
    mutate(study_date = as.Date(study_date))

  limits <- read_csv(file.path(data_path, "decision_limits.csv"), show_col_types = FALSE)

  list(studies = studies, limits = limits)
}

data <- load_data()
studies_df <- data$studies
limits_df <- data$limits

# Statistical functions for EP07/ICH Q2 analysis
calculate_statistics <- function(data) {
  data |>
    group_by(interferent_concentration) |>
    summarise(
      n = n(),
      mean_measured = mean(measured_value),
      sd_measured = sd(measured_value),
      cv_percent = (sd_measured / mean_measured) * 100,
      mean_bias_pct = mean(bias_percent),
      sd_bias_pct = sd(bias_percent),
      baseline = first(baseline_value),
      se = sd_measured / sqrt(n),
      ci_lower = mean_measured - qt(0.975, n - 1) * se,
      ci_upper = mean_measured + qt(0.975, n - 1) * se,
      .groups = "drop"
    )
}

assess_interference <- function(stats_df, analyte, limits_df, spec_limit = 2.0) {
  limit_row <- limits_df |> filter(analyte == !!analyte)

  pct_limit <- if (nrow(limit_row) > 0 && !is.na(limit_row$percent_limit[1])) {
    limit_row$percent_limit[1]
  } else {
    spec_limit
  }

  stats_df |>
    mutate(
      assessment = case_when(
        interferent_concentration == 0 ~ "Baseline",
        abs(mean_bias_pct) > pct_limit ~ "OOS",
        abs(mean_bias_pct) > pct_limit * 0.5 ~ "Borderline",
        TRUE ~ "Pass"
      ),
      pct_limit = pct_limit
    )
}

# Equivalence test (TOST) for ICH Q2 validation
perform_tost <- function(data, equivalence_margin = 2.0) {
  baseline_data <- data |> filter(interferent_concentration == 0)
  test_data <- data |> filter(interferent_concentration > 0)

  if (nrow(baseline_data) < 3 || nrow(test_data) < 3) {
    return(NULL)
  }

  results <- test_data |>
    group_by(interferent_concentration) |>
    summarise(
      n_test = n(),
      mean_test = mean(measured_value),
      sd_test = sd(measured_value),
      .groups = "drop"
    ) |>
    mutate(
      baseline_mean = mean(baseline_data$measured_value),
      baseline_sd = sd(baseline_data$measured_value),
      n_baseline = nrow(baseline_data),
      diff = mean_test - baseline_mean,
      diff_pct = (diff / baseline_mean) * 100,
      pooled_se = sqrt(sd_test^2 / n_test + baseline_sd^2 / n_baseline),
      t_lower = (diff - (-equivalence_margin / 100 * baseline_mean)) / pooled_se,
      t_upper = (diff - (equivalence_margin / 100 * baseline_mean)) / pooled_se,
      df = n_test + n_baseline - 2,
      p_lower = 1 - pt(t_lower, df),
      p_upper = pt(t_upper, df),
      equivalent = p_lower < 0.05 & p_upper < 0.05
    )

  results
}

# UI
ui <- page_navbar(
  theme = bs_theme(
    primary = ABBOTT_COLORS$primary,
    secondary = ABBOTT_COLORS$secondary,
    success = ABBOTT_COLORS$success,
    warning = ABBOTT_COLORS$warning,
    danger = ABBOTT_COLORS$danger,
    "enable-rounded" = TRUE
  ),
  title = div(
    span("Abbott Manufacturing", style = "font-weight: bold;"),
    span(" | ICH Q2 Interference Analyzer", style = "font-size: 0.85em; color: #666;")
  ),

  sidebar = sidebar(
    width = 320,

    accordion(
      accordion_panel(
        "Study Selection",
        icon = bsicons::bs_icon("eyedropper"),
        selectInput("analyte", "Active Pharmaceutical Ingredient (API)",
                    choices = sort(unique(studies_df$analyte)),
                    selected = "Glucose"),
        selectInput("interferent", "Interferent/Excipient",
                    choices = sort(unique(studies_df$interferent)),
                    selected = "Hemolysis"),
        selectInput("pool_level", "Concentration Level",
                    choices = c("All", "Low", "Medium", "High"),
                    selected = "All")
      ),
      accordion_panel(
        "Acceptance Criteria",
        icon = bsicons::bs_icon("check-circle"),
        numericInput("spec_limit", "Specification Limit (±%)",
                     value = 2.0, min = 0.1, max = 20, step = 0.1),
        checkboxInput("use_tost", "Perform TOST Equivalence Test", value = TRUE),
        numericInput("equivalence_margin", "Equivalence Margin (±%)",
                     value = 2.0, min = 0.1, max = 10, step = 0.1)
      ),
      accordion_panel(
        "Data Upload",
        icon = bsicons::bs_icon("upload"),
        fileInput("upload_file", "Upload Assay Data (CSV)",
                  accept = c(".csv")),
        helpText("Upload chromatogram or assay results for instant analysis")
      ),
      open = c("Study Selection", "Acceptance Criteria")
    ),

    hr(),
    downloadButton("download_pdf", "Generate Validation Report", class = "btn-primary w-100 mb-2"),
    downloadButton("download_csv", "Export Results (CSV)", class = "btn-secondary w-100")
  ),

  nav_panel(
    "Spike & Recovery",
    icon = bsicons::bs_icon("graph-up"),
    layout_columns(
      card(
        card_header(
          class = "bg-primary text-white",
          "Dose-Response Curve"
        ),
        plotlyOutput("dose_response_plot", height = "400px")
      ),
      card(
        card_header(
          class = "bg-primary text-white",
          "Percent Recovery Plot"
        ),
        plotlyOutput("recovery_plot", height = "400px")
      ),
      col_widths = c(6, 6)
    ),
    card(
      card_header("Statistical Summary (gtsummary)"),
      gt_output("stats_gt_table")
    )
  ),

  nav_panel(
    "Pass/Fail Assessment",
    icon = bsicons::bs_icon("clipboard-check"),
    layout_columns(
      card(
        card_header(
          class = "bg-primary text-white",
          "Specification Compliance"
        ),
        plotlyOutput("assessment_plot", height = "400px")
      ),
      card(
        card_header(
          class = "bg-primary text-white",
          "Batch Disposition"
        ),
        uiOutput("disposition_card")
      ),
      col_widths = c(8, 4)
    ),
    card(
      card_header("OOS Investigation Support"),
      uiOutput("oos_details")
    )
  ),

  nav_panel(
    "Equivalence Test",
    icon = bsicons::bs_icon("arrow-left-right"),
    card(
      card_header(
        class = "bg-primary text-white",
        "Two One-Sided Tests (TOST) for Statistical Equivalence"
      ),
      plotlyOutput("tost_plot", height = "400px")
    ),
    card(
      card_header("TOST Results"),
      gt_output("tost_table")
    ),
    card(
      card_header("Interpretation"),
      uiOutput("tost_interpretation")
    )
  ),

  nav_panel(
    "AI Deviation Analysis",
    icon = bsicons::bs_icon("cpu"),
    card(
      card_header(
        class = "bg-warning",
        "Root Cause Analysis Assistant"
      ),
      p("When an interference study fails specifications, use this AI assistant to brainstorm potential root causes for your investigation report."),
      actionButton("analyze_deviation", "Analyze Deviation", class = "btn-warning mb-3"),
      verbatimTextOutput("ai_deviation_analysis")
    ),
    card(
      card_header("Data Standardization Preview"),
      p("AI-assisted cleanup of inconsistent metadata entries:"),
      gt_output("standardization_table")
    )
  ),

  nav_panel(
    "Audit Trail",
    icon = bsicons::bs_icon("journal-text"),
    card(
      card_header(
        class = "bg-secondary text-white",
        "Analysis Audit Log"
      ),
      gt_output("audit_table")
    ),
    card(
      card_header("Comparison: Manual vs Automated Workflow"),
      gt_output("comparison_table")
    )
  ),

  nav_spacer(),
  nav_item(
    tags$span(
      class = "text-muted small",
      "Synthetic Data - Demo Only"
    )
  )
)

# Server
server <- function(input, output, session) {

  # Reactive: Filtered data
  filtered_data <- reactive({
    data <- studies_df |>
      filter(analyte == input$analyte,
             interferent == input$interferent)

    if (input$pool_level != "All") {
      data <- data |> filter(pool_level == input$pool_level)
    }

    data
  })

  # Reactive: Statistics
  study_stats <- reactive({
    calculate_statistics(filtered_data())
  })

  # Reactive: Assessment
  assessment_data <- reactive({
    assess_interference(study_stats(), input$analyte, limits_df, input$spec_limit)
  })

  # Reactive: TOST results
  tost_results <- reactive({
    if (input$use_tost) {
      perform_tost(filtered_data(), input$equivalence_margin)
    } else {
      NULL
    }
  })

  # Dose-response plot
  output$dose_response_plot <- renderPlotly({
    data <- filtered_data()
    stats <- study_stats()

    p <- ggplot() +
      geom_point(data = data,
                 aes(x = interferent_concentration, y = measured_value),
                 alpha = 0.4, color = ABBOTT_COLORS$secondary) +
      geom_line(data = stats,
                aes(x = interferent_concentration, y = mean_measured),
                color = ABBOTT_COLORS$primary, linewidth = 1.2) +
      geom_point(data = stats,
                 aes(x = interferent_concentration, y = mean_measured),
                 color = ABBOTT_COLORS$primary, size = 4) +
      geom_ribbon(data = stats,
                  aes(x = interferent_concentration, ymin = ci_lower, ymax = ci_upper),
                  alpha = 0.2, fill = ABBOTT_COLORS$primary) +
      geom_hline(yintercept = stats$baseline[1], linetype = "dashed",
                 color = ABBOTT_COLORS$success) +
      labs(
        x = paste0(input$interferent, " (", data$interferent_unit[1], ")"),
        y = paste0(input$analyte, " (", data$analyte_unit[1], ")"),
        title = "Interference Dose-Response"
      ) +
      theme_minimal(base_size = 12) +
      theme(plot.title = element_text(face = "bold"))

    ggplotly(p, tooltip = c("x", "y"))
  })

  # Recovery plot
  output$recovery_plot <- renderPlotly({
    assessment <- assessment_data()
    baseline <- assessment$baseline[1]

    assessment <- assessment |>
      mutate(
        recovery_pct = (mean_measured / baseline) * 100,
        color = case_when(
          assessment == "OOS" ~ ABBOTT_COLORS$danger,
          assessment == "Borderline" ~ ABBOTT_COLORS$warning,
          TRUE ~ ABBOTT_COLORS$success
        )
      )

    p <- ggplot(assessment, aes(x = factor(interferent_concentration), y = recovery_pct)) +
      geom_col(aes(fill = color), color = "black", width = 0.7) +
      geom_hline(yintercept = 100, linetype = "solid", color = "black") +
      geom_hline(yintercept = 100 - input$spec_limit, linetype = "dashed",
                 color = ABBOTT_COLORS$danger) +
      geom_hline(yintercept = 100 + input$spec_limit, linetype = "dashed",
                 color = ABBOTT_COLORS$danger) +
      scale_fill_identity() +
      labs(
        x = paste0(input$interferent, " Concentration"),
        y = "% Recovery",
        title = paste0("Recovery (±", input$spec_limit, "% limits)")
      ) +
      theme_minimal(base_size = 12) +
      theme(plot.title = element_text(face = "bold"))

    ggplotly(p)
  })

  # gtsummary statistics table
  output$stats_gt_table <- render_gt({
    data <- filtered_data() |>
      mutate(
        conc_group = factor(
          interferent_concentration,
          labels = paste0(unique(interferent_concentration), " ", interferent_unit[1])
        )
      )

    data |>
      select(conc_group, measured_value, bias_percent) |>
      tbl_summary(
        by = conc_group,
        statistic = list(
          measured_value ~ "{mean} ({sd})",
          bias_percent ~ "{mean} ({sd})"
        ),
        label = list(
          measured_value ~ "Measured Value",
          bias_percent ~ "Bias (%)"
        ),
        digits = list(
          measured_value ~ 3,
          bias_percent ~ 2
        )
      ) |>
      add_n() |>
      modify_header(label = "**Statistic**") |>
      modify_caption(paste0("**", input$analyte, " Interference by ", input$interferent, "**")) |>
      as_gt() |>
      tab_options(
        table.font.size = px(12),
        heading.background.color = ABBOTT_COLORS$primary
      )
  })

  # Assessment plot
  output$assessment_plot <- renderPlotly({
    assessment <- assessment_data()

    colors <- case_when(
      assessment$assessment == "OOS" ~ ABBOTT_COLORS$danger,
      assessment$assessment == "Borderline" ~ ABBOTT_COLORS$warning,
      assessment$assessment == "Baseline" ~ ABBOTT_COLORS$light,
      TRUE ~ ABBOTT_COLORS$success
    )

    p <- ggplot(assessment, aes(x = factor(interferent_concentration), y = mean_bias_pct)) +
      geom_col(fill = colors, color = "black", width = 0.7) +
      geom_errorbar(aes(ymin = mean_bias_pct - sd_bias_pct,
                        ymax = mean_bias_pct + sd_bias_pct),
                    width = 0.2) +
      geom_hline(yintercept = 0, color = "black") +
      geom_hline(yintercept = input$spec_limit, linetype = "dashed",
                 color = ABBOTT_COLORS$danger) +
      geom_hline(yintercept = -input$spec_limit, linetype = "dashed",
                 color = ABBOTT_COLORS$danger) +
      annotate("rect", xmin = -Inf, xmax = Inf,
               ymin = -input$spec_limit, ymax = input$spec_limit,
               fill = ABBOTT_COLORS$success, alpha = 0.1) +
      labs(
        x = paste0(input$interferent, " Concentration"),
        y = "Bias (%)",
        title = "Specification Compliance Assessment"
      ) +
      theme_minimal(base_size = 12) +
      theme(plot.title = element_text(face = "bold"))

    ggplotly(p)
  })

  # Disposition card
  output$disposition_card <- renderUI({
    assessment <- assessment_data()
    oos_count <- sum(assessment$assessment == "OOS")
    borderline_count <- sum(assessment$assessment == "Borderline")
    pass_count <- sum(assessment$assessment == "Pass")

    if (oos_count > 0) {
      status <- "REJECT"
      status_color <- ABBOTT_COLORS$danger
      first_oos <- assessment |> filter(assessment == "OOS") |> pull(interferent_concentration) |> min()
      threshold_text <- paste0("OOS at ", input$interferent, " ≥", first_oos)
    } else if (borderline_count > 0) {
      status <- "REVIEW"
      status_color <- ABBOTT_COLORS$warning
      threshold_text <- "Borderline results require investigation"
    } else {
      status <- "RELEASE"
      status_color <- ABBOTT_COLORS$success
      threshold_text <- "All concentrations within specification"
    }

    div(
      style = "text-align: center; padding: 30px;",
      h1(status, style = paste0("color: ", status_color, "; font-size: 48px; margin-bottom: 10px;")),
      p(threshold_text, style = "font-weight: bold; font-size: 14px;"),
      hr(),
      div(
        style = "display: flex; justify-content: space-around; margin-top: 20px;",
        div(
          span(pass_count, style = paste0("font-size: 28px; font-weight: bold; color: ", ABBOTT_COLORS$success, ";")),
          p("Pass", style = "margin: 0;")
        ),
        div(
          span(borderline_count, style = paste0("font-size: 28px; font-weight: bold; color: ", ABBOTT_COLORS$warning, ";")),
          p("Borderline", style = "margin: 0;")
        ),
        div(
          span(oos_count, style = paste0("font-size: 28px; font-weight: bold; color: ", ABBOTT_COLORS$danger, ";")),
          p("OOS", style = "margin: 0;")
        )
      )
    )
  })

  # OOS details
  output$oos_details <- renderUI({
    assessment <- assessment_data()
    oos_rows <- assessment |> filter(assessment == "OOS")

    if (nrow(oos_rows) == 0) {
      return(div(
        class = "alert alert-success",
        icon("check-circle"),
        " No Out-of-Specification results detected. Batch meets ICH Q2 acceptance criteria."
      ))
    }

    div(
      class = "alert alert-danger",
      h5(icon("exclamation-triangle"), " OOS Investigation Required"),
      p("The following concentrations exceeded the specification limit of ±", input$spec_limit, "%:"),
      tags$ul(
        lapply(seq_len(nrow(oos_rows)), function(i) {
          tags$li(
            paste0(
              input$interferent, " = ", oos_rows$interferent_concentration[i],
              ": Bias = ", round(oos_rows$mean_bias_pct[i], 2), "%"
            )
          )
        })
      ),
      p(strong("Required Actions:")),
      tags$ol(
        tags$li("Document deviation in quality system"),
        tags$li("Perform root cause analysis (use AI Assistant tab)"),
        tags$li("Implement sample rejection criteria"),
        tags$li("Consider alternative analytical method")
      )
    )
  })

  # TOST plot
  output$tost_plot <- renderPlotly({
    tost <- tost_results()

    if (is.null(tost) || nrow(tost) == 0) {
      return(plotly_empty() |> layout(title = "No TOST results available"))
    }

    margin <- input$equivalence_margin

    p <- ggplot(tost, aes(x = factor(interferent_concentration), y = diff_pct)) +
      geom_point(aes(color = equivalent), size = 4) +
      geom_errorbar(aes(ymin = diff_pct - 1.96 * (pooled_se / baseline_mean * 100),
                        ymax = diff_pct + 1.96 * (pooled_se / baseline_mean * 100),
                        color = equivalent),
                    width = 0.2) +
      geom_hline(yintercept = 0, linetype = "solid") +
      geom_hline(yintercept = margin, linetype = "dashed", color = ABBOTT_COLORS$danger) +
      geom_hline(yintercept = -margin, linetype = "dashed", color = ABBOTT_COLORS$danger) +
      annotate("rect", xmin = -Inf, xmax = Inf,
               ymin = -margin, ymax = margin,
               fill = ABBOTT_COLORS$success, alpha = 0.15) +
      scale_color_manual(
        values = c("TRUE" = ABBOTT_COLORS$success, "FALSE" = ABBOTT_COLORS$danger),
        labels = c("TRUE" = "Equivalent", "FALSE" = "Not Equivalent"),
        name = "TOST Result"
      ) +
      labs(
        x = paste0(input$interferent, " Concentration"),
        y = "Difference from Baseline (%)",
        title = paste0("TOST Equivalence Test (±", margin, "% margin)")
      ) +
      theme_minimal(base_size = 12) +
      theme(plot.title = element_text(face = "bold"))

    ggplotly(p)
  })

  # TOST table
  output$tost_table <- render_gt({
    tost <- tost_results()

    if (is.null(tost) || nrow(tost) == 0) {
      return(gt(data.frame(Message = "Enable TOST in sidebar to view results")))
    }

    tost |>
      select(interferent_concentration, n_test, diff_pct, p_lower, p_upper, equivalent) |>
      gt() |>
      cols_label(
        interferent_concentration = "Concentration",
        n_test = "N",
        diff_pct = "Diff (%)",
        p_lower = "P (lower)",
        p_upper = "P (upper)",
        equivalent = "Equivalent"
      ) |>
      fmt_number(columns = c(diff_pct, p_lower, p_upper), decimals = 4) |>
      data_color(
        columns = equivalent,
        colors = scales::col_factor(
          palette = c(ABBOTT_COLORS$danger, ABBOTT_COLORS$success),
          domain = c(FALSE, TRUE)
        )
      ) |>
      tab_header(
        title = "TOST Equivalence Results",
        subtitle = paste0("α = 0.05, Margin = ±", input$equivalence_margin, "%")
      ) |>
      tab_options(
        heading.background.color = ABBOTT_COLORS$primary
      )
  })

  # TOST interpretation
  output$tost_interpretation <- renderUI({
    tost <- tost_results()

    if (is.null(tost) || nrow(tost) == 0) {
      return(p("Enable TOST equivalence testing in the sidebar."))
    }

    all_equivalent <- all(tost$equivalent)

    if (all_equivalent) {
      div(
        class = "alert alert-success",
        h5(icon("check-circle"), " Statistical Equivalence Demonstrated"),
        p("At all tested interferent concentrations, the mean measured values are ",
          strong("statistically equivalent"), " to baseline within the ±",
          input$equivalence_margin, "% margin (p < 0.05 for both one-sided tests)."),
        p("This satisfies ICH Q2(R1) specificity requirements for the tested range.")
      )
    } else {
      non_eq <- tost |> filter(!equivalent)
      div(
        class = "alert alert-warning",
        h5(icon("exclamation-triangle"), " Equivalence Not Demonstrated"),
        p("Statistical equivalence was NOT demonstrated at the following concentrations:"),
        tags$ul(
          lapply(non_eq$interferent_concentration, function(c) {
            tags$li(paste0(input$interferent, " = ", c))
          })
        ),
        p("Consider expanding the equivalence margin or investigating analytical root causes.")
      )
    }
  })

  # AI Deviation Analysis
  output$ai_deviation_analysis <- renderText({
    req(input$analyze_deviation)

    assessment <- assessment_data()
    oos_rows <- assessment |> filter(assessment == "OOS")

    if (nrow(oos_rows) == 0) {
      return("No OOS results to analyze. The study meets all specifications.")
    }

    # Simulated AI response (replace with actual API call in production)
    paste0(
      "=== AI ROOT CAUSE ANALYSIS ===\n",
      "Analyte: ", input$analyte, "\n",
      "Interferent: ", input$interferent, "\n",
      "OOS Concentrations: ", paste(oos_rows$interferent_concentration, collapse = ", "), "\n\n",
      "POTENTIAL ROOT CAUSES:\n\n",
      "1. CHEMICAL INTERACTION\n",
      "   - ", input$interferent, " may compete for binding sites on the assay antibody\n",
      "   - Possible spectral overlap at detection wavelength\n",
      "   - pH modification affecting enzyme kinetics\n\n",
      "2. MATRIX EFFECTS\n",
      "   - High ", input$interferent, " concentrations may alter sample viscosity\n",
      "   - Potential precipitation or turbidity interference\n",
      "   - Ion strength effects on electrochemical detection\n\n",
      "3. INSTRUMENT CONSIDERATIONS\n",
      "   - Check calibration status of analyzer\n",
      "   - Review reagent lot consistency\n",
      "   - Verify sample aspiration volume accuracy\n\n",
      "RECOMMENDED INVESTIGATIONS:\n",
      "- Run interference study with fresh reagent lot\n",
      "- Perform spike-and-recovery at intermediate concentrations\n",
      "- Compare results on alternate analytical platform\n",
      "- Review historical data for similar deviations\n\n",
      "Note: This analysis is AI-generated for brainstorming purposes only.\n",
      "All conclusions must be verified by qualified personnel."
    )
  })

  # Data standardization table (AI-assisted cleanup demo)
  output$standardization_table <- render_gt({
    tibble(
      original = c("Vit C", "Vit. C", "Ascorbic Acid", "L-Ascorbic acid", "vitamin c"),
      standardized = rep("Ascorbic Acid", 5),
      confidence = c(0.95, 0.94, 1.00, 0.98, 0.92)
    ) |>
      gt() |>
      cols_label(
        original = "Original Entry",
        standardized = "Standardized",
        confidence = "AI Confidence"
      ) |>
      fmt_percent(columns = confidence, decimals = 0) |>
      data_color(
        columns = confidence,
        colors = scales::col_numeric(
          palette = c(ABBOTT_COLORS$warning, ABBOTT_COLORS$success),
          domain = c(0.9, 1.0)
        )
      ) |>
      tab_header(
        title = "AI-Assisted Metadata Standardization",
        subtitle = "Harmonizing inconsistent interferent names"
      )
  })

  # Audit trail table
  output$audit_table <- render_gt({
    tibble(
      timestamp = format(Sys.time() - c(0, 60, 120, 180, 300), "%Y-%m-%d %H:%M:%S"),
      action = c(
        "Assessment completed",
        "Specification limit changed to ±2%",
        "Interferent filter applied: Hemolysis",
        "Analyte filter applied: Glucose",
        "Session initialized"
      ),
      user = rep("analyst@abbott.com", 5),
      details = c(
        paste0("Result: ", ifelse(sum(assessment_data()$assessment == "OOS") > 0, "OOS", "PASS")),
        "Previous: ±10%",
        "All pool levels selected",
        "Default selection",
        "Application started"
      )
    ) |>
      gt() |>
      cols_label(
        timestamp = "Timestamp",
        action = "Action",
        user = "User",
        details = "Details"
      ) |>
      tab_header(
        title = "Analysis Audit Trail",
        subtitle = "21 CFR Part 11 Compliant Logging"
      ) |>
      tab_options(
        heading.background.color = ABBOTT_COLORS$secondary
      )
  })

  # Comparison table (manual vs automated)
  output$comparison_table <- render_gt({
    tibble(
      feature = c("Data Entry", "Analysis", "Reporting", "Audit Trail", "Time per Study"),
      manual = c(
        "Manual import, cleaning via UI",
        "Point-and-click; risk of wrong test",
        "Copy-paste into Word/Excel",
        "Proprietary project files",
        "4+ hours"
      ),
      automated = c(
        "API/scheduled scripts",
        "Pre-validated, SOP-aligned functions",
        "Auto-generated Quarto PDFs",
        "Git version control",
        "10 seconds"
      )
    ) |>
      gt() |>
      cols_label(
        feature = "Feature",
        manual = "JMP/Minitab Workflow",
        automated = "Posit (Code-First) Workflow"
      ) |>
      tab_style(
        style = cell_fill(color = "#ffeeee"),
        locations = cells_body(columns = manual)
      ) |>
      tab_style(
        style = cell_fill(color = "#eeffee"),
        locations = cells_body(columns = automated)
      ) |>
      tab_header(
        title = "Workflow Comparison",
        subtitle = "Manual vs Automated Compliance"
      ) |>
      tab_options(
        heading.background.color = ABBOTT_COLORS$primary
      )
  })

  # Download handlers
  output$download_csv <- downloadHandler(
    filename = function() {
      paste0("interference_results_", input$analyte, "_", input$interferent, "_", Sys.Date(), ".csv")
    },
    content = function(file) {
      assessment_data() |>
        mutate(
          analyte = input$analyte,
          interferent = input$interferent,
          spec_limit = input$spec_limit,
          analysis_date = Sys.time()
        ) |>
        write_csv(file)
    }
  )

  output$download_pdf <- downloadHandler(
    filename = function() {
      paste0("ICH_Q2_Report_", input$analyte, "_", input$interferent, "_", Sys.Date(), ".html")
    },
    content = function(file) {
      # In production, this would render a Quarto document
      writeLines(
        paste0(
          "<html><body>",
          "<h1>ICH Q2 Interference Validation Report</h1>",
          "<p>Analyte: ", input$analyte, "</p>",
          "<p>Interferent: ", input$interferent, "</p>",
          "<p>Generated: ", Sys.time(), "</p>",
          "<p>This is a placeholder. In production, Quarto renders a full PDF.</p>",
          "</body></html>"
        ),
        file
      )
    }
  )
}

shinyApp(ui, server)
