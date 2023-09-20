version 1.0

workflow Generate_Input_Files {
    input {
        String docker = "msmitherb/csplotch:latest"
        String zones = "us-central1-a us-central1-b us-central1-c us-central1-f us-east1-b us-east1-c us-east1-d us-west1-a us-west1-b us-west1-c"
        Int preemptible = 2
        String memory = "16G"
        Int disk_size_gb
        Int boot_disk_size_gb = 3
        String root_dir
        String spaceranger_dir
        String annotation_dir
        File metadata_file
        Int scaling_factor
        Int n_levels
        Int minimum_sequencing_depth = 100
        Int maximum_spots_per_tissue = 4992
        String csplotch_input_dir
        Boolean visium = true
    }
    
    call generate {
        input:
            docker = docker,
            zones = zones,
            preemptible = preemptible,
            memory = memory,
            disk_size_gb = disk_size_gb,
            boot_disk_size_gb = boot_disk_size_gb,
            root_dir = root_dir,
            spaceranger_dir = spaceranger_dir,
            annotation_dir = annotation_dir,
            metadata_file = metadata_file,
            scaling_factor = scaling_factor,
            n_levels = n_levels,
            minimum_sequencing_depth = minimum_sequencing_depth,
            maximum_spots_per_tissue = maximum_spots_per_tissue,
            csplotch_input_dir = csplotch_input_dir,
            visium = visium
    }

    output {
        File gene_indexes_reference = generate.gene_indexes
    }
}


task generate {
    input {
        String docker = "msmitherb/csplotch:latest"
        String zones = "us-central1-a us-central1-b us-central1-c us-central1-f us-east1-b us-east1-c us-east1-d us-west1-a us-west1-b us-west1-c"
        Int preemptible = 2
        String memory = "16G"
        Int disk_size_gb
        Int boot_disk_size_gb = 3
        String root_dir
        String spaceranger_dir
        String annotation_dir
        File metadata_file
        Int scaling_factor
        Int n_levels
        Int minimum_sequencing_depth = 100
        Int maximum_spots_per_tissue = 4992
        String csplotch_input_dir
        Boolean visium = true
    }


    String visium_flag = if visium then "-V" else ""

    command <<<
        mkdir ./spaceranger_output
        mkdir ./annotation
        gsutil -m cp -r "~{spaceranger_dir}/*" ./spaceranger_output
        gsutil -m cp -r "~{annotation_dir}/*" ./annotation

        
        mkdir ./splotch_inputs

        splotch_generate_input_files -c ./spaceranger_output/*/*.unified.tsv -m ~{metadata_file} -s ~{scaling_factor} -l ~{n_levels} \
            -d ~{minimum_sequencing_depth} -t ~{maximum_spots_per_tissue} ~{visium_flag} -o ./splotch_inputs > Generate_Input_Files.log

        
        gsutil -m cp -r "./splotch_inputs/*" ~{csplotch_input_dir}
        gsutil cp ./Generate_Input_Files.log ~{root_dir}


        python3 <<CODE
        import pandas as pd
        import pickle
        from pathlib import Path

        info = pickle.load(open("./splotch_inputs/information.p", "rb"))

        dir = Path.cwd()
        features_ex_path = list(dir.glob("./spaceranger_output/*/outs/filtered_feature_bc_matrix/features.tsv.gz"))[0].as_posix()
        feature_example = pd.read_csv(features_ex_path, delimiter="\t", names=["ensembl", "gene", "type"])

        if not(feature_example["ensembl"][0].startswith("ENS")):
            feature_example = feature_example.rename(columns={"ensembl": "gene", "gene": "ensembl"})

        idx_df = pd.DataFrame()

        info_genes = info['genes']

        key = "ensembl" if info_genes[0].startswith("ENS") else "gene"

        idx_df[key] = info_genes
        idx_df = idx_df.merge(feature_example, on=key)
        idx_df.index = idx_df.index + 1
        idx_df.index.name = "gene_index"

        idx_df.to_csv("gene_indexes.csv", index=True)
        CODE

        gsutil cp ./gene_indexes.csv ~{root_dir}
    >>>
  
    output {
        File gene_indexes = "${root_dir}/gene_indexes.csv"
    }

    runtime {
        preemptible: preemptible
        bootDiskSizeGb: boot_disk_size_gb
        disks: "local-disk ${disk_size_gb} HDD"
        docker: docker
        cpu: 1
        zones: zones
        memory: memory
    }
}