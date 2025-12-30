#!/bin/bash

# Script to generate prediction file for a single instance from AthenaAgent42/ansible-swe-bench-pro dataset
# Usage: ./run.sh [instance_index] [model_name] [config_path]

set -e  # Exit on any error

# Default values
INSTANCE_INDEX=${1:-0}  # Default to first instance (index 0)
MODEL_NAME=${2:-"gpt-4o"}  # Default model
CONFIG_PATH=${3:-"config/default.yaml"}  # Default config

# Dataset information
DATASET_NAME="AthenaAgent42/ansible-swe-bench-pro"
DATASET_SPLIT="test"

# Output directory
OUTPUT_DIR="./predictions"
mkdir -p "$OUTPUT_DIR"

echo "=== SWE-agent Single Instance Run ==="
echo "Dataset: $DATASET_NAME"
echo "Instance Index: $INSTANCE_INDEX"
echo "Model: $MODEL_NAME"
echo "Config: $CONFIG_PATH"
echo "Output Directory: $OUTPUT_DIR"
echo "======================================"

# Create a Python script to extract the instance data
cat > /tmp/extract_instance.py << 'EOF'
import sys
from datasets import load_dataset
import json

instance_index = int(sys.argv[1])
dataset_name = sys.argv[2]
split = sys.argv[3]

# Load dataset
print(f"Loading dataset {dataset_name}...")
ds = load_dataset(dataset_name, split=split)

if instance_index >= len(ds):
    print(f"Error: Instance index {instance_index} is out of range. Dataset has {len(ds)} instances.")
    sys.exit(1)

# Get the specific instance
instance = ds[instance_index]

print(f"Extracted instance {instance_index}: {instance['instance_id']}")
print(f"Repository: {instance['repo']}")
print(f"Base commit: {instance['base_commit']}")

# Print instance data as JSON for the shell script to use
print("INSTANCE_DATA_JSON:")
print(json.dumps(instance, indent=2))
EOF

# Extract instance data
echo "Extracting instance data..."
INSTANCE_OUTPUT=$(python /tmp/extract_instance.py "$INSTANCE_INDEX" "$DATASET_NAME" "$DATASET_SPLIT")

# Parse the instance data (this is a simple approach, could be made more robust)
INSTANCE_ID=$(echo "$INSTANCE_OUTPUT" | grep -A 100 "INSTANCE_DATA_JSON:" | tail -n +2 | python -c "
import sys, json
data = json.load(sys.stdin)
print(data['instance_id'])
")

REPO_URL=$(echo "$INSTANCE_OUTPUT" | grep -A 100 "INSTANCE_DATA_JSON:" | tail -n +2 | python -c "
import sys, json
data = json.load(sys.stdin)
print('https://github.com/' + data['repo'])
")

BASE_COMMIT=$(echo "$INSTANCE_OUTPUT" | grep -A 100 "INSTANCE_DATA_JSON:" | tail -n +2 | python -c "
import sys, json
data = json.load(sys.stdin)
print(data['base_commit'])
")

PROBLEM_STATEMENT=$(echo "$INSTANCE_OUTPUT" | grep -A 100 "INSTANCE_DATA_JSON:" | tail -n +2 | python -c "
import sys, json
data = json.load(sys.stdin)
print(data['problem_statement'])
")

echo "Instance ID: $INSTANCE_ID"
echo "Repository URL: $REPO_URL"
echo "Base Commit: $BASE_COMMIT"

# Create a temporary problem statement file
PROBLEM_STATEMENT_FILE="/tmp/problem_statement_${INSTANCE_INDEX}.md"
echo "$PROBLEM_STATEMENT" > "$PROBLEM_STATEMENT_FILE"

echo "Created problem statement file: $PROBLEM_STATEMENT_FILE"
echo "Running SWE-agent..."

# Run SWE-agent
sweagent run \
    --config "$CONFIG_PATH" \
    --agent.model.name "$MODEL_NAME" \
    --env.repo.github_url "$REPO_URL" \
    --env.repo.base_commit "$BASE_COMMIT" \
    --problem_statement.path "$PROBLEM_STATEMENT_FILE" \
    --problem_statement.id "$INSTANCE_ID" \
    --output_dir "$OUTPUT_DIR" \
    --env.deployment.image "python:3.12"

echo "======================================"
echo "SWE-agent run completed!"
echo "Check the output directory: $OUTPUT_DIR"
echo "Instance processed: $INSTANCE_ID"

# Clean up
rm -f /tmp/extract_instance.py "$PROBLEM_STATEMENT_FILE"

echo "Prediction file should be available in: $OUTPUT_DIR"