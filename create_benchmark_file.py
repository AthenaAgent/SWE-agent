#!/usr/bin/env python3
"""Create a properly formatted SWE-Bench prediction file from predictions directory.

This script handles the mapping between shortened instance IDs (used in directory names)
and full instance IDs (required for SWE-Bench evaluation).
"""

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from datasets import load_dataset


def get_shortened_id(full_id: str) -> str:
    """Generate a shortened ID from a full instance ID using the same method as SWE-agent.
    
    SWE-agent uses the first 6 characters of the MD5 hash of the instance ID.
    """
    return hashlib.md5(full_id.encode()).hexdigest()[:6]


def create_benchmark_file(
    predictions_dir: Path,
    dataset_name: str,
    dataset_split: str,
    output_file: Path | None = None,
) -> None:
    """Create a SWE-Bench benchmark file from predictions directory.
    
    Args:
        predictions_dir: Directory containing prediction subdirectories
        dataset_name: Name of the dataset to load (e.g., 'AthenaAgent42/ansible-swe-bench-pro')
        dataset_split: Dataset split (e.g., 'test')
        output_file: Output file path. If None, writes to predictions_dir/preds.json
    """
    if output_file is None:
        output_file = predictions_dir / "preds.json"
    
    print(f"Loading dataset {dataset_name} (split: {dataset_split})...")
    dataset = load_dataset(dataset_name, split=dataset_split)
    
    # Create a mapping from shortened IDs to full instance IDs
    id_mapping = {}
    for item in dataset:
        full_id = item["instance_id"]
        short_id = get_shortened_id(full_id)
        id_mapping[short_id] = full_id
    
    print(f"Found {len(id_mapping)} instances in dataset")
    print(f"Example mapping: {list(id_mapping.items())[0] if id_mapping else 'None'}")
    
    # Find all .pred files
    pred_files = list(predictions_dir.rglob("*.pred"))
    print(f"\nFound {len(pred_files)} prediction files:")
    
    if not pred_files:
        print("❌ No prediction files found!")
        return
    
    # Process predictions
    predictions: dict[str, dict[str, Any]] = {}
    for pred_file in pred_files:
        pred_data = json.loads(pred_file.read_text())
        short_id = pred_data["instance_id"]
        
        # Try to map to full instance ID
        if short_id in id_mapping:
            full_id = id_mapping[short_id]
            print(f"  ✓ {pred_file.parent.name}: {short_id} -> {full_id}")
        else:
            # If not found in mapping, use as-is (might already be full ID)
            full_id = short_id
            print(f"  ⚠ {pred_file.parent.name}: Using original ID: {short_id}")
        
        # Update with full instance ID
        pred_data["instance_id"] = full_id
        
        # Ensure model_patch is a string
        if "model_patch" not in pred_data:
            print(f"  ⚠ Prediction {pred_file} does not contain a model_patch. SKIPPING")
            continue
        
        pred_data["model_patch"] = (
            str(pred_data["model_patch"]) if pred_data["model_patch"] is not None else ""
        )
        
        if full_id in predictions:
            print(f"  ⚠ Duplicate instance ID: {full_id}")
            continue
        
        predictions[full_id] = pred_data
    
    # Write output file
    output_file.parent.mkdir(parents=True, exist_ok=True)
    output_file.write_text(json.dumps(predictions, indent=2))
    
    print(f"\n✅ Successfully created benchmark file: {output_file}")
    print(f"   Total predictions: {len(predictions)}")
    print(f"\n📝 You can now use this file for SWE-Bench evaluation")


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "predictions_dir",
        type=Path,
        help="Directory containing prediction files",
    )
    parser.add_argument(
        "--dataset",
        type=str,
        default="AthenaAgent42/ansible-swe-bench-pro",
        help="Dataset name (default: AthenaAgent42/ansible-swe-bench-pro)",
    )
    parser.add_argument(
        "--split",
        type=str,
        default="test",
        help="Dataset split (default: test)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="Output file path (default: predictions_dir/preds.json)",
    )
    
    args = parser.parse_args()
    
    create_benchmark_file(
        predictions_dir=args.predictions_dir,
        dataset_name=args.dataset,
        dataset_split=args.split,
        output_file=args.output,
    )


if __name__ == "__main__":
    main()
