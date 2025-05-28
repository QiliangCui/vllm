#!/bin/bash

TIMEZONE="America/Los_Angeles"
TAG="$(TZ="$TIMEZONE" date +%Y%m%d_%H%M%S)"

RESULT="/tmp/result.txt"

if [ ! -f "$1" ]; then
  echo "Error: The env file '$1' does not exist."
  echo "Error: The env file '$1' does not exist." >> $RESULT
  exit 1  # Exit the script with a non-zero status to indicate an error
fi


ENV_FILE=$1

set -a
source $ENV_FILE
set +a

export VLLM_CODE="."

mkdir -p "/tmp/log/$TAG"
LOG_ROOT="/tmp/log/$TAG"
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

if [ -d "$HOME/miniconda3" ]; then
  CONDA="$HOME/miniconda3"
elif [ -d "/opt/conda" ]; then
  CONDA="/opt/conda"
else
  echo "Error: Conda installation not found." >&2
  exit 1
fi

# Check if the environment "vllm" does NOT exist
if ! $CONDA/bin/conda info --envs | grep -qE "^\s*vllm\s"; then
    echo "Environment 'vllm' does not exist. Creating..."
    $CONDA/bin/conda create -y -n vllm python=3.11
else
    echo "Environment 'vllm' already exists. Skipping creation."
fi

echo "running tag $TAG"
echo "result file $RESULT"
echo

if [ "$LOCAL_RUN" != "1" ]; then
  echo "docker pull $IMAGE_NAME"
  echo
  sudo docker pull $IMAGE_NAME
fi



sleep 1

IFS=';' read -ra models <<< "$MODELS"

table_results=""

# Loop through each pair and print it
for pair in "${models[@]}"; do
    # trim leading/trailing spaces
    pair=$(echo "$pair" | xargs)
    echo "iteration: $pair"  
    short_model=$(echo "$pair" | cut -d' ' -f1)
    model_name=$(echo "$pair" | cut -d' ' -f2-)

    echo "===== run model $model_name... ===="
    echo

    if [ "$LOCAL_RUN" -eq 1 ]; then    
      echo "run on local vm."
      export WORKSPACE="/tmp/workspace"

      echo "delete work space $WORKSPACE"
      echo
      rm -rf $WORKSPACE

      echo "Create workspace..."
      mkdir -p $WORKSPACE    

      echo "source $CONDA/bin/activate vllm"
      source $CONDA/bin/activate vllm
      echo "run script..."
      echo
      MODEL=$model_name HF_TOKEN=$HF_SECRETE benchmarks/tpu/run_bm.sh
      conda deactivate

      echo "copy result back..."
      VLLM_LOG="$LOG_ROOT/$short_model"_vllm_log.txt
      BM_LOG="$LOG_ROOT/$short_model"_bm_log.txt
      TABLE_FILE="/tmp/$short_model"_table.txt
      cp "$WORKSPACE/vllm_log.txt" "$VLLM_LOG" 
      cp "$WORKSPACE/bm_log.txt" "$BM_LOG"      
      current_hash=$(cat $WORKSPACE/hash.txt)

    else      
      echo "run on docker -- not implemented yet"
      exit 1
    fi

    through_put=$(grep "Request throughput (req/s):" "$BM_LOG" | sed 's/[^0-9.]//g')
    echo "through put for $short_model: $through_put"
    echo "through put for $short_model: $through_put" >> "$RESULT"    
    if [ -n "$current_hash" ]; then
      echo "$TAG,$current_hash,$through_put" >> "$TABLE_FILE"
    fi    
    echo
done

echo "delete unused docker images"
echo "sudo docker image prune -f"

