
This workflow calculates the [Bayes Factor](https://en.wikipedia.org/wiki/Bayes_factor) and log<sub>2</sub> fold change between two experimental groups. The groups can be specified by any level condition, anatomical annotation regions (AAR), or single cell types for compositional data.

The group corresponding with _test_type_ ("aars", "conditions" or "cells") must have a length of one (for one group vs the rest) or a length of two (to directly compare the two groups). The other groups are then used to subset the data.

For example, if _test_type_ = "aars", _condition_level_ = 1, _conditions_=["ALS"], and _aars_ = ["Layer_1", "Layer_2"], then the differential gene expression is calculated for spots labeled as "Layer_1" and "Layer_2" for ALS samples.

### Inputs

_aars_ - When _test_type_ = "aars", these must be the two AARs to test against each other. Otherwise, the list is the specified AARs to subset the data by.

_condition_level_ - The condition/beta level that _conditions_ specifies.

_conditions_ - When _test_type_ = "conditions", these must be the two conditions to test against each other. Otherwise, the list is the specified conditions to subset the data by. These conditions must also be valid conditions for the specified _condition_level_ of the data.

_csplotch_output_dir_ - The gsutil URI of the directory where the summarized output files will be placed (if a gene's output file already exists, then the workflow will skip the gene).

_gene_indexes_ - The file named "gene_indexes.csv" that is produced by the **Generate_Input_Files** workflow. This file is used as a lookup for the gene and ensembl names of each cSplotch gene index.

_results_csv_name_ - Name of the results file that will be placed in the Google cloud _results_dir_ directory.

_results_dir_ - The gsutil URI of the directory where the results CSV file will be placed.

_splotch_information_p_ -  The pickled Python dictionary with cSplotch metadata that is output during the **Generate_Input_Files** workflow and typically located in the cSplotch input directory.

_test_type_ - 

_memory_ (default "32G")

_num_cpu_ (default 2)

### Outputs

