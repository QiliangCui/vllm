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

source /etc/environment

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

if [ -d "/opt/conda" ]; then
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

echo "source $CONDA/bin/activate vllm"
source $CONDA/bin/activate vllm
echo "run script..."

# WARNING:root:libtpu.so and TPU device found. Setting PJRT_DEVICE=TPU.
echo "USER $USER"
echo "PWD $PWD"

echo "run the python script"
python -c "import torch_xla.core.xla_model as xm; print(xm.xla_device())"