#!/bin/bash
###############################################################################
#
# MIT License
#
# Copyright (c) 2024 Advanced Micro Devices, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#################################################################################
set -ex

#TODO: remove these env vars when the docker img (rocm/pytorch-private:20240827_exec_dashboard_unified_rc6_withvllm) is pre-configured 

# vLLM performance settings
export HIP_FORCE_DEV_KERNARG=1
export VLLM_USE_ROCM_CUSTOM_PAGED_ATTN=1
export VLLM_USE_TRITON_FLASH_ATTN=0
export VLLM_INSTALL_PUNICA_KERNELS=1
export TOKENIZERS_PARALLELISM=false
export RAY_EXPERIMENTAL_NOSET_ROCR_VISIBLE_DEVICES=1
export NCCL_MIN_NCHANNELS=112

# PyTorch tunableOp settings
export PYTORCH_TUNABLEOP_ENABLED=1
export PYTORCH_TUNABLEOP_TUNING=0
export PYTORCH_TUNABLEOP_VERBOSE=0
export PYTORCH_TUNABLEOP_NUMERICAL_CHECK=0
export PYTORCH_TUNABLEOP_FILENAME=/pre-tuned/afo_tune_device_%d_full.csv

if [[ "$MAD_SYSTEM_GPU_ARCHITECTURE" != *"gfx94"* ]] && [[ "$MAD_SYSTEM_GPU_ARCHITECTURE" != *"gfx90a"* ]]; then 
	echo "Unsuported GPU arch detected, please use supported GPU archetecture (MI300X | MI250 | MI210)\n"
	exit 1
fi

# Parse named arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --model_repo) MODEL_NAME="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
    case $1 in
        --test_option) TEST_OPTION="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
    case $1 in
        --num_gpu) N_GPUS="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
    case $1 in
        --datatype) DTYPE="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

TEST_OPTION_SP=""
for i in $(echo $TEST_OPTION | tr "," "\n")
do
  TEST_OPTION_SP="$TEST_OPTION_SP $i"
done

DTYPE_SP=""
for i in $(echo $DTYPE | tr "," "\n")
do
  DTYPE_SP="$DTYPE_SP $i"
done

export HF_HUB_CACHE="/myworkspace"

echo "=hyper params start="
echo $MODEL_NAME
echo $TEST_OPTION_SP
echo $DTYPE_SP
echo "=hyper params end="

for scenario in $TEST_OPTION_SP; do
    for dtype in $DTYPE_SP; do
        ./vllm_benchmark_report.sh -s $scenario -m $MODEL_NAME -g $N_GPUS -d $dtype
    done
done
