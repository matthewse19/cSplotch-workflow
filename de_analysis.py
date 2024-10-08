from splotch.utils import to_stan_variables, savagedickey
import numpy as np
import pandas as pd
import os
import h5py
import pickle
import multiprocessing
from concurrent.futures import ProcessPoolExecutor
import sys
import gc

def gene_de_dict(gene_h5, sinfo, test_type, aars, conditions, level=1, cell_types=None):
    """Computes differential expression of the given gene with the specified tests

    Parameters
    ----------
    gene_h5 : (hdf5) File object
        Gene summary file object
    sinfo : Obj
        Unpickled information.p
    test_type : str
        aspect of model to test, either 'aars', 'conditions', or 'cell_types'
    aars : list[str]
        When test_type='aars', one AAR tests that region against the rest,
        and two AARs test them against each other.
        When test_type='conditions', subset the data to only include spots of the given AARs.
    conditions : list[str]
        When test_type='conditions', one conditions tests that condition against the rest,
        and two conditions test them against each other.
        When test_type='aars', subset the data to only include samples with the specified condition.
    level : int (default 1)
        Beta level of the hierarchical model that the specified conditions come from.
    
    Returns
    -------
    dict()
        Keys "bf" (Bayes Factor) and "l2fc" (log2 fold change)
    """
    assert test_type in ['aars', 'conditions', 'cell_types'], "test_type must be 'aars' or 'conditions' or 'cell_types' to calculate the DE"
    annotation_mapping, beta_mapping = sinfo['annotation_mapping'], sinfo['beta_mapping']

    compositional = cell_types is not None

    beta_level = f"beta_level_{level}"

    aar_idxs = [to_stan_variables(annotation_mapping, m) for m in aars]
    condition_idxs = [to_stan_variables(beta_mapping[beta_level], t) for t in conditions]

    if compositional:
        cell_types_idxs = [to_stan_variables(sinfo['celltype_mapping'], c) for c in cell_types]

    n_samples = gene_h5[beta_level]['samples'].shape[0]
    if test_type == "aars":
        assert len(aars) in [1,2], "For aars test type, must specify either one aar (for one vs rest) or two aars (one vs one)"

        if conditions is None or len(conditions) == 0:
            condition_idxs = list(range(len(beta_mapping[beta_level])))

        first_aar_idx = [aar_idxs[0]]
        if len(aars) == 1:
            second_aar_idx = list(set(range(len(annotation_mapping))) - set(first_aar_idx)) #remove first index from [0, 1, ... num_aars]
        else:
            second_aar_idx = [aar_idxs[1]]

        if compositional:
            ix_grid1 = np.ix_([True] * n_samples, condition_idxs, first_aar_idx, cell_types_idxs)
            ix_grid2 = np.ix_([True] * n_samples, condition_idxs, second_aar_idx, cell_types_idxs)
        else:
            ix_grid1 = np.ix_([True] * n_samples, condition_idxs, first_aar_idx)
            ix_grid2 = np.ix_([True] * n_samples, condition_idxs, second_aar_idx)
        
    elif test_type == "conditions":
        assert len(conditions) in [1,2] and len(aars) > 0, "For conditions test type, must specify either one condition (for one vs rest) or two conditions (one vs one), and an aar"

        if aars is None or len(aars) == 0:
            aar_idxs = list(range(len(annotation_mapping)))

        first_condition_idx = [condition_idxs[0]]
        if len(condition_idxs) == 1:
            second_condition_idx = list(set(range(len(beta_mapping[beta_level]))) - first_condition_idx) #remove first index from rest
        else:
            second_condition_idx = [condition_idxs[1]]

        if compositional:
            ix_grid1 = np.ix_([True] * n_samples, first_condition_idx, aar_idxs, cell_types_idxs)
            ix_grid2 = np.ix_([True] * n_samples, second_condition_idx, aar_idxs, cell_types_idxs)
        else:
            ix_grid1 = np.ix_([True] * n_samples, first_condition_idx, aar_idxs)
            ix_grid2 = np.ix_([True] * n_samples, second_condition_idx, aar_idxs)

    else:
        assert len(cell_types) in [1,2], "For cell_types test type, must specify either one cell type (for one vs rest) or two cell types (one vs one)"

        first_type_idx = [cell_types_idxs[0]]
        if len(cell_types) == 1:
            second_type_idx = list(set(range(len(sinfo['celltype_mapping']))) - first_type_idx) #remove first index from rest
        else:
            second_type_idx = [cell_types_idxs[1]]

        ix_grid1 = np.ix_([True] * n_samples, condition_idxs, aar_idxs, first_type_idx)
        ix_grid2 = np.ix_([True] * n_samples, condition_idxs, aar_idxs, second_type_idx)
    
    #hdf5 doesn't support fancy indexing with ix_
    np_data = np.array(gene_h5[beta_level]['samples'])
    sample1 = np_data[ix_grid1].flatten()
    sample2 = np_data[ix_grid2].flatten()
    bf = savagedickey(sample1, sample2)
    l2fc = np.log2(np.exp(sample1).mean() / np.exp(sample2).mean())
    return {"bf": bf, "l2fc": l2fc}

#helper function for multiprocessing gene_de_dict
def gene_dict_helper(t):
    gene_idx, name, ensembl, splotch_output_path, sinfo, test_type, aars, conditions, condition_level, cell_types  = t
    print(f"Started processing {gene_idx}")
    sys.stdout.flush()

    summary_path = os.path.join(splotch_output_path, str(gene_idx // 100), f"combined_{gene_idx}.hdf5")

    gene_summary = h5py.File(summary_path, "r")

    de_dict = gene_de_dict(gene_summary, sinfo, test_type, aars, conditions, condition_level, cell_types)
    de_dict['gene'] = name
    de_dict['ensembl'] = ensembl

    print(f"Processed gene {gene_idx}")
    sys.stdout.flush()
    
    return de_dict

def start_process():
    print('Starting', multiprocessing.current_process().name)
    sys.stdout.flush()

def de_csv(csv_path, sinfo, gene_lookup_df, splotch_output_path, test_type, aars, conditions, condition_level=1, cell_types=None, start_gene=1, total_genes=None):
    """
    Creates a CSV containing the Bayes factor and log fold change for each gene file located in splotch_output_path

    Parameters
    ----------
    csv_path : str
        path to save the CSV
    sinfo : Obj
        Unpickled information.p
    gene_lookup_df : DataFrame
        pandas DataFrame where each row represents a gene with columns 'gene' and 'ensembl'
    splotch_output_path : str
        Path to the directory which contains the numbered parent directories,
        each containing a gene summary hdf5 file.
    test_type : str
        aspect of model to test, either 'aars', 'conditions', or 'cell_types'
    aars : list[str]
        When test_type='aars', one AAR tests that region against the rest,
        and two AARs test them against each other.
        When test_type is 'conditions' or 'cell_types', subset the data to only include spots of the given AARs.
    conditions : list[str]
        When test_type='conditions', one conditions tests that condition against the rest,
        and two conditions test them against each other.
        When test_type is 'aars' or 'cell_types', subset the data to only include samples with the specified condition.
    condition_level : int (default 1)
        Beta level of the hierarchical model that the specified conditions come from.
    cell_types : list[str] (default None)
        When test_type='cell_types', one cell_type tests that type against the rest,
        and two types test them against each other.
        When test_type is 'aars' or 'conditions', subset the data to only include samples with the specified condition.
        The default of None sets cell_types to be all types present in sinfo['celltype_mapping']
    
    """
    assert test_type in ['aars', 'conditions', 'cell_types'], "test_type must be 'aars' or 'conditions' or 'cell_types' to calculate the DE"
    
    num_levels = len(sinfo['beta_mapping'])
    assert condition_level >= 1 and condition_level <= num_levels, f"Condition level must be between 1 and {num_levels}"
    
    all_conditions = sinfo['beta_mapping'][f"beta_level_{condition_level}"]
    assert set(conditions).issubset(set(all_conditions)), \
        f"The conditions must be a list of elements from the conditions at level {condition_level}: {all_conditions}"

    all_aars = sinfo['annotation_mapping']
    assert set(aars).issubset(set(all_aars)), \
        f"The aars must be a list of elements from the full list of possible AARs: {all_aars}"
    
    compositional = 'celltype_mapping' in sinfo
    assert cell_types is None or compositional, "'cell_types' must be None if no compositional data was provided"
    
    if compositional:
        all_cell_types = sinfo['celltype_mapping']
        if cell_types is None:
            cell_types = all_cell_types
        
        assert set(cell_types).issubset(set(all_cell_types)), \
            f"The cell_types must be a list of elements from the full list of possible cell types: {all_cell_types}"

    #set 'gene' column to blank if it DNE
    if 'gene' not in gene_lookup_df.columns:
        gene_lookup_df['gene'] = ""

    #only operate on genes with existing summary files
    gene_data = filter(lambda tup: os.path.exists(os.path.join(splotch_output_path, str(tup[0] // 100), f"combined_{tup[0]}.hdf5")),\
                gene_lookup_df[['gene', 'ensembl']].itertuples(name=None))

    if total_genes is None:
        total_genes = len(gene_data)

    #only operate in specified gene range (for "poor-man's multiprocessing")
    gene_data = filter(lambda tup: tup[0] >= start_gene and tup[0] < start_gene + total_genes, gene_data)

    results = []

    for idx, name, ensembl in gene_data:
        t = (idx, name, ensembl, splotch_output_path, sinfo, test_type, aars, conditions, condition_level, cell_types)
        de_dict = gene_dict_helper(t)
        results.append(de_dict)
        gc.collect()

    pd.DataFrame(results)[['gene', 'ensembl', 'bf', 'l2fc']].to_csv(csv_path, index=False)


def main():
    args = sys.argv
    assert len(args) == 12
    csv_path = args[1]
    sinfo = pickle.load(open(args[2], "rb"))
    gene_lookup_df = pd.read_csv(args[3])
    gene_lookup_df = gene_lookup_df.set_index('gene_index')
    splotch_output_path = args[4]
    test_type = args[5]
    aars = args[6].split(",")
    conditions = args[7].split(",")
    condition_level = int(args[8])
    cell_types = args[9].split(",") if args[9] != "" else None
    start_gene = int(args[10])
    total_genes = int(args[11])

    de_csv(csv_path, sinfo, gene_lookup_df, splotch_output_path, test_type, aars, conditions, condition_level, cell_types, start_gene, total_genes)


if __name__ == "__main__":
    main()
