version 1.0

workflow Prepare_Count_Files {
    input {
        String docker = "msmitherb/csplotch:latest"
        String zones = "us-central1-a us-central1-b us-central1-c us-central1-f us-east1-b us-east1-c us-east1-d us-west1-a us-west1-b us-west1-c"
        Int preemptible = 2
        String memory = "16G"
        Int disk_size_gb
        Int boot_disk_size_gb = 3
        String spaceranger_dir
        Float min_detection_rate = 0.02
        Boolean visium = true
    }
    
    call prepare {
        input:
            docker = docker,
            zones = zones,
            preemptible = preemptible,
            memory = memory,
            disk_size_gb = disk_size_gb,
            boot_disk_size_gb = boot_disk_size_gb,
            spaceranger_dir = spaceranger_dir,
            min_detection_rate = min_detection_rate,
            visium = visium
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
        String spaceranger_dir
        Float min_detection_rate = 0.02
        Boolean visium = true
    }


    String visium_flag = if visium then "-V" else ""

    command <<<
        mkdir ./spaceranger_output
        gsutil cp -mr "~{spaceranger_dir}/*" ./spaceranger_output
        
        splotch_prepare_count_files -c ./spaceranger_output/* -d ~{min_detection_rate} ~{visium_flag} > Prepare_Count_Files.log

        cd ./spaceranger_output
        for f in ./*/*.unified.tsv; do gsutil cp "$f" ~{spaceranger_dir}/$f; done

        gsutil cp ../Prepare_Count_Files.log ~{spaceranger_dir}/..
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