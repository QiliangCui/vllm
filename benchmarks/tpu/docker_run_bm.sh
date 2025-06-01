#!/bin/bash

TIMEZONE="America/Los_Angeles"
TIME_TAG="$(TZ="$TIMEZONE" date +%Y%m%d_%H%M%S)"

if [ ! -f "$1" ]; then
  echo "Error: The env file '$1' does not exist."
  echo "Error: The env file '$1' does not exist." >> $RESULT
  exit 1  # Exit the script with a non-zero status to indicate an error
fi

ENV_FILE=$1

# For testing on local vm, use `set -a` to export all variables
source /etc/environment
source $ENV_FILE
cat $ENV_FILE
echo "========$CONTAINER_NAME========"

mkdir -p "./log/$TIME_TAG"
LOG_ROOT="./log/$TIME_TAG"

echo "time:$TIME_TAG"

if [ -z "$HF_TOKEN" ]; then
  echo "Error: HF_TOKEN is not set or is empty."  
  exit 1
fi

# Make sure mounted disk or dir exists
if [ ! -d "$DOWNLOAD_DIR" ]; then
    echo "Error: Folder $DOWNLOAD_DIR does not exist. This is useually a mounted drive. If no mounted drive, just create a folder."
    exit 1
fi

echo "Run model $MODEL"
echo

echo "deleteing docker $CONTAINER_NAME"
echo
docker rm -f "$CONTAINER_NAME"

echo "starting docker...$CONTAINER_NAME"
echo    
docker run -v $DOWNLOAD_DIR:$DOWNLOAD_DIR --env-file $ENV_FILE -e HF_TOKEN="$HF_TOKEN" -e MODEL=$MODEL -e WORKSPACE=/workspace --name $CONTAINER_NAME -d --privileged --network host -v /dev/shm:/dev/shm vllm/vllm-tpu-bm:$BUILDKITE_COMMIT tail -f /dev/null

echo "run script..."
echo
docker exec "$CONTAINER_NAME" /bin/bash -c "benchmarks/tpu/run_bm.sh"

echo "copy result back..."
VLLM_LOG="$LOG_ROOT/$TEST_NAME"_vllm_log.txt
BM_LOG="$LOG_ROOT/$TEST_NAME"_bm_log.txt
TABLE_FILE="./$TEST_NAME"_table.txt
docker cp "$CONTAINER_NAME:/workspace/vllm_log.txt" "$VLLM_LOG" 
docker cp "$CONTAINER_NAME:/workspace/bm_log.txt" "$BM_LOG"

# todo - the code is using current_hash as indicator of if it runs successfully.
current_hash=$BUILDKITE_COMMIT


through_put=$(grep "Request throughput (req/s):" "$BM_LOG" | sed 's/[^0-9.]//g')
echo "through put for $TEST_NAME at current_hash: $through_put"

echo "deleteing docker $CONTAINER_NAME"
echo
docker rm -f "$CONTAINER_NAME"

if [ "$BUILDKITE" = "true" ]; then
  echo "Running inside Buildkite"
  buildkite-agent artifact upload "$VLLM_LOG" 
  buildkite-agent artifact upload "$BM_LOG"
else
  echo "Not running inside Buildkite"
fi
