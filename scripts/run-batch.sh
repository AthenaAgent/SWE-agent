#!/bin/bash

# Script to run SWE-agent on multiple instances from the dataset
# Usage: ./run-batch.sh [start_index] [end_index]

set -e  # Exit on any error

# Configuration
MODEL_NAME="openai/rnj-1-instruct"
CONFIG_PATH="config/default.yaml"
BASE_URL="https://trojanvectors--rnj-inference-serve.modal.run/v1"

# Get start and end indices from arguments
START_INDEX=${1:-0}
END_INDEX=${2:-9}  # Default to 10 instances (0-9)

echo "=== SWE-agent Batch Run ==="
echo "Model: $MODEL_NAME"
echo "Config: $CONFIG_PATH"
echo "Base URL: $BASE_URL"
echo "Processing instances from $START_INDEX to $END_INDEX"
echo "======================================"

# Loop through instances
for i in $(seq $START_INDEX $END_INDEX); do
    echo ""
    echo ">>> Processing instance $i..."
    echo ""
    
    ./scripts/run.sh "$i" "$MODEL_NAME" "$CONFIG_PATH" "$BASE_URL"
    
    if [ $? -eq 0 ]; then
        echo "✓ Instance $i completed successfully"
    else
        echo "✗ Instance $i failed"
        # Continue with next instance even if this one fails
    fi
    
    echo "======================================"
done

echo ""
echo "=== Batch processing complete ==="
echo "Processed instances: $START_INDEX to $END_INDEX"
echo "Check ./predictions/ for output files"
