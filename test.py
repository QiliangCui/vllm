# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Copyright contributors to the vLLM project
from tqdm.auto import tqdm

from vllm.entrypoints.llm import LLM


class DisabledTqdm(tqdm):

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs, disable=True)


# hf_logging.set_verbosity_debug()
# good
# snapshot_download(
#             "mistralai/Ministral-8B-Instruct-2410",
#             allow_patterns=['*.safetensors'],
#             ignore_patterns=['original/**/*'],
#             cache_dir="/mnt/disks/persist",
#             tqdm_class=DisabledTqdm,
#             revision=None,
#             local_files_only=False,
#         )

#
# good to be run along `python3 test.py`
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

# def test_download():
#     guided_decoding_backend = "xgrammar"
#     tokenizer_mode = "auto"
#     speculative_config = None

#     llm = LLM(
#         model="Qwen/Qwen3-1.7B",
#         # model="mistralai/Ministral-8B-Instruct-2410",
#         enforce_eager=False,
#         max_model_len=1024,
#         guided_decoding_backend=guided_decoding_backend,
#         guided_decoding_disable_any_whitespace=(guided_decoding_backend
#                                                 in {"xgrammar", "guidance"}),
#         tokenizer_mode=tokenizer_mode,
#         speculative_config=speculative_config,
#         download_dir="/mnt/disks/persist")

#     print(f"done!! {type(llm)}")
