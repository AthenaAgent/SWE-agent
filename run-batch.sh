#!/bin/bash

# Script to generate prediction files for a slice of instances from AthenaAgent42/ansible-swe-bench-pro dataset
# Usage: ./run-batch.sh [start_index] [end_index] [model_name] [config_path]

set -e  # Exit on any error

# Default values
START_INDEX=${1:-0}  # Default to first instance
END_INDEX=${2:-1}    # Default to process just one instance (exclusive)
MODEL_NAME=${3:-"gpt-4o"}  # Default model
CONFIG_PATH=${4:-"config/default.yaml"}  # Default config

# Dataset information
DATASET_NAME="AthenaAgent42/ansible-swe-bench-pro"
DATASET_SPLIT="test"

# Output directory
OUTPUT_DIR="./predictions"
mkdir -p "$OUTPUT_DIR"

echo "=== SWE-agent Batch Run ==="
echo "Dataset: $DATASET_NAME"
echo "Instance Range: [$START_INDEX, $END_INDEX)"
echo "Total Instances to Process: $((END_INDEX - START_INDEX))"
echo "Model: $MODEL_NAME"
echo "Config: $CONFIG_PATH"
echo "Output Directory: $OUTPUT_DIR"
echo "======================================"

# Validate indices
if [ "$START_INDEX" -ge "$END_INDEX" ]; then
    echo "Error: START_INDEX must be less than END_INDEX"
    exit 1
fi

# Create a Python script to extract instance data
cat > /tmp/extract_instance_batch.py << 'EOF'
import sys
from datasets import load_dataset
import json

instance_index = int(sys.argv[1])
dataset_name = sys.argv[2]
split = sys.argv[3]

# Load dataset (cache will be used for subsequent calls)
print(f"Loading dataset {dataset_name}...", file=sys.stderr)
ds = load_dataset(dataset_name, split=split)

if instance_index >= len(ds):
    print(f"Error: Instance index {instance_index} is out of range. Dataset has {len(ds)} instances.", file=sys.stderr)
    sys.exit(1)

# Get the specific instance
instance = ds[instance_index]

print(f"Extracted instance {instance_index}: {instance['instance_id']}", file=sys.stderr)
print(f"Repository: {instance['repo']}", file=sys.stderr)
print(f"Base commit: {instance['base_commit']}", file=sys.stderr)

# Print instance data as JSON for the shell script to use
print(json.dumps(instance, indent=2))
EOF

# Track statistics
TOTAL_INSTANCES=$((END_INDEX - START_INDEX))
SUCCESSFUL_RUNS=0
FAILED_RUNS=0
FAILED_INSTANCES=()

# Process each instance in the range
for ((i=START_INDEX; i<END_INDEX; i++)); do
    CURRENT_NUM=$((i - START_INDEX + 1))
    echo ""
    echo "======================================"
    echo "Processing instance $i ($CURRENT_NUM/$TOTAL_INSTANCES)"
    echo "======================================"
    
    # Extract instance data
    echo "Extracting instance data..."
    INSTANCE_DATA=$(python /tmp/extract_instance_batch.py "$i" "$DATASET_NAME" "$DATASET_SPLIT" 2>&1)
    
    # Check if extraction was successful
    if [ $? -ne 0 ]; then
        echo "Error: Failed to extract instance $i"
        FAILED_RUNS=$((FAILED_RUNS + 1))
        FAILED_INSTANCES+=("$i (extraction failed)")
        continue
    fi
    
    # Parse the instance data
    INSTANCE_ID=$(echo "$INSTANCE_DATA" | tail -n +4 | python -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data['instance_id'])
except Exception as e:
    print('ERROR', file=sys.stderr)
    sys.exit(1)
")
    
    if [ "$INSTANCE_ID" == "ERROR" ] || [ -z "$INSTANCE_ID" ]; then
        echo "Error: Failed to parse instance ID for instance $i"
        FAILED_RUNS=$((FAILED_RUNS + 1))
        FAILED_INSTANCES+=("$i (parsing failed)")
        continue
    fi
    
    REPO_URL=$(echo "$INSTANCE_DATA" | tail -n +4 | python -c "
import sys, json
data = json.load(sys.stdin)
print('https://github.com/' + data['repo'])
")
    
    BASE_COMMIT=$(echo "$INSTANCE_DATA" | tail -n +4 | python -c "
import sys, json
data = json.load(sys.stdin)
print(data['base_commit'])
")
    
    PROBLEM_STATEMENT=$(echo "$INSTANCE_DATA" | tail -n +4 | python -c "
import sys, json
data = json.load(sys.stdin)
print(data['problem_statement'])
")
    
    echo "Instance ID: $INSTANCE_ID"
    echo "Repository URL: $REPO_URL"
    echo "Base Commit: $BASE_COMMIT"
    
    # Create a temporary problem statement file
    PROBLEM_STATEMENT_FILE="/tmp/problem_statement_${i}.md"
    echo "$PROBLEM_STATEMENT" > "$PROBLEM_STATEMENT_FILE"
    
    echo "Created problem statement file: $PROBLEM_STATEMENT_FILE"
    echo "Running SWE-agent..."
    
    # Run SWE-agent
    if sweagent run \
        --config "$CONFIG_PATH" \
        --agent.model.name "$MODEL_NAME" \
        --agent.model.per_instance_cost_limit 0.0 \
        --agent.model.total_cost_limit 0.0 \
        --env.repo.github_url "$REPO_URL" \
        --env.repo.base_commit "$BASE_COMMIT" \
        --problem_statement.path "$PROBLEM_STATEMENT_FILE" \
        --problem_statement.id "$INSTANCE_ID" \
        --output_dir "$OUTPUT_DIR" \
        --env.deployment.image "python:3.12"; then
        
        echo "✓ Successfully processed instance $i: $INSTANCE_ID"
        SUCCESSFUL_RUNS=$((SUCCESSFUL_RUNS + 1))
    else
        echo "✗ Failed to process instance $i: $INSTANCE_ID"
        FAILED_RUNS=$((FAILED_RUNS + 1))
        FAILED_INSTANCES+=("$i ($INSTANCE_ID)")
    fi
    
    # Clean up
    rm -f "$PROBLEM_STATEMENT_FILE"
    
    echo "Progress: $SUCCESSFUL_RUNS successful, $FAILED_RUNS failed out of $CURRENT_NUM processed"
done

# Clean up
rm -f /tmp/extract_instance_batch.py

echo ""
echo "======================================"
echo "Batch run completed!"
echo "======================================"
echo "Total instances processed: $TOTAL_INSTANCES"
echo "Successful runs: $SUCCESSFUL_RUNS"
echo "Failed runs: $FAILED_RUNS"

if [ $FAILED_RUNS -gt 0 ]; then
    echo ""
    echo "Failed instances:"
    for instance in "${FAILED_INSTANCES[@]}"; do
        echo "  - $instance"
    done
fi

echo ""
echo "Output directory: $OUTPUT_DIR"
echo "======================================"

