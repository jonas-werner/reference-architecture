# PyTorch Distributed All-Reduce on Slurm

This directory contains two examples demonstrating how to run a basic distributed PyTorch application on a Slurm cluster. Both examples perform a simple `all_reduce` collective operation across all ranks (nodes) in the Slurm job allocation.

The primary goal is to illustrate two common methods for initializing `torch.distributed.ProcessGroup`:

1.  **Direct `srun` Invocation**: Manually setting environment variables from within the Slurm batch script and the Python script.
2.  **Using `torchrun`**: Leveraging PyTorch's launch utility to handle process creation and environment variable setup.

## Example 1: Direct `srun` Invocation

This method provides fine-grained control by manually mapping Slurm environment variables to those expected by PyTorch's `env://` initialization method.

### Key Files

*   `allreduce.sbatch`: The Slurm batch script. It derives `MASTER_ADDR` and `MASTER_PORT` and launches the Python script on each allocated node using `srun`.
*   `allreduce.py`: The Python script. It reads Slurm environment variables (`SLURM_NODEID`, `SLURM_JOB_NUM_NODES`, etc.) to set the required `RANK` and `WORLD_SIZE` environment variables before initializing the process group.

### How to Run

Submit the job to Slurm using `sbatch`:

```bash
sbatch allreduce.sbatch
```

## Example 2: Using `torchrun`

This is the modern, recommended approach for launching distributed PyTorch jobs. `torchrun` simplifies the launch process by automatically managing worker setup and teardown.

### Key Files

*   `allreduce-torchrun.sbatch`: The Slurm batch script. It still sets `MASTER_ADDR` and `MASTER_PORT`, but then uses `srun` to invoke `torchrun` on each node.
*   `allreduce-torchrun.py`: A simplified Python script. It does not need to manually interpret Slurm environment variables, as `torchrun` provides `RANK`, `WORLD_SIZE`, and `LOCAL_RANK` directly.

### How to Run

Submit the job to Slurm using `sbatch`:

```bash
sbatch allreduce-torchrun.sbatch
```
