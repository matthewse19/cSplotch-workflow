version 1.0

workflow Run_Splotch {
    input {
        String docker = "msmitherb/csplotch:latest"
        String zones = "us-central1-a us-central1-b us-central1-c us-central1-f us-east1-b us-east1-c us-east1-d us-west1-a us-west1-b us-west1-c"
        Int num_cpu = 4
        Int preemptible = 1
        String memory = "1G"
        Int disk_size_gb
        Int max_concurrent_VMs
        Int bootDiskSizeGb = 3
        Array[Int] splotch_gene_idxs = [] #optional array
        Int? total_genes
        Int num_samples = 500
        Int num_chains = 4
        String csplotch_input_dir
        String csplotch_output_dir
        Float gene_timeout_hrs = 12
    }
    
    #add extra offset if splotch_gene_idxs is defined bc its first element will be 0
    Int start_idx = if length(splotch_gene_idxs) > 0 then 0 else 1
    #if both total_genes is defined and splotch_gene_idxs has elements, overwrite total_genes to array's length
    Int? defined_total_genes = if defined(total_genes) && length(splotch_gene_idxs) == 0 then total_genes else length(splotch_gene_idxs)
    Array[Int] defined_splotch_gene_idxs = if length(splotch_gene_idxs) > 0 then splotch_gene_idxs else range(total_genes + 1)

    # "large_groups" will process floor(total_genes / max_vms) + 1 genes
    # total_genes mod max_vms is the number of "large groups"
    Int large_groups = defined_total_genes % max_concurrent_VMs
    Int large_size = floor(defined_total_genes / max_concurrent_VMs) + 1
    Int small_size = floor(defined_total_genes / max_concurrent_VMs)
    
    scatter (vm in range(max_concurrent_VMs)){
        #larger chunks first
        Int num_genes = if vm < large_groups then large_size else small_size
        
        Int current_idx = if vm < large_groups then start_idx + vm * large_size else start_idx + large_groups * large_size + (vm - large_groups) * small_size

        call run_splotch {
            input:
                num_cpu = num_cpu,
                memory = memory,
                disk_size_gb = disk_size_gb,
                bootDiskSizeGb = bootDiskSizeGb,
                preemptible = preemptible,
                zones = zones,
                docker = docker,
                first_idx = current_idx,
                num_genes = num_genes,
                all_genes = defined_splotch_gene_idxs,
                csplotch_input_dir = csplotch_input_dir,
                csplotch_output_dir = csplotch_output_dir,
                num_samples = num_samples,
                num_chains = num_chains,
                gene_timeout_hrs = gene_timeout_hrs
        }

    }
  
    output {
        Array[Int] first_index_list = run_splotch.out_first_idx
        Array[Int] num_genes_list = run_splotch.out_num_genes
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
        Int first_idx
        Int num_genes
        Array[Int] all_genes
        String csplotch_input_dir
        String csplotch_output_dir
        Int num_samples
        Int num_chains
        Float gene_timeout_hrs
    }

    String csplotch_input_dir_stripped = sub(csplotch_input_dir, "/+$", "")
    String csplotch_output_dir_stripped = sub(csplotch_output_dir, "/+$", "")

    Int last_idx = first_idx + num_genes - 1
  
    command <<<
        ALL_GENES=(~{sep=' ' all_genes}) 

        #IDX is the index of the all_genes array (not necessarily the cSplotch gene index)
        for IDX in $(seq ~{first_idx} ~{last_idx}) 
        do
            GENE_IDX=${ALL_GENES[$IDX]}
            GENE_DIR=$((GENE_IDX / 100))
            SUMMARY_EXISTS=`gsutil -q stat ~{csplotch_output_dir_stripped}/$GENE_DIR/combined_$GENE_IDX.hdf5; echo $?`
            if [ $SUMMARY_EXISTS -ne 0 ]; then
                GENE_FILE=~{csplotch_input_dir_stripped}/$GENE_DIR/data_$GENE_IDX.R
                mkdir -p ./data_directory/$GENE_DIR
                gsutil cp $GENE_FILE ./data_directory/$GENE_DIR/
                
                mkdir -p ./csplotch_outputs/$GENE_DIR/
                
                GENE_STATUS=`timeout ~{gene_timeout_hrs}h splotch -g $GENE_IDX -d ./data_directory -o ./csplotch_outputs -b $SPLOTCH_BIN -n ~{num_samples} -c ~{num_chains} -s; echo $?`
                
                if [ $GENE_STATUS -eq 124 ]; then
                    echo "Gene timed out after ~{gene_timeout_hrs} hours" > ./csplotch_outputs/timeout_$GENE_IDX.txt
                    gsutil cp ./csplotch_outputs/timeout_$GENE_IDX.txt ~{csplotch_output_dir_stripped}/$GENE_DIR/timeout_$GENE_IDX.txt
                else
                    gsutil cp ./csplotch_outputs/$GENE_DIR/combined_$GENE_IDX.hdf5 ~{csplotch_output_dir_stripped}/$GENE_DIR/combined_$GENE_IDX.hdf5
                fi


            fi
            
        done

    >>>
  
    output {
        Int out_first_idx = first_idx
        Int out_num_genes = num_genes
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