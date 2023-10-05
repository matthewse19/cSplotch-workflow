version 1.0

workflow Gene_Diff_Exp {
    input {
        String docker = "msmitherb/csplotch:latest"
        String zones = "us-central1-a us-central1-b us-central1-c us-central1-f us-east1-b us-east1-c us-east1-d us-west1-a us-west1-b us-west1-c"
        Int preemptible = 2
        String memory = "16G"
        Int num_cpu = 1
        Int disk_size_gb
        Int boot_disk_size_gb = 3
        File gene_indexes
        File splotch_information_p
        String results_csv_name
        String results_dir
        String csplotch_output_dir
        String test_type
        Array[String]+ aars
        Array[String]+ conditions
        Int condition_level 
    }

    parameter_meta {
        test_type: "Must be 'aars' or 'conditions'"
    }
    
    
    call diff_exp {
        input:
            docker = docker,
            zones = zones,
            preemptible = preemptible,
            memory = memory,
            num_cpu = num_cpu,
            disk_size_gb = disk_size_gb,
            boot_disk_size_gb = boot_disk_size_gb,
            gene_indexes = gene_indexes,
            splotch_information_p = splotch_information_p,
            results_csv_name = results_csv_name,
            results_dir = results_dir,
            csplotch_output_dir = csplotch_output_dir,
            test_type = test_type,
            aars = aars,
            conditions = conditions,
            condition_level = condition_level,
    }

    output {
        String de_results = diff_exp.de_results
    }
}


task diff_exp {
    input {
        String docker
        String zones = "us-central1-a us-central1-b us-central1-c us-central1-f us-east1-b us-east1-c us-east1-d us-west1-a us-west1-b us-west1-c"
        Int preemptible = 2
        String memory = "16G"
        Int num_cpu = 1
        Int disk_size_gb
        Int boot_disk_size_gb = 3
        File gene_indexes
        File splotch_information_p
        String results_csv_name
        String results_dir
        String csplotch_output_dir
        String test_type
        Array[String]+ aars
        Array[String]+ conditions
        Int condition_level 
    }

    String csplotch_output_dir_stripped = sub(csplotch_output_dir, "/+$", "")
    String results_dir_stripped = sub(results_dir, "/+$", "")


    command <<<
        mkdir ./csplotch_outputs

        gsutil -m cp -r "~{csplotch_output_dir_stripped}/*" ./csplotch_outputs
        
        #TODO move analysis script elsewhere
        curl https://raw.githubusercontent.com/matthewse19/cSplotch-workflow/main/de_analysis.py -O

        BASE=`basename ~{results_csv_name} .csv`

        TOTAL_GENES=$(( wc -l < ~{gene_indexes} ))

        PARTITION_SIZE=$(( TOTAL_GENES / ~{num_cpu} ))

        REMAINDER = $(( TOTAL_GENES % ~{num_cpu} ))

        START=1

        #"poor-man's" multiprocessing
        for i in $(seq 1 ~{num_cpu})
        do
            PROC_GENES=PARTITION_SIZE
            #do the remainder of the genes on last process
            if [ $i == ~{num_cpu} ]; then
                PROC_GENES=$(( PARTITION_SIZE + REMAINDER ))
            fi

            python3 de_analysis.py \
                "$base$i.csv" "~{splotch_information_p}" "~{gene_indexes}" "./csplotch_outputs" \
                "~{test_type}" "~{sep=',' aars}" "~{sep=',' conditions}" "~{condition_level}" "$START" "$PROC_GENES" &
                pids[${i}]=$!

            START=$(( START + PROC_GENES ))
        done

        # wait for all pids
        for pid in ${pids[*]}; do
            wait $pid
        done

        #combine all csvs https://stackoverflow.com/questions/16890582/unixmerge-multiple-csv-files-with-same-header-by-keeping-the-header-of-the-firs
        awk 'FNR==1 && NR!=1{next;}{print}' *.csv > ~{results_csv_name}

        gsutil cp ~{results_csv_name} ~{results_dir_stripped}
    >>>
  
    output {
        String de_results = "${results_dir_stripped}/${results_csv_name}"
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