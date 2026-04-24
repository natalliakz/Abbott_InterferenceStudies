# Abbott Manufacturing: ICH Q2 Interference Study Analyzer

A comprehensive Posit demonstration showcasing the transition from point-and-click tools (JMP, Minitab) to an automated, GxP-compliant code-first pipeline for pharmaceutical interference/specificity studies.

**DISCLAIMER:** This project contains synthetic data and analysis created for demonstration purposes only.

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

### R Shiny Dashboard (`app.R`) - with gtsummary

A GxP-compliant application featuring:

- **Spike & Recovery Analysis** with interactive dose-response plots
- **Pass/Fail Assessment** against configurable specification limits (default ±2%)
- **TOST Equivalence Testing** for ICH Q2 statistical validation
- **gtsummary Tables** for publication-ready statistical summaries
- **AI Deviation Analysis** for root cause investigation brainstorming
- **Audit Trail** with 21 CFR Part 11 compliant logging
- **OOS Flagging** with automatic identification of out-of-spec outliers

### Python Shiny Dashboard (`app.py`)

Alternative implementation for Python-preferred teams with:

- Interactive plotly visualizations
- Claude API integration for AI summaries
- Data upload capability
- Heatmap overview of all analyte-interferent pairs

### Parameterized Quarto Report (`reports/interference_report.qmd`)

ICH Q2(R1) compliant validation reports:

- Change one parameter → render complete PDF
- gtsummary statistical tables
- TOST equivalence analysis
- Signature blocks for QA approval
- Eliminates copy-paste errors (FDA audit red flag)

## Quick Start

### R Shiny App

```bash
cd Abbott_InterferenceStudies

# Install dependencies
R -e "install.packages(c('shiny', 'bslib', 'dplyr', 'tidyr', 'ggplot2', 'plotly', 'gtsummary', 'gt', 'readr', 'purrr', 'broom', 'bsicons'))"

# Run the app
R -e "shiny::runApp('app.R', port = 8050)"
```

### Python Shiny App

```bash
cd Abbott_InterferenceStudies
pip install -r requirements.txt
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
  -P spec_limit:2.0 \
  -P study_id:"INT-2026-042" \
  -P protocol_number:"VAL-ANA-2026-088"
```

## AI Integration (GxP-Safe Approach)

Pharma is hesitant about AI due to "black box" concerns. This demo positions AI for **workflow efficiency**, not batch-release decisions:

### 1. Code Generation Support
- GitHub Copilot in Posit Workbench translates Minitab workflows to R/Python
- `chattr` package provides in-IDE ChatGPT assistance

### 2. Root Cause Analysis
- When interference study fails, AI brainstorms potential chemical interactions
- Acts as investigation report partner, not decision maker

### 3. Data Standardization
- LLMs harmonize messy metadata ("Vit C", "Vit. C", "Ascorbic Acid" → "Ascorbic Acid")
- Runs BEFORE statistical analysis

## Synthetic Data

- **8 Analytes**: Glucose, Creatinine, Bilirubin, HbA1c, Potassium, Troponin I, TSH, ALT
- **7 Interferents**: Hemolysis, Lipemia, Icterus, Ascorbic Acid, Acetaminophen, Biotin, RF
- **Design**: CLSI EP07-A3 dose-response with 5 replicates per condition

## Project Structure

```
Abbott_InterferenceStudies/
├── app.R                           # R Shiny dashboard (gtsummary)
├── app.py                          # Python Shiny dashboard
├── requirements.txt                # Python dependencies
├── _brand.yml                      # Brand styling
├── data/
│   ├── generate_data.py            # Synthetic data generator
│   ├── interference_studies.csv    # Main study data
│   ├── decision_limits.csv         # CLIA acceptance criteria
│   └── instruments.csv             # Instrument metadata
└── reports/
    └── interference_report.qmd     # ICH Q2 parameterized report
```

## Deployment to Posit Connect

```bash
# R Shiny app
rsconnect::deployApp(".", appName = "abbott-interference-analyzer")

# Quarto report (schedule for routine QC)
quarto publish connect reports/interference_report.qmd
```

## Regulatory References

- **ICH Q2(R1)**: Validation of Analytical Procedures - Section 2.2 Specificity
- **CLSI EP07-A3**: Interference Testing in Clinical Chemistry
- **21 CFR Part 11**: Electronic Records; Electronic Signatures
- **CLIA '88**: Clinical Laboratory Improvement Amendments

---

*Built with Posit tools for Abbott Manufacturing. Contact your Posit representative for more information.*
