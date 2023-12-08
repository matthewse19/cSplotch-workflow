
This workflow runs the cSplotch model independently for each gene. The model is parallelized by running multiple VMs independetly, set by the _max_concurrent_vms_ input parameter. It is recommendend to run a few genes first, (i.e. set _splotch_gene_idxs_ to [1, 2, 3, 4, 5]) to estimate the minimum amount of memory and disk size required, and the amount of time each gene will take. The amount of time for each gene can be reduced be lowering the number of samples (175 is the lowest one should go). If the genes are completed in less than 24 hours, then _preemptible_ can be left at 2 so that the VM may be randomly forced to restart (and forced to restart at 24hrs) but will also cost significantly less. Otherwise, set _preemptible_ to be 0 so that the VM won't get restarted.

The workflow will create summarized output files for each gene (and not replace existing files withing _csplotch_output_dir_). The outputs are grouped into subdirectories which each contain 100 summary files.

### Inputs

_compositional_data_ - A boolean set to _true_ or _false_, indicating whether to run the compositional cSplotch model or the non-compositional Splotch model.

_csplotch_input_dir_ - The GS URI of the directory within the _root_dir_ where the gene input files exist.

_csplotch_output_dir_ - The GS URI of the directory within the _root_dir_ where the summarized output files will be placed (if a gene's output file already exists, then the workflow will skip over the gene).

_disk_size_gb_ - Size in GB that the VM should allocate for storage. 20GB should be sufficient for 32 Visium samples.

_max_concurrent_VMs_ - The number of VMs to distribute the set of genes across. 

_memory_ - The amount of memory allocated to each VM instanced. "16G" should be sufficient for 32 Visium arrays, but a pilot run on a few genes should be done first to obtain the minimum threshold for the amount of memory required.

_gene_timeout_hrs_ (default 24) - The number of hours the cSplotch model will run on a single gene before restarting or moving on to the next gene.

_num_chains_ (default 4) - The number of independent Hamiltonian Monte Carlo (HMC) chains to run.

_num_cpu_ (default 4) - The number of CPUs each VM will request. Should match the number of chains for optimal performance.

_hmc_samples_ (default 250) - The number of times each chain will draw a sample in the HMC process.

_preemptible_ (default 2) - Number of times to preempt a VM before switching to an on-demand machine. Preemptible machines will be forced to preempt/restart after 24 hours.

_splotch_gene_idxs_ (optional) - The integer indexes of the genes to run cSplotch on. If left blank, the first _total_genes_ number of genes will be ran.

_total_genes_ (optional) - The number of genes to run cSplotch on. Defaults to the length of _splotch_gene_idxs_ if the list is defined, otherwise 0 if also left blank. 

_tries_per_gene_ (default 1) - The number of timeouts alloted per gene before skipping to the next (value of 1 skips to next gene after first timeout).

_vm_total_retries_ (default 3) - The total number of allowed timeouts across all genes ran on the VM plus the number of preemptions.

