
This workflow generates an R dump format file for each gene, grouping the genes into subdirectories of 100 files each. The model structure must be specified in this step, a metadata file must be provided. 

The metadata file is a .TSV with the following columns: library_sample_id, Level 1, Level 2, Level 3, Count file, Annotation file, Spaceranger output (only for Visium data).
"Level 2" and "Level 3" may be left out if they are not applicable to the data.

See https://github.com/adaly/cSplotch/tree/master#annotation-of-st-spots on how to create and structure the samples' annotation files.

To determine the expression estimates of individual cell-types (and not just annotomical regions), a compositional file may be provided, and listed in a column titled "Composition file". See https://github.com/adaly/cSplotch/tree/master#annotation-of-cell-types on how to generate and structure the compositional files. 


Since all referenced files must be localized within a VM, the naming conventions of the metadata file is strict when using cSplotch in Terra. Paths in the Count file column must start with "./st_counts" for ST data and "./spaceranger_output" for Visium data. The Annotation file column must start with "./annotation", Composition file must start with "./composition", and the Spaceranger output column must start with "./spaceranger_output". 

An example row in a metadata file for a three level Visium data run would look like:

### Inputs

### Outputs

Enter the following to easily access the "genes_indexes.csv" file that gets generated.

_gene_indexes_ - this.gene_indexes

This file has the columns "gene_index", "ensembl", "type" and "gene" for a Visium workflow. It is a useful reference when wanting to run individual genes at a time in **Run_cSplotch**.
