
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

