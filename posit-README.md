# Posit Demo: Abbott Manufacturing - ICH Q2 Interference Studies

## Customer Context

**Company:** Abbott Manufacturing (Pharmaceutical/Diagnostics Division)
**Industry:** Pharmaceutical Manufacturing / In-Vitro Diagnostics
**Current Tools:** SAS JMP, Minitab
**Key Contact Role:** Bench chemists, QA/QC analysts, Validation Scientists, Lab Directors
**Regulatory Environment:** FDA 21 CFR Part 11, ICH Q2(R1), CLSI EP07-A3

## The Challenge

Abbott's QC/validation teams are transitioning from GUI-heavy statistical tools (JMP, Minitab) to a code-first ecosystem. In pharma, **human intervention is a risk**. Key concerns:

1. **Cultural Resistance**: Scientists fear losing visual interaction with data
2. **Regulatory Compliance**: ICH Q2 and CLSI EP07 require standardized, reproducible analysis
3. **Audit Trail Requirements**: 21 CFR Part 11 demands traceable electronic records
4. **Copy-Paste Errors**: Manual reporting is an FDA audit red flag
5. **Repetitive Workflows**: Interference studies are highly repetitive across excipients

## The Core Message

**Transform interference studies from an "event" into an automated "pipeline."**

| Feature | JMP/Minitab Workflow | Posit (Code-First) Workflow |
|---------|---------------------|----------------------------|
| **Data Entry** | Manual import, cleaning via UI | Automated pulling via APIs or scheduled scripts |
| **Analysis** | Point-and-click; risk of wrong test | Pre-validated, hardcoded functions aligned with SOPs |
| **Reporting** | Copy-pasting plots into Word/Excel | Auto-generated, reproducible Quarto PDFs |
| **Audit Trail** | Proprietary project files | Git-backed version control tracking every keystroke |
| **Time per Study** | 4+ hours | 10 seconds |

## Demo Strategy

### 1. Purpose-Built Shiny Apps for the Bench Chemist

**User Concern:** "I don't want to stare at code all day"

**Demo Response:** The R Shiny dashboard (`app.R`) provides:
- Dropdown menus for API/interferent selection (familiar JMP feel)
- **±2% specification limit** configurable (ICH Q2 default)
- Interactive plotly graphs where users hover over data points to identify **OOS outliers**
- gtsummary tables for publication-ready statistics

**Key Talking Point:** "This isn't about removing the GUI - it's building a BETTER GUI that's restricted to your exact approved validation protocols. The app instantly flags if interference exceeds the specification limit. No wrong test selection possible."

### 2. Parameterized Quarto for ICH Q2 Validation Reports

**User Concern:** "I spend 4 hours copying graphs into Word after every study"

**Demo Response:** The Quarto report (`reports/interference_report.qmd`):
- Bench chemist inputs excipient name and raw data file path
- One click → pre-validated R script runs, generates spike-and-recovery plots, calculates statistical equivalence
- Outputs **locked PDF** ready for QA review with signature blocks

**Key Talking Point:** "This eliminates copy-paste errors—a massive red flag during FDA audits. The exact same statistical models are applied to every single batch, every single time. The code IS your SOP."

### 3. Deploy AI Safely in a GxP Environment

**User Concern:** "AI is a black box—we can't use it for batch release decisions"

**Strategic Response:** Position AI for **workflow efficiency**, not final decisions:

#### a) Code Generation (Posit Workbench + Copilot)
- Show GitHub Copilot in RStudio/VS Code
- Type `# calculate TOST equivalence test for interference data` → Copilot generates R code
- `chattr` package: "How do I do an equivalence test in R like I used to do in Minitab?"

#### b) AI for Root Cause Analysis
- When interference study fails (e.g., Biotin causes unexpected signal on Troponin)
- Click "Analyze Deviation" → AI suggests potential chemical interactions, equipment issues
- Acts as **brainstorming partner** for investigation report, not decision maker

#### c) Data Standardization
- LLMs harmonize messy metadata before analysis
- "Vit C", "Vit. C", "Ascorbic Acid" → standardized to "Ascorbic Acid"
- Runs BEFORE statistical analysis to prevent garbage-in-garbage-out

**Key Talking Point:** "We're not asking AI to release batches. We're using it to help your scientists translate their Minitab knowledge to R, brainstorm root causes when something fails, and clean up messy spreadsheet entries."

## Demo Flow (45 minutes)

### Opening (5 min)
- Acknowledge JMP/Minitab comfort level
- Present the workflow comparison table
- "What if I told you this could be faster AND more compliant?"

### R Shiny Dashboard (15 min)
1. Open app, select Glucose + Hemolysis
2. **Spike & Recovery tab**: Show dose-response curve with 95% CI
3. **Pass/Fail tab**: Show ±2% specification limit, OOS flagging
4. Change spec limit to ±10% → watch assessment update
5. **Equivalence Test tab**: Show TOST results (ICH Q2 requirement)
6. **AI Deviation tab**: Simulate failed study, click "Analyze Deviation"
7. **Audit Trail tab**: Show comparison table (manual vs automated)

### Quarto Report (10 min)
1. Show the parameterized YAML header
2. Render with Glucose + Hemolysis (HTML)
3. Change to: `-P analyte:"Troponin I" -P interferent:"Biotin" -P spec_limit:2.0`
4. Render again → different report, same validated template
5. Show PDF output with signature blocks
6. "This goes straight to QA. Every single time."

### AI Coding Assistance (10 min)
1. Open VS Code/RStudio with Copilot enabled
2. Type: `# read interference CSV and calculate TOST equivalence test`
3. Show Copilot suggestion appearing in real-time
4. Accept, run, show result
5. Open `chattr`: "How do I create a dose-response plot with ggplot2?"
6. "Your scientists don't need to be programmers from day one"

### gtsummary Demo (5 min)
1. Show gtsummary table in app and Quarto report
2. "Publication-ready tables, automatically. No manual formatting."
3. Compare to JMP table export → Word → manual reformatting

### Closing
- ROI: 4 hours → 10 seconds per study
- Compliance: Same validated analysis every time
- Audit trail: Git tracks every change
- Ask: "What's one interference study you could automate next week?"

## Technical Demo Requirements

### Environment Setup
```bash
cd Abbott_InterferenceStudies

# R dependencies
R -e "install.packages(c('shiny', 'bslib', 'dplyr', 'tidyr', 'ggplot2', 'plotly', 'gtsummary', 'gt', 'readr', 'purrr', 'broom', 'bsicons'))"

# Python dependencies (for app.py)
uv venv
source .venv/bin/activate
uv pip install -r requirements.txt
```

### Running the Demo
```bash
# Terminal 1: R Shiny app (primary demo)
R -e "shiny::runApp('app.R', port = 8050)"

# Terminal 2: Python Shiny app (alternative)
shiny run app.py --port 8051

# Quarto rendering
quarto render reports/interference_report.qmd -P analyte:"Troponin I" -P interferent:"Biotin"
```

### Posit Connect Deployment
```bash
# R Shiny app
rsconnect::deployApp(".", appName = "abbott-interference-analyzer")

# Quarto (schedule for routine batch reports)
quarto publish connect reports/interference_report.qmd
```

## Objection Handling

### "My team doesn't know R/Python"
- "That's exactly why we integrated GitHub Copilot and chattr. They describe what they want, AI writes the code."
- "The Shiny app requires zero coding for end users—it's all dropdown menus."
- "Quarto reports are one-click. Code is written once by your validation team, then anyone can render."

### "We're regulated—can't change our validated process"
- "The code IS your SOP. Every analysis runs identically, every time."
- "Git version control gives you a complete audit trail—better than proprietary project files."
- "This actually improves compliance by eliminating human error."

### "JMP just works"
- "JMP works for one study at a time, with manual documentation."
- "With Posit Connect, you can schedule 100 interference reports overnight."
- "The Shiny app enforces your exact acceptance criteria—no wrong test selection possible."

### "AI is a black box—we can't use it"
- "We're not using AI for batch release decisions."
- "AI helps with code generation, root cause brainstorming, and data cleanup."
- "All final decisions remain with your qualified scientists."
- "We use Claude via AWS Bedrock for enterprise security and compliance."

### "What about 21 CFR Part 11 compliance?"
- "Git provides complete audit trail with timestamps and user IDs."
- "Quarto generates locked PDFs with embedded metadata."
- "The Shiny app logs every parameter change."

## Follow-Up Materials

After the demo, provide:

1. **This repository** - They can run it themselves
2. **Posit Connect trial** - Let them deploy and share internally
3. **Workbench trial** - For the Copilot/chattr demo
4. **Validation IQ/OQ templates** - If they ask about 21 CFR Part 11

## Success Metrics

Track these for the opportunity:

- [ ] Demo completed
- [ ] Technical follow-up scheduled (validation team)
- [ ] Trial access provided (Connect + Workbench)
- [ ] POC defined (specific interferent study)
- [ ] IT security review initiated
- [ ] Business case built (time savings × studies/year)
- [ ] Legal/procurement engaged

## Related Resources

- [ICH Q2(R1) Guideline](https://www.ich.org/page/quality-guidelines) - Analytical validation
- [CLSI EP07-A3](https://clsi.org/) - Interference testing standard
- [21 CFR Part 11](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/part-11-electronic-records-electronic-signatures) - Electronic records
- [gtsummary documentation](https://www.danieldsjoberg.com/gtsummary/)
- [Posit Connect Admin Guide](https://docs.posit.co/connect/)

---

*Demo created by Posit Solutions Engineering. For questions, contact your SE team.*
