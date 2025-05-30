#!/bin/bash

TIMEZONE="America/Los_Angeles"
TAG="$(TZ="$TIMEZONE" date +%Y%m%d_%H%M%S)"

RESULT="./result.txt"
if [ ! -f "$1" ]; then
  echo "Error: The env file '$1' does not exist."
  echo "Error: The env file '$1' does not exist." >> $RESULT
  exit 1  # Exit the script with a non-zero status to indicate an error
fi

ENV_FILE=$1

set -a
source $ENV_FILE
set +a

mkdir -p "./log/$TAG"
LOG_ROOT="./log/$TAG"
REMOTE_LOG_ROOT="gs://$GCS_BUCKET/$HOSTNAME/log/$TAG"

echo "time:$TAG" >> "$RESULT"

# HF_SECRETE=<your hugging face secrete>
if [ -z "$HF_SECRETE" ]; then
  echo "Error: HF_SECRETE is not set or is empty."
  echo "Error: HF_SECRETE is not set or is empty." >> "$RESULT"
  exit 1
fi

# Make sure mounted disk or dir exists
if [ ! -d "$MOUNT_DISK" ]; then
    echo "Error: Folder $MOUNT_DISK does not exist. This is useually a mounted drive. If no mounted drive, just create a folder."
    exit 1
fi

IFS=';' read -ra models <<< "$MODELS"
for pair in "${models[@]}"; do
    # trim leading/trailing spaces
    pair=$(echo "$pair" | xargs)
    echo "iteration: $pair"  
    short_model=$(echo "$pair" | cut -d' ' -f1)
    model_name=$(echo "$pair" | cut -d' ' -f2-)

    echo "===== run model $model_name... ===="
    echo
    
    echo "deleteing docker $CONTAINER_NAME"
    echo
    docker rm -f "$CONTAINER_NAME"

    echo "starting docker...$CONTAINER_NAME"
    echo    
    docker run -v $MOUNT_DISK:$DOWNLOAD_DIR --env-file $ENV_FILE -e HF_TOKEN="$HF_SECRETE" -e MODEL=$model_name -e WORKSPACE=/workspace --name $CONTAINER_NAME -d --privileged --network host -v /dev/shm:/dev/shm vllm/vllm-tpu-bm:$BUILDKITE_COMMIT tail -f /dev/null             

    echo "run script..."
    echo
    docker exec "$CONTAINER_NAME" /bin/bash -c "benchmarks/tpu/run_bm.sh"
    
    echo "copy result back..."
    VLLM_LOG="$LOG_ROOT/$short_model"_vllm_log.txt
    BM_LOG="$LOG_ROOT/$short_model"_bm_log.txt
    TABLE_FILE="./$short_model"_table.txt
    docker cp "$CONTAINER_NAME:/workspace/vllm_log.txt" "$VLLM_LOG" 
    docker cp "$CONTAINER_NAME:/workspace/bm_log.txt" "$BM_LOG"

    # todo - the code is using current_hash as indicator of if it runs successfully.
    current_hash=$BUILDKITE_COMMIT


    through_put=$(grep "Request throughput (req/s):" "$BM_LOG" | sed 's/[^0-9.]//g')
    echo "through put for $short_model: $through_put"
    echo "through put for $short_model: $through_put" >> "$RESULT"    
    if [ -n "$current_hash" ]; then
      echo "$TAG,$current_hash,$through_put" >> "$TABLE_FILE"
    fi    
    echo
done