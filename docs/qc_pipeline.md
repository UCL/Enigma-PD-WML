# Quality Control pipeline details

See [the QC usage docs](./qc_usage.md) for information about how to use the quality control interface. This document
focuses on the technical details of how the QC files are created.

## Pipeline components

The pipeline operates in two sequential stages: first generating PNG images from NIfTI volumes, then assembling those
images into the HTML. Each stage is executed by a dedicated script, as follows:

| Script | Function | Output |
| ------------- | ------------------- | ----------------- |
| `png_generator.py` | Converts 3D NIfTI volumes into 2D axial slice images (PNGs) | 182 axial slices per registration type |
| `MAKE_HTML.sh` | Assembles PNG images into HTML viewer | HTML files with QC controls |

## Input requirements

The QC framework expects outputs from the upstream ENIGMA-PD-WML processing pipeline. For each subject, two pairs of
NIfTIs are required, one pair for linear registration and another for nonlinear registration:

| Registration | Base Image (FLAIR) | WML Overlay Mask |
| ------------- | ------------------- | ----------------- |
| Nonlinear | FLAIR_biascorr_brain_to_MNI_nonlin.nii.gz | results2mni_nonlin_combined.nii.gz |
| Linear | FLAIR_biascorr_brain_to_MNI_lin.nii.gz | results2mni_lin_combined.nii.gz |

## Output directory structure

All outputs from the QC framework are organized under a dedicated QC folder under the main enigma-pd-wml folder. This
structure helps having all the reference images (see the
[assessing segmentation quality section](./qc_usage.md#assessing-segmentation-quality)), the generated PNGs and HTMLs
in a single folder that the user can later zip to save space. See the
[output images section of the readme](../README.md#output-images) for the output structure, including the `QC` directory.

## png_generator.py

The `png_generator.py` script handles the conversion of 3D NIfTI volumes into 2D PNG images for fast and easy
visualization. For each unique subject/session, it processes both registration types (linear and nonlinear), extracting
all 182 axial slices and generating paired base/overlay images for each slice.

### Command

`python png_generator.py <data_dir> <output_png_dir>`

### Arguments

| Parameter | Description | Example |
| ---------- | ------------ | --------- |
| data_dir | Path to directory containing pipeline outputs for a single subject/session | `/data/derivatives/enigma-pd-wml/sub-1/ses-1/` |
| output_png_dir | Destination directory for generated PNG images | `/data/derivatives/enigma-pd-wml/QC/PNGs` |

### Execution

The PNG generation process involves loading paired NIfTI volumes, validating their integrity, and extracting 2D axial
slices as PNG images. The following subsections explain the processing steps.

#### Python dependencies

The following Python libraries are required:

| Library | Function |
| --------- | ------------ |
| nibabel | NIfTI file I/O Handling |
| numpy | Array operations and masking |
| matplotlib | Image generation (uses Agg backend) |

### Input file discovery and validation

For each subject, the script searches for the required NIfTI files in `data_dir/output`.

Within this path, the script looks for two file pairs — one for each registration type (linear and nonlinear):

- FLAIR_biascorr_brain_to_MNI_{nonlin|lin}.nii.gz:  base FLAIR image
- results2mni_{nonlin|lin}_combined.nii.gz: WML segmentation overlay mask

Prior to processing, several validation checks are performed to ensure data integrity:

1. File existence: Both base and overlay files must be present
2. Format validation: Files must be valid NIfTI format (verified via nibabel)
3. Data integrity: Arrays must be non-empty with valid dimensions
4. Shape matching: Base and overlay volumes must have identical dimensions

If any validation check fails, the subject is skipped for that registration type and an appropriate error message is
logged (see [the log section](#log-output)).

### PNG slice extraction

Once validated, each 3D volume is processed slice-by-slice along the axial (z) dimension. For each of the 182 slices in
MNI space, the script performs the following operations:

1. Slice extraction: The 2D axial slice is extracted and rotated 90° (np.rot90) to conform to radiological display
   convention
2. Base image generation: The FLAIR slice is rendered using a grayscale colormap
3. Overlay image generation: The same FLAIR slice is rendered with the WML segmentation mask superimposed in solid blue
   at 90% opacity

This produces two PNG files per slice: `{slice_number}_base.png` and `{slice_number}_overlay.png`.

### Output PNG specifications

All generated PNG images have the following specifications:

| Specification | Value |
| --------- | ------------ |
| Image dimensions | 600 x 600 pixels |
| Resolution | 100 DPI |
| Format | PNG (lossless compression) |
| Base Image Colormap | Grayscale |
| WML Overlay Color | Solid Blue (#0000FF) |
| Overlay transparency | 90% opaque |
| Naming convention | {slice_number}_base.png {slice_number}_overlay.png |

### Output file and memory management

Each subject generates a total of 728 PNG files across both registration types, as summarized below. We estimate a
storage requirement for all PNGs (linear + nonlinear) to be approximately 15-20 MB per subject.

| File type | Count | Calculation |
| --------- | ------------ | ---------- |
| Slices per volume | 182 | MNI space standard |
| Images per slice | 2 | base + overlay |
| Registration types | 2 | linear + nonlinear |
| Total PNGs per scan | 728 | 182 x 2 x 2 |

### Log output

The script outputs processing status to stdout for each subject/session (saved to their individual log files at e.g.
`data/derivatives/enigma-pd-wml/sub-1/ses-1/sub-1_ses-1.log`). These logs are essential for identifying failed
subjects, and diagnosing issues. Some logs generated by the script are summarised below:

- Successful processing

  ```bash
  Processing subject: sub-1
  sub-1 (nonlin): Saved 182/182 axial slices
  sub-1 (lin): Saved 182/182 axial slices
  Successfully processed sub-1 for both registration types
  ```

- File not found

  ```bash
  Processing subject: sub-3
  ERROR: sub-3 (nonlin): Base NIfTI not found: FLAIR_biascorr_brain_to_MNI_nonlin.nii.gz
  ERROR: sub-3 (lin): Neither base nor overlay NIfTI found in /data/sub-3/ses-*/output
  Failed to process sub-3 for both registration types
  ```

  Probable cause: NifTI files missing from expected path

- Dimension mismatch error

  ```bash
  Processing subject: sub-4
  ERROR: sub-4 (nonlin): Shape mismatch - base (182, 218, 182) vs overlay (91, 109, 91)
  sub-4 (lin): Saved 182/182 axial slices
  Processed sub-4 with one registration type failing

  ```

  Probable cause: Base and overlay have different dimensions

- Multiple files warning

  ```bash
  Processing subject: sub-5
  WARNING: sub-5 (nonlin): Multiple base files found, using /data/sub-5/ses-01/output/…
  sub-5 (nonlin): Saved 182/182 axial slices
  ```

  Probable cause: Duplicate files

- Partial slice failure

  ```bash
  Processing subject: sub-6
  WARNING: sub-6 (nonlin): Failed to save slice 45: [Errno 28] No space left on device
  WARNING: sub-6 (nonlin): Failed to save 2 slices: [45, 46]
  sub-6 (nonlin): Saved 180/182 axial slices
  ```

  Probable cause: Disk full or write error

## MAKE_HTML.sh

The MAKE_HTML.sh script assembles the generated PNG images into an interactive HTML-based QC viewer using CSS styling
and JavaScript functionality. The resulting interface enables efficient review of WML segmentations with built-in tools
for slice navigation, overlay toggling, and standardized QC rating.

### MAKE_HTML command

`./MAKE_HTML.sh <png_dir> <output_dir> <qc_guide_dir> <dataset_name/html_prefix>`

### MAKE_HTML arguments

| Parameter | Description | Example |
| ---------- | ------------ | --------- |
| png_dir | Directory containing generated PNG images | `/data/derivatives/enigma-pd-wml/QC/PNGs` |
| output_dir | Destination for HTML output files | `/data/derivatives/enigma-pd-wml/QC` |
| qc_guide_dir | Directory with QC reference example images | `/data/derivatives/enigma-pd-wml/QC/QC_guide_examples` |
| dataset_name / html_prefix | Prefix for output HTML filenames | `dataset_1` |

### MAKE_HTML execution

The HTML generator assembles the PNG images into an interactive viewer for efficient QC. To ensure responsive browser
performance, each HTML file displays a maximum of 200 scans. For datasets exceeding this threshold, subjects/sessions
are automatically distributed across multiple HTML files.

Separate HTML files are generated for linear and nonlinear registrations, enabling independent review of each
registration type. For example, a dataset with 450 subjects (each with only one session) would produce six HTML files:

Linear Registration:

- <html_prefix>_ENIGMA_WML_QC_Linear_01.html : subjects 1 - 200
- <html_prefix>_ENIGMA_WML_QC_Linear_02.html : subjects 201 - 400
- <html_prefix>_ENIGMA_WML_QC_Linear_03.html : subjects 401 - 450

Nonlinear Registration:

- <html_prefix>_ENIGMA_WML_QC_Nonlinear_01.html : subjects 1 - 200
- <html_prefix>_ENIGMA_WML_QC_Nonlinear_02.html : subjects 201 - 400
- <html_prefix>_ENIGMA_WML_QC_Nonlinear_03.html : subjects 401 - 450

See [the QC usage docs](./qc_usage.md) for details of HTML features and how to use them.
