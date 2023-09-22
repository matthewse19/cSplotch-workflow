from splotch.utils import to_stain_varaiables, savagedickey
import numpy as np
import pandas as pd
import os
import h5py

def gene_de_dict(gene_h5, sinfo, test_type, aars, conditions, level=1):
    assert test_type in ['aars', 'conditions'], "test_type must be 'aars' or 'conditions' to calculate the DE"

    beta_level = f"beta_level_{level}"

    aar_idxs = [to_stan_variables(sinfo['annotation_mapping'], m) for m in aars]
    condition_idxs = [to_stan_variables(sinfo['beta_mapping'][beta_level], t) for t in conditions]

    if test_type == "aars":
        assert len(aars) in [1,2], "For aars test type, must specify either one aar (for one vs rest) or two aars (one vs one)"

        if conditions is None or len(conditions) == 0:
            condition_idxs = list(range(len(sinfo['beta_mapping'][beta_level])))

        first_aar_idx = aar_idxs[0]
        if len(aars) == 1:
            second_aar_idx = list(set(range(len(sinfo['annotation_mapping']))) - first_aar_idx) #remove first index from [0, 1, ... num_aars]
        else:
            second_aar_idx = aar_idxs[1]

        sample1 = gene_h5[beta_level]['samples'][:, condition_idxs, first_aar_idx].flatten()
        sample2 = gene_h5[beta_level]['samples'][:, condition_idxs, second_aar_idx].flatten()
        bf = savagedickey(sample1, sample2)
        delta = np.mean(gene_h5[beta_level]['mean'][condition_idxs, first_aar_idx]) - np.mean(gene_h5[beta_level]['mean'][condition_idxs, second_aar_idx])
    else:
        assert len(conditions) in [1,2] and len(aars) > 0, "For conditions test type, must specify either one condition (for one vs rest) or two conditions (one vs one), and an aar"

        if aars is None or len(aars) == 0:
            aar_idxs = list(range(len(sinfo['annotation_mapping'])))

        first_condition_idx = condition_idxs[0]
        if len(condition_idxs) == 1:
            second_condition_idx = list(set(range(len(sinfo['beta_mapping'][beta_level]))) - first_condition_idx) #remove first index from rest
        else:
            second_condition_idx = condition_idxs[1]

        sample1 = gene_h5[beta_level]['samples'][:, first_condition_idx, aar_idxs].flatten()
        sample2 = gene_h5[beta_level]['samples'][:, second_condition_idx, aar_idxs].flatten()
        bf = savagedickey(sample1, sample2)
        delta = np.mean(gene_h5[beta_level]['mean'][first_condition_idx, aar_idxs]) - np.mean(gene_h5[beta_level]['mean'][second_condition_idx, aar_idxs])

    return {"bf": bf, "delta": delta}

def de_csv(csv_path, sinfo, gene_lookup_df, splotch_output_path, test_type, aars, conditions, condition_level=1):
    assert test_type in ['aars', 'conditions'], "test_type must be 'aars' or 'conditions' to calculate the DE"
    
    num_levels = len(sinfo['beta_mapping'])
    assert condition_level > 1 and condition_level <= num_levels, f"Condition level must be between 1 and {num_levels}"
    
    all_conditions = sinfo['beta_mapping'][f"beta_level_{condition_level}"]
    assert set(conditions).issubset(set(all_conditions)), \
        f"The conditions must be a list of elements from the conditions at level {condition_level}: {all_conditions}"

    all_aars = sinfo['annotation_mapping']
    assert set(aars).issubset(set(all_aars)), \
        f"The aars must be a list of elements from the full list of possible AARs: {all_aars}"
    
    de_dict_list = []
    for gene_idx, row in gene_lookup_df.iterrows():
        name = row['gene']
        ensembl = row['ensembl']

        summary_path = os.path.join(splotch_output_path, gene_idx // 100, f"combined_{gene_idx}.hdf5")

        #splotch may not have been run on all genes, only work on the summarized files
        if os.path.exists(summary_path):
            gene_summary = h5py.File(summary_path, "r")

            de_dict = gene_de_dict(gene_summary, sinfo, test_type, aars, conditions, condition_level)
            de_dict['gene'] = name
            de_dict['ensembl'] = ensembl

            de_dict_list.append(de_dict)
            print(f"Processed gene {gene_idx}")

    pd.DataFrame(de_dict_list)[['gene', 'ensembl', 'bf', 'delta']].to_csv(csv_path, index=False)

