from openai import OpenAI
import json

client = OpenAI(
    api_key="sk-local",
    base_url="http://localhost:8000/v1",
)

tools = [
    {
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "Get current weather for a city",
            "parameters": {
                "type": "object",
                "properties": {
                    "location": {"type": "string"},
                    "unit": {"type": "string", "enum": ["celsius", "fahrenheit"]},
                },
                "required": ["location", "unit"],
            },
        },
    }
]

resp = client.chat.completions.create(
    model="rnj-1-8b-instruct",
    messages=[{"role": "user", "content": "What's the weather in San Francisco in celsius?"}],
    tools=tools,
    tool_choice="auto",  # vLLM supports auto/required/none depending on version :contentReference[oaicite:6]{index=6}
)

msg = resp.choices[0].message
print("tool_calls:", msg.tool_calls)

# If the model called a tool, execute it and send tool result back:
if msg.tool_calls:
    tc = msg.tool_calls[0]
    args = json.loads(tc.function.arguments)

    # your actual tool implementation here:
    tool_result = {"location": args["location"], "unit": args["unit"], "temp": 18}

    resp2 = client.chat.completions.create(
        model="rnj-1-8b-instruct",
        messages=[
            {"role": "user", "content": "What's the weather in San Francisco in celsius?"},
            msg,
            {"role": "tool", "tool_call_id": tc.id, "content": json.dumps(tool_result)},
        ],
    )
    print(resp2.choices[0].message.content)
