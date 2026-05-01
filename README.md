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

For Python-preferred teams (requires uv/venv):

- Interactive plotly visualizations
- **AI-powered study summaries and Q&A** via Claude on AWS Bedrock
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
# Create and activate virtual environment with uv
uv venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# Install dependencies
uv pip install -r requirements.txt
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
# Activate venv first, then run
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
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

The Python app uses Claude via AWS Bedrock for AI-powered study summaries and Q&A.

### AWS Credentials Configuration

#### Option 1: Posit Workbench / Positron (Local Development)

Configure AWS credentials using the AWS CLI or environment variables:

```bash
# Using AWS CLI (recommended)
aws configure
# Enter your AWS Access Key ID, Secret Access Key, and region (us-west-2)

# Or set environment variables in your shell profile (~/.bashrc, ~/.zshrc)
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_DEFAULT_REGION="us-west-2"
```

For Positron/VS Code, you can also add these to your workspace `.env` file:

```
AWS_ACCESS_KEY_ID=your-access-key-id
AWS_SECRET_ACCESS_KEY=your-secret-access-key
AWS_DEFAULT_REGION=us-west-2
```

#### Option 2: Posit Connect (Deployment)

When publishing to Posit Connect, configure AWS credentials using **Environment Variables** in the Connect dashboard:

1. Deploy the app using `rsconnect-python` or the Posit Publisher extension
2. In Posit Connect, navigate to your app's **Settings** > **Vars** tab
3. Add the following environment variables:
   - `AWS_ACCESS_KEY_ID` - Your AWS access key
   - `AWS_SECRET_ACCESS_KEY` - Your AWS secret key
   - `AWS_DEFAULT_REGION` - Set to `us-west-2`

**For production deployments**, use IAM roles instead of access keys:
- If Posit Connect runs on AWS (EC2/EKS), attach an IAM role with Bedrock permissions to the instance
- The Anthropic SDK will automatically use the instance role credentials

#### Required IAM Permissions

Your AWS credentials need the following Bedrock permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ],
      "Resource": "arn:aws:bedrock:us-west-2::foundation-model/anthropic.*"
    }
  ]
}
```

Ensure Claude models are enabled in your AWS Bedrock console (Model Access).

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
