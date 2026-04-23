#!/bin/bash
set -euo pipefail

function allFilesExist(){
    # Checks that all files in given array exist
    path_array=("$@")
    for file_path in "${path_array[@]}";
    do
        if [ ! -f $file_path ]
        then
            return 1
        fi
    done
    return 0
}

function fslAnat(){
   cd ${data_outdir}/input

   # if all output files exist, skip rest of function
   anat_dir=${data_outdir}/input/t1-mni.anat/
   output_files=(
    "${anat_dir}"/T1_biascorr_brain.nii.gz
    "${anat_dir}"/T1_biascorr.nii.gz
    "${anat_dir}"/T1_fast_pve_0.nii.gz
    "${anat_dir}"/MNI_to_T1_nonlin_field.nii.gz
    "${anat_dir}"/T1.nii.gz
    "${anat_dir}"/T1_fullfov.nii.gz
    "${anat_dir}"/T1_to_MNI_lin.mat
    "${anat_dir}"/T1_to_MNI_nonlin_coeff.nii.gz
    "${anat_dir}"/T1_roi2nonroi.mat
   )
   if [ "$overwrite" = false ] && allFilesExist "${output_files[@]}"
   then
        echo "Skipping fsl_anat as output already exists"
        return
   fi

   # run FSL's fsl_anat tool on the input T1 image, with outputs
   # saved to a new subdirectory ${data_outdir}/input/t1-mni.anat
   echo running fsl_anat on t1 in ${anat_dir}
   # flags this will stop fsl_anat going through unnecessary steps and generating outputs we don’t use.
   fsl_anat -o t1-mni -i ./t1vol_orig.nii.gz --nosubcortseg --clobber

   echo "fsl_anat done"
   echo
}

function flairPrep(){
   # create new subdirectory to pre-process input FLAIR image
   flair_dir=${data_outdir}/input/flair-bet
   mkdir -p ${flair_dir}
   cd ${flair_dir}

   # if all output files exist, skip rest of function
   output_files=(
    "${flair_dir}"/flairvol_brain.nii.gz
    "${flair_dir}"/flairbrain2t1brain_inv.mat
    "${flair_dir}"/flairvol2t1brain.nii.gz
    "${flair_dir}"/flairvol.nii.gz
   )
   if [ "$overwrite" = false ] && allFilesExist "${output_files[@]}"
   then
        echo "Skipping flair prep as output already exists"
        return
   fi

   # run FSL's tools on input FLAIR image to ensure mni orientation followed by brain extraction
   echo preparing flair in ${flair_dir}
   fslreorient2std -m flair_orig2std.mat ../flairvol_orig.nii.gz flairvol
   bet flairvol.nii.gz flairvol_brain -m -R -S -B -Z -v

   # run FSL's flirt tool to register/align FLAIR brain with T1 brain
   flirt -in flairvol_brain.nii.gz -omat flairbrain2t1brain.mat \
     -out flairbrain2t1brain \
     -bins 256 -cost normmi -searchrx 0 0 -searchry 0 0 -searchrz 0 0 -dof 6 \
     -interp trilinear -ref ../t1-mni.anat/T1_biascorr_brain.nii.gz

   # run FSL's flirt tool to transform/align input FLAIR image (whole head) with T1 brain
   flirt -in flairvol.nii.gz -applyxfm -init flairbrain2t1brain.mat \
     -out flairvol2t1brain \
     -paddingsize 0.0 -interp trilinear -ref ../t1-mni.anat/T1_biascorr_brain.nii.gz

   # run FSL's convert_xfm to invert FLAIR to T1 transformation matrix
   convert_xfm -omat flairbrain2t1brain_inv.mat -inverse flairbrain2t1brain.mat
   echo "flair prep done"
   echo
}

function ventDistMapping(){
   # create new subdirectory to create distance map from ventricles in order to determine periventricular vs deep white matter
   vent_dir=${data_outdir}/input/vent_dist_mapping
   mkdir -p ${vent_dir}
   cd ${vent_dir}

   # if all output files exist, skip rest of function
   output_files=(
    "${vent_dir}"/perivent_t1brain.nii.gz
    "${vent_dir}"/dwm_t1brain.nii.gz
    "${vent_dir}"/perivent_flairbrain.nii.gz
    "${vent_dir}"/dwm_flairbrain.nii.gz
   )
   if [ "$overwrite" = false ] && allFilesExist "${output_files[@]}"
   then
        echo "Skipping ventricle distance mapping as output already exists"
        return
   fi

   # copy required images and transformation/warp coefficients from ${data_outdir}/input/t1-mni.anat here
   cp ../t1-mni.anat/T1_biascorr.nii.gz .
   cp ../t1-mni.anat/T1_biascorr_brain.nii.gz .
   cp ../t1-mni.anat/T1_fast_pve_0.nii.gz .
   cp ../t1-mni.anat/MNI_to_T1_nonlin_field.nii.gz .
   cp ../flair-bet/flairvol_brain.nii.gz .
   cp ../flair-bet/flairbrain2t1brain_inv.mat .

   # run FSL's make_bianca_mask tool to create binary masks of the ventricles (ventmask) and white matter (bianca_mask)
   make_bianca_mask T1_biascorr.nii.gz T1_fast_pve_0.nii.gz MNI_to_T1_nonlin_field.nii.gz

   # run FSL's flirt tool to transform/align ventmask and bianca_mask with FLAIR brain
   flirt -in T1_biascorr_bianca_mask.nii.gz -applyxfm -init flairbrain2t1brain_inv.mat -out biancamask_trans2_flairbrain -paddingsize 0.0 -interp nearestneighbour -ref flairvol_brain.nii.gz
   flirt -in T1_biascorr_ventmask.nii.gz -applyxfm -init flairbrain2t1brain_inv.mat -out ventmask_trans2_flairbrain -paddingsize 0.0 -interp nearestneighbour -ref flairvol_brain.nii.gz

   # run FSL's distancemap tool to create maps of the distance of every white matter voxel from the edge of the ventricles,
   # in the T1 and FLAIR brains respectively
   distancemap --in=T1_biascorr_ventmask.nii.gz --out=dist_from_vent_t1brain -v
   distancemap --in=ventmask_trans2_flairbrain.nii.gz --out=dist_from_vent_flairbrain -v

   # run FSL's fslmaths tool to threshold the distance-from-ventricles maps to give perivantricular vs deep white matter masks
   fslmaths dist_from_vent_t1brain -uthr 10 -mas T1_biascorr_bianca_mask -bin perivent_t1brain
   fslmaths dist_from_vent_t1brain -thr 10 -mas T1_biascorr_bianca_mask -bin dwm_t1brain_orig
   fslmaths dist_from_vent_flairbrain -uthr 10 -mas biancamask_trans2_flairbrain -bin perivent_flairbrain
   fslmaths dist_from_vent_flairbrain -thr 10 -mas biancamask_trans2_flairbrain -bin dwm_flairbrain_orig

   fslmaths perivent_t1brain.nii.gz -mul dwm_t1brain_orig.nii.gz perivent_dwm_t1_overlap
   fslmaths dwm_t1brain_orig.nii.gz -sub perivent_dwm_t1_overlap.nii.gz dwm_t1brain
   rm dwm_t1brain_orig.nii.gz
   fslmaths perivent_flairbrain.nii.gz -mul dwm_flairbrain_orig.nii.gz perivent_dwm_flair_overlap
   fslmaths dwm_flairbrain_orig.nii.gz -sub perivent_dwm_flair_overlap.nii.gz dwm_flairbrain
   rm dwm_flairbrain_orig.nii.gz

   echo "ventricle distance mapping done"
   echo
}

function prepImagesForUnet(){
   # change one directory up
   cd ${data_outdir}/input

   # if all output files exist, skip rest of function
   output_files=(
    "${data_outdir}"/input/T1.nii.gz
    "${data_outdir}"/input/FLAIR.nii.gz
    "${data_outdir}"/input/T1_croppedmore2roi.mat
   )
   if [ "$overwrite" = false ] && allFilesExist "${output_files[@]}"
   then
        echo "Skipping UNets-pgs prep as output already exists"
        return
   fi

   # run FSL's fslroi tool to crop correctly-oriented T1 and co-registered FLAIR, ready for UNets-pgs
   # Only crop if dim1 or dim2 are >= 500
   t1size=( $(fslsize ./t1-mni.anat/T1.nii.gz) )
   if [ ${t1size[1]} -ge 500 ] || [ ${t1size[3]} -ge 500 ]
   then
       fslroi ./t1-mni.anat/T1.nii.gz                     T1    20 472 8 496 0 -1
       fslroi ./flair-bet/flairvol2t1brain.nii.gz         FLAIR 20 472 8 496 0 -1
   else
       cp ./t1-mni.anat/T1.nii.gz                     T1.nii.gz
       cp ./flair-bet/flairvol2t1brain.nii.gz         FLAIR.nii.gz
   fi

   # run FSL's flirt tool to register/align cropped T1 with full-fov T1
   flirt -in T1.nii.gz -omat T1_croppedmore2roi.mat \
     -out T1_croppedmore2roi \
     -bins 256 -cost normmi -searchrx 0 0 -searchry 0 0 -searchrz 0 0 -dof 6 \
     -interp trilinear -ref ./t1-mni.anat/T1.nii.gz

  echo "Images prepared for UNets-pgs"
  echo
}

function unetsPgs(){
   # change one directory up
   cd ${data_outdir}

   # if all output files exist, skip rest of function
   output_files=(
    "${data_outdir}"/output/results.nii.gz
   )
   if [ "$overwrite" = false ] && allFilesExist "${output_files[@]}"
   then
        echo "Skipping UNets-pgs as output already exists"
        return
   fi

   # run UNets-pgs in Singularity
   echo running UNets-pgs Singularity in ${data_outdir}

   /WMHs_segmentation_PGS.sh T1.nii.gz FLAIR.nii.gz results.nii.gz ./input ./output

   echo UNets-pgs done!
   echo
}

function processOutputs(){
   # change into output directory
   cd ${data_outdir}/output

   # if all output files exist, skip rest of function
   output_files=(
    "${data_outdir}"/output/results2mni_lin_deep.nii.gz
    "${data_outdir}"/output/results2mni_lin.nii.gz
    "${data_outdir}"/output/results2mni_lin_perivent.nii.gz
    "${data_outdir}"/output/results2mni_nonlin.nii.gz
    "${data_outdir}"/output/results2mni_nonlin_deep.nii.gz
    "${data_outdir}"/output/results2mni_nonlin_perivent.nii.gz
    "${data_outdir}"/output/T1_biascorr_brain_to_MNI_lin.nii.gz
    "${data_outdir}"/output/FLAIR_biascorr_brain_to_MNI_lin.nii.gz
    "${data_outdir}"/output/T1_biascorr_brain_to_MNI_nonlin.nii.gz
    "${data_outdir}"/output/FLAIR_biascorr_brain_to_MNI_nonlin.nii.gz
   )
   if [ "$overwrite" = false ] && allFilesExist "${output_files[@]}"
   then
        echo "Skipping processing outputs as output already exists"
        return
   fi

   echo processing outputs in ${data_outdir}/output/

   echo "copy required images"
   # copy required images and transformation/warp coefficients from ${data_outdir}/input here, renaming T1 and FLAIR
   cp ${data_outdir}/input/T1_croppedmore2roi.mat .
   cp ${data_outdir}/input/t1-mni.anat/T1.nii.gz T1_roi.nii.gz
   cp ${data_outdir}/input/t1-mni.anat/T1_fullfov.nii.gz .
   cp ${data_outdir}/input/t1-mni.anat/T1_to_MNI_lin.mat .
   cp ${data_outdir}/input/t1-mni.anat/T1_to_MNI_nonlin_coeff.nii.gz .
   cp ${data_outdir}/input/t1-mni.anat/T1_roi2nonroi.mat .
   cp ${data_outdir}/input/flair-bet/flairbrain2t1brain_inv.mat .
   cp ${data_outdir}/input/flair-bet/flairvol.nii.gz FLAIR_orig.nii.gz
   cp ${data_outdir}/input/vent_dist_mapping/perivent_t1brain.nii.gz .
   cp ${data_outdir}/input/vent_dist_mapping/dwm_t1brain.nii.gz .
   cp ${data_outdir}/input/vent_dist_mapping/perivent_flairbrain.nii.gz .
   cp ${data_outdir}/input/vent_dist_mapping/dwm_flairbrain.nii.gz .
   cp ${data_outdir}/input/t1-mni.anat/T1_biascorr_brain.nii.gz .
   cp ${data_outdir}/input/flair-bet/flairvol2t1brain.nii.gz .
   cp ${data_outdir}/input/flair-bet/flairbrain2t1brain.nii.gz .


   tree ${data_outdir}/input/

   # copy MNI T1 template images here
   cp ${FSLDIR}/data/standard/MNI152_T1_1mm.nii.gz .
   cp ${FSLDIR}/data/standard/MNI152_T1_1mm_brain.nii.gz .

   # copy MNI white matter tract and striatal connectivity atlases here
   cp ${FSLDIR}/data/atlases/JHU/JHU-ICBM-labels-1mm.nii.gz .
   cp ${FSLDIR}/data/atlases/Striatum/striatum-con-label-thr50-7sub-1mm.nii.gz .


   echo "STEP 01"
   # run FSL's flirt tool to transform/align WML segmentations from UNets-pgs with roi-cropped T1
   flirt -in results.nii.gz -applyxfm -init T1_croppedmore2roi.mat \
     -out results2t1roi \
     -paddingsize 0.0 -interp nearestneighbour -ref T1_roi.nii.gz

   echo "STEP 02"
   # run FSL's flirt tool to transform/align WML segmentations from UNets-pgs with full-fov T1
   flirt -in results2t1roi.nii.gz -applyxfm -init T1_roi2nonroi.mat \
     -out results2t1fullfov \
     -paddingsize 0.0 -interp nearestneighbour -ref T1_fullfov.nii.gz

   echo "STEP 03"
   # run FSL's flirt tool to transform/align WML segmentations with full-fov FLAIR
   flirt -in results2t1roi.nii.gz -applyxfm -init flairbrain2t1brain_inv.mat \
     -out results2flairfullfov \
     -paddingsize 0.0 -interp nearestneighbour -ref FLAIR_orig.nii.gz

   # run FSL's fslmaths tool to divide WML segmentations from UNets-pgs into periventricular and deep white matter
   fslmaths results2t1roi.nii.gz -mul perivent_t1brain.nii.gz results2t1roi_perivent
   fslmaths results2t1roi.nii.gz -mul dwm_t1brain.nii.gz results2t1roi_deep
   fslmaths results2flairfullfov.nii.gz -mul perivent_flairbrain.nii.gz results2flairfullfov_perivent
   fslmaths results2flairfullfov.nii.gz -mul dwm_flairbrain.nii.gz results2flairfullfov_deep

   # run FSL's flirt tool to transform/align WML periventricular and deep white matter portions with full-fov T1
   flirt -in results2t1roi_perivent.nii.gz -applyxfm -init T1_roi2nonroi.mat \
     -out results2t1fullfov_perivent \
     -paddingsize 0.0 -interp nearestneighbour -ref T1_fullfov.nii.gz

   flirt -in results2t1roi_deep.nii.gz -applyxfm -init T1_roi2nonroi.mat \
     -out results2t1fullfov_deep \
     -paddingsize 0.0 -interp nearestneighbour -ref T1_fullfov.nii.gz

   echo "STEP 04"
   # run FSL's flirt tool to linearly transform/align WML segmentations with MNI T1
   flirt -in results2t1roi.nii.gz -applyxfm -init T1_to_MNI_lin.mat \
     -out results2mni_lin \
     -paddingsize 0.0 -interp nearestneighbour -ref MNI152_T1_1mm_brain.nii.gz

   flirt -in results2t1roi_perivent.nii.gz -applyxfm -init T1_to_MNI_lin.mat \
     -out results2mni_lin_perivent \
     -paddingsize 0.0 -interp nearestneighbour -ref MNI152_T1_1mm_brain.nii.gz

   flirt -in results2t1roi_deep.nii.gz -applyxfm -init T1_to_MNI_lin.mat \
     -out results2mni_lin_deep \
     -paddingsize 0.0 -interp nearestneighbour -ref MNI152_T1_1mm_brain.nii.gz

   flirt -in T1_biascorr_brain.nii.gz -applyxfm -init T1_to_MNI_lin.mat \
     -out T1_biascorr_brain_to_MNI_lin \
     -paddingsize 0.0 -interp trilinear -ref MNI152_T1_1mm_brain.nii.gz

   flirt -in flairbrain2t1brain.nii.gz -applyxfm -init T1_to_MNI_lin.mat \
     -out FLAIR_biascorr_brain_to_MNI_lin \
     -paddingsize 0.0 -interp trilinear -ref MNI152_T1_1mm_brain.nii.gz

   fslmaths results2mni_lin_perivent -add results2mni_lin_deep -bin results2mni_lin_combined

   echo "STEP 05"
   # run FSL's applywarp tool to nonlinearly warp WML segmentations with MNI T1
   applywarp --in=results2t1roi.nii.gz --warp=T1_to_MNI_nonlin_coeff.nii.gz \
          --out=results2mni_nonlin \
          --interp=nn --ref=MNI152_T1_1mm_brain.nii.gz

   applywarp --in=results2t1roi_perivent.nii.gz --warp=T1_to_MNI_nonlin_coeff.nii.gz \
          --out=results2mni_nonlin_perivent \
          --interp=nn --ref=MNI152_T1_1mm_brain.nii.gz

   applywarp --in=results2t1roi_deep.nii.gz --warp=T1_to_MNI_nonlin_coeff.nii.gz \
          --out=results2mni_nonlin_deep \
          --interp=nn --ref=MNI152_T1_1mm_brain.nii.gz

   applywarp --in=T1_biascorr_brain.nii.gz --warp=T1_to_MNI_nonlin_coeff.nii.gz \
          --out=T1_biascorr_brain_to_MNI_nonlin \
          --interp=trilinear --ref=MNI152_T1_1mm_brain.nii.gz

   applywarp --in=flairbrain2t1brain.nii.gz --warp=T1_to_MNI_nonlin_coeff.nii.gz \
          --out=FLAIR_biascorr_brain_to_MNI_nonlin \
          --interp=trilinear --ref=MNI152_T1_1mm_brain.nii.gz

   fslmaths results2mni_nonlin_perivent -add results2mni_nonlin_deep -bin results2mni_nonlin_combined

   echo "STEP 06"
   # run FSL's invwarp and then applywarp tools to nonlinearly warp
   # FSL's JHU white matter tract and striatal connectivity atlases from MNI to T1
   # and multiply with WML segmentations to obtain tract location maps
   invwarp --ref=T1_roi.nii.gz --warp=T1_to_MNI_nonlin_coeff \
      --out=T1_to_MNI_nonlin_inv_coeff

   applywarp --in=JHU-ICBM-labels-1mm.nii.gz --warp=T1_to_MNI_nonlin_inv_coeff \
      --out=JHU-ICBM-labels-1mm_2t1roi \
      --interp=nn --ref=T1_roi.nii.gz

   applywarp --in=striatum-con-label-thr50-7sub-1mm.nii.gz --warp=T1_to_MNI_nonlin_inv_coeff \
      --out=striatum-con-label-thr50-7sub-1mm_2t1roi \
      --interp=nn --ref=T1_roi.nii.gz

   fslmaths results2t1roi.nii.gz -mul JHU-ICBM-labels-1mm_2t1roi.nii.gz results2t1roi_jhuwmtracts
   fslmaths results2t1roi.nii.gz -mul striatum-con-label-thr50-7sub-1mm_2t1roi.nii.gz results2t1roi_striatal

   # run FSL's flirt and applywarp tools to linearly transform/align and nonlinearly warp
   # tract location maps with MNI T1
   flirt -in results2t1roi_jhuwmtracts.nii.gz -applyxfm -init T1_to_MNI_lin.mat \
     -out results2mni_lin_jhuwmtracts \
     -paddingsize 0.0 -interp nearestneighbour -ref MNI152_T1_1mm_brain.nii.gz

   flirt -in results2t1roi_striatal.nii.gz -applyxfm -init T1_to_MNI_lin.mat \
     -out results2mni_lin_striatal \
     -paddingsize 0.0 -interp nearestneighbour -ref MNI152_T1_1mm_brain.nii.gz

   applywarp --in=results2t1roi_jhuwmtracts.nii.gz --warp=T1_to_MNI_nonlin_coeff.nii.gz \
          --out=results2mni_nonlin_jhuwmtracts \
          --interp=nn --ref=MNI152_T1_1mm_brain.nii.gz

   applywarp --in=results2t1roi_striatal.nii.gz --warp=T1_to_MNI_nonlin_coeff.nii.gz \
          --out=results2mni_nonlin_striatal \
          --interp=nn --ref=MNI152_T1_1mm_brain.nii.gz

   echo all done!
   echo
}

function runAnalysis (){
   # set options are lost when running this function in parallel
   # so set them again here
   set -euo pipefail

   # Make FSL and conda commands available
  . ${FSLDIR}/etc/fslconf/fsl.sh
  . /conda/etc/profile.d/conda.sh

   flair_fn=$1
   t1_fn=$2
   data_outfile=$3
   data_outdir=$(dirname "${data_outfile}")
   export data_outdir

   echo "Processing session with:"
   echo flair_fn : ${flair_fn}
   echo t1_fn    : ${t1_fn}
   echo data_outfile : "${data_outfile}"
   echo data_outdir : ${data_outdir}
   echo

   # change into output directory and create input and output subdirectories
   # directories are required by flair
   cd ${data_outdir}
   mkdir -p ${data_outdir}/input
   mkdir -p ${data_outdir}/output

   # change into input directory ${data_outdir}/input
   # flirt expects to be ran in the same dir (maybe able to do this
   # outside of dir, but paths would be long)
   cd ${data_outdir}/input

   # copy input T1 and FLAIR images here, renaming them
   # files need to be renamed otherwise overwritten when fslroi is called.
   # also need to keep original file for flirt command
   cp ${t1_fn}    t1vol_orig.nii.gz
   cp ${flair_fn} flairvol_orig.nii.gz

   # activate conda env used for FSL
   conda activate "${FSLENV}"

   fslAnat
   flairPrep
   ventDistMapping
   prepImagesForUnet

   # temporarily deactivate conda env for unet step. This uses
   # another python install from the base cvriend/pgs image
   conda deactivate
   unetsPgs
   conda activate "${FSLENV}"

   processOutputs

   cd ${data_outdir}/output
   zip -q "${data_outfile}" \
      results2mni_lin*.nii.gz \
      results2mni_nonlin*.nii.gz \
      T1_biascorr_brain_to_MNI_*lin.nii.gz \
      FLAIR_biascorr_brain_to_MNI_*lin.nii.gz

   # Generate qc pngs for this subject / session
   png_dir=${derivatives_path}/QC/PNGS
   python /png_generator.py "$data_outdir" "$png_dir"
}

function parseArguments() {
  n=1
  subjects_file=""
  csv_file=""
  subjects=()
  html_prefix="dataset_1"
  export overwrite=false

  while getopts "n:of:s:l:h:" opt; do
    case ${opt} in
      n)
        n=${OPTARG}
        ;;
      o)
        echo "overwrite option enabled"
        overwrite=true
        ;;
      f)
        subjects_file="${data_path}/${OPTARG}"
        ;;
      s)
        IFS=',' read -r -a temp_subjects <<< "${OPTARG}"
        subjects+=("${temp_subjects[@]}")
        ;;
      l)
        csv_file="${data_path}/${OPTARG}"
        ;;
      h)
        html_prefix=${OPTARG}
        ;;
      ?)
        echo "Invalid option: -${OPTARG}."
        exit 1
        ;;
    esac
  done
}

function setupRunAnalysis(){

  parseArguments "$@"

  if [[ -n "$csv_file" ]]; then
    echo "Using CSV file: ${csv_file}"
    echo "See logs for each session in their respective output folders"
    if [[ $n -eq 1 ]]; then
      echo "Running sequentially on 1 core"
      while IFS=',' read -r flair_fn t1_fn data_outfile; do
        if [[ "$flair_fn" != "flair" ]]; then # Skip header row
          data_outdir=$(dirname "${data_path}/${data_outfile}")
          mkdir -p ${data_outdir}
          echo ${flair_fn}
          echo ${t1_fn}
          echo ${data_outdir}
          runAnalysis "${data_path}/${flair_fn}" "${data_path}/${t1_fn}" "${data_path}/${data_outfile}.zip" > "${data_path}/${data_outfile}.log" 2>&1
        fi
      done < "$csv_file"
    else
      echo "Running in parallel with ${n} jobs"
      while IFS=',' read -r flair_fn t1_fn data_outfile; do
        if [[ "$flair_fn" != "flair" ]]; then # Skip header row
          data_outdir=$(dirname "${data_path}/${data_outfile}")
          mkdir -p ${data_outdir}
        fi
      done < "$csv_file"
      export -f runAnalysis fslAnat flairPrep ventDistMapping prepImagesForUnet unetsPgs processOutputs allFilesExist
      tail -n +2 "$csv_file" | parallel --jobs ${n} --colsep ',' \
          runAnalysis \
          "${data_path}/{1}" \
          "${data_path}/{2}" \
          "${data_path}/{3}.zip" \
          ">" "'${data_path}/{3}.log'" "2>&1"
    fi
  else
    # Include subjects from file if provided
    if [[ -n "$subjects_file" ]]; then
      echo "Using subjects file: ${subjects_file}"
      while IFS=$'\n' read -r subject; do
        subjects+=("$subject")
      done < "$subjects_file"
    fi

    if [[ ${#subjects[@]} -gt 0 ]]; then
      # remove duplicates (subjects in both `subjects_file` and `subjects_list`)
      subjects=($(echo "${subjects[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    else
      echo "No subjects file or list provided. Running analysis on all subjects."
      # shellcheck disable=SC2011
      subjects=($(ls -d ${data_path}/sub-* | xargs -n 1 basename))
    fi

    # Get sessions for selected subjects
    subjects_sessions=()
    for subject in "${subjects[@]}"; do
    # shellcheck disable=SC2038
      sessions=$(find ${data_path}/${subject}/ses-*/anat/${subject}_ses-*_T1w.nii.gz | xargs -n 1 dirname | xargs -n 1 dirname | xargs -n 1 basename)
      for session in $sessions; do
        subjects_sessions+=("${subject} ${session}")
        mkdir -p ${data_path}/derivatives/enigma-pd-wml/${subject}/${session}
      done
    done

    # Run the analysis
    echo
    echo "See logs for each session in their respective folders: derivatives/enigma-pd-wml/sub-*/ses-*/"
    if [[ $n -eq 1 ]]
    then
      echo "Running sequentially on 1 core"
      for subject_session in "${subjects_sessions[@]}"; do
        subject=$(echo $subject_session | cut -d ' ' -f 1)
        session=$(echo $subject_session | cut -d ' ' -f 2)
        t1_fn=$(find ${data_path}/${subject}/${session}/anat/${subject}_${session}_T1w.nii.gz)
        flair_fn=$(find ${data_path}/${subject}/${session}/anat/${subject}_${session}_FLAIR.nii.gz)
        data_outdir=${data_path}/derivatives/enigma-pd-wml/${subject}/${session}
        data_outfile=${data_path}/derivatives/enigma-pd-wml/${subject}/${session}/${subject}_${session}_results.zip
        runAnalysis "$flair_fn" "$t1_fn" "$data_outfile" > "${data_outdir}/${subject}_${session}.log" 2>&1
      done
    else
      echo "Running in parallel with ${n} jobs"
      export -f runAnalysis fslAnat flairPrep ventDistMapping prepImagesForUnet unetsPgs processOutputs allFilesExist
      printf "%s\n" "${subjects_sessions[@]}" | parallel --jobs ${n} --colsep ' ' \
        runAnalysis \
        "${data_path}/{1}/{2}/anat/{1}_{2}_FLAIR.nii.gz" \
        "${data_path}/{1}/{2}/anat/{1}_{2}_T1w.nii.gz" \
        "${data_path}/derivatives/enigma-pd-wml/{1}/{2}/{1}_{2}.zip" \
        ">" "'${data_path}/derivatives/enigma-pd-wml/{1}/{2}/{1}_{2}.log'" "2>&1"
    fi
  fi

  # Make QC html files, that summarise all processed subjects and sessions
  qc_dir=${derivatives_path}/QC
  qc_guide_dir=${qc_dir}/QC_guide_examples
  cp -r /qc_guide_images "$qc_guide_dir"
  /MAKE_HTML.sh  "${qc_dir}/PNGS" "${qc_dir}" "${qc_guide_dir}" "${html_prefix}"
}

# assign paths for code and input data directories, as well as overall log file
export data_path=/data
export derivatives_path=${data_path}/derivatives/enigma-pd-wml
echo "See overall log at enigma-pd-wml.log in your data directory"
export overall_log=${data_path}/enigma-pd-wml.log

echo "Running analysis script"
setupRunAnalysis "$@" >> $overall_log 2>&1
