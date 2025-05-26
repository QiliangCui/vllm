#!/bin/bash

# backup project.toml.back
cp pyproject.toml pyproject.toml.bak

# rename
sed 's/name = "vllm"/name = "vllm-tpu"/' pyproject.toml.bak > pyproject.toml

# commit changes
git add pyproject.toml.bak 
git add pyproject.toml



