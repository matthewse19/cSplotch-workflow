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
    >>>
  
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