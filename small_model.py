# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Copyright contributors to the vLLM project
from vllm import LLM, SamplingParams

# Load the Qwen3-0.6B model from Hugging Face
model_name = "Qwen/Qwen3-0.6B"

# Optional sampling parameters for decoding
sampling_params = SamplingParams(temperature=0.7, top_p=0.9, max_tokens=200)

# Initialize the LLM
llm = LLM(model=model_name)

# Prompt to ask
prompt = "What is the capital of France?"

# Generate a response
outputs = llm.generate(prompt, sampling_params)

# Print the generated output
for output in outputs:
    print("Prompt:", output.prompt)
    print("Response:", output.outputs[0].text.strip())
