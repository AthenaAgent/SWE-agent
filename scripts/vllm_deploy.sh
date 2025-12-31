export CUDA_VISIBLE_DEVICES=0,1
export HF_TOKEN=YOUR_TOKEN
export VLLM_API_KEY=sk-local

vllm serve EssentialAI/rnj-1-instruct \
  --host 0.0.0.0 --port 8000 \
  --served-model-name rnj-1-8b-instruct \
  --tensor-parallel-size 2 \
  --dtype bfloat16 \
  --max-model-len 32768 \
  --kv-cache-dtype fp8 \
  --calculate-kv-scales \
  --enable-chunked-prefill \
  --gpu-memory-utilization 0.90 \
  --max-num-seqs 2 \
  --enable-auto-tool-choice \
  --tool-call-parser hermes \
  --api-key "$VLLM_API_KEY"
