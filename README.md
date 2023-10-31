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


For more details on the cSplotch probablistic model, or to run cSplotch, visit the GitHub page https://github.com/adaly/cSplotch.


## cSplotch Worfklows

There are three workflows that must be run to get the cSplotch output and there is one workflow to assist in identifying differential expression in genes. 

The following must run successfully in order:
1. **[Prepare_Count_Files](https://app.terra.bio/#workspaces/techinno/cSplotch/workflows/techinno/Prepare_Count_Files)** - creates unified count files for each sample and filters lowly expressed genes
2. **[Generate_Input_files](https://app.terra.bio/#workspaces/techinno/cSplotch/workflows/techinno/Generate_Input_Files)** - generates an individual input file for each gene and specifies the model parameters
3. **[Run_cSplotch](https://app.terra.bio/#workspaces/techinno/cSplotch/workflows/techinno/Run_Splotch)** - runs the cSplotch model and outputs the posterior likelihoods for a given gene
4. **[Gene_Diff_Exp](https://app.terra.bio/#workspaces/techinno/cSplotch/workflows/techinno/Gene_Diff_Exp)** - calculates Bayes Factor and log2 fold change between a given pair of conditions/regions for all genes

# Workflow descriptions and inputs

## Runtime input parameters
The following input parameters are present in all of the cSplotch Terra workflows. For a more in-depth explanation, see https://cromwell.readthedocs.io/en/stable/RuntimeAttributes/.

_disk\_size\_gb_ - Size in GB that the VM should allocate for storage.

_boot\_disk\_size\_gb_ (default 3) - Size of the disk where the docker image is booted.

_docker_ (default "msmitherb/csplotch:latest") - Docker image to use for the VM (it must have cSplotch and CmdStan installed). 

_memory_ - Amount of RAM to use.

_preemptible_ (default 2) - Number of times to preempt a VM before switching to an on-demand machine.

_zones_ (default "us-central1-a us-central1-b... us-east1-a us-east1-b... us-west1-a us-west1-b...") - Ordered list of zone preference. 

## Prepare_Count_Files

This workflow creates a .unified.tsv file for each sample, which ensures that the gene indexing across all samples is consistent and also filters out lowly expressed genes. If Visium was used, only fill in the _spaceranger_dir_ input, otherwise for ST data, fill in _st_count_dir_.

### Inputs
_root_dir_ - gsutil URI (e.g. "gs://[bucket_uri]/[parent_dir]") to the root directory containing the cSplotch metadata file and the Spaceranger/ST directory. A _Prepare_Count_Files.log_ file will be placed in this directory after the Workflow is completed successfully. 

_min_detection_rate_ (default 0.02) - Minimum expression rate over every spot in all samples that a gene must have in order to be kept.

_spaceranger_dir_ - The gsutil URI of the parent directory containing each sample's Spaceranger folder (not used for ST data).

_st_count_dir_ - The gsutil URI of the parent directory containing each sample's count file (not used for Visium data).


### Outputs
Before running the workflow, create a data table with a blank row so the outputs get stored. This can be done in the workspace by going to the Data tab > IMPORT DATA > Upload TSV > TEXT IMPORT > Copy and paste the following:
```
entity:cSplotch_run_id
1
```
Now back in the **Prepare_Count_Files** workflow, ensure that "Run workflow(s) with inputs defined by data table" is chosen and click 'SELECT DATA' to choose the cSplotch run ID. In the outputs tab, enter the following for each output variable (or choose any other descriptive column name):

_genes_detected_ - this.genes_detected

_genes_kept_ - this.genes_kept

_median_seq_depth_ - this.median_seq_depth

After Prepare_Count_Files is completed successfully, the workflow will automatically populate these fields  in the selected row in the data table.

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

_annotation_dir_ - The gsutil URI of the annotation directory.

_csplotch_input_dir_ - The gsutil URI of an empty directory in the _root_dir_ where the gene input files will be placed.

_metadata_file_ - The metadata file that in the above structure.

_n_levels_ - The number of condition levels present in the metadata (1, 2, or 3).

_root_dir_ - The gsutil URI of the root directory containing the directories _annotation_dir_, _spaceranger_dir_/_st_count_dir_, _csplotch_input_dir_, and optionally _composition_dir_. A _Generate_Input_Files.log_ file will be placed in this directory after the Workflow is completed successfully. 

_scaling_factor_ - The median sequencing depth over all spots which is found during **Prepare_Count_Files**. Select "Run workflow(s) with inputs defined by data table" and enter the value "this.median_seq_depth" to reference the value stored in data table's selected row.

_composition_dir_ (optional) - The gsutil URI to the directory containing the composition files, referenced in the metadata file.

_empirical_priors_ (optional) - An AnnData (HDF5 format) file with single cell gene expression to inform the model's priors of the expression in each cell type (only for compositional data). See 

_maximum_spots_per_tissue_ (default 4992) - Number of spots threshold for identifying overlapping tissue sections. 4992 covers an entire Visium array.

_minimum_sequencing_depth_ (default 100) - Minimum number of UMIs per spot.

_no_car_ (default false) - Disable the conditional autoregressive prior.

_no_zip_ (default false) - Use the Poisson likelihood instead of the zero-inflated Poisson likelihood.

_sc_gene_symbols_ (optional) - Key in single-cell AnnData.var corresponding to gene names in ST count/Visium data (required when _empirical_priors_ is given; must match gene names in count files).

_sc_group_key_ (optional) - Key in single-cell AnnData.obs containing cell type annotations (required when _empirical_priors_ is given; must match cell type naming in annotation files).

_spaceranger_dir_ - The gsutil URI of the parent directory containing each sample's Spaceranger folder (not used for ST data).

_st_count_dir_ - The gsutil URI of the parent directory containing each sample's count file (not used for Visium data).

### Outputs

Enter the following to easily access the "genes_indexes.csv" file that gets generated.

_gene_indexes_ - this.gene_indexes

This file has the columns "gene_index", "ensembl", "type" and "gene" for a Visium workflow. It is a useful reference when wanting to run individual genes at a time in **Run_cSplotch**.

## Run_cSplotch

### Inputs

### Outputs

## Gene_Diff_Exp

### Inputs


### Outputs

# References
[1] Ståhl, Patrik L., et al. ["Visualization and analysis of gene expression in tissue sections by spatial transcriptomics."](https://science.sciencemag.org/content/353/6294/78) *Science* 353.6294 (2016): 78-82.

[2] Carpenter, Bob, et al. ["Stan: A probabilistic programming language."](https://www.jstatsoft.org/article/view/v076i01) *Journal of Statistical Software* 76(1) (2017).

[3] Maniatis, Silas, et al. ["Spatiotemporal dynamics of molecular pathology in amyotrophic lateral sclerosis."](https://science.sciencemag.org/content/364/6435/89) *Science* 364.6435 (2019): 89-93.