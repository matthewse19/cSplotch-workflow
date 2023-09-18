version 1.0

workflow Run_Splotch {
    input {
        String docker = "msmitherb/csplotch:latest"
        String zones = "us-central1-a us-central1-b us-central1-c us-central1-f us-east1-b us-east1-c us-east1-d us-west1-a us-west1-b us-west1-c"
        Int num_cpu = 4
        Int preemptible = 2
        String memory = "1G"
        Int disk_size_gb
        Int bootDiskSizeGb = 3
        Array[Int] gene_idxs
        Int num_samples = 500
        Int num_chains = 4
        String csplotch_input_dir
        String csplotch_output_dir
    }
    
    scatter (gene_idx in gene_idxs){
        call run_splotch {
            input:
                num_cpu = num_cpu,
                memory = memory,
                disk_size_gb = disk_size_gb,
                bootDiskSizeGb = bootDiskSizeGb,
                preemptible = preemptible,
                zones = zones,
                docker = docker,
                gene_idx = gene_idx,
                csplotch_input_dir = csplotch_input_dir,
                csplotch_output_dir = csplotch_output_dir,
                num_samples = num_samples,
                num_chains = num_chains
      }
    }
  
    
  
    output {
        Array[String] gene_summaries = run_splotch.gene_summary
    }
}


task run_splotch {
    input {
        Int num_cpu
        String memory
        Int disk_size_gb
        Int bootDiskSizeGb = 4
        Int preemptible
        String zones
        String docker
        Int gene_idx
        String csplotch_input_dir
        String csplotch_output_dir
        Int num_samples
        Int num_chains
    }
    Int gene_dir = floor(gene_idx / 100.0)
  	String gene_file = "${csplotch_input_dir}/${gene_dir}/data_${gene_idx}.R"
  
    command <<<
        mkdir -p ./data_directory/~{gene_dir}
        gsutil cp ~{gene_file} ./data_directory/~{gene_dir}/
        
        mkdir -p ./csplotch_outputs/~{gene_dir}/
        
        splotch -g ~{gene_idx} -d ./data_directory -o ./csplotch_outputs -b $SPLOTCH_BIN -n ~{num_samples} -c ~{num_chains} -s
        
        gsutil cp ./csplotch_outputs/~{gene_dir}/combined_~{gene_idx}.hdf5 ~{csplotch_output_dir}/~{gene_dir}/combined_~{gene_idx}.hdf5
    >>>
  
    output {
        String gene_summary = "${csplotch_output_dir}/${gene_dir}/combined_${gene_idx}.hdf5"
    }
  
    runtime {
        preemptible: preemptible
        bootDiskSizeGb: bootDiskSizeGb
        disks: "local-disk ${disk_size_gb} HDD"
        docker: docker
        cpu: num_cpu
        zones: zones
        memory: memory
    }
}