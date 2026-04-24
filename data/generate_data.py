"""
Generate synthetic interference study data for demonstration.
Based on CLSI EP07-A3 guidelines for interference testing.

This creates realistic-looking data for clinical chemistry assays
with various interferent substances.
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import random

np.random.seed(42)

# Define analytes and their reference ranges
ANALYTES = {
    "Glucose": {"unit": "mg/dL", "low": 70, "high": 200, "precision_cv": 2.5},
    "Creatinine": {"unit": "mg/dL", "low": 0.5, "high": 5.0, "precision_cv": 3.0},
    "Total Bilirubin": {"unit": "mg/dL", "low": 0.2, "high": 15.0, "precision_cv": 4.0},
    "Hemoglobin A1c": {"unit": "%", "low": 4.0, "high": 14.0, "precision_cv": 2.0},
    "Potassium": {"unit": "mEq/L", "low": 3.0, "high": 6.5, "precision_cv": 1.5},
    "Troponin I": {"unit": "ng/mL", "low": 0.01, "high": 10.0, "precision_cv": 5.0},
    "TSH": {"unit": "mIU/L", "low": 0.1, "high": 20.0, "precision_cv": 4.5},
    "ALT": {"unit": "U/L", "low": 10, "high": 300, "precision_cv": 3.5},
}

# Define interferents based on CLSI EP07 common substances
INTERFERENTS = {
    "Hemolysis": {"unit": "mg/dL Hb", "levels": [0, 50, 100, 200, 500, 1000]},
    "Lipemia": {"unit": "mg/dL TG", "levels": [0, 100, 250, 500, 1000, 2000]},
    "Icterus": {"unit": "mg/dL Bili", "levels": [0, 5, 10, 20, 40, 60]},
    "Ascorbic Acid": {"unit": "mg/dL", "levels": [0, 3, 10, 20, 30, 50]},
    "Acetaminophen": {"unit": "mg/L", "levels": [0, 20, 50, 100, 200, 300]},
    "Biotin": {"unit": "ng/mL", "levels": [0, 10, 30, 100, 500, 1200]},
    "RF (Rheumatoid Factor)": {"unit": "IU/mL", "levels": [0, 50, 100, 300, 500, 1000]},
}

# Interference relationships (which interferents affect which analytes)
INTERFERENCE_EFFECTS = {
    "Glucose": {
        "Hemolysis": {"direction": "negative", "threshold": 200, "slope": -0.08},
        "Ascorbic Acid": {"direction": "negative", "threshold": 10, "slope": -0.15},
        "Lipemia": {"direction": "positive", "threshold": 500, "slope": 0.03},
    },
    "Creatinine": {
        "Icterus": {"direction": "negative", "threshold": 20, "slope": -0.12},
        "Hemolysis": {"direction": "positive", "threshold": 500, "slope": 0.05},
        "Lipemia": {"direction": "positive", "threshold": 1000, "slope": 0.04},
    },
    "Total Bilirubin": {
        "Hemolysis": {"direction": "positive", "threshold": 100, "slope": 0.10},
        "Lipemia": {"direction": "negative", "threshold": 500, "slope": -0.06},
    },
    "Hemoglobin A1c": {
        "Hemolysis": {"direction": "positive", "threshold": 200, "slope": 0.07},
        "Ascorbic Acid": {"direction": "negative", "threshold": 15, "slope": -0.08},
    },
    "Potassium": {
        "Hemolysis": {"direction": "positive", "threshold": 50, "slope": 0.25},
    },
    "Troponin I": {
        "Biotin": {"direction": "negative", "threshold": 30, "slope": -0.35},
        "RF (Rheumatoid Factor)": {"direction": "positive", "threshold": 100, "slope": 0.12},
        "Hemolysis": {"direction": "positive", "threshold": 500, "slope": 0.08},
    },
    "TSH": {
        "Biotin": {"direction": "negative", "threshold": 30, "slope": -0.40},
        "Lipemia": {"direction": "positive", "threshold": 1000, "slope": 0.05},
    },
    "ALT": {
        "Hemolysis": {"direction": "positive", "threshold": 200, "slope": 0.15},
        "Icterus": {"direction": "negative", "threshold": 40, "slope": -0.08},
    },
}


def calculate_interference(baseline, interferent, concentration, effects):
    """Calculate the measured value with interference effect."""
    if interferent not in effects:
        return baseline

    effect = effects[interferent]
    threshold = effect["threshold"]
    slope = effect["slope"]
    direction = effect["direction"]

    if concentration <= threshold:
        return baseline

    excess = concentration - threshold
    bias_pct = slope * excess

    if direction == "negative":
        measured = baseline * (1 + bias_pct)
    else:
        measured = baseline * (1 + bias_pct)

    return max(0.001, measured)


def generate_study_data():
    """Generate a complete interference study dataset."""
    records = []
    study_id = 1

    # Generate studies for each analyte-interferent combination
    for analyte, analyte_info in ANALYTES.items():
        effects = INTERFERENCE_EFFECTS.get(analyte, {})

        for interferent, interferent_info in INTERFERENTS.items():
            # Generate 3 pool levels per analyte (low, medium, high)
            pool_values = [
                analyte_info["low"] + (analyte_info["high"] - analyte_info["low"]) * 0.2,
                analyte_info["low"] + (analyte_info["high"] - analyte_info["low"]) * 0.5,
                analyte_info["low"] + (analyte_info["high"] - analyte_info["low"]) * 0.8,
            ]

            for pool_idx, baseline_value in enumerate(pool_values, 1):
                pool_name = ["Low", "Medium", "High"][pool_idx - 1]

                for interferent_conc in interferent_info["levels"]:
                    # Generate replicates (n=5 per condition)
                    for rep in range(1, 6):
                        expected = calculate_interference(
                            baseline_value, interferent, interferent_conc, effects
                        )

                        # Add measurement noise based on assay CV
                        cv = analyte_info["precision_cv"] / 100
                        measured = expected * (1 + np.random.normal(0, cv))
                        measured = max(0.001, measured)

                        # Calculate bias
                        if interferent_conc == 0:
                            bias_pct = 0
                            bias_abs = 0
                        else:
                            bias_abs = measured - baseline_value
                            bias_pct = (bias_abs / baseline_value) * 100

                        records.append({
                            "study_id": study_id,
                            "analyte": analyte,
                            "analyte_unit": analyte_info["unit"],
                            "interferent": interferent,
                            "interferent_unit": interferent_info["unit"],
                            "interferent_concentration": interferent_conc,
                            "pool_level": pool_name,
                            "baseline_value": round(baseline_value, 3),
                            "measured_value": round(measured, 3),
                            "replicate": rep,
                            "bias_absolute": round(bias_abs, 3),
                            "bias_percent": round(bias_pct, 2),
                            "study_date": datetime.now() - timedelta(days=random.randint(1, 90)),
                            "technician_id": f"TECH{random.randint(1, 5):02d}",
                            "instrument_id": f"CHEM{random.randint(1, 3):02d}",
                            "lot_number": f"LOT{random.randint(2024001, 2024020)}",
                        })

                study_id += 1

    return pd.DataFrame(records)


def generate_decision_limits():
    """Generate acceptable bias limits based on CLIA/clinical requirements."""
    limits = []

    clia_limits = {
        "Glucose": {"abs_limit": 6.0, "pct_limit": 10.0, "clinical_decision": 126},
        "Creatinine": {"abs_limit": 0.3, "pct_limit": 15.0, "clinical_decision": 1.2},
        "Total Bilirubin": {"abs_limit": 0.4, "pct_limit": 20.0, "clinical_decision": 1.0},
        "Hemoglobin A1c": {"abs_limit": 0.5, "pct_limit": 6.0, "clinical_decision": 6.5},
        "Potassium": {"abs_limit": 0.5, "pct_limit": None, "clinical_decision": 5.0},
        "Troponin I": {"abs_limit": None, "pct_limit": 30.0, "clinical_decision": 0.04},
        "TSH": {"abs_limit": None, "pct_limit": 20.0, "clinical_decision": 4.0},
        "ALT": {"abs_limit": None, "pct_limit": 20.0, "clinical_decision": 40},
    }

    for analyte, analyte_info in ANALYTES.items():
        clia = clia_limits.get(analyte, {"abs_limit": None, "pct_limit": 10.0, "clinical_decision": None})
        limits.append({
            "analyte": analyte,
            "unit": analyte_info["unit"],
            "absolute_limit": clia["abs_limit"],
            "percent_limit": clia["pct_limit"],
            "clinical_decision_point": clia["clinical_decision"],
            "reference_guideline": "CLIA '88 / CLSI EP07-A3",
        })

    return pd.DataFrame(limits)


def generate_instrument_info():
    """Generate instrument metadata."""
    instruments = []

    for i in range(1, 4):
        instruments.append({
            "instrument_id": f"CHEM{i:02d}",
            "manufacturer": random.choice(["Abbott", "Roche", "Siemens", "Beckman Coulter"]),
            "model": random.choice(["Architect c8000", "Cobas 8000", "ADVIA Chemistry", "AU5800"]),
            "serial_number": f"SN{random.randint(100000, 999999)}",
            "installation_date": datetime(2022, random.randint(1, 12), random.randint(1, 28)),
            "last_calibration": datetime.now() - timedelta(days=random.randint(1, 30)),
            "location": random.choice(["Main Lab", "STAT Lab", "Reference Lab"]),
        })

    return pd.DataFrame(instruments)


if __name__ == "__main__":
    print("Generating synthetic interference study data...")

    # Generate datasets
    study_data = generate_study_data()
    decision_limits = generate_decision_limits()
    instruments = generate_instrument_info()

    # Save to CSV
    study_data.to_csv("data/interference_studies.csv", index=False)
    decision_limits.to_csv("data/decision_limits.csv", index=False)
    instruments.to_csv("data/instruments.csv", index=False)

    print(f"Generated {len(study_data)} interference study records")
    print(f"Covering {study_data['analyte'].nunique()} analytes and {study_data['interferent'].nunique()} interferents")
    print(f"Saved to data/ directory")
