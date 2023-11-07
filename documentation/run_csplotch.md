
### Inputs

_compositional_data_ - A boolean set to _true_ or _false_, dictating whether to run the compositional cSplotch model or the non-compositional Splotch model.

_csplotch_input_dir_ - The gsutil URI of the directory within the _root_dir_ where the gene input files exist.

_csplotch_output_dir_ - The gsutil URI of the directory within the _root_dir_ where the summarized output files will be placed (if a gene's output file already exists, then the workflow will skip the gene).

_max_concurrent_VMs_ - The number of VMs to distribute the individual genes across. 

_gene_timeout_hrs_ (default 20) - The number of hours the cSplotch model will run on a single gene before restarting or moving on to the next gene.

_num_chains_ (default 4) - The number of independent MCMC chains to run.

_num_cpu_ (default 4) - The number of CPUs each VM will request. Should match the number of chains for optimal performance.

_num_samples_ (default 500) - The number of times each chain will draw a sample in the MCMC process.

_splotch_gene_idxs_ (optional) - The integer indexes of the genes to run cSplotch on. If left blank, the first _total_genes_ number of genes will be ran.

_total_genes_ (optional) - The number of genes to run cSplotch on. Defaults to the length of _splotch_gene_idxs_ if defined, otherwise 0 if also left blank. 

_tries_per_gene_ (default 1) - The number of timeouts alloted per gene before skipping to the next.

_vm_total_retries_ (default 3) - The total number of allowed timeouts across all genes ran on the VM plus the number of preemptions.

### Outputs

