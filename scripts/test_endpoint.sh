curl https://trojanvectors--rnj-inference-serve.modal.run/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d '{
      "model": "rnj-1-instruct",
      "messages": [
        {"role": "user", "content": "What is the weather in San Francisco?"}
      ],
      "tools": [
        {
          "type": "function",
          "function": {
            "name": "get_weather",
            "description": "Get the current weather for a location",
            "parameters": {
              "type": "object",
              "properties": {
                "location": {"type": "string", "description": "City name"}
              },
              "required": ["location"]
            }
          }
        }
      ]
    }'