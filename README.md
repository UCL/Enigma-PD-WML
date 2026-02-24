# Enigma-PD-WML

Segment White Matter Lesions (WML) in T1-weighted and FLAIR MRI images using FSL and U-Net

## What does the pipeline do?

This pipeline allows white matter lesions (WMLs) to be segmented from a subject's T1-weighted and FLAIR MRI images from
the same scanning session. The analysis steps (including pre- and post- processing) make use of the following tools:

- [FSL (FMRIB Software Library)](https://fsl.fmrib.ox.ac.uk/fsl/docs/) : a library of analysis tools for FMRI, MRI and
  diffusion brain imaging data.
  We are using version 6.0.7.13 of FSL.

- [UNet-pgs](https://www.sciencedirect.com/science/article/pii/S1053811921004171?via%3Dihub) : A segmentation pipeline
  for white matter hyperintensities (WMHs) using U-Net.

- [Nipoppy](https://nipoppy.readthedocs.io/en/stable/installation.html) : A Python package
  to structure DICOM and NIFTI images in BIDS format

For details of the processing steps, see the [pipeline documentation](/docs/pipeline.md).

The pipeline is available as a [Docker](https://www.docker.com/) or [Apptainer](https://apptainer.org/) container,
allowing it to be run on many different systems.

## How to run the pipeline?

Setting up and running the pipeline requires the following steps, which are explained in detail in the sections below:

```mermaid
%%{init: {"flowchart": {"htmlLabels": false}} }%%
flowchart TD
    installation("`Install prerequisites`")
    convert("`Ensure data is in BIDS format`")
    run("`Run the container with Docker / Apptainer`")
    installation --> convert
    convert --> run
```

## 1. Install prerequisites

If your MRI data isn't in BIDS format, it is recommended to install [Nipoppy](https://nipoppy.readthedocs.io).

If you want to run the container via Docker, install [Docker Desktop](https://docs.docker.com/get-started/get-docker/).
They have installation instructions for [Mac](https://docs.docker.com/desktop/install/mac-install/),
[Windows](https://docs.docker.com/desktop/install/windows-install/) and
[Linux](https://docs.docker.com/desktop/install/linux-install/) systems.

If you want to use Apptainer instead, then follow the
[installation instructions on their website](https://apptainer.org/docs/user/main/quick_start.html).

## 2. Convert data to BIDS format (if required)

<!-- markdownlint-disable MD028/no-blanks-blockquote -->
> [!NOTE]
> We recommend you convert your data to BIDS format before running the pipeline. If you prefer not to convert your data
> to BIDS, you can [run the pipeline on non-BIDS data](./docs/non-bids-data.md).

If your data isn't structured in BIDS format, we recommend you use [Nipoppy](https://nipoppy.readthedocs.io)
to restructure your into the required format.

For detailed instructions on the BIDSification process, please see the
[excellent guide](https://github.com/ENIGMA-PD/FS7?tab=readme-ov-file#getting-started) written by the
ENIGMA-PD core team for the FS7 pipeline.

Once you have converted your data to BIDS format, your data directory should have the following
structure:

```bash
data
├───sub-1
│   └───ses-1
│       └───anat
│           ├───sub-1_ses-1_T1w.nii.gz
│           └───sub-1_ses-1_FLAIR.nii.gz
│
├───sub-2
│   └───ses-1
│       └───anat
│           ├───sub-2_ses-1_T1w.nii.gz
│           └───sub-2_ses-1_FLAIR.nii.gz
```

## 3. Run the container

>[!IMPORTANT]
> When running the container, make sure you run the command from the top-level directory
of your BIDS-structured data, e.g. the [`data` directory in this example folder structure](#2-convert-data-to-bids-format-if-required)
<!-- markdownlint-disable MD028/no-blanks-blockquote -->
> [!NOTE]
> There are some [optional arguments](#options) you can add to the end of the Docker / Apptainer command.
<!-- markdownlint-disable MD028/no-blanks-blockquote -->
> [!TIP]
> If you encounter issues when running the pipeline, check the [output logs](#output-logs) for any errors.

### Using Docker

The image is available on Docker Hub in the
[enigma-pd-wml](https://hub.docker.com/r/hamiedaharoon24/enigma-pd-wml/tags) repository.

To run the analysis using Docker:

```bash
docker run -v "${PWD}":/data hamiedaharoon24/enigma-pd-wml:<tag>
```

where `<tag>` is the version of the image you would like to pull.

For example, to run the analysis using version `0.12.0` of the image:

```bash
docker run -v "${PWD}":/data hamiedaharoon24/enigma-pd-wml:0.12.0
```

Note, the image will be downloaded from Docker Hub the first time you run a particular version of the
image.

### Using Apptainer

To run the analysis with Apptainer, you will first need to build an image based on the Docker image
available on Docker Hub.

```bash
apptainer build enigma-pd-wml-<tag>.sif docker://hamiedaharoon24/enigma-pd-wml:<tag>
```

where `<tag>` is the version of the image you would like to pull. For example, to build an Apptainer
image from version `0.12.0` of the Docker image:

```bash
apptainer build enigma-pd-wml-0.12.0.sif docker://hamiedaharoon24/enigma-pd-wml:0.12.0
```

This will create an `enigma-pd-wml-0.12.0.sif` image file in your current working directory.

To run the analysis (changing the version number in the filename if necessary):

```bash
apptainer run --bind "${PWD}":/data enigma-pd-wml-0.12.0.sif
```

Note, this requires either:

- the `enigma-pd-wml-0.12.0.sif` file is in your current working
  directory (which should be your top-level BIDS data directory)
- or, you provide the full path to the `.sif` file in the command

### Options

- `-n` : the number of jobs to run in parallel. Defaults to 1. See also potentials issues
  of [increased memory usage](#tensorflow-memory-usage) when running in parallel.

- `-o` : overwrite existing intermediate files

  When this flag is set, the pipeline will run all steps of the pipeline, overwriting any previous output for a given
  session.

  When this flag is not set, the pipeline will re-use any existing output files, skipping steps that have previously been
  completed. This is useful if, for example, the pipeline fails at a late stage and you want to run it again, without
  having to re-run time-consuming earlier steps. This is the default behaviour.

- `-f` : Path to a file containing a list of subjects to target.

  The path must be relative to your data directory, and the file must be within the `data/` directory or one of its
  sub-directories. The file must contain one subject per line, e.g.

  ```bash filename="subjects.txt"
  sub-1
  sub-2
  sub-3
  ```

- `-s` : Comma-separated list of subjects to include in the analysis, e.g. `-s sub-1,sub-2,sub-3`

- `-l` : path to CSV file containing list of subjects to include in the analysis. This should only be used if you would
  like to [run the pipelineon non-BIDS data](./docs/non-bids-data.md). This path must be relative to your data directory.

> [!NOTE]
> If `-f`, `-s`, and `-l` are omitted, the pipeline will be run on all subjects and assume data is in BIDS format.
<!-- markdownlint-disable MD028/no-blanks-blockquote -->
> [!NOTE]
> If a CSV file is passed using the `-l` option, `-f` and `-s` will be ignored.

## Pipeline output

### Output images

After running your analysis, your data directory should have the following structure:

```bash
data
├── enigma-pd-wml.log
├── dataset_description.json
├── derivatives
│   └── enigma-pd-wml
│       ├── enigma-pd-wml-results.zip
│       └── sub-1
│           ├── ses-1
│           │   ├── input/
│           │   ├── output/
│           │   ├── sub-1_ses-1.log
│           │   └── sub-1_ses-1_results.zip
│           └── ses-2
│               ├── input/
│               ├── output/
│               ├── sub-1_ses-2.log
│               └── sub-1_ses-2_results.zip
├── sub-1
│   ├── ses-1
│   │   └── anat
│   │       ├── sub-1_ses-1_FLAIR.nii.gz
│   │       └── sub-1_ses-1_T1w.nii.gz
│   └── ses-2
│       └── anat
│           ├── sub-1_ses-2_FLAIR.nii.gz
│           └── sub-1_ses-2_T1w.nii.gz
```

#### Session-level zip files

The pipeline will generate multiple `.zip` files - one per session, stored within the corresponding session
sub-folder, e.g. `derivatives/enigma-pd-wml/sub-1/ses-1/sub-1_ses-1_results.zip`.

These zip files should contain 12 files:

- `results2mni_lin.nii.gz`: WML segmentations linearly transformed to MNI space.

- `results2mni_lin_deep.nii.gz`: WML segmentations (deep white matter) linearly transformed to MNI space.

- `results2min_lin_perivent.nii.gz`: WML segmentations (periventricular) linearly transformed to MNI space.

- `results2mni_nonlin.nii.gz`: WML segmentations non-linearly warped to MNI space.

- `results2min_nonlin_deep.nii.gz`: WML segmentations (deep white matter) non-linearly warped to MNI space.

- `results2mni_lin_jhuwmtracts.nii.gz`: WML segmentations (on jhu-icbm white matter tracts) linearly transformed to
  MNI space.

- `results2mni_lin_striatal.nii.gz`: WML segmentations (on striatal connections) linearly transformed to MNI space.

- `results2mni_nonlin_perivent.nii.gz`: WML segmentations (periventricular) non-linearly warped to MNI space.

- `results2mni_nonlin_jhuwmtracts.nii.gz`: WML segmentations (on jhu-icbm white matter tracts) non-linearly warped
  to MNI space.

- `results2mni_nonlin_striatal.nii.gz`: WML segmentations (on striatal connections) non-linearly warped to MNI space.

- `T1_biascorr_brain_to_MNI_lin.nii.gz`: T1 bias-corrected brain linearly transformed to MNI space.

- `FLAIR_biascorr_brain_to_MNI_lin.nii.gz`: FLAIR bias-corrected brain linearly transformed to MNI space.

- `T1_biascorr_brain_to_MNI_nonlin.nii.gz`: T1 bias-corrected brain non-linearly warped to MNI space.

- `FLAIR_biascorr_brain_to_MNI_nonlin.nii.gz`: FLAIR bias-corrected brain non-linearly warped to MNI space.

> [!NOTE]
> Please send these zip files to the ENIGMA-PD Vasc team.

#### Intermediate files

The pipeline generates several intermediate files. These are stored in the `derivatives/enigma-pd-wml/<subject>/<session>/input`
and `derivatives/enigma-pd-wml/<subject>/<session>/output` folders.

### Output logs

Pipeline logs can be found at:

- `enigma-pd-wml.log`: contains minimal information about the initial pipeline setup.

- `derivatives/enigma-pd-wml/<subject>/<session>/<subject>_<session>.log`: one log per session; contains information about
  the various processing steps.

## Quality control

See notes on [quality control](docs/qc.md) for the WML pipeline.

New interactive QC feature soon to be added.

## Common issues

### Tensorflow memory usage

A common issue is UNets-pgs failing due to high memory usage. You may see warnings / errors in your subject logs
similar to:

- `tensorflow/core/framework/allocator.cc:124] Allocation of 675840000 exceeds 10% of system memory.`

- `/WMHs_segmentation_PGS.sh: line 14: 69443 Killed`

You may want to try:

- Running the pipeline on a system with more memory

- Reducing the number of jobs passed to the `-n` option (if you're using it). This will slow down the pipeline, but
  also reduce overall memory usage.

## For developers

Some brief notes on the development setup for this repository are provided in a
[separate developer docs file](/docs/developer.md).

## License

This software is licensed under BSD Clause 3. See the [LICENSE](LICENSE) file for details.

FSL is released under a 'free for non-commercial purposes license', and
  is bundled with third-party libraries 'released under a range of different open source licenses'.
  See the [FSL license](https://fsl.fmrib.ox.ac.uk/fsl/docs/#/license) for full details.

## Contributors

### Creators

Drs Sarah Al-Bachari, Hamied Haroon, Robin Long, Kimberley Meecham and Paul Smith. With specialist input from Professor
Neda Jahanshad, Dr Conor Owens-Walton and Miss Sunanda Somu and Dr Chris Vriend.

### Acknowledgements and Thanks

Academy of Medical Sciences and Professor Schrag for directly supporting the project.  The Centre for Advanced Research
Computing at UCL. All members of the ENIGMA-PD core team. Professor Laura Parkes and the University of Manchester
computing facilities.

## Citations

`FSL`:

- M. Jenkinson, C.F. Beckmann, T.E. Behrens, M.W. Woolrich, S.M. Smith. FSL.
  NeuroImage, 62:782-90, 2012

- Jenkinson, M., Bannister, P., Brady, J. M. and Smith, S. M. Improved Optimisation for the
  Robust and Accurate Linear Registration and Motion Correction of Brain Images.
  NeuroImage, 17(2), 825-841, 2002.

- Andersson JLR, Jenkinson M, Smith S (2010) Non-linear registration, aka spatial normalisation.
  FMRIB technical report TR07JA2

- Zhang, Y. and Brady, M. and Smith, S. Segmentation of brain MR images through a
  hidden Markov random field model and the expectation-maximization algorithm.
  IEEE Trans Med Imag, 20(1):45-57, 2001

- L. Griffanti, G. Zamboni, A. Khan, L. Li, G. Bonifacio, V. Sundaresan,
  U. G. Schulz, W. Kuker, M. Battaglini, P. M. Rothwell, M. Jenkinson (2016)
  BIANCA (Brain Intensity AbNormality Classification Algorithm): a new tool for
  automated segmentation of white matter hyperintensities. Neuroimage. 141:191-205

`UNets`:

- Park, G., Hong, J., Duffy, B. A., Lee, J. M., & Kim, H. (2021). White matter hyperintensities segmentation
  using the ensemble U-Net with multi-scale highlighting foregrounds.Neuroimage, 237, 118140.

`Nipoppy`:

- <https://github.com/nipoppy/nipoppy.git>, doi: 10.5281/zenodo.8084759
