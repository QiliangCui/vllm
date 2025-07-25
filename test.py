# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Copyright contributors to the vLLM project
from tqdm.auto import tqdm

from vllm.entrypoints.llm import LLM


class DisabledTqdm(tqdm):

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs, disable=True)


guided_decoding_backend = "xgrammar"
tokenizer_mode = "auto"
speculative_config = None
llm = LLM(
    # model="mistralai/Ministral-8B-Instruct-2410",
    model="Qwen/Qwen3-1.7B",
    enforce_eager=False,
    max_model_len=1024,
    guided_decoding_backend=guided_decoding_backend,
    guided_decoding_disable_any_whitespace=(guided_decoding_backend
                                            in {"xgrammar", "guidance"}),
    tokenizer_mode=tokenizer_mode,
    speculative_config=speculative_config)

print(f"done!! {type(llm)}")
