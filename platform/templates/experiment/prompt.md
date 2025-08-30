# Prompt Templates for {EXPERIMENT_NAME}

## System Prompt

You are {ROLE_DESCRIPTION}. Your primary responsibility is to {PRIMARY_TASK}.

### Context
{CONTEXT_DESCRIPTION}

### Capabilities
- {CAPABILITY_1}
- {CAPABILITY_2}
- {CAPABILITY_3}

### Constraints
- {CONSTRAINT_1}
- {CONSTRAINT_2}
- {CONSTRAINT_3}

### Output Format
{OUTPUT_FORMAT_INSTRUCTIONS}

---

## User Prompt Template

### Task Description
{TASK_DESCRIPTION}

### Input
{INPUT_DESCRIPTION}

**Input Data:**
```
{INPUT_PLACEHOLDER}
```

### Instructions
1. {INSTRUCTION_1}
2. {INSTRUCTION_2}
3. {INSTRUCTION_3}

### Expected Output
{OUTPUT_EXPECTATIONS}

### Examples

#### Example 1
**Input:**
```
{EXAMPLE_1_INPUT}
```

**Expected Output:**
```
{EXAMPLE_1_OUTPUT}
```

**Reasoning:**
{EXAMPLE_1_REASONING}

#### Example 2
**Input:**
```
{EXAMPLE_2_INPUT}
```

**Expected Output:**
```
{EXAMPLE_2_OUTPUT}
```

**Reasoning:**
{EXAMPLE_2_REASONING}

#### Example 3
**Input:**
```
{EXAMPLE_3_INPUT}
```

**Expected Output:**
```
{EXAMPLE_3_OUTPUT}
```

**Reasoning:**
{EXAMPLE_3_REASONING}

---

## Prompt Variations

### Variation A: Detailed Instructions
```markdown
You are a {ROLE} tasked with {DETAILED_TASK}. 

Given the following input:
{INPUT_PLACEHOLDER}

Please provide a comprehensive analysis that includes:
1. {DETAILED_REQUIREMENT_1}
2. {DETAILED_REQUIREMENT_2}
3. {DETAILED_REQUIREMENT_3}

Format your response as follows:
{DETAILED_OUTPUT_FORMAT}
```

### Variation B: Concise Instructions
```markdown
{ROLE}: {BRIEF_TASK}

Input: {INPUT_PLACEHOLDER}
Output: {BRIEF_OUTPUT_FORMAT}
```

### Variation C: Chain-of-Thought
```markdown
You are {ROLE}. Your task is to {TASK} by thinking through the problem step by step.

Input: {INPUT_PLACEHOLDER}

Please work through this systematically:

Step 1: {COT_STEP_1}
Step 2: {COT_STEP_2}
Step 3: {COT_STEP_3}
Step 4: {COT_STEP_4}

Final Answer: {FINAL_FORMAT}
```

### Variation D: Few-Shot with Reasoning
```markdown
You are {ROLE}. Here are some examples of how to approach this task:

Example 1:
Input: {FS_EXAMPLE_1_INPUT}
Reasoning: {FS_EXAMPLE_1_REASONING}
Output: {FS_EXAMPLE_1_OUTPUT}

Example 2:
Input: {FS_EXAMPLE_2_INPUT}
Reasoning: {FS_EXAMPLE_2_REASONING}
Output: {FS_EXAMPLE_2_OUTPUT}

Now, please handle this new case:
Input: {INPUT_PLACEHOLDER}
Reasoning: [Think through your approach]
Output: [Your response]
```

---

## Domain-Specific Prompt Templates

### For Classification Tasks
```markdown
Classify the following {INPUT_TYPE} into one of these categories: {CATEGORIES}

Input: {INPUT_PLACEHOLDER}

Classification: [Category]
Confidence: [0-1]
Reasoning: [Brief explanation]
```

### For Generation Tasks
```markdown
Generate a {OUTPUT_TYPE} based on the following requirements:

Requirements:
- {REQUIREMENT_1}
- {REQUIREMENT_2}
- {REQUIREMENT_3}

Context: {GENERATION_CONTEXT}
Input: {INPUT_PLACEHOLDER}

Generated {OUTPUT_TYPE}:
```

### For Analysis Tasks
```markdown
Analyze the following {INPUT_TYPE} and provide insights on:

1. {ANALYSIS_DIMENSION_1}
2. {ANALYSIS_DIMENSION_2}
3. {ANALYSIS_DIMENSION_3}

Input: {INPUT_PLACEHOLDER}

Analysis:
1. {ANALYSIS_DIMENSION_1}: 
2. {ANALYSIS_DIMENSION_2}: 
3. {ANALYSIS_DIMENSION_3}: 

Summary: 
Recommendations: 
```

### For Comparison Tasks
```markdown
Compare and contrast the following {INPUT_TYPE}:

Item A: {ITEM_A_PLACEHOLDER}
Item B: {ITEM_B_PLACEHOLDER}

Please analyze:
- Similarities: 
- Differences: 
- Advantages/Disadvantages: 
- Recommendations: 
```

---

## Prompt Engineering Strategies

### Strategy 1: Role-Based Prompting
Assign specific roles to leverage specialized knowledge and behavior patterns.

### Strategy 2: Context Priming
Provide relevant background information to improve response quality.

### Strategy 3: Constraint Specification
Clearly define what the model should and shouldn't do.

### Strategy 4: Output Formatting
Specify exact format requirements for consistent parsing.

### Strategy 5: Example-Driven Learning
Use examples to demonstrate expected behavior and reasoning.

---

## Testing and Validation

### Prompt Testing Checklist
- [ ] Clear and unambiguous instructions
- [ ] Appropriate level of detail
- [ ] Consistent formatting requirements
- [ ] Relevant examples provided
- [ ] Edge cases considered
- [ ] Output format specified
- [ ] Constraints clearly stated

### Common Issues to Avoid
1. **Ambiguous Instructions**: Ensure clarity in task description
2. **Missing Context**: Provide sufficient background information
3. **Inconsistent Examples**: Ensure examples align with instructions
4. **Unclear Output Format**: Specify exact formatting requirements
5. **Conflicting Constraints**: Avoid contradictory requirements

### Prompt Iteration Log
| Version | Changes | Performance Impact | Notes |
|---------|---------|-------------------|--------|
| v1.0 | Initial prompt | Baseline | {NOTES_V1} |
| v1.1 | Added examples | +{IMPROVEMENT}% | {NOTES_V1.1} |
| v1.2 | Refined instructions | +{IMPROVEMENT}% | {NOTES_V1.2} |
| v2.0 | Major restructure | +{IMPROVEMENT}% | {NOTES_V2.0} |

---

## Variable Definitions

Replace the following placeholders with actual values:

- `{ROLE_DESCRIPTION}`: Detailed description of the AI's role
- `{PRIMARY_TASK}`: Main task the AI should perform
- `{CONTEXT_DESCRIPTION}`: Background context for the task
- `{CAPABILITY_1/2/3}`: Specific capabilities the AI should demonstrate
- `{CONSTRAINT_1/2/3}`: Limitations or restrictions on the AI's behavior
- `{INPUT_DESCRIPTION}`: Description of expected input format
- `{OUTPUT_EXPECTATIONS}`: Description of expected output format
- `{EXAMPLE_X_INPUT/OUTPUT/REASONING}`: Specific examples with explanations
- `{CATEGORIES}`: List of classification categories
- `{REQUIREMENTS}`: Specific requirements for generation tasks
- `{ANALYSIS_DIMENSIONS}`: Aspects to analyze in analysis tasks