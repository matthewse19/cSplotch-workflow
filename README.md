# cSplotch in Terra

This workspace contains the Terra workflows to run cSplotch, a hierarchical generative probabilistic model for analyzing Spatial Transcriptomics (ST) [[1]](#references) and 10x Genomics' Visium data. 


## cSplotch Model Features
- Supports complex hierarchical experimental designs and model-based analysis of replicates
- Full Bayesian inference with Hamiltonian Monte Carlo (HMC) using the adaptive HMC sampler as implemented in Stan [[2]](#references)
- Analysis of expression differences between anatomical regions and conditions using posterior samples
- Different anatomical annotated regions are modelled using a linear model
- Zero-inflated Poisson or Poisson likelihood for counts
- Conditional autoregressive (CAR) prior for spatial random effect
- Ability to deconvolve gene expression into cell type-specific signatures using compositional data gathered from histology images
- Use single-cell/single-nuclear expression data to calculate priors over expression in each cell type

We support the original ST array design (1007 spots, a diameter of 100 μm, and a center-to-center distance of 200 μm) by [Spatial Transcriptomics AB](https://spatialtranscriptomics.com), as well as [Visium Spatial Gene Expression Solution](https://www.10xgenomics.com/spatial-transcriptomics/) by [10x Genomics, Inc.](https://www.10xgenomics.com), interfacing directly with file formats output by [Spaceranger and Loupe Browser](https://support.10xgenomics.com/spatial-gene-expression/software/pipelines/latest/output/overview).


For more details on the cSplotch probablistic model, or to run cSplotch locally, visit the GitHub page https://github.com/adaly/cSplotch. A diagram of the cSplotch model from the GitHub is illustrated below:

![Hierarchical models](https://github.com/adaly/cSplotch/blob/bd7f77dfc7414f432f6e05ab9789b7aa593b12b4/cSplotch_Model.png?raw=true)

## cSplotch Worfklows

There are three workflows that must be run to get the cSplotch output and there is one workflow to assist in identifying differential expression in genes. 

The following must run successfully in order:
1. **[Prepare_Count_Files](https://app.terra.bio/#workspaces/techinno/cSplotch/workflows/techinno/Prepare_Count_Files)** - creates unified count files for each sample and filters lowly expressed genes
2. **[Generate_Input_files](https://app.terra.bio/#workspaces/techinno/cSplotch/workflows/techinno/Generate_Input_Files)** - generates an individual input file for each gene and specifies the model parameters
3. **[Run_cSplotch](https://app.terra.bio/#workspaces/techinno/cSplotch/workflows/techinno/Run_Splotch)** - runs the cSplotch model and outputs the posterior likelihoods for a given gene
4. **[Gene_Diff_Exp](https://app.terra.bio/#workspaces/techinno/cSplotch/workflows/techinno/Gene_Diff_Exp)** - calculates Bayes Factor and log2 fold change between a given pair of conditions/regions for all genes

# Workflow descriptions and inputs

## Global runtime input parameters
The following input parameters are present in all of the cSplotch Terra workflows. For a more in-depth explanation of each parameter, see https://cromwell.readthedocs.io/en/stable/RuntimeAttributes/.

_disk\_size\_gb_ - Size in GB that the VM should allocate for storage.

_boot\_disk\_size\_gb_ (default 6) - Size of the disk where the docker image is booted.

_docker_ (default "us-central1-docker.pkg.dev/techinno/images/csplotch_img:latest") - Docker image to use for the VM (it must have cSplotch and CmdStan installed and use google-cloud-cli as a base, see the [csplotch_img](https://github.com/matthewse19/cSplotch-workflow/blob/main/Dockerfile) default Dockerfile). 

_memory_ (e.g. "16G" for 16GB) - Amount of RAM to use.

_preemptible_ (default 2) - Number of times to preempt a VM before switching to an on-demand machine.

_zones_ (default "us-central1-a us-central1-b... us-east1-a us-east1-b... us-west1-a us-west1-b...") - Ordered list of zone preference. 


Many of the workflows also have inputs which supposed to be the Google Cloud GS URIs pointing to folders (e.g. _root_dir_, _spaceranger_dir_, _st_cout_dir_, etc).
These strings must start with _gs://_ and are then followed by the URI of the folder. To find the URI of specific directory, nagivate to https://console.cloud.google.com/storage/browser and find the directory within the bucket. The full URI (without the prefix _gs://_) of the folder can be copied as shown below:

![GS URI](https://github.com/matthewse19/cSplotch-workflow/blob/main/documentation/copy_gs_uri.png?raw=true)

## Prepare_Count_Files

This workflow creates a .unified.tsv file for each sample, which ensures that the gene indexing across all samples is consistent and also filters out lowly expressed genes. If Visium was used, only fill in the _spaceranger_dir_ input, otherwise for ST data, fill in _st_count_dir_.

### Inputs

_disk_size_gb_ - Size in GB that the VM should allocate for storage. Approximately 2GB for each sample should be sufficient.

_root_dir_ - GS URI (e.g. "gs://[bucket_uri]/[parent_dir]") to the root directory containing the cSplotch metadata file and the Spaceranger/ST directory. A _Prepare_Count_Files.log_ file will be placed in this directory after the Workflow is completed successfully. 

_memory_ (default "50G") - Amount of RAM. 50G for 32 Visium samples and 80G for 50 Visium samples should be sufficient.

_min_detection_rate_ (default 0.02) - Minimum expression rate over every labeled spot in all samples that a gene must have in order to be kept.

_spaceranger_dir_ - The GS URI (e.g. "gs://[bucket_uri]/[parent_dir]/spaceranger_output/") of the parent directory containing each sample's Spaceranger folder (not used for ST data).

_st_count_dir_ - The GS URI (e.g. "gs://[bucket_uri]/[parent_dir]/counts/") of the parent directory containing each sample's count file (not used for Visium data).


### Outputs
Before running the workflow, create a data table with a blank row so the outputs get stored. This can be done in the workspace by going to the Data tab > IMPORT DATA > Upload TSV > TEXT IMPORT > Copy and paste the following:
```
entity:cSplotch_run_id
mouse_colon
```
Now back in the **Prepare_Count_Files** workflow, ensure that "Run workflow(s) with inputs defined by data table" is chosen and click 'SELECT DATA' to choose the cSplotch run ID. In the outputs tab, enter the following for each output variable (or choose any other descriptive column name):

_genes_detected_ - this.genes_detected

_genes_kept_ - this.genes_kept

_median_seq_depth_ - this.median_seq_depth

After **Prepare_Count_Files** is completed successfully, the workflow will automatically populate these fields  in the selected row in the data table.

## Generate_Input_Files

This workflow generates an R dump formatted file for each gene, grouping the genes into subdirectories of 100 files each. The model structure must be specified in this step with the metadata file that is provided. 

The metadata file is a .TSV with the following columns: library_sample_id, Level 1, Level 2, Level 3, Count file, Annotation file, Spaceranger output (only for Visium data).
"Level 2" and "Level 3" may be left out if they are not applicable to the data.

See https://github.com/adaly/cSplotch/tree/master#annotation-of-st-spots on how to create and structure the samples' annotation files.

To determine the expression estimates of individual cell-types (and not just annotomical regions), a compositional file may be provided, and listed in a column titled "Composition file". See https://github.com/adaly/cSplotch/tree/master#annotation-of-cell-types on how to generate and structure the compositional files. 


Since all referenced files must be localized within a VM, the naming conventions of the metadata file is strict when using cSplotch in Terra. Paths in the Count file column must start with "./st_counts" for ST data and "./spaceranger_output" for Visium data. The Annotation file column must start with "./annotation", Composition file must start with "./composition", and the Spaceranger output column must start with "./spaceranger_output". 

An example row in a metadata file for a three level Visium data run would look like:

| library_sample_id | Level 1 | Level 2 | Level 3 | Count file                               | Annotation file      | Spaceranger output       |
|-------------------|---------|---------|---------|------------------------------------------|----------------------|--------------------------|
| 001               | Ctrl    | No EFI  | Male    | ./spaceranger_output/001/001.unified.tsv | ./annotation/001.csv | ./spaceranger_output/001 |

### Inputs

_annotation_dir_ - The GS URI of the annotation directory.

_csplotch_input_dir_ - The GS URI of an empty directory in the _root_dir_ where the gene input files will be placed and a file named _information.p_ which is a pickled Python dictionary that has useful metadata and model parameters about the run.

_disk_size_gb_ (default 120) - Size in GB that the VM should allocate for storage.

_metadata_file_ - The metadata file that is in the above structure.

_n_levels_ - The number of condition levels present in the metadata (1, 2, or 3).

_root_dir_ - The GS URI of the root directory containing the directories _annotation_dir_, _spaceranger_dir_/_st_count_dir_, _csplotch_input_dir_, and optionally _composition_dir_. A _Generate_Input_Files.log_ file will be placed in this directory after the workflow is completed successfully. 

_scaling_factor_ - The median sequencing depth over all spots which is found during **Prepare_Count_Files**. Select "Run workflow(s) with inputs defined by data table" and enter the value "this.median_seq_depth" to reference the value stored in data table's selected row. This value can also be found in _Prepare_Count_Files.log_ in the _root_dir_.

_composition_dir_ (optional) - The GS URI to the directory containing the composition files, referenced in the metadata file.

_empirical_priors_ (optional) - An AnnData (HDF5 format) file with single cell gene expression to inform the model's priors of the expression in each cell type (only for compositional data). 

_maximum_spots_per_tissue_ (default 4992) - Number of spots threshold for identifying overlapping tissue sections. 4992 covers an entire Visium array.

_memory_ (default "50G") - Amount of RAM. 50G should be sufficient for 32 Visium samples.

_minimum_sequencing_depth_ (default 100) - Minimum number of UMIs per spot.

_no_car_ (default false) - Disable the conditional autoregressive prior.

_no_zip_ (default false) - Use the Poisson likelihood instead of the default zero-inflated Poisson likelihood.

_sc_gene_symbols_ (optional) - Key in `AnnData.var` of the _empirical_priors_ file corresponding to gene names in ST count/Visium data (required when _empirical_priors_ is given; must match gene names in count files).

_sc_group_key_ (optional) - Key in `AnnData.obs` of the _empirical_priors_ file corresponding to cell type annotations (required when _empirical_priors_ is given; must match cell type naming in annotation files).

_spaceranger_dir_ - The GS URI (e.g. "gs://[bucket_uri]/[parent_dir]/spaceranger_output/") of the parent directory containing each sample's Spaceranger folder (not used for ST data).

_st_count_dir_ - The GS URI (e.g. "gs://[bucket_uri]/[parent_dir]/counts/") of the parent directory containing each sample's count file (not used for Visium data).


### Outputs

Enter the following in the output fields to easily access the "genes_indexes.csv" file that gets generated:

_gene_indexes_ - this.gene_indexes

This file has the columns "gene_index", "ensembl", "type" and "gene". It is a useful reference when wanting to run individual genes at a time in **Run_cSplotch** and is also needed in the **plotting_and_analysis.ipynb** notebook.

## Run_cSplotch

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

## Gene_Diff_Exp

This workflow calculates the [Bayes Factor](https://en.wikipedia.org/wiki/Bayes_factor) and log<sub>2</sub> fold change between two experimental groups. The groups can be specified by any level condition, anatomical annotation regions (AAR), or single cell types for compositional data.

The group corresponding with _test_type_ ("aars", "conditions" or "cells") must have a length of one (for one group vs the rest) or a length of two (to directly compare the two groups). The other groups that aren't of type _test_type_ are then used to subset the data.

For example, if _test_type_ = "aars", _condition_level_ = 1, _conditions_=["ALS"], and _aars_ = ["Layer_1", "Layer_2"], then the differential gene expression is calculated between the two groups of spots labeled as "Layer_1" and "Layer_2" for ALS samples.

### Inputs

_aars_ - When _test_type_ = "aars", these must be the two AARs to test against each other or one to test against the rest. Otherwise, the list is the specified AARs to subset the data by.

_condition_level_ - The condition/beta level that _conditions_ specifies.

_conditions_ - When _test_type_ = "conditions", these must be the two conditions to test against each other or one to test against the rest. Otherwise, the list is the specified conditions to subset the data by. These conditions must also be valid conditions for the specified _condition_level_ of the data.

_csplotch_output_dir_ - The GS URI of the directory where the summarized output files will be placed (if a gene's output file already exists, then the workflow will skip the gene).

_gene_indexes_ - The file named "gene_indexes.csv" that is produced by the **Generate_Input_Files** workflow. This file is used as a lookup for the gene and ensembl names of each cSplotch gene index.

_results_csv_name_ - Name of the results file that will be placed in the Google cloud _results_dir_ directory.

_results_dir_ - The GS URI of the directory where the results CSV file will be placed.

_splotch_information_p_ -  The pickled Python dictionary with cSplotch metadata that is output during the **Generate_Input_Files** workflow and typically located in the cSplotch input directory.

_test_type_ - Must be "conditions", "aars", or "cell_types" for compositional data. The corresponding variable list be must 

_cell_types_ (optional) - When _test_type_ = "cell_types", these must be the two cell types to test against each other or one to test against the rest. Otherwise, the list is the specified cell types to subset the data by. This is only applicable for compositional data.

_memory_ (default "32G") - Amount of RAM.

_num_cpu_ (default 1) - Number of CPUs to allocate to the VM. The workflow takes advantage of multi-processing and will drastically speed up with more CPUs.

### Outputs

_de_results_ - The string of the GS URI pointing to the results file. Can be set to the column of a Terra data table for easy retrieval.

# Downstream analysis

There is an example notebook named **plotting_and_analysis.ipynb** found in the "ANALYSIS" tab of this workspace. This notebook demonstrates how to find the most differentially expressed genes from the CSVs produced by **Diff_Gene_Exp** and also provides example uses of each visualization function in `splotch.utils_plotting`. 

The following plotting/analysis tasks are included:

- Visualize KDEs of the posterior distributions grouped by combinations of conditions, AARs, and cell-types
- Plot a gene's raw expression levels and cSplotch's lambda values on a specified array
- Identify gene-gene coexpression modules using the cSplotch lambda values (as done in [[1]](#references))
- Plot the scaled gene expression of genes in each module on a specified array
- Visualize the standardized gene expression of genes in a module grouped by AAR or condition
- Identify coexpression submodules using an scRNA AnnData file


# References
[1] Ståhl, Patrik L., et al. ["Visualization and analysis of gene expression in tissue sections by spatial transcriptomics."](https://science.sciencemag.org/content/353/6294/78) *Science* 353.6294 (2016): 78-82.

[2] Carpenter, Bob, et al. ["Stan: A probabilistic programming language."](https://www.jstatsoft.org/article/view/v076i01) *Journal of Statistical Software* 76(1) (2017).

[3] Maniatis, Silas, et al. ["Spatiotemporal dynamics of molecular pathology in amyotrophic lateral sclerosis."](https://science.sciencemag.org/content/364/6435/89) *Science* 364.6435 (2019): 89-93.