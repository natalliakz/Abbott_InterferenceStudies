"""
Abbott Manufacturing: ICH Q2 Interference Study Analyzer - Shiny for Python

Interactive dashboard for pharmaceutical interference/specificity studies following
ICH Q2(R1) and CLSI EP07-A3 guidelines. Designed to replace manual JMP/Minitab
workflows with a standardized, GxP-compliant automated pipeline.

This project contains synthetic data created for demonstration purposes only.
"""

import pandas as pd
import numpy as np
from pathlib import Path
from scipy import stats
from shiny import App, reactive, render, ui
from shiny.types import ImgData
from shinywidgets import render_widget, output_widget
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
from chatlas import ChatBedrockAnthropic
import querychat

# Configuration
DATA_PATH = Path(__file__).parent / "data"
ABBOTT_COLORS = {
    "primary": "#003087",
    "secondary": "#00A3E0",
    "success": "#00843D",
    "warning": "#FF6D00",
    "danger": "#C8102E",
    "light": "#F5F5F5",
}

# Initialize chatlas client with AWS Bedrock
chat_client = ChatBedrockAnthropic(
    model="us.anthropic.claude-sonnet-4-5-20250929-v1:0",
    aws_region="us-west-2",
    max_tokens=1024
)


def load_data():
    """Load all datasets."""
    if not (DATA_PATH / "interference_studies.csv").exists():
        import subprocess
        subprocess.run(["python", str(DATA_PATH / "generate_data.py")], check=True)

    studies = pd.read_csv(DATA_PATH / "interference_studies.csv")
    studies["study_date"] = pd.to_datetime(studies["study_date"])
    limits = pd.read_csv(DATA_PATH / "decision_limits.csv")
    instruments = pd.read_csv(DATA_PATH / "instruments.csv")
    return studies, limits, instruments


studies_df, limits_df, instruments_df = load_data()

# Initialize querychat for interactive data Q&A (after data is loaded)
qc = querychat.QueryChat(
    data_source=studies_df,
    table_name="interference_studies",
    id="querychat",
    data_description="""Interference study data for pharmaceutical assays per CLSI EP07-A3 guidelines.
    Contains measurements of analyte values at different interferent concentrations.
    Key columns: analyte, interferent, interferent_concentration, measured_value, bias_percent.
    Used to determine if interferents cause clinically significant bias in assay results.""",
    greeting="""Welcome to the ICH Q2 Interference Study Assistant!

I can help you explore the interference study data. Try asking:
- "Which analyte-interferent pairs show the highest bias?"
- "What is the average bias for Hemolysis interference on Glucose?"
- "Show me the data for Troponin I with Biotin"
- "Filter to show only results with bias > 10%"
""",
    client=chat_client
)


def calculate_statistics(data):
    """Calculate EP07-compliant statistics for interference evaluation."""
    grouped = data.groupby("interferent_concentration").agg({
        "measured_value": ["mean", "std", "count"],
        "bias_percent": ["mean", "std"],
        "baseline_value": "first"
    }).reset_index()

    grouped.columns = [
        "interferent_concentration", "mean_measured", "sd_measured", "n",
        "mean_bias_pct", "sd_bias_pct", "baseline"
    ]

    grouped["cv_percent"] = (grouped["sd_measured"] / grouped["mean_measured"]) * 100
    grouped["se"] = grouped["sd_measured"] / np.sqrt(grouped["n"])
    grouped["ci_lower"] = grouped["mean_measured"] - 1.96 * grouped["se"]
    grouped["ci_upper"] = grouped["mean_measured"] + 1.96 * grouped["se"]

    return grouped


def assess_interference(stats_df, analyte, limits_df):
    """Determine if interference is clinically significant."""
    limit_row = limits_df[limits_df["analyte"] == analyte]
    if limit_row.empty:
        pct_limit = 10.0
        abs_limit = None
    else:
        pct_limit = limit_row["percent_limit"].values[0]
        abs_limit = limit_row["absolute_limit"].values[0]

    results = []
    baseline_row = stats_df[stats_df["interferent_concentration"] == 0]
    if baseline_row.empty:
        return pd.DataFrame()

    baseline_mean = baseline_row["mean_measured"].values[0]

    for _, row in stats_df.iterrows():
        if row["interferent_concentration"] == 0:
            assessment = "Baseline"
        else:
            bias = abs(row["mean_bias_pct"])
            abs_bias = abs(row["mean_measured"] - baseline_mean)

            exceeds_pct = pd.notna(pct_limit) and bias > pct_limit
            exceeds_abs = pd.notna(abs_limit) and abs_bias > abs_limit

            if exceeds_pct or exceeds_abs:
                assessment = "SIGNIFICANT"
            elif bias > (pct_limit * 0.5 if pd.notna(pct_limit) else 5):
                assessment = "Borderline"
            else:
                assessment = "Acceptable"

        results.append({
            **row.to_dict(),
            "assessment": assessment,
            "pct_limit": pct_limit,
            "abs_limit": abs_limit,
        })

    return pd.DataFrame(results)


def generate_ai_summary(analyte, interferent, assessment_df):
    """Generate AI-powered plain-text summary of interference results using Claude via AWS Bedrock."""
    data_summary = assessment_df.to_string(index=False)

    prompt = f"""You are an expert clinical chemist analyzing interference study data per ICH Q2(R1) and CLSI EP07-A3 guidelines.

Analyze the following interference study results for {analyte} with interferent {interferent}:

{data_summary}

Provide a concise professional summary including:
1. Study identification (analyte, interferent, baseline value)
2. Key findings (threshold concentration where significant interference occurs, if any)
3. Clinical recommendation
4. Reference to CLSI EP07-A3 compliance

Format as a plain-text report suitable for inclusion in a validation document. Keep it under 200 words."""

    try:
        response = chat_client.chat(prompt, echo="none")
        return str(response)
    except Exception as e:
        return f"Error generating AI summary: {str(e)}"


app_ui = ui.page_sidebar(
    ui.sidebar(
        ui.h4("Study Selection"),
        ui.input_select(
            "analyte",
            "Select Analyte",
            choices=sorted(studies_df["analyte"].unique().tolist()),
            selected="Glucose"
        ),
        ui.input_select(
            "interferent",
            "Select Interferent",
            choices=sorted(studies_df["interferent"].unique().tolist()),
            selected="Hemolysis"
        ),
        ui.input_select(
            "pool_level",
            "Pool Level",
            choices=["All", "Low", "Medium", "High"],
            selected="All"
        ),
        ui.hr(),
        ui.h4("Data Upload"),
        ui.input_file("upload_file", "Upload CSV Data", accept=[".csv"]),
        ui.hr(),
        ui.h4("Display Options"),
        ui.input_checkbox("show_ci", "Show 95% Confidence Intervals", value=True),
        ui.input_checkbox("show_limits", "Show Acceptance Limits", value=True),
        ui.input_numeric("decision_limit_pct", "Custom % Limit (override)", value=None, min=0, max=100),
        ui.hr(),
        ui.download_button("download_report", "Download Results CSV", class_="btn-primary w-100"),
        width=300
    ),

    ui.navset_tab(
        ui.nav_panel(
            "Dose-Response",
            ui.layout_columns(
                ui.card(
                    ui.card_header("Dose-Response Curve"),
                    output_widget("dose_response_plot"),
                ),
                ui.card(
                    ui.card_header("Bias Plot (% Change from Baseline)"),
                    output_widget("bias_plot"),
                ),
                col_widths=[6, 6]
            ),
            ui.card(
                ui.card_header("Study Statistics"),
                ui.output_data_frame("stats_table"),
            ),
        ),
        ui.nav_panel(
            "Assessment",
            ui.layout_columns(
                ui.card(
                    ui.card_header("Interference Assessment"),
                    output_widget("assessment_chart"),
                ),
                ui.card(
                    ui.card_header("Pass/Fail Summary"),
                    ui.output_ui("pass_fail_summary"),
                ),
                col_widths=[8, 4]
            ),
            ui.card(
                ui.card_header("Detailed Results"),
                ui.output_data_frame("assessment_table"),
            ),
        ),
        ui.nav_panel(
            "AI Summary",
            ui.card(
                ui.card_header("AI-Generated Study Summary"),
                ui.input_action_button("generate_summary", "Generate Summary", class_="btn-secondary mb-3"),
                ui.output_text_verbatim("ai_summary"),
            ),
        ),
        ui.nav_panel(
            "AI Chat",
            ui.layout_columns(
                ui.card(
                    ui.card_header("Chat with Your Data"),
                    qc.ui(),
                    height="500px",
                ),
                ui.card(
                    ui.card_header("Filtered Data Preview"),
                    ui.output_data_frame("querychat_data"),
                ),
                col_widths=[6, 6]
            ),
        ),
        ui.nav_panel(
            "All Studies",
            ui.card(
                ui.card_header("Interference Overview (All Analyte-Interferent Pairs)"),
                output_widget("heatmap_plot"),
            ),
            ui.card(
                ui.card_header("Flagged Combinations"),
                ui.output_data_frame("flagged_table"),
            ),
        ),
    ),
    title=ui.div(
        ui.span("Abbott Manufacturing: ICH Q2 Interference Analyzer", style="font-weight: bold;"),
        ui.span(" | GxP Compliant Pipeline", style="font-size: 0.8em; color: #666;"),
    ),
    fillable=True,
)


def server(input, output, session):
    # Initialize querychat server
    qc_result = qc.server()

    @render.data_frame
    def querychat_data():
        return render.DataGrid(qc_result.df(), selection_mode="none")

    @reactive.calc
    def filtered_data():
        data = studies_df[
            (studies_df["analyte"] == input.analyte()) &
            (studies_df["interferent"] == input.interferent())
        ]
        if input.pool_level() != "All":
            data = data[data["pool_level"] == input.pool_level()]
        return data

    @reactive.calc
    def study_stats():
        return calculate_statistics(filtered_data())

    @reactive.calc
    def assessment_data():
        stats = study_stats()
        return assess_interference(stats, input.analyte(), limits_df)

    @render_widget
    def dose_response_plot():
        data = filtered_data()
        stats = study_stats()

        fig = go.Figure()

        fig.add_trace(go.Scatter(
            x=data["interferent_concentration"],
            y=data["measured_value"],
            mode="markers",
            name="Individual Values",
            marker=dict(color=ABBOTT_COLORS["secondary"], size=6, opacity=0.5),
        ))

        fig.add_trace(go.Scatter(
            x=stats["interferent_concentration"],
            y=stats["mean_measured"],
            mode="lines+markers",
            name="Mean",
            line=dict(color=ABBOTT_COLORS["primary"], width=3),
            marker=dict(size=10),
        ))

        if input.show_ci():
            fig.add_trace(go.Scatter(
                x=list(stats["interferent_concentration"]) + list(stats["interferent_concentration"][::-1]),
                y=list(stats["ci_upper"]) + list(stats["ci_lower"][::-1]),
                fill="toself",
                fillcolor="rgba(0, 48, 135, 0.2)",
                line=dict(color="rgba(0,0,0,0)"),
                name="95% CI",
            ))

        baseline = stats[stats["interferent_concentration"] == 0]["mean_measured"]
        if not baseline.empty:
            fig.add_hline(
                y=baseline.values[0],
                line_dash="dash",
                line_color=ABBOTT_COLORS["success"],
                annotation_text="Baseline"
            )

        interferent_unit = data["interferent_unit"].iloc[0] if len(data) > 0 else ""
        analyte_unit = data["analyte_unit"].iloc[0] if len(data) > 0 else ""

        fig.update_layout(
            xaxis_title=f"{input.interferent()} ({interferent_unit})",
            yaxis_title=f"{input.analyte()} ({analyte_unit})",
            template="plotly_white",
            height=400,
            legend=dict(orientation="h", yanchor="bottom", y=1.02),
        )

        return fig

    @render_widget
    def bias_plot():
        stats = study_stats()
        assessment = assessment_data()

        fig = go.Figure()

        colors = []
        for _, row in assessment.iterrows():
            if row["assessment"] == "SIGNIFICANT":
                colors.append(ABBOTT_COLORS["danger"])
            elif row["assessment"] == "Borderline":
                colors.append(ABBOTT_COLORS["warning"])
            else:
                colors.append(ABBOTT_COLORS["success"])

        fig.add_trace(go.Bar(
            x=assessment["interferent_concentration"],
            y=assessment["mean_bias_pct"],
            marker_color=colors,
            name="Mean Bias %",
            error_y=dict(type="data", array=assessment["sd_bias_pct"], visible=True),
        ))

        limit = input.decision_limit_pct() if input.decision_limit_pct() else assessment["pct_limit"].iloc[0]
        if input.show_limits() and pd.notna(limit):
            fig.add_hline(y=limit, line_dash="dash", line_color=ABBOTT_COLORS["danger"], annotation_text=f"+{limit}%")
            fig.add_hline(y=-limit, line_dash="dash", line_color=ABBOTT_COLORS["danger"], annotation_text=f"-{limit}%")

        data = filtered_data()
        interferent_unit = data["interferent_unit"].iloc[0] if len(data) > 0 else ""

        fig.update_layout(
            xaxis_title=f"{input.interferent()} ({interferent_unit})",
            yaxis_title="Bias (%)",
            template="plotly_white",
            height=400,
        )

        return fig

    @render.data_frame
    def stats_table():
        stats = study_stats()
        display_df = stats[["interferent_concentration", "n", "mean_measured", "sd_measured", "cv_percent", "mean_bias_pct"]].copy()
        display_df.columns = ["Concentration", "N", "Mean", "SD", "CV%", "Bias%"]
        display_df = display_df.round(3)
        return render.DataGrid(display_df, selection_mode="none")

    @render_widget
    def assessment_chart():
        assessment = assessment_data()

        fig = go.Figure()

        assessment_colors = {
            "Baseline": ABBOTT_COLORS["light"],
            "Acceptable": ABBOTT_COLORS["success"],
            "Borderline": ABBOTT_COLORS["warning"],
            "SIGNIFICANT": ABBOTT_COLORS["danger"],
        }

        fig.add_trace(go.Scatter(
            x=assessment["interferent_concentration"],
            y=assessment["mean_measured"],
            mode="markers+lines",
            marker=dict(
                size=20,
                color=[assessment_colors.get(a, ABBOTT_COLORS["secondary"]) for a in assessment["assessment"]],
                line=dict(width=2, color="black"),
            ),
            line=dict(color=ABBOTT_COLORS["primary"], width=2),
            text=assessment["assessment"],
            hovertemplate="Concentration: %{x}<br>Mean: %{y:.2f}<br>Status: %{text}<extra></extra>",
        ))

        baseline = assessment[assessment["interferent_concentration"] == 0]["mean_measured"]
        if not baseline.empty and input.show_limits():
            bv = baseline.values[0]
            limit_pct = assessment["pct_limit"].iloc[0] if pd.notna(assessment["pct_limit"].iloc[0]) else 10

            fig.add_hrect(
                y0=bv * (1 - limit_pct/100),
                y1=bv * (1 + limit_pct/100),
                fillcolor="rgba(0, 132, 61, 0.1)",
                line_width=0,
                annotation_text="Acceptable Range",
                annotation_position="top left",
            )

        data = filtered_data()
        interferent_unit = data["interferent_unit"].iloc[0] if len(data) > 0 else ""
        analyte_unit = data["analyte_unit"].iloc[0] if len(data) > 0 else ""

        fig.update_layout(
            xaxis_title=f"{input.interferent()} ({interferent_unit})",
            yaxis_title=f"{input.analyte()} ({analyte_unit})",
            template="plotly_white",
            height=400,
        )

        return fig

    @render.ui
    def pass_fail_summary():
        assessment = assessment_data()
        total = len(assessment) - 1
        significant = len(assessment[assessment["assessment"] == "SIGNIFICANT"])
        borderline = len(assessment[assessment["assessment"] == "Borderline"])
        acceptable = len(assessment[assessment["assessment"] == "Acceptable"])

        if significant > 0:
            overall_status = "FAILED"
            status_color = ABBOTT_COLORS["danger"]
            first_sig = assessment[assessment["assessment"] == "SIGNIFICANT"]["interferent_concentration"].min()
            threshold_text = f"Interference threshold: {first_sig:.0f}"
        elif borderline > 0:
            overall_status = "CAUTION"
            status_color = ABBOTT_COLORS["warning"]
            threshold_text = "No significant interference, borderline results present"
        else:
            overall_status = "PASSED"
            status_color = ABBOTT_COLORS["success"]
            threshold_text = "No significant interference detected"

        return ui.div(
            ui.div(
                ui.h2(overall_status, style=f"color: {status_color}; text-align: center; margin: 20px 0;"),
                ui.p(threshold_text, style="text-align: center; font-weight: bold;"),
                ui.hr(),
                ui.div(
                    ui.div(
                        ui.span(f"{acceptable}", style=f"font-size: 24px; font-weight: bold; color: {ABBOTT_COLORS['success']};"),
                        ui.p("Acceptable", style="margin: 0;"),
                        style="text-align: center; flex: 1;"
                    ),
                    ui.div(
                        ui.span(f"{borderline}", style=f"font-size: 24px; font-weight: bold; color: {ABBOTT_COLORS['warning']};"),
                        ui.p("Borderline", style="margin: 0;"),
                        style="text-align: center; flex: 1;"
                    ),
                    ui.div(
                        ui.span(f"{significant}", style=f"font-size: 24px; font-weight: bold; color: {ABBOTT_COLORS['danger']};"),
                        ui.p("Significant", style="margin: 0;"),
                        style="text-align: center; flex: 1;"
                    ),
                    style="display: flex; justify-content: space-around; padding: 20px 0;",
                ),
            ),
            style="padding: 20px;",
        )

    @render.data_frame
    def assessment_table():
        assessment = assessment_data()
        display_df = assessment[["interferent_concentration", "n", "mean_measured", "sd_measured", "mean_bias_pct", "assessment"]].copy()
        display_df.columns = ["Concentration", "N", "Mean", "SD", "Bias%", "Assessment"]
        display_df = display_df.round(3)
        return render.DataGrid(display_df, selection_mode="none")

    @render.text
    @reactive.event(input.generate_summary)
    def ai_summary():
        assessment = assessment_data()
        return generate_ai_summary(input.analyte(), input.interferent(), assessment)

    @render_widget
    def heatmap_plot():
        summary = studies_df.groupby(["analyte", "interferent"]).apply(
            lambda x: x[x["interferent_concentration"] == x["interferent_concentration"].max()]["bias_percent"].mean()
        ).reset_index(name="max_bias")

        pivot = summary.pivot(index="analyte", columns="interferent", values="max_bias")

        fig = px.imshow(
            pivot,
            color_continuous_scale=["green", "yellow", "red"],
            color_continuous_midpoint=0,
            aspect="auto",
            labels=dict(color="Max Bias %"),
        )

        fig.update_layout(
            title="Maximum Bias (%) at Highest Interferent Concentration",
            template="plotly_white",
            height=500,
        )

        return fig

    @render.data_frame
    def flagged_table():
        flagged_data = []
        for analyte in studies_df["analyte"].unique():
            for interferent in studies_df["interferent"].unique():
                subset = studies_df[
                    (studies_df["analyte"] == analyte) &
                    (studies_df["interferent"] == interferent)
                ]
                if subset.empty:
                    continue

                stats = calculate_statistics(subset)
                assessment = assess_interference(stats, analyte, limits_df)

                significant = assessment[assessment["assessment"] == "SIGNIFICANT"]
                if not significant.empty:
                    threshold = significant["interferent_concentration"].min()
                    max_bias = significant["mean_bias_pct"].abs().max()
                    flagged_data.append({
                        "Analyte": analyte,
                        "Interferent": interferent,
                        "Threshold": threshold,
                        "Max Bias %": round(max_bias, 1),
                        "Status": "SIGNIFICANT"
                    })

        if flagged_data:
            return render.DataGrid(pd.DataFrame(flagged_data), selection_mode="none")
        else:
            return render.DataGrid(pd.DataFrame({"Message": ["No significant interferences detected"]}), selection_mode="none")

    @render.download(filename="interference_results.csv")
    def download_report():
        assessment = assessment_data()
        assessment["analyte"] = input.analyte()
        assessment["interferent"] = input.interferent()
        yield assessment.to_csv(index=False)


app = App(app_ui, server)
