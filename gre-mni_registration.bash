#!/usr/bin/env bash
set -euo pipefail
trap 'e=$?; [ $e -ne 0 ] && echo "$0 exited in error"' EXIT
# https://github.com/ANTsX/ANTs/wiki/simple-case:-T1-to-MNI-mapping-for-both-structure-and-pre-registered-fMRI
# 20210401WF - init

# Skullstrip
# "brain extraction" using fsl's bet. could use AFNI's 3dSkullstrip or SPM
test ! -r t1_bet.nii.gz &&
   bet T1_MPRAGE_ISO_0006.nii $_
test ! -r gre_bet.nii.gz &&
   bet GRE.nii $_

## Regisration
test -d warps || mkdir $_  # make sure dir exists
# using ants in two steps. MNI<->T1. GRE<->T1
# forking both and waiting until they both complete (10 minutes?)
# default to -t="s" ==>  rigid + affine + deformable syn (3 stages)

# t1 <-> mni
[ -r warps/t1_2_mniWarped.nii.gz ] ||
   antsRegistrationSyN.sh -d 3 -f MNI_brain.nii.gz -m t1_bet.nii.gz -o warps/t1_2_mni &

# gre <-> t1
# this is rigid (r) transform only 
# TODO: should we do ridgid+affine?
[ -r warps/gre_2_t1Warped.nii.gz ] ||
   antsRegistrationSyN.sh -d 3 -t r -f t1_bet.nii.gz -m gre_bet.nii.tz -o warps/gre_2_t1 &
wait

# combine transforms
# TODO: confrim
antsApplyTransforms -d 3 -r MNI_brain.nii.gz -i GRE_R2s.nii \
   -t warps/gre_2_t10GenericAffine.mat -t warps/t1_2_mni1InverseWarp.nii.gz \
   -o GRE_R2s-mni.nii.gz
