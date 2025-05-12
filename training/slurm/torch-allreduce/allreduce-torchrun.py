"""
Simple PyTorch Distributed All-Reduce Script (torchrun)
------------------------------------------------------
Launch with **torchrun**, e.g. from Slurm:

    torchrun \
        --nproc_per_node=1 \
        --nnodes=$SLURM_JOB_NUM_NODES \
        --node_rank=$SLURM_NODEID \
        --master_addr=$MASTER_ADDR \
        --master_port=$MASTER_PORT \
        allreduce_torch.py
"""

import logging
import os

import torch
import torch.distributed as dist

# -----------------------------------------------------------------------------
# Logging - emit INFO only on rank 0 to avoid duplicatio
# -----------------------------------------------------------------------------

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
if int(os.getenv("RANK", "0")) != 0:
    logger.setLevel(logging.WARNING)


# -----------------------------------------------------------------------------
# Main collective logic
# -----------------------------------------------------------------------------


def main() -> None:
    # torchrun populates these env vars for every rank
    rank = int(os.environ["RANK"])
    world_size = int(os.environ["WORLD_SIZE"])
    local_rank = int(os.environ["LOCAL_RANK"])

    logger.info(
        "Initializing process group (backend=nccl, rank=%d, world_size=%d):",
        rank,
        world_size,
    )
    dist.init_process_group(backend="nccl", init_method="env://")
    logger.info("Process group ready.")

    # Pin this rank to its designated GPU
    torch.cuda.set_device(local_rank)
    logger.info("Pinned to CUDA device %d", local_rank)

    # Perform a simple all-reduce (SUM) across ranks
    tensor = torch.tensor([rank], device="cuda")
    logger.info("Performing all-reduce (SUM):")
    dist.all_reduce(tensor, op=dist.ReduceOp.SUM)

    logger.info("All-reduce result on rank %d: %d", rank, tensor.item())

    dist.destroy_process_group()
    logger.info("Finished.")


if __name__ == "__main__":
    main()
