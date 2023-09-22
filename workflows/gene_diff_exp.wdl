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
        File de_results = diff_exp.de_results
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

        python3 <<CODE
        import pickle
        import pandas as pd
        import de_analysis

        aars_str = "~{sep=',' aars}"
        conditions_str = "~{sep=',' conditions}"

        aars = aars_str.split(",")
        conditions = conditions_str.split(",")

        sinfo = pickle.load(open("~{splotch_information_p}", "rb"))
        gene_lookup_df = pd.read_csv("~{gene_indexes}", index_col=0)

        de_analysis.de_csv("~{results_csv_name}", sinfo, gene_lookup_df, "./csplotch_outputs", "~{test_type}", aars, conditions, condition_level=~{condition_level}, cores=~{num_cpu})
        CODE

        gsutil cp ~{results_csv_name} ~{results_dir_stripped}
    >>>
  
    output {
        File de_results = "${results_dir_stripped}/${results_csv_name}"
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