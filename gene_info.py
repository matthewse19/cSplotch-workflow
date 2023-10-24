import pandas as pd
import pickle

info = pickle.load(open("../information.p", "rb"))

feature_example = pd.read_csv("../features.tsv", delimiter="\t", names=["ensembl", "gene", "type"])

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