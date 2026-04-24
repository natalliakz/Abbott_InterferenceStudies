# Abbott Manufacturing: ICH Q2 Interference Study Analyzer

A comprehensive Posit demonstration showcasing the transition from point-and-click tools (JMP, Minitab) to an automated, GxP-compliant code-first pipeline for pharmaceutical interference/specificity studies.

**DISCLAIMER:** This project contains synthetic data and analysis created for demonstration purposes only.

## Quick Start (Posit Workbench / RStudio)

```bash
# 1. Clone the repository
git clone https://github.com/natalliakz/Abbott_InterferenceStudies.git
cd Abbott_InterferenceStudies

# 2. Install R packages (run once)
Rscript install_packages.R

# 3. Run the Shiny app
R -e "shiny::runApp('app.R', port = 8050)"
```

Or in RStudio: Open `app.R` and click **Run App**.

## The Shift: Manual to Automated Compliance

| Feature | JMP/Minitab Workflow | Posit (Code-First) Workflow |
|---------|---------------------|----------------------------|
| **Data Entry** | Manual import, cleaning via UI | Automated data pulling via APIs or scheduled scripts |
| **Analysis** | Point-and-click; risk of choosing wrong test | Pre-validated, hardcoded functions aligned with SOPs |
| **Reporting** | Copy-pasting plots into Word/Excel | Auto-generated, reproducible Quarto PDFs |
| **Audit Trail** | Proprietary project files | Git-backed version control tracking every keystroke |
| **Time per Study** | 4+ hours | 10 seconds |

## Why This Matters for Pharma

In pharmaceutical interference studies, human intervention is a **risk**. JMP and Minitab rely on operators clicking the right buttons in the right order. Posit transforms an interference study from an "event" into an automated **pipeline**.

## Features

### R Shiny Dashboard (`app.R`) - Primary Demo

A GxP-compliant application featuring:

- **Spike & Recovery Analysis** with interactive dose-response plots
- **Pass/Fail Assessment** against configurable specification limits (default ±2%)
- **TOST Equivalence Testing** for ICH Q2 statistical validation
- **gtsummary Tables** for publication-ready statistical summaries
- **AI Deviation Analysis** for root cause investigation brainstorming (simulated)
- **Audit Trail** with 21 CFR Part 11 compliant logging
- **OOS Flagging** with automatic identification of out-of-spec outliers

### Python Shiny Dashboard (`app.py`) - Alternative

For Python-preferred teams (requires pip/venv):

- Interactive plotly visualizations
- Simulated AI responses for demo
- Data upload capability
- Heatmap overview of all analyte-interferent pairs

### Parameterized Quarto Report (`reports/interference_report.qmd`)

ICH Q2(R1) compliant validation reports:

- Change one parameter → render complete PDF
- gtsummary statistical tables
- TOST equivalence analysis
- Signature blocks for QA approval
- Eliminates copy-paste errors (FDA audit red flag)

## Installation

### R Packages (Required)

```bash
# Option 1: Use the install script
Rscript install_packages.R

# Option 2: Manual install
R -e "install.packages(c('shiny', 'bslib', 'dplyr', 'tidyr', 'ggplot2', 'plotly', 'gtsummary', 'gt', 'readr', 'purrr', 'broom', 'bsicons', 'scales'))"
```

### Python Packages (Optional - for app.py only)

```bash
# Only if you have pip available
pip install -r requirements.txt
```

## Running the Apps

### R Shiny App (Recommended)

```bash
# From terminal
R -e "shiny::runApp('app.R', port = 8050)"

# Or use the launcher script
Rscript run_app.R
```

Then open: http://localhost:8050

### Python Shiny App

```bash
# Requires pip install first
shiny run app.py --port 8051
```

### Render Quarto Report

```bash
# Default parameters (Glucose + Hemolysis)
quarto render reports/interference_report.qmd

# Custom parameters - ICH Q2 specificity study
quarto render reports/interference_report.qmd \
  -P analyte:"Troponin I" \
  -P interferent:"Biotin" \
  -P spec_limit:2.0
```

## AI Integration (GxP-Safe Approach)

This demo positions AI for **workflow efficiency**, not batch-release decisions:

1. **Root Cause Analysis** - When interference study fails, AI brainstorms potential chemical interactions
2. **Data Standardization** - Harmonize messy metadata entries
3. **Code Generation** - GitHub Copilot / chattr for learning R/Python

Note: AI features use simulated responses - no API keys required.

## Synthetic Data

- **8 Analytes**: Glucose, Creatinine, Bilirubin, HbA1c, Potassium, Troponin I, TSH, ALT
- **7 Interferents**: Hemolysis, Lipemia, Icterus, Ascorbic Acid, Acetaminophen, Biotin, RF
- **Design**: CLSI EP07-A3 dose-response with 5 replicates per condition
- **Total Records**: 5,040

## Project Structure

```
Abbott_InterferenceStudies/
├── app.R                    # R Shiny dashboard (primary)
├── app.py                   # Python Shiny dashboard (alternative)
├── install_packages.R       # R package installer
├── run_app.R                # R app launcher
├── requirements.txt         # Python dependencies
├── _brand.yml               # Brand styling
├── README.md                # This file
├── posit-README.md          # Sales demo guide
├── data/
│   ├── generate_data.py     # Synthetic data generator
│   ├── interference_studies.csv
│   ├── decision_limits.csv
│   └── instruments.csv
└── reports/
    └── interference_report.qmd  # ICH Q2 parameterized report
```

## Deployment to Posit Connect

```r
# R Shiny app
rsconnect::deployApp(".", appName = "abbott-interference-analyzer")

# Quarto report
quarto::quarto_publish_doc("reports/interference_report.qmd")
```

## Troubleshooting

### "there is no package called 'gtsummary'"
```bash
Rscript install_packages.R
```

### "pip: command not found" (Posit Workbench)
Use the R Shiny app instead - it's the primary demo and doesn't need pip.

### Port already in use
```bash
R -e "shiny::runApp('app.R', port = 8051)"  # Use different port
```

## Regulatory References

- **ICH Q2(R1)**: Validation of Analytical Procedures - Section 2.2 Specificity
- **CLSI EP07-A3**: Interference Testing in Clinical Chemistry
- **21 CFR Part 11**: Electronic Records; Electronic Signatures
- **CLIA '88**: Clinical Laboratory Improvement Amendments

---

*Built with Posit tools for Abbott Manufacturing.*
