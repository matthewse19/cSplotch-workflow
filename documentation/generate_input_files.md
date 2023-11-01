
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

