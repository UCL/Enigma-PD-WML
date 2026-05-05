# Running the pipeline on non-BIDS data

We recommend you convert your data to BIDS format before running the pipeline. However, if you have non-BIDS data, you
can still run the pipeline by following these steps:

- [install the pre-requisites](../README.md/#1-install-prerequisites)
- create a CSV file that describes the directory structure of your data
- run the pipeline using the CSV file

## Create a CSV file

You will need to create an CSV file that describes the directory structure of your data.

The CSV file must contain one row for each subject you want to analyse. It must contain the following columns:

- `flair`: path to the FLAIR MRI image for a subject
- `t1`: path to the T1-weighted MRI image for a subject
- `subject`: the id of the subject these images belong to
- `session`: the id of the session these images belong to

For example, if you have the following directory structure:

```bash
data
├───subject-1-session-1
│   ├───flair.nii.gz
│   └───t1.nii.gz
│
├───subject-1-session-2
│   ├───flair.nii.gz
│   └───t1.nii.gz
│
├───subject-2-session-1
│   ├───flair.nii.gz
│   └───t1.nii.gz
```

you would create the following CSV file:

```csv
flair,t1,subject,session
subject-1-session-1/flair.nii.gz,subject-1-session-1/t1.nii.gz,1,1
subject-1-session-2/flair.nii.gz,subject-1-session-2/t1.nii.gz,1,2
subject-2-session-1/flair.nii.gz,subject-2-session-1/t1.nii.gz,2,1
```

> [!NOTE]
> All filename must be relative to the data directory from which you run the Docker or Apptainer image. For example,
> with the above directory structure you would run the Docker (or Apptainer) run command
> from the `data/` directory, and the paths in the CSV file must be relative to this
> directory.

## Run the pipeline

To run the pipeline, follow the [instructions for running the container](../README.md#3-run-the-container), and pass the
`-l` flag to the run command, specifying the relative path to your csv file. For example, to run with Docker:

```bash
docker run -v "${PWD}":/data hamiedaharoon24/enigma-pd-wml:<tag> -l input.csv
```

assuming you have saved the CSV file as `input.csv` in the `data/` directory.

## Output data

The pipeline will create a `derivatives` directory inside `data/` containing the results.
Your entire directory structure will look like this:

```bash
data
├── input.csv
├── enigma-pd-wml.log
├── subject-1-session-1
│   ├── flair.nii.gz
│   └── t1.nii.gz
│
├── subject-1-session-2
│   ├── flair.nii.gz
│   └── t1.nii.gz
│
├── subject-2-session-1
│   ├── flair.nii.gz
│   └── t1.nii.gz
│
├── derivatives
│    └── enigma-pd-wml
│          ├── QC
│          │   ├── PNGS/
│          │   ├── QC_guide_examples/
│          │   ├── dataset_1_ENIGMA_WML_QC_Linear_01.html
│          │   └── dataset_1_ENIGMA_WML_QC_Nonlinear_01.html
│          │
│          ├── sub-1
│          │   ├── ses-1
│          │   │   ├── input/
│          │   │   ├── output/
│          │   │   ├── sub-1_ses-1.log
│          │   │   └── sub-1_ses-1_results.zip
│          │   └── ses-2
│          │       ├── input/
│          │       ├── output/
│          │       ├── sub-1_ses-2.log
│          │       └── sub-1_ses-2_results.zip
│          └── sub-2
│               └──ses-1
│                  ├── input/
│                  ├── output/
│                  ├── sub-2_ses-1.log
│                  └── sub-2_ses-1_results.zip
```

The [session-level zip files](../README.md#session-level-zip-files) are stored in
`data/derivatives/enigma-pd-wml/sub-1/ses-1/sub-1_ses-1_results.zip`, and so on for the other subject / session ids.
These are the files you will need to send to the ENIGMA-PD Vasc team.

The [intermediate files](../README.md#intermediate-files) are stored in the
`data/derivatives/enigma-pd-wml/sub-1/ses-1/input/` and `data/derivatives/enigma-pd-wml/sub-1/ses-1/output/` directories
for subject and session 1 (and the corresponding directories for other sessions and subjects).

The top-level [log file](../README.md#output-logs) is stored in `data/enigma-pd-wml.log`, and the session-level log
files are stored in `data/derivatives/enigma-pd-wml/sub-1/ses-1/sub-1_ses-1.log` (and corresponding files for each
subject / session combination).
