#!/bin/bash

# Simple script to merge prediction files for SWE-Bench evaluation
# Usage: ./merge_preds.sh [predictions_dir] [output_file]

set -e

PREDICTIONS_DIR=${1:-"predictions"}
OUTPUT_FILE=${2:-"$PREDICTIONS_DIR/preds.json"}

echo "=== Merging SWE-agent Predictions ==="
echo "Predictions directory: $PREDICTIONS_DIR"
echo "Output file: $OUTPUT_FILE"
echo "======================================"

# Count prediction files
PRED_COUNT=$(find "$PREDICTIONS_DIR" -name "*.pred" | wc -l | tr -d ' ')
echo "Found $PRED_COUNT prediction file(s)"

if [ "$PRED_COUNT" -eq 0 ]; then
    echo "❌ No prediction files found in $PREDICTIONS_DIR"
    exit 1
fi

# Use SWE-agent's built-in merge tool
echo "Merging predictions..."
uv run python -m sweagent.run.merge_predictions "$PREDICTIONS_DIR" --output "$OUTPUT_FILE"

echo ""
echo "✅ Successfully created: $OUTPUT_FILE"
echo ""
echo "To verify the output:"
echo "  uv run python -c \"import json; preds = json.load(open('$OUTPUT_FILE')); print(f'Total: {len(preds)} predictions')\""

