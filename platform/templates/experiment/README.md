# Experiment: {EXPERIMENT_NAME}

## Overview

**Objective**: {EXPERIMENT_OBJECTIVE}
**Type**: {EXPERIMENT_TYPE} (e.g., prompt_engineering, model_comparison, ablation_study)
**Status**: {STATUS} (planning | running | completed | paused)
**Created**: {DATE}
**Duration**: {DURATION}

## Hypothesis

{HYPOTHESIS_STATEMENT}

### Key Questions
- {QUESTION_1}
- {QUESTION_2}
- {QUESTION_3}

## Methodology

### Experimental Design
- **Independent Variables**: {VARIABLES}
- **Dependent Variables**: {METRICS}
- **Control Groups**: {CONTROLS}
- **Sample Size**: {SAMPLE_SIZE}
- **Randomization**: {RANDOMIZATION_STRATEGY}

### Setup
1. {SETUP_STEP_1}
2. {SETUP_STEP_2}
3. {SETUP_STEP_3}

### Procedure
1. {PROCEDURE_STEP_1}
2. {PROCEDURE_STEP_2}
3. {PROCEDURE_STEP_3}

## Data Collection

### Datasets
- **Training**: {TRAINING_DATA}
- **Validation**: {VALIDATION_DATA}
- **Test**: {TEST_DATA}

### Metrics
- **Primary**: {PRIMARY_METRICS}
- **Secondary**: {SECONDARY_METRICS}
- **Statistical Tests**: {STATISTICAL_TESTS}

## Results

### Summary
{RESULTS_SUMMARY}

### Key Findings
1. {FINDING_1}
2. {FINDING_2}
3. {FINDING_3}

### Visualizations
- {CHART_1}: `results/charts/{chart1}.png`
- {CHART_2}: `results/charts/{chart2}.png`
- {CHART_3}: `results/tables/{table1}.csv`

## Analysis

### Statistical Significance
- {METRIC_1}: p-value = {P_VALUE_1}
- {METRIC_2}: p-value = {P_VALUE_2}

### Effect Sizes
- {EFFECT_SIZE_ANALYSIS}

### Confidence Intervals
- {CONFIDENCE_INTERVALS}

## Conclusions

### Hypothesis Validation
{HYPOTHESIS_RESULT}

### Implications
- **Theoretical**: {THEORETICAL_IMPLICATIONS}
- **Practical**: {PRACTICAL_IMPLICATIONS}
- **Business**: {BUSINESS_IMPLICATIONS}

### Limitations
- {LIMITATION_1}
- {LIMITATION_2}
- {LIMITATION_3}

## Reproducibility

### Environment
- **Python Version**: {PYTHON_VERSION}
- **Dependencies**: See `requirements.txt`
- **Hardware**: {HARDWARE_SPECS}
- **Random Seeds**: {RANDOM_SEEDS}

### Reproduction Steps
```bash
# Clone and setup
git clone {REPO_URL}
cd {EXPERIMENT_DIR}
pip install -r requirements.txt

# Run experiment
python run_experiment.py --config config.yaml

# Generate results
python analyze_results.py --output results/
```

## Files Structure
```
{EXPERIMENT_NAME}/
├── README.md              # This file
├── config.yaml           # Configuration
├── prompt.md             # Prompt templates
├── eval.md              # Evaluation criteria
├── data/                # Input data
├── src/                 # Source code
├── results/             # Output results
├── notebooks/           # Analysis notebooks
└── requirements.txt     # Dependencies
```

## Next Steps
- [ ] {NEXT_STEP_1}
- [ ] {NEXT_STEP_2}
- [ ] {NEXT_STEP_3}

## References
1. {REFERENCE_1}
2. {REFERENCE_2}
3. {REFERENCE_3}

---
**Experiment ID**: {EXPERIMENT_ID}
**Contact**: {CONTACT_EMAIL}
**Last Updated**: {LAST_UPDATED}