version 1.0

workflow Prepare_Count_Files {
    input {
        String docker = "msmitherb/csplotch:latest"
        String zones = "us-central1-a us-central1-b us-central1-c us-central1-f us-east1-b us-east1-c us-east1-d us-west1-a us-west1-b us-west1-c"
        Int preemptible = 2
        String memory = "16G"
        Int disk_size_gb
        Int boot_disk_size_gb = 3
        String root_dir
        String spaceranger_dir = ""
        String st_count_dir = ""
        Float min_detection_rate = 0.02
    }
    
    call prepare {
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
            min_detection_rate = min_detection_rate,
    }

    output {
        Int genes_detected = prepare.genes_detected
        Int genes_kept = prepare.genes_kept
        Int median_seq_depth = prepare.median_seq_depth
    }
}


task prepare {
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
        Float min_detection_rate = 0.02
    }

    String root_dir_stripped = sub(root_dir, "/+$", "")
    String spaceranger_dir_stripped = sub(spaceranger_dir, "/+$", "")
    String st_count_dir_stripped = sub(st_count_dir, "/+$", "")

    command <<<

        if [ "~{spaceranger_dir_stripped}" == "" ]; then
            mkdir ./counts_output
            gsutil -m cp -r "~{st_count_dir_stripped}/*" ./counts_output

            splotch_prepare_count_files -c ./counts_output/* -d ~{min_detection_rate} | tee Prepare_Count_Files.log
            gsutil -m cp -r ./counts_output/*.unified.tsv ~{st_count_dir_stripped}

        else
            mkdir ./spaceranger_output
            gsutil -m cp -r "~{spaceranger_dir_stripped}/*" ./spaceranger_output
            
            splotch_prepare_count_files -c ./spaceranger_output/* -d ~{min_detection_rate} -V | tee Prepare_Count_Files.log

            cd ./spaceranger_output

            for f in ./*/*.unified.tsv; do gsutil cp "$f" ~{spaceranger_dir_stripped}`cut -c 2- <<< "$f"`; done #remove the leading '.' from the path

            cd ..
        fi

        

        gsutil cp Prepare_Count_Files.log ~{root_dir_stripped}

        #-o only the match, -P perl regex mode
        grep -oP '(?<=We have detected )[0-9]*' Prepare_Count_Files.log > genes_detected.txt
        grep -oP '(?<=We keep )[0-9]*' Prepare_Count_Files.log > genes_kept.txt
        grep -oP '(?<=The median sequencing depth across the ST spots is )[0-9]*' Prepare_Count_Files.log > median_seq_depth.txt
    >>>
  
    output {
        Int genes_detected = read_int("genes_detected.txt")
        Int genes_kept = read_int("genes_kept.txt")
        Int median_seq_depth = read_int("median_seq_depth.txt")
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