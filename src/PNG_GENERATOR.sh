#!/bin/bash
# Written by Sunanda Somu
# ----------- Usage ----------------------------------------------------------------------------------------------------------------------------------
# PNG_GENERATOR.sh /path/to/subjects.txt /path/to/data_dir /path/to/output_png_dir /path/to/python_binary
# This script generates PNG images for each axial slice (n = 182; MNI space)
# from the pipeline’s outputs.
#
# Non-linear registration:
#   - Base image:    FLAIR_biascorr_brain_to_MNI_nonlin.nii.gz << CHANGE FILENAMES TO the LATEST PIPLEINE OUTPUTS >>
#   - WML overlay:   results2mni_nonlin.nii.gz << CHANGE FILENAMES TO the LATEST PIPLEINE OUTPUTS >>
#
# Linear registration:
#   - Base image:    FLAIR_biascorr_brain_to_MNI_lin.nii.gz << CHANGE FILENAMES TO the LATEST PIPLEINE OUTPUTS >>
#   - WML overlay:   results2mni_lin.nii.gz << CHANGE FILENAMES TO the LATEST PIPLEINE OUTPUTS >>
# ----------------------------------------------------------------------------------------------------------------------------------------------------

#### UPDATE THE FOLLOWING TO INTEGRATE WITH EXISTING PIPELINE
#### Please add code for better logging wherever necessary
#### <<START EDIT>>
# subjects_file=<</path/to/subjects.txt>>
# data_dir=<<Add_data_path>>/bids/derivatives/enigma-pd-wml/
# output_dir=<<Add_data_path>>/bids/derivatives/enigma-pd-wml/PNGS   ###This is the directory that will store all the subjects PNGs
# python_bin=<</path/to/python_binary>>
# << CHANGE FILENAMES TO the LATEST PIPLEINE OUTPUTS IN THE PYTHON CODE>>
#### <<END EDIT>>

mkdir -p "$output_dir"
echo "Processing subject: $subject"

# Embedded Python script
${python_bin}/python - "$subject" "$data_dir" "$output_dir" <<'EOF'
import os
import sys
import glob
import nibabel as nib
import numpy as np
import matplotlib
matplotlib.use('Agg')  
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors

def process_registration_type(subj, data_dir, outdir, reg_type):
    """Process either 'nonlin' or 'lin' registration with error checks"""
    base_pattern = f"FLAIR_biascorr_brain_to_MNI_{reg_type}.nii.gz" 
    overlay_pattern = f"results2mni_{reg_type}.nii.gz"
    
    # Search for files
    search_path = os.path.join(data_dir, subj, "ses-*/output")
    base_candidates = glob.glob(os.path.join(search_path, base_pattern))
    overlay_candidates = glob.glob(os.path.join(search_path, overlay_pattern))

    # Check for missing files
    if not base_candidates and not overlay_candidates:
        print(f"ERROR: {subj} ({reg_type}): Neither base nor overlay NIfTI found in {search_path}")
        return False
    
    if not base_candidates:
        print(f"ERROR: {subj} ({reg_type}): Base NIfTI not found: {base_pattern} in {search_path}")
        return False
    
    if not overlay_candidates:
        print(f"ERROR: {subj} ({reg_type}): Overlay NIfTI not found: {overlay_pattern} in {search_path}")
        return False

    base_nii = base_candidates[0]
    overlay_nii = overlay_candidates[0]
    
    # Warn if multiple files found
    if len(base_candidates) > 1:
        print(f"WARNING: {subj} ({reg_type}): Multiple base files found, using {base_nii}")
    if len(overlay_candidates) > 1:
        print(f"WARNING: {subj} ({reg_type}): Multiple overlay files found, using {overlay_nii}")

    # Load NIfTI files
    try:
        base_img = nib.load(base_nii)
        overlay_img = nib.load(overlay_nii)
    except FileNotFoundError as e:
        print(f"ERROR: {subj} ({reg_type}): File not found during load: {e}")
        return False
    except nib.filebasedimages.ImageFileError as e:
        print(f"ERROR: {subj} ({reg_type}): Invalid NIfTI file format: {e}")
        return False
    except Exception as e:
        print(f"ERROR: {subj} ({reg_type}): Error loading NIfTI: {e}")
        return False

    # Get data
    try:
        base_data = base_img.get_fdata()
        overlay_data = overlay_img.get_fdata()
    except Exception as e:
        print(f"ERROR: {subj} ({reg_type}): Error extracting data from NIfTI: {e}")
        return False

    # Check for empty data
    if base_data.size == 0 or overlay_data.size == 0:
        print(f"ERROR: {subj} ({reg_type}): Empty NIfTI data array (base: {base_data.shape}, overlay: {overlay_data.shape})")
        return False

    # Check shape mismatch
    if base_data.shape != overlay_data.shape:
        print(f"ERROR: {subj} ({reg_type}): Shape mismatch - base {base_data.shape} vs overlay {overlay_data.shape}")
        return False

    n_slices = base_data.shape[2]  # axial slices
    out_subj_dir = os.path.join(outdir, subj, reg_type)
    
    # Create output directory
    try:
        os.makedirs(out_subj_dir, exist_ok=True)
    except PermissionError as e:
        print(f"ERROR: {subj} ({reg_type}): Permission denied creating directory: {out_subj_dir}")
        return False
    except Exception as e:
        print(f"ERROR: {subj} ({reg_type}): Error creating output directory: {e}")
        return False

    # Solid blue colormap for WML overlay
    blue_cmap = mcolors.ListedColormap(['blue'])

    # Process slices
    failed_slices = []
    for i in range(n_slices):
        try:
            base_slice = np.rot90(base_data[:, :, i])
            overlay_slice = np.rot90(overlay_data[:, :, i])

            # Save base slice
            fig, ax = plt.subplots(figsize=(6, 6), dpi=100)
            ax.imshow(base_slice, cmap='gray', interpolation='none')
            ax.axis('off')
            plt.subplots_adjust(left=0, right=1, top=1, bottom=0)
            base_png = os.path.join(out_subj_dir, f"{i}_base.png")
            plt.savefig(base_png, bbox_inches='tight', pad_inches=0, dpi=100)
            plt.close(fig)

            # Save WML overlay slice
            fig, ax = plt.subplots(figsize=(6, 6), dpi=100)
            overlay_mask = np.ma.masked_where(overlay_slice == 0, np.ones_like(overlay_slice))
            ax.imshow(base_slice, cmap='gray', interpolation='none')
            ax.imshow(overlay_mask, cmap=blue_cmap, vmin=0, vmax=1,
                  alpha=0.9, interpolation='none')
            ax.axis('off')
            plt.subplots_adjust(left=0, right=1, top=1, bottom=0)
            overlay_png = os.path.join(out_subj_dir, f"{i}_overlay.png")
            plt.savefig(overlay_png, bbox_inches='tight', pad_inches=0, dpi=100)
            plt.close(fig)
            
        except Exception as e:
            print(f"WARNING: {subj} ({reg_type}): Failed to save slice {i}: {e}")
            failed_slices.append(i)
            plt.close('all')  # Ensure cleanup

    if failed_slices:
        print(f"WARNING: {subj} ({reg_type}): Failed to save {len(failed_slices)} slices: {failed_slices}")

    print(f"{subj} ({reg_type}): Saved {n_slices - len(failed_slices)}/{n_slices} axial slices")
    
    return True

# Main execution
try:
    subj, data_dir, outdir = sys.argv[1:]
except ValueError:
    print("ERROR: Missing required arguments to python script. Usage: script.py <subject> <data_dir> <output_dir>")
    sys.exit(1)

print(f"Processing subject: {subj}")

# Process both registration types
nonlin_success = process_registration_type(subj, data_dir, outdir, 'nonlin')
lin_success = process_registration_type(subj, data_dir, outdir, 'lin')

# Exit with code
if not nonlin_success and not lin_success:
    print(f"Failed to process {subj} for both registration types")
    sys.exit(1)
elif not nonlin_success or not lin_success:
    print(f"Processed {subj} with one registration type failing")
    sys.exit(0)
else:
    print(f"Successfully processed {subj} for both registration types")
    sys.exit(0)
EOF