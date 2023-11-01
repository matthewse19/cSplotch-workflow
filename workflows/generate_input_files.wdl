version 1.0

workflow Generate_Input_Files {
    input {
        String docker = "us-central1-docker.pkg.dev/techinno/images/csplotch_img:latest"
        String zones = "us-central1-a us-central1-b us-central1-c us-central1-f us-east1-b us-east1-c us-east1-d us-west1-a us-west1-b us-west1-c"
        Int preemptible = 2
        String memory = "16G"
        Int disk_size_gb
        Int boot_disk_size_gb = 3
        String root_dir
        String spaceranger_dir = ""
        String st_count_dir = ""
        String composition_dir = ""
        String annotation_dir
        File metadata_file
        Int scaling_factor
        Int n_levels
        Int minimum_sequencing_depth = 100
        Int maximum_spots_per_tissue = 4992
        String csplotch_input_dir
        File? empirical_priors
        String? sc_group_key
        String? sc_gene_symbols
        Boolean no_car = false
        Boolean no_zip = false
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
            st_count_dir = st_count_dir,
            composition_dir = composition_dir,
            annotation_dir = annotation_dir,
            metadata_file = metadata_file,
            scaling_factor = scaling_factor,
            n_levels = n_levels,
            minimum_sequencing_depth = minimum_sequencing_depth,
            maximum_spots_per_tissue = maximum_spots_per_tissue,
            csplotch_input_dir = csplotch_input_dir,
            empirical_priors = empirical_priors,
            sc_group_key = sc_group_key,
            sc_gene_symbols = sc_gene_symbols,
            no_car = no_car,
            no_zip = no_zip
    }

    output {
        String gene_indexes_reference = generate.gene_indexes
    }
}


task generate {
    input {
        String docker
        String zones = "us-central1-a us-central1-b us-central1-c us-central1-f us-east1-b us-east1-c us-east1-d us-west1-a us-west1-b us-west1-c"
        Int preemptible = 2
        String memory = "16G"
        Int disk_size_gb
        Int boot_disk_size_gb = 3
        String root_dir
        String spaceranger_dir
        String st_count_dir
        String composition_dir
        String annotation_dir
        File metadata_file
        Int scaling_factor
        Int n_levels
        Int minimum_sequencing_depth = 100
        Int maximum_spots_per_tissue = 4992
        String csplotch_input_dir
        File? empirical_priors
        String? sc_group_key
        String? sc_gene_symbols
        Boolean no_car = false
        Boolean no_zip = false
    }
    String visium_flag = if spaceranger_dir != "" then "-V" else ""
    String compositional_flag = if composition_dir != "" then "-p" else ""

    String no_car_flag = if no_car then "-n" else ""
    String no_zip_flag = if no_zip then "-z" else ""

    String empirical_flag = if defined(empirical_priors) then "-e" else ""
    String sc_group_flag = if defined(sc_group_key) then "-g " + sc_group_key else ""
    String sc_gene_flag = if defined(sc_gene_symbols) then "-G " + sc_gene_symbols else ""

    String root_dir_stripped = sub(root_dir, "/+$", "")
    String spaceranger_dir_stripped = sub(spaceranger_dir, "/+$", "")
    String st_count_dir_stripped = sub(st_count_dir, "/+$", "")
    String composition_dir_stripped = sub(composition_dir, "/+$", "")
    String annotation_dir_stripped = sub(annotation_dir, "/+$", "")
    String csplotch_input_dir_stripped = sub(csplotch_input_dir, "/+$", "")



    command <<<
        mkdir ./spaceranger_output
        mkdir ./st_counts
        mkdir ./composition
        mkdir ./annotation

        if [ "~{spaceranger_dir_stripped}" == "" ] && [ "~{st_count_dir_stripped}" == "" ]; then
            echo "Either 'spaceranger_dir' or 'st_count_dir' must be defined"
            exit 1
        fi

        if [ "~{spaceranger_dir_stripped}" != "" ]; then
            gsutil -m cp -r "~{spaceranger_dir_stripped}/*" ./spaceranger_output
            COUNTS="./spaceranger_output/*/*.unified.tsv"
        else
            gsutil -m cp -r "~{st_count_dir_stripped}/*" ./st_counts
            COUNTS="./st_counts/*.unified.tsv"
        fi

        if [ "~{composition_dir_stripped}" != "" ]; then
            gsutil -m cp -r "~{composition_dir_stripped}/*" ./composition
        fi

        gsutil -m cp -r "~{annotation_dir_stripped}/*" ./annotation

        mkdir ./splotch_inputs

        splotch_generate_input_files -c $COUNTS -m ~{metadata_file} -s ~{scaling_factor} -l ~{n_levels} \
                -d ~{minimum_sequencing_depth} -t ~{maximum_spots_per_tissue} ~{visium_flag} -o ./splotch_inputs ~{no_car_flag} ~{no_zip_flag} \
                ~{compositional_flag} ~{empirical_flag} ~{empirical_priors} ~{sc_group_flag} ~{sc_gene_flag} | tee Generate_Input_Files.log
        
        gsutil -m cp -r "./splotch_inputs/*" ~{csplotch_input_dir_stripped}
        gsutil cp ./Generate_Input_Files.log ~{root_dir_stripped}

        if [ "~{visium_flag}" != "" ]; then
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

        else
            echo "gene_index,ensembl" > gene_indexes.csv
            awk -F '\t' 'NR>1 {print NR - 1","$1}' < $( ls ./st_counts/*.unified.tsv | head -n1; ) >> gene_indexes.csv
        fi
        gsutil cp ./gene_indexes.csv ~{root_dir_stripped}

    >>>
  
    output {
        String gene_indexes = "${root_dir_stripped}/gene_indexes.csv"
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