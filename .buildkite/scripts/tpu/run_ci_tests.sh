#!/bin/bash

set -euo pipefail

CSV_FILE="$1"

if [[ ! -f "$CSV_FILE" ]]; then
    echo "CSV file $CSV_FILE does not exist."
    exit 1
fi

# Escape function definitions so we can pass them into the container
# --- Begin function and setup definitions ---
RUNNER_FUNCTIONS=$(cat <<'EOF'

set -e
set -u

echo "--- Starting script inside Docker container ---"

RESULTS_DIR=$(mktemp -d)
echo "Results will be stored in: $RESULTS_DIR"
tra
echo "--- Installing Python dependencies ---"
python3 -m pip install --progress-bar off git+https://github.com/thuml/depyf.git \
    && python3 -m pip install --progress-bar off pytest pytest-asyncio tpu-info \
    && python3 -m pip install --progress-bar off lm_eval[api]==0.4.4 \
    && python3 -m pip install --progress-bar off hf-transfer
echo "--- Python dependencies installed ---"

export VLLM_USE_V1=1
export VLLM_XLA_CHECK_RECOMPILATION=1
export VLLM_XLA_CACHE_PATH=
echo "Using VLLM V1"

echo "--- Hardware Information ---"

overall_script_exit_code=0

run_test() {
    local test_num=$1
    local test_name=$2
    local test_command=$3
    local log_file="$RESULTS_DIR/test_${test_num}.log"

    echo "--- TEST_$test_num: Running $test_name ---"
    eval "$test_command" > >(tee -a "$log_file") 2> >(tee -a "$log_file" >&2)
    local actual_exit_code=$?

    echo "TEST_${test_num}_COMMAND_EXIT_CODE: $actual_exit_code"
    echo "TEST_${test_num}_COMMAND_EXIT_CODE: $actual_exit_code" >> "$log_file"

    if [ "$actual_exit_code" -ne 0 ]; then
        echo "TEST_$test_num ($test_name) FAILED with exit code $actual_exit_code." >&2
        echo "--- Log for failed TEST_$test_num ($test_name) ---" >&2
        cat "$log_file" >&2 || echo "Log file not found." >&2
        echo "--- End of log for TEST_$test_num ($test_name) ---" >&2
        return "$actual_exit_code"
    else
        echo "TEST_$test_num ($test_name) PASSED."
        return 0
    fi
}

run_and_track_test() {
    local test_num="$1"
    local test_name="$2"
    local test_command="$3"

    run_test "$test_num" "$test_name" "$test_command"
    local test_exit_code=$?
    if [ "$test_exit_code" -ne 0 ]; then
        overall_script_exit_code=1
    fi
}
EOF
)
# --- End function and setup definitions ---

# Prepare the list of test commands from the CSV
TEST_LIST=$(awk -F',' 'NR > 1 || (NR == 1 && $1 != "name") {
    gsub(/\r/, "", $0);
    test_name=$1;
    test_path=$2;
    env_str=($3);
    printf("run_and_track_test %d \"%s\" \"%s python3 -m pytest -s -v /workspace/vllm/%s\"\n", NR-1, test_name, $3, test_path)
}' "$CSV_FILE")

# Compose the final command to run inside Docker
DOCKER_CMD=$(cat <<EOF
${RUNNER_FUNCTIONS}
${TEST_LIST}

if [ "\$overall_script_exit_code" -ne 0 ]; then
    echo "--- One or more tests FAILED. ---"
else
    echo "--- All tests PASSED. ---"
fi
exit "\$overall_script_exit_code"
EOF
)

# Build Docker image if not already done
docker build -f docker/Dockerfile.tpu -t vllm-tpu .

# Run the Docker container with the command
docker rm -f tpu-test >/dev/null 2>&1 || true

source /etc/environment

docker run --privileged --net host --shm-size=16G -it \
    -e "HF_TOKEN=${HF_TOKEN:-}" \
    --name tpu-test \
    vllm-tpu /bin/bash -c "$DOCKER_CMD"
