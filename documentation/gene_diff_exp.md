
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

