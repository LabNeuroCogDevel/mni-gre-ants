#!/usr/bin/env bash
set -euo pipefail
trap 'e=$?; [ $e -ne 0 ] && echo "$0 exited in error"' EXIT
# https://github.com/ANTsX/ANTs/wiki/simple-case:-T1-to-MNI-mapping-for-both-structure-and-pre-registered-fMRI
# 20210401WF - init

# Skullstrip
test -d bet || mkdir $_
# "brain extraction" using fsl's bet. could use AFNI's 3dSkullstrip or SPM
test ! -r bet/t1_bet.nii.gz &&
   bet input/T1_MPRAGE_ISO_0006.nii.gz $_
test ! -r bet/gre_bet.nii.gz &&
   bet input/GRE.nii.gz $_

## Regisration
test -d warps || mkdir $_  # make sure dir exists
# using ants in two steps. MNI<->T1. GRE<->T1
# forking both and waiting until they both complete (30 minutes?)
# -t="s" (default) ==>  rigid + affine + deformable syn (3 stages)
# -f is "fixed" source reference
# -m is "moving" target
# -n is number of threads

# t1 <-> mni
[ -r warps/t1_2_mni_Warped.nii.gz ] ||
   antsRegistrationSyN.sh -d 3 -f template/MNI152_T1_1mm_brain.nii.gz -m bet/t1_bet.nii.gz -o warps/t1_2_mni_ -n 5 &

# gre <-> t1
# -t r is rigid transform only
[ -r warps/gre_2_t1_rigid_Warped.nii.gz ] ||
   antsRegistrationSyN.sh -d 3 -t r -f bet/t1_bet.nii.gz -m bet/gre_bet.nii.gz -o warps/gre_2_t1_rigid_ -n 5 &

# if we wanted rigid+affine (-t a):
#[ -r warps/gre_2_t1_affine_Warped.nii.gz ] ||
#   antsRegistrationSyN.sh -d 3 -t a -f bet/t1_bet.nii.gz -m bet/gre_bet.nii.gz -o warps/gre_2_t1_affine_ &

wait


# combine transforms
# TODO: confrim warp order produces correct output
antsApplyTransforms -d 3 -r template/MNI152_T1_1mm_brain.nii.gz -i input/GRE_R2s.nii.gz \
   -t warps/gre_2_t1_rigid_0GenericAffine.mat -t warps/t1_2_mni_0GenericAffine.mat -t warps/t1_2_mni_Warp.nii.gz \
   -o warps/GRE_R2s-WarpedMNI.nii.gz


### visualizing

# for visualizing, just the gre
# dont need 
 antsApplyTransforms -d 3 -r template/MNI152_T1_1mm_brain.nii.gz -i bet/gre_bet.nii.gz \
    -t warps/gre_2_t1_rigid_0GenericAffine.mat  -t warps/t1_2_mni_0GenericAffine.mat -t warps/t1_2_mni_1Warp.nii.gz \
    -o warps/GRE-WarpedMNI.nii.gz

# just for use with afni. without refit cannot see warped overlayed on tempalte
3drefit -space MNI warps/t1_2_mni_Warped.nii.gz warps/GRE*-WarpedMNI*nii.gz

## inspect: how well did the warps go?
test -d imgs || mkdir $_
# t1->mni
slicer template/MNI152_T1_1mm_brain.nii.gz warps/t1_2_mni_Warped.nii.gz -a imgs/t1_mni.png
# gre->t1
slicer bet/t1_bet.nii.gz warps/gre_2_t1_affine_Warped.nii.gz -a imgs/gre_t1.png
# gre->mni
slicer template/MNI152_T1_1mm_brain.nii.gz warps/GRE-WarpedMNI.nii.gz -a imgs/gre_mni.png
