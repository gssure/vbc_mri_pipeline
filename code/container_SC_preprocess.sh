#!/bin/bash

input=${1}
threads=${2}
sbj=${3}

totalNum=$(grep -c $ ${input})
for (( i = 1; i < totalNum + 1 ; i++ )); do
	cmd=$(sed -n ${i}p ${input})
	eval "${cmd}"
done
# threads=${threads1}

# Path setting
# ------------
wp=$(pwd)
tmp=${ppsc}/${grp}/${sbj}/temp
aseg=${tmp}/aseg.nii.gz
parcseg=${tmp}/aparc.a2009s+aseg.nii.gz

t1=${sp}/${grp}/${sbj}/anat/${sbj}_T1w.nii.gz
dwi=${sp}/${grp}/${sbj}/dwi/${sbj}_dwi.nii.gz
dwi_json=${sp}/${grp}/${sbj}/dwi/${sbj}_dwi.json
bval=${sp}/${grp}/${sbj}/dwi/${sbj}_dwi.bval
bvec=${sp}/${grp}/${sbj}/dwi/${sbj}_dwi.bvec

mc_bval=${ppsc}/${grp}/${sbj}/mc_bval.dat
mc_bvec=${ppsc}/${grp}/${sbj}/mc_bvec.dat
ctx=${ppsc}/${grp}/${sbj}/fs_t1_ctx_mask_to_dwi.nii.gz
sub=${ppsc}/${grp}/${sbj}/fs_t1_subctx_mask_to_dwi.nii.gz
csf=${ppsc}/${grp}/${sbj}/fs_t1_csf_mask_to_dwi.nii.gz
wm=${ppsc}/${grp}/${sbj}/fs_t1_wm_mask_to_dwi.nii.gz
wmneck=${ppsc}/${grp}/${sbj}/fs_t1_neck_wm_mask_to_dwi.nii.gz
gmneck=${ppsc}/${grp}/${sbj}/fs_t1_neck_gm_mask_to_dwi.nii.gz
ftt=${ppsc}/${grp}/${sbj}/5tt.nii.gz

# Colors
# ------
RED='\033[1;31m'	# Red
GRN='\033[1;32m' 	# Green
NCR='\033[0m' 		# No Color

# Call container_SC_dependencies
# ------------------------------
source /usr/local/bin/container_SC_dependencies.sh
export SUBJECTS_DIR=/opt/freesurfer/subjects

# Freesurfer license
# ------------------
if [[ -f /opt/freesurfer/license.txt ]]; then
	printf "Freesurfer license has been checked.\n"
else
	echo "${email}" >> $FREESURFER_HOME/license.txt
	echo "${digit}" >> $FREESURFER_HOME/license.txt
	echo "${line1}" >> $FREESURFER_HOME/license.txt
	echo "${line2}" >> $FREESURFER_HOME/license.txt
	printf "Freesurfer license has been updated.\n"
fi

# Target folder check
# -------------------
if [[ -d ${ppsc}/${grp}/${sbj} ]]; then
	printf "${GRN}[Unix]${RED} ID: ${grp}${sbj}${NCR} - Target folder exists, so the process will overwrite the files in the target folder.\n"
else
	printf "${GRN}[Unix]${RED} ID: ${grp}${sbj}${NCR} - Create a target folder.\n"
	mkdir -p ${ppsc}/${grp}/${sbj}
fi

# Temporary folder check
# ----------------------
if [[ -d ${tmp} ]]; then
	printf "${GRN}[Unix]${RED} ID: ${grp}${sbj}${NCR} - Temporary folder exists, so the process will overwrite the files in the target folder.\n"
else
	printf "${GRN}[Unix]${RED} ID: ${grp}${sbj}${NCR} - Create a temporary folder.\n"
	mkdir -p ${tmp}
fi

# Start the SC preprocessing
# --------------------------
startingtime=$(date +%s)
et=${ppsc}/${grp}/${sbj}/SC_pipeline_elapsedtime.txt
echo "[+] SC preprocessing with ${threads} thread(s) - $(date)" >> ${et}
echo "    Starting time in seconds ${startingtime}" >> ${et}

# Check T1-weighted image
# -----------------------
if [[ -f ${t1} ]]; then
	printf "${GRN}[T1-weighted]${RED} ID: ${grp}${sbj}${NCR} - Check file: ${t1}\n"
else
	printf "${RED}[T1-weighted]${RED} ID: ${grp}${sbj}${NCR} - There is not T1-weighted image!!! ${t1}\n"
	exit 1
fi

# Check Diffusion-weighted images
# -------------------------------
if [[ -f ${dwi} ]]; then
	printf "${GRN}[Diffusion-weighted]${RED} ID: ${grp}${sbj}${NCR} - Check file: ${dwi}\n"
else
	printf "${RED}[Diffusion-weighted]${RED} ID: ${grp}${sbj}${NCR} - There is not Diffusion-weighted image!!!\n"
	exit 1
fi

# Check a json file of DWIs
# -------------------------
if [[ -f ${dwi_json} ]]; then
	printf "${GRN}[Diffusion-weighted]${RED} ID: ${grp}${sbj}${NCR} - Check file: ${dwi_json}\n"
	printf "${GRN}[Diffusion-weighted]${RED} ID: ${grp}${sbj}${NCR} - The option 'pe_json' has been set as 'json'.\n"
	pe_json=json
else
	printf "${GRN}[Diffusion-weighted]${RED} ID: ${grp}${sbj}${NCR} - There is not a json file for diffusion-weighted image!!!\n"
	printf "${GRN}[Diffusion-weighted]${RED} ID: ${grp}${sbj}${NCR} - The option 'pe_json' has been set as 'none'.\n"
	pe_json=none
fi

# Bias-field correction for T1-weighted image before recon-all
# ------------------------------------------------------------
if [[ -f ${ppsc}/${grp}/${sbj}/t1w_bc.nii.gz ]]; then
	printf "${GRN}[ANTs]${RED} ID: ${grp}${sbj}${NCR} - Bias-field correction for T1-weighted image was already performed.\n"
else
	printf "${GRN}[ANTs]${RED} ID: ${grp}${sbj}${NCR} - Estimate bias-field of T1-weighted image.\n"
	
	# 4-time iterative bias-field corrections, because of the bright occipital lobe by very dark outside of the brain.
	# ----------------------------------------------------------------------------------------------------------------
	N4BiasFieldCorrection -i ${t1} -o [${ppsc}/${grp}/${sbj}/t1w_bc1.nii.gz,${ppsc}/${grp}/${sbj}/t1_bf1.nii.gz]
	N4BiasFieldCorrection -i ${ppsc}/${grp}/${sbj}/t1w_bc1.nii.gz -o [${ppsc}/${grp}/${sbj}/t1w_bc2.nii.gz,${ppsc}/${grp}/${sbj}/t1_bf2.nii.gz]
	N4BiasFieldCorrection -i ${ppsc}/${grp}/${sbj}/t1w_bc2.nii.gz -o [${ppsc}/${grp}/${sbj}/t1w_bc3.nii.gz,${ppsc}/${grp}/${sbj}/t1_bf3.nii.gz]
	N4BiasFieldCorrection -i ${ppsc}/${grp}/${sbj}/t1w_bc3.nii.gz -o [${ppsc}/${grp}/${sbj}/t1w_bc.nii.gz,${ppsc}/${grp}/${sbj}/t1_bf4.nii.gz]
	
	rm -f ${ppsc}/${grp}/${sbj}/t1w_bc1.nii.gz
	rm -f ${ppsc}/${grp}/${sbj}/t1w_bc2.nii.gz
	rm -f ${ppsc}/${grp}/${sbj}/t1w_bc3.nii.gz

	if [[ -f ${ppsc}/${grp}/${sbj}/t1w_bc.nii.gz ]]; then
		printf "${GRN}[ANTs]${RED} ID: ${grp}${sbj}${NCR} - ${ppsc}/${grp}/${sbj}/t1w_bc.nii.gz has been saved.\n"
	else
		printf "${GRN}[ANTs]${RED} ID: ${grp}${sbj}${NCR} - ${ppsc}/${grp}/${sbj}/t1w_bc.nii.gz has not been saved!!\n"
		exit 1
	fi

	# Elapsed time
	# ------------
	elapsedtime=$(($(date +%s) - ${startingtime}))
	printf "${GRN}[ANTs]${RED} ID: ${grp}${sbj}${NCR} - Elapsed time = ${elapsedtime} seconds.\n"
	echo "    ${elapsedtime} N4BiasFieldCorrection" >> ${et}
fi

# Check a subject directory for Freesurfing
# -----------------------------------------
if [[ -d ${fp}/${grp}_${sbj}/mri/orig ]]; then
	printf "${GRN}[Freesurfer]${RED} ID: ${grp}${sbj}${NCR} - The subject directory exists.\n"
else
	printf "${GRN}[Freesurfer]${RED} ID: ${grp}${sbj}${NCR} - Make a subject directory.\n"
	mkdir -p ${fp}/${grp}_${sbj}/mri/orig
fi

# AC-PC alignment
# ---------------
if [[ -f ${tmp}/t1w_acpc.nii.gz ]]; then
	printf "${GRN}[Freesurfer]${RED} ID: ${grp}${sbj}${NCR} - AC-PC aligned T1-weighted image exists!!!l.\n"
else
	printf "${GRN}[Freesurfer]${RED} ID: ${grp}${sbj}${NCR} - AC-PC align and convert T1-weighted image to mgz.\n"
	fslreorient2std ${ppsc}/${grp}/${sbj}/t1w_bc.nii.gz ${tmp}/t1w_bc_reori.nii.gz
	robustfov -i ${tmp}/t1w_bc_reori.nii.gz -b 170 -m ${tmp}/acpc_roi2full.mat -r ${tmp}/acpc_robustroi.nii.gz
	flirt -interp spline -in ${tmp}/acpc_robustroi.nii.gz -ref ${mni} -omat ${tmp}/acpc_roi2std.mat -out ${tmp}/acpc_roi2std.nii.gz -searchrx -30 30 -searchry -30 30 -searchrz -30 30
	convert_xfm -omat ${tmp}/acpc_full2roi.mat -inverse ${tmp}/acpc_roi2full.mat
	convert_xfm -omat ${tmp}/acpc_full2std.mat -concat ${tmp}/acpc_roi2std.mat ${tmp}/acpc_full2roi.mat
	aff2rigid ${tmp}/acpc_full2std.mat ${tmp}/acpc.mat
	applywarp --rel --interp=spline -i ${tmp}/t1w_bc_reori.nii.gz -r ${mni} --premat=${tmp}/acpc.mat -o ${tmp}/t1w_acpc.nii.gz
	if [[ -f ${tmp}/t1w_acpc.nii.gz ]]; then
		printf "${GRN}[FSL]${RED} ID: ${grp}${sbj}${NCR} - ${tmp}/t1w_acpc.nii.gz has been saved.\n"
	else
		printf "${GRN}[FSL]${RED} ID: ${grp}${sbj}${NCR} - ${tmp}/t1w_acpc.nii.gz has not been saved!!\n"
		exit 1
	fi	
fi

# Copy to the directory for recon-all
# -----------------------------------
if [[ -f ${fp}/${grp}_${sbj}/mri/orig/001.mgz ]]; then
	printf "${GRN}[Freesurfer]${RED} ID: ${grp}${sbj}${NCR} - The T1-weighted image exists in the subject directory for recon-all.\n"
else
	printf "${GRN}[Freesurfer]${RED} ID: ${grp}${sbj}${NCR} - Convert T1-weighted image to mgz.\n"
	mri_convert ${tmp}/t1w_acpc.nii.gz ${fp}/${grp}_${sbj}/mri/orig/001.mgz
fi

# Check recon-all by Freesurfer
# -----------------------------
if [[ -f ${fp}/${grp}_${sbj}/scripts/recon-all.done ]]; then
	printf "${GRN}[Freesurfer]${RED} ID: ${grp}${sbj}${NCR} - Freesurfer already preprocessed!!!\n"
else
	printf "${GRN}[Freesurfer]${RED} ID: ${grp}${sbj}${NCR} - Start recon-all.\n"
	recon-all -subjid ${grp}_${sbj} -all -noappend -no-isrunning -parallel -openmp ${threads} -sd ${fp}
	if [[ -f ${fp}/${grp}_${sbj}/scripts/recon-all.done ]]; then
		printf "${GRN}[MRtrix]${RED} ID: ${grp}${sbj}${NCR} - ${fp}/${grp}_${sbj}/scripts/recon-all.done has been saved.\n"
	else
		printf "${GRN}[MRtrix]${RED} ID: ${grp}${sbj}${NCR} - ${fp}/${grp}_${sbj}/scripts/recon-all.done has not been saved!!\n"
		exit 1
	fi

	# Elapsed time
	# ------------
	elapsedtime=$(($(date +%s) - ${startingtime}))
	printf "${GRN}[Freesurfer]${RED} ID: ${grp}${sbj}${NCR} - Elapsed time = ${elapsedtime} seconds.\n"
	echo "    ${elapsedtime} recon-all" >> ${et}
fi

# Check denoise of DWIs
# ---------------------
if [[ -f ${ppsc}/${grp}/${sbj}/dwi_denoise.nii.gz ]]; then
	printf "${GRN}[MRtrix]${RED} ID: ${grp}${sbj}${NCR} - Denoising of DWIs was already performed!!!\n"
else
	printf "${GRN}[MRtrix]${RED} ID: ${grp}${sbj}${NCR} - Start denoise.\n"
	dwidenoise ${dwi} ${ppsc}/${grp}/${sbj}/dwi_denoise.nii.gz -nthreads ${threads}
	if [[ -f ${ppsc}/${grp}/${sbj}/dwi_denoise.nii.gz ]]; then
		printf "${GRN}[MRtrix]${RED} ID: ${grp}${sbj}${NCR} - ${ppsc}/${grp}/${sbj}/dwi_denoise.nii.gz has been saved.\n"
	else
		printf "${GRN}[MRtrix]${RED} ID: ${grp}${sbj}${NCR} - ${ppsc}/${grp}/${sbj}/dwi_denoise.nii.gz has not been saved!!\n"
		exit 1
	fi

	# Elapsed time
	# ------------
	elapsedtime=$(($(date +%s) - ${startingtime}))
	printf "${GRN}[MRtrix]${RED} ID: ${grp}${sbj}${NCR} - Elapsed time = ${elapsedtime} seconds.\n"
	echo "    ${elapsedtime} dwidenoise" >> ${et}
fi

# Check degibbs of DWIs
# ---------------------
if [[ -f ${ppsc}/${grp}/${sbj}/dwi_denoise_degibbs.nii.gz ]]; then
	printf "${GRN}[MRtrix]${RED} ID: ${grp}${sbj}${NCR} - Degibbsing of DWIs was already performed!!!\n"
else
	printf "${GRN}[MRtrix]${RED} ID: ${grp}${sbj}${NCR} - Start degibbs.\n"
	mrdegibbs ${dwi} ${ppsc}/${grp}/${sbj}/dwi_denoise_degibbs.nii.gz -nthreads ${threads}
	if [[ -f ${ppsc}/${grp}/${sbj}/dwi_denoise_degibbs.nii.gz ]]; then
		printf "${GRN}[MRtrix]${RED} ID: ${grp}${sbj}${NCR} - ${ppsc}/${grp}/${sbj}/dwi_denoise_degibbs.nii.gz has been saved.\n"
	else
		printf "${GRN}[MRtrix]${RED} ID: ${grp}${sbj}${NCR} - ${ppsc}/${grp}/${sbj}/dwi_denoise_degibbs.nii.gz has not been saved!!\n"
		exit 1
	fi

	# Elapsed time
	# ------------
	elapsedtime=$(($(date +%s) - ${startingtime}))
	printf "${GRN}[MRtrix]${RED} ID: ${grp}${sbj}${NCR} - Elapsed time = ${elapsedtime} seconds.\n"
	echo "    ${elapsedtime} mrdegibbs" >> ${et}
fi

# Bias-field correction (DWIs)
# ----------------------------
if [[ -f ${ppsc}/${grp}/${sbj}/dwi_bc.nii.gz ]]; then
	printf "${GRN}[MRtrix & ANTs]${RED} ID: ${grp}${sbj}${NCR} - Bias-field correction was already performed!!!\n"
else
	printf "${GRN}[MRtrix & ANTs]${RED} ID: ${grp}${sbj}${NCR} - Estimate Bias-field (dwibiascorrect by ANTs).\n"
	dwibiascorrect ants -bias ${ppsc}/${grp}/${sbj}/dwi_biasfield.nii.gz -fslgrad ${bvec} ${bval} -nthreads ${threads} -force ${ppsc}/${grp}/${sbj}/dwi_denoise_degibbs.nii.gz ${ppsc}/${grp}/${sbj}/dwi_bc.nii.gz
	if [[ -f ${ppsc}/${grp}/${sbj}/dwi_bc.nii.gz ]]; then
		printf "${GRN}[MRtrix & ANTs]${RED} ID: ${grp}${sbj}${NCR} - ${ppsc}/${grp}/${sbj}/dwi_bc.nii.gz has been saved.\n"
	else
		printf "${GRN}[MRtrix & ANTs]${RED} ID: ${grp}${sbj}${NCR} - ${ppsc}/${grp}/${sbj}/dwi_bc.nii.gz has not been saved!!\n"
		exit 1
	fi

	# Elapsed time
	# ------------
	elapsedtime=$(($(date +%s) - ${startingtime}))
	printf "${GRN}[MRtrix & ANTs]${RED} ID: ${grp}${sbj}${NCR} - Elapsed time = ${elapsedtime} seconds.\n"
	echo "    ${elapsedtime} dwibiascorrect" >> ${et}
fi

# Eddy current correction, head motion correction, and b-vector rotation
# ----------------------------------------------------------------------
if [[ -f ${ppsc}/${grp}/${sbj}/dwi_bcecmc.nii.gz ]]; then
	printf "${GRN}[MRtrix & FSL]${RED} ID: ${grp}${sbj}${NCR} - DWIs preprocessing by eddy was already processed!!!\n"
else
	printf "${GRN}[MRtrix & FSL]${RED} ID: ${grp}${sbj}${NCR} - Start dwifslpreproc for head motion correction, b-vector rotation and eddy correction.\n"
	case ${pe_json} in
		json )
		dwifslpreproc ${ppsc}/${grp}/${sbj}/dwi_bc.nii.gz ${ppsc}/${grp}/${sbj}/dwi_bcecmc.nii.gz -fslgrad ${bvec} ${bval} -export_grad_fsl ${mc_bvec} ${mc_bval} -nthreads ${threads} -rpe_header -json_import ${dwi_json}
		;;
		none )
		dwifslpreproc ${ppsc}/${grp}/${sbj}/dwi_bc.nii.gz ${ppsc}/${grp}/${sbj}/dwi_bcecmc.nii.gz -fslgrad ${bvec} ${bval} -export_grad_fsl ${mc_bvec} ${mc_bval} -nthreads ${threads} -rpe_none -pe_dir ${pe_dir}
		;;
	esac
	if [[ -f ${ppsc}/${grp}/${sbj}/dwi_bcecmc.nii.gz ]]; then
		printf "${GRN}[MRtrix & FSL]${RED} ID: ${grp}${sbj}${NCR} - ${ppsc}/${grp}/${sbj}/dwi_bcecmc.nii.gz has been saved.\n"
	else
		printf "${GRN}[MRtrix & FSL]${RED} ID: ${grp}${sbj}${NCR} - ${ppsc}/${grp}/${sbj}/dwi_bcecmc.nii.gz has not been saved!!\n"
		exit 1
	fi

	# Elapsed time
	# ------------
	elapsedtime=$(($(date +%s) - ${startingtime}))
	printf "${GRN}[MRtrix]${RED} ID: ${grp}${sbj}${NCR} - Elapsed time = ${elapsedtime} seconds.\n"
	echo "    ${elapsedtime} dwifslpreproc" >> ${et}
fi

# Check dt_recon results
# ----------------------
# if [[ -f ${ppsc}/${grp}/${sbj}/dt_recon/dwi-ec.nii.gz ]]; then
# 	printf "${GRN}[Freesurfer]${RED} ID: ${grp}${sbj}${NCR} - DWIs preprocessing by dt_recon was already processed!!!\n"
# else
# 	printf "${GRN}[Freesurfer]${RED} ID: ${grp}${sbj}${NCR} - Start dt_recon.\n"
# 	dt_recon --i ${ppsc}/${grp}/${sbj}/dwi_bc.nii.gz --no-reg --no-tal --b ${bval} ${bvec} --s ${grp}_${sbj} --o ${ppsc}/${grp}/${sbj}/dt_recon --sd ${fp}
# 	if [[ -f ${ppsc}/${grp}/${sbj}/dt_recon/dwi-ec.nii.gz ]]; then
# 		printf "${GRN}[FSL Co-registration]${RED} ID: ${grp}${sbj}${NCR} - ${ppsc}/${grp}/${sbj}/dt_recon/dwi-ec.nii.gz has been saved.\n"
# 	else
# 		printf "${GRN}[FSL Co-registration]${RED} ID: ${grp}${sbj}${NCR} - ${ppsc}/${grp}/${sbj}/dt_recon/dwi-ec.nii.gz has not been saved!!\n"
# 		exit 1
# 	fi
#
# 	# Elapsed time
# 	# ------------
# 	elapsedtime=$(($(date +%s) - ${startingtime}))
# 	printf "${GRN}[Freesurfer]${RED} ID: ${grp}${sbj}${NCR} - Elapsed time = ${elapsedtime} seconds.\n"
# 	echo "    ${elapsedtime} dt_recon" >> ${et}
# fi

# Create brain masks on T1 space (Freesurfer output)
# --------------------------------------------------
if [[ -f ${tmp}/fs_t1_gmwm_mask.nii.gz ]]; then
	printf "${GRN}[FSL & Image processing]${RED} ID: ${grp}${sbj}${NCR} - Brain masks on T1 space (Freesurfer output) exist!!!\n"
else
	printf "${GRN}[FSL & Image processing]${RED} ID: ${grp}${sbj}${NCR} - Create brain masks on T1 space (Freesurfer output).\n"
	mri_convert ${fp}/${grp}_${sbj}/mri/aseg.mgz ${aseg}

	# White-matter mask with a neck
	# -----------------------------
	for i in 2 7 16 28 41 46 60 77 251 252 253 254 255
	do
		fslmaths ${aseg} -thr ${i} -uthr ${i} -bin ${tmp}/temp_roi_${i}.nii.gz
		if [[ ${i} = 2 ]]; then
			cp ${tmp}/temp_roi_${i}.nii.gz ${tmp}/temp_mask.nii.gz
		else
			fslmaths ${tmp}/temp_mask.nii.gz -add ${tmp}/temp_roi_${i}.nii.gz ${tmp}/temp_mask.nii.gz
		fi
	done
	fslmaths ${tmp}/temp_mask.nii.gz -bin ${tmp}/fs_t1_neck_wm_mask.nii.gz
	fslreorient2std ${tmp}/fs_t1_neck_wm_mask.nii.gz ${tmp}/fs_t1_neck_wm_mask.nii.gz
	if [[ -f ${tmp}/fs_t1_neck_wm_mask.nii.gz ]]; then
		printf "${GRN}[FSL Tissue masks]${RED} ID: ${grp}${sbj}${NCR} - ${tmp}/fs_t1_neck_wm_mask.nii.gz has been saved.\n"
	else
		printf "${GRN}[FSL Tissue masks]${RED} ID: ${grp}${sbj}${NCR} - ${tmp}/fs_t1_neck_wm_mask.nii.gz has not been saved!!\n"
		exit 1
	fi

	# White-matter
	# ------------
	fslmaths ${tmp}/temp_roi_2.nii.gz -add ${tmp}/temp_roi_41.nii.gz -add ${tmp}/temp_roi_77.nii.gz -add ${tmp}/temp_roi_251.nii.gz -add ${tmp}/temp_roi_252.nii.gz -add ${tmp}/temp_roi_253.nii.gz -add ${tmp}/temp_roi_254.nii.gz -add ${tmp}/temp_roi_255.nii.gz -bin ${tmp}/fs_t1_wm_mask.nii.gz
	fslreorient2std ${tmp}/fs_t1_wm_mask.nii.gz ${tmp}/fs_t1_wm_mask.nii.gz
	if [[ -f ${tmp}/fs_t1_wm_mask.nii.gz ]]; then
		printf "${GRN}[FSL Tissue masks]${RED} ID: ${grp}${sbj}${NCR} - ${tmp}/fs_t1_wm_mask.nii.gz has been saved.\n"
	else
		printf "${GRN}[FSL Tissue masks]${RED} ID: ${grp}${sbj}${NCR} - ${tmp}/fs_t1_wm_mask.nii.gz has not been saved!!\n"
		exit 1
	fi

	# Cortical mask
	# -------------
	for i in 3 8 42 47
	do
		fslmaths ${aseg} -thr ${i} -uthr ${i} -bin ${tmp}/temp_roi_${i}.nii.gz
		if [[ ${i} = 3 ]]; then
			cp ${tmp}/temp_roi_${i}.nii.gz ${tmp}/temp_mask.nii.gz
		else
			fslmaths ${tmp}/temp_mask.nii.gz -add ${tmp}/temp_roi_${i}.nii.gz ${tmp}/temp_mask.nii.gz
		fi
	done
	fslmaths ${tmp}/temp_mask.nii.gz -bin ${tmp}/fs_t1_ctx_mask.nii.gz
	fslreorient2std ${tmp}/fs_t1_ctx_mask.nii.gz ${tmp}/fs_t1_ctx_mask.nii.gz
	if [[ -f ${tmp}/fs_t1_ctx_mask.nii.gz ]]; then
		printf "${GRN}[FSL Tissue masks]${RED} ID: ${grp}${sbj}${NCR} - ${tmp}/fs_t1_ctx_mask.nii.gz has been saved.\n"
	else
		printf "${GRN}[FSL Tissue masks]${RED} ID: ${grp}${sbj}${NCR} - ${tmp}/fs_t1_ctx_mask.nii.gz has not been saved!!\n"
		exit 1
	fi

	# Subcortical mask
	# ----------------
	for i in 10 11 12 13 17 18 26 49 50 51 52 53 54 58
	do
		fslmaths ${aseg} -thr ${i} -uthr ${i} -bin ${tmp}/temp_roi_${i}.nii.gz
		if [[ ${i} = 10 ]]; then
			cp ${tmp}/temp_roi_${i}.nii.gz ${tmp}/temp_mask.nii.gz
		else
			fslmaths ${tmp}/temp_mask.nii.gz -add ${tmp}/temp_roi_${i}.nii.gz ${tmp}/temp_mask.nii.gz
		fi
	done
	fslmaths ${tmp}/temp_mask.nii.gz -bin ${tmp}/fs_t1_subctx_mask.nii.gz
	fslreorient2std ${tmp}/fs_t1_subctx_mask.nii.gz ${tmp}/fs_t1_subctx_mask.nii.gz
	if [[ -f ${tmp}/fs_t1_subctx_mask.nii.gz ]]; then
		printf "${GRN}[FSL Tissue masks]${RED} ID: ${grp}${sbj}${NCR} - ${tmp}/fs_t1_subctx_mask.nii.gz has been saved.\n"
	else
		printf "${GRN}[FSL Tissue masks]${RED} ID: ${grp}${sbj}${NCR} - ${tmp}/fs_t1_subctx_mask.nii.gz has not been saved!!\n"
		exit 1
	fi
	
	# Cerebrospinal fluid (CSF)
	# -------------------------
	for i in 4 5 14 15 24 31 43 44 63
	do
		fslmaths ${aseg} -thr ${i} -uthr ${i} -bin ${tmp}/temp_roi_${i}.nii.gz
		if [[ ${i} = 4 ]]; then
			cp ${tmp}/temp_roi_${i}.nii.gz ${tmp}/temp_mask.nii.gz
		else
			fslmaths ${tmp}/temp_mask.nii.gz -add ${tmp}/temp_roi_${i}.nii.gz ${tmp}/temp_mask.nii.gz
		fi
	done
	fslmaths ${tmp}/temp_mask.nii.gz -bin ${tmp}/fs_t1_csf_mask.nii.gz
	fslreorient2std ${tmp}/fs_t1_csf_mask.nii.gz ${tmp}/fs_t1_csf_mask.nii.gz
	if [[ -f ${tmp}/fs_t1_csf_mask.nii.gz ]]; then
		printf "${GRN}[FSL Tissue masks]${RED} ID: ${grp}${sbj}${NCR} - ${tmp}/fs_t1_csf_mask.nii.gz has been saved.\n"
	else
		printf "${GRN}[FSL Tissue masks]${RED} ID: ${grp}${sbj}${NCR} - ${tmp}/fs_t1_csf_mask.nii.gz has not been saved!!\n"
		exit 1
	fi

	# Brain-tissue
	# ------------
	fslmaths ${tmp}/fs_t1_ctx_mask.nii.gz -add ${tmp}/fs_t1_subctx_mask.nii.gz -bin ${tmp}/fs_t1_neck_gm_mask.nii.gz
	fslmaths ${tmp}/fs_t1_neck_gm_mask.nii.gz -add ${tmp}/fs_t1_neck_wm_mask.nii.gz -bin ${tmp}/fs_t1_gmwm_mask.nii.gz
	if [[ -f ${tmp}/fs_t1_gmwm_mask.nii.gz ]]; then
		printf "${GRN}[FSL Tissue masks]${RED} ID: ${grp}${sbj}${NCR} - ${tmp}/fs_t1_gmwm_mask.nii.gz has been saved.\n"
	else
		printf "${GRN}[FSL Tissue masks]${RED} ID: ${grp}${sbj}${NCR} - ${tmp}/fs_t1_gmwm_mask.nii.gz has not been saved!!\n"
		exit 1
	fi

	# Elapsed time
	# ------------
	elapsedtime=$(($(date +%s) - ${startingtime}))
	printf "${GRN}[FSL]${RED} ID: ${grp}${sbj}${NCR} - Elapsed time = ${elapsedtime} seconds.\n"
	echo "    ${elapsedtime} Creating tissue masks" >> ${et}
fi

# Averaged DWIs
# -------------
if [[ -f ${ppsc}/${grp}/${sbj}/dwi_bcecmc_avg.nii.gz ]]; then
	printf "${GRN}[MRtrix & FSL]${RED} ID: ${grp}${sbj}${NCR} - An averaged DWI was already created!!!\n"
else
	printf "${GRN}[MRtrix & FSL]${RED} ID: ${grp}${sbj}${NCR} - Make an averaged DWI.\n"
	dwiextract -shells ${non_zero_shells} -fslgrad ${mc_bvec} ${mc_bval} -nthreads ${threads} ${ppsc}/${grp}/${sbj}/dwi_bcecmc.nii.gz ${ppsc}/${grp}/${sbj}/dwi_nonzero_bval.nii.gz
	fslmaths ${ppsc}/${grp}/${sbj}/dwi_nonzero_bval.nii.gz -Tmean ${ppsc}/${grp}/${sbj}/dwi_bcecmc_avg.nii.gz
fi

# Co-registration (from T1WI to averaged DWI)
# -------------------------------------------
if [[ -f ${ppsc}/${grp}/${sbj}/fs_t1_to_dwi.nii.gz ]]; then
	printf "${GRN}[FSL]${RED} ID: ${grp}${sbj}${NCR} - Coregistration from T1WI in Freesurfer to DWI space was already performed!!!\n"
else
	printf "${GRN}[FSL]${RED} ID: ${grp}${sbj}${NCR} - Start coregistration.\n"
	mri_convert ${fp}/${grp}_${sbj}/mri/nu.mgz ${tmp}/fs_t1.nii.gz
	fslreorient2std ${tmp}/fs_t1.nii.gz ${tmp}/fs_t1.nii.gz

	# Dilate the brain-tissue mask
	# ----------------------------
	mri_binarize --i ${tmp}/fs_t1_gmwm_mask.nii.gz --min 0.5 --max 1.5 --dilate 20 --o ${tmp}/fs_t1_gmwm_mask_dilate.nii.gz
	fslmaths ${tmp}/fs_t1.nii.gz -mas ${tmp}/fs_t1_gmwm_mask_dilate.nii.gz ${ppsc}/${grp}/${sbj}/fs_t1.nii.gz
	fslmaths ${tmp}/fs_t1.nii.gz -mas ${tmp}/fs_t1_gmwm_mask.nii.gz ${ppsc}/${grp}/${sbj}/fs_t1_brain.nii.gz

	# Linear registration
	# -------------------
	flirt -in ${ppsc}/${grp}/${sbj}/dwi_bcecmc_avg.nii.gz -ref ${ppsc}/${grp}/${sbj}/fs_t1_brain.nii.gz -out ${ppsc}/${grp}/${sbj}/dwi_to_fs_t1_affine.nii.gz -omat ${ppsc}/${grp}/${sbj}/dwi_to_fs_t1_affine.mat -dof ${coreg_flirt_dof} -cost ${coreg_flirt_cost}
	convert_xfm -omat ${ppsc}/${grp}/${sbj}/dwi_to_fs_t1_invaffine.mat -inverse ${ppsc}/${grp}/${sbj}/dwi_to_fs_t1_affine.mat
	applywarp -i ${ppsc}/${grp}/${sbj}/fs_t1.nii.gz -r ${ppsc}/${grp}/${sbj}/dwi_bcecmc_avg.nii.gz -o ${ppsc}/${grp}/${sbj}/fs_t1_to_dwi.nii.gz --premat=${ppsc}/${grp}/${sbj}/dwi_to_fs_t1_invaffine.mat
	applywarp -i ${ppsc}/${grp}/${sbj}/fs_t1_brain.nii.gz -r ${ppsc}/${grp}/${sbj}/dwi_bcecmc_avg.nii.gz -o ${ppsc}/${grp}/${sbj}/fs_t1_brain_to_dwi.nii.gz --premat=${ppsc}/${grp}/${sbj}/dwi_to_fs_t1_invaffine.mat
	if [[ -f ${ppsc}/${grp}/${sbj}/fs_t1_to_dwi.nii.gz ]]; then
		printf "${GRN}[FSL Co-registration]${RED} ID: ${grp}${sbj}${NCR} - ${ppsc}/${grp}/${sbj}/fs_t1_to_dwi.nii.gz has been saved.\n"
	else
		printf "${GRN}[FSL Co-registration]${RED} ID: ${grp}${sbj}${NCR} - ${ppsc}/${grp}/${sbj}/fs_t1_to_dwi.nii.gz has not been saved!!\n"
		exit 1
	fi

	# Elapsed time
	# ------------
	elapsedtime=$(($(date +%s) - ${startingtime}))
	printf "${GRN}[FSL]${RED} ID: ${grp}${sbj}${NCR} - Elapsed time = ${elapsedtime} seconds.\n"
	echo "    ${elapsedtime} Co-registration" >> ${et}
fi

# Registration from MNI space to DWI space
# ----------------------------------------
if [[ -f ${ppsc}/${grp}/${sbj}/mni_to_dwi.nii.gz ]]; then
	printf "${GRN}[FSL]${RED} ID: ${grp}${sbj}${NCR} - Registration from MNI to DWI space was already performed!!!\n"
else
	printf "${GRN}[FSL]${RED} ID: ${grp}${sbj}${NCR} - Start registration from MNI to T1WI space.\n"
	
	# From T1 (Freesurfer) to MNI152 1mm
	# ----------------------------------
	flirt -ref ${mni_brain} -in ${ppsc}/${grp}/${sbj}/fs_t1_brain.nii.gz -omat ${ppsc}/${grp}/${sbj}/fs_t1_to_mni_affine.mat -dof ${reg_flirt_dof}
	fnirt --in=${ppsc}/${grp}/${sbj}/fs_t1_brain.nii.gz --aff=${ppsc}/${grp}/${sbj}/fs_t1_to_mni_affine.mat --cout=${ppsc}/${grp}/${sbj}/fs_t1_to_mni_warp_struct.nii.gz --config=T1_2_MNI152_2mm
	
	# From MNI152 1mm to T1 (Freesurfer) - inverse
	# --------------------------------------------
	invwarp --ref=${ppsc}/${grp}/${sbj}/fs_t1_brain.nii.gz --warp=${ppsc}/${grp}/${sbj}/fs_t1_to_mni_warp_struct.nii.gz --out=${ppsc}/${grp}/${sbj}/mni_to_fs_t1_warp_struct.nii.gz
	applywarp --ref=${ppsc}/${grp}/${sbj}/fs_t1_brain.nii.gz --in=${mni_brain} --warp=${ppsc}/${grp}/${sbj}/mni_to_fs_t1_warp_struct.nii.gz --out=${ppsc}/${grp}/${sbj}/mni_brain_to_fs_t1.nii.gz --interp=${reg_fnirt_interp}
	applywarp --ref=${ppsc}/${grp}/${sbj}/fs_t1_brain.nii.gz --in=${mni} --warp=${ppsc}/${grp}/${sbj}/mni_to_fs_t1_warp_struct.nii.gz --out=${ppsc}/${grp}/${sbj}/mni_to_fs_t1.nii.gz --interp=${reg_fnirt_interp}

	# Rigid transform from T1 (Freesurfer) to DWI space
	# -------------------------------------------------
	printf "${GRN}[FSL]${RED} ID: ${grp}${sbj}${NCR} - Start registration from MNI to DWI space.\n"
	applywarp -i ${ppsc}/${grp}/${sbj}/mni_to_fs_t1.nii.gz -r ${ppsc}/${grp}/${sbj}/dwi_bcecmc_avg.nii.gz -o ${ppsc}/${grp}/${sbj}/mni_to_dwi.nii.gz --premat=${ppsc}/${grp}/${sbj}/dwi_to_fs_t1_invaffine.mat
	applywarp -i ${ppsc}/${grp}/${sbj}/mni_brain_to_fs_t1.nii.gz -r ${ppsc}/${grp}/${sbj}/dwi_bcecmc_avg.nii.gz -o ${ppsc}/${grp}/${sbj}/mni_brain_to_dwi.nii.gz --premat=${ppsc}/${grp}/${sbj}/dwi_to_fs_t1_invaffine.mat
	if [[ -f ${ppsc}/${grp}/${sbj}/mni_to_dwi.nii.gz ]]; then
		printf "${GRN}[FSL Non-linear registration]${RED} ID: ${grp}${sbj}${NCR} - ${ppsc}/${grp}/${sbj}/mni_to_dwi.nii.gz has been saved.\n"
	else
		printf "${GRN}[FSL Non-linear registration]${RED} ID: ${grp}${sbj}${NCR} - ${ppsc}/${grp}/${sbj}/mni_to_dwi.nii.gz has not been saved!!\n"
		exit 1
	fi

	# Elapsed time
	# ------------
	elapsedtime=$(($(date +%s) - ${startingtime}))
	printf "${GRN}[FSL]${RED} ID: ${grp}${sbj}${NCR} - Elapsed time = ${elapsedtime} seconds.\n"
	echo "    ${elapsedtime} Non-linear registration" >> ${et}
fi

# Transform tissue masks (from aseg.mgz) to the diffusion space
# -------------------------------------------------------------
if [[ -f ${ppsc}/${grp}/${sbj}/dwi_bcecmc_avg_bet_mask.nii.gz ]]; then
	printf "${GRN}[FSL & Image processing]${RED} ID: ${grp}${sbj}${NCR} - A cortical mask of Destrieux in Freesurfer exists!!!\n"
else
	printf "${GRN}[FSL & Image processing]${RED} ID: ${grp}${sbj}${NCR} - Make a cortical mask of Destrieux in Freesurfer.\n"

	# Cortical gray-matter mask (Cerebrum + Cerebellum)
	# -------------------------------------------------
	applywarp -i ${tmp}/fs_t1_ctx_mask.nii.gz -r ${ppsc}/${grp}/${sbj}/dwi_bcecmc_avg.nii.gz -o ${ctx} --premat=${ppsc}/${grp}/${sbj}/dwi_to_fs_t1_invaffine.mat
	fslmaths ${ctx} -thr 0.5 -bin ${ctx}
	if [[ -f ${ctx} ]]; then
		printf "${GRN}[FSL & Image processing]${RED} ID: ${grp}${sbj}${NCR} - ${ctx} has been saved.\n"
	else
		printf "${GRN}[FSL & Image processing]${RED} ID: ${grp}${sbj}${NCR} - ${ctx} has not been saved!!\n"
		exit 1
	fi

	# Gray-matter mask (Cortex + Subcortical areas)
	# ---------------------------------------------
	applywarp -i ${tmp}/fs_t1_neck_gm_mask.nii.gz -r ${ppsc}/${grp}/${sbj}/dwi_bcecmc_avg.nii.gz -o ${gmneck} --premat=${ppsc}/${grp}/${sbj}/dwi_to_fs_t1_invaffine.mat
	fslmaths ${gmneck} -thr 0.5 -bin ${gmneck}
	if [[ -f ${gmneck} ]]; then
		printf "${GRN}[FSL & Image processing]${RED} ID: ${grp}${sbj}${NCR} - ${gmneck} has been saved.\n"
	else
		printf "${GRN}[FSL & Image processing]${RED} ID: ${grp}${sbj}${NCR} - ${gmneck} has not been saved!!\n"
		exit 1
	fi

	# White-matter
	# ------------
	applywarp -i ${tmp}/fs_t1_wm_mask.nii.gz -r ${ppsc}/${grp}/${sbj}/dwi_bcecmc_avg.nii.gz -o ${wm} --premat=${ppsc}/${grp}/${sbj}/dwi_to_fs_t1_invaffine.mat
	fslmaths ${wm} -thr 0.5 -bin ${wm}
	if [[ -f ${wm} ]]; then
		printf "${GRN}[FSL & Image processing]${RED} ID: ${grp}${sbj}${NCR} - ${wm} has been saved.\n"
	else
		printf "${GRN}[FSL & Image processing]${RED} ID: ${grp}${sbj}${NCR} - ${wm} has not been saved!!\n"
		exit 1
	fi

	# White-matter with a neck
	# ------------------------
	applywarp -i ${tmp}/fs_t1_neck_wm_mask.nii.gz -r ${ppsc}/${grp}/${sbj}/dwi_bcecmc_avg.nii.gz -o ${wmneck} --premat=${ppsc}/${grp}/${sbj}/dwi_to_fs_t1_invaffine.mat
	fslmaths ${wmneck} -thr 0.5 -bin ${wmneck}
	if [[ -f ${wmneck} ]]; then
		printf "${GRN}[FSL & Image processing]${RED} ID: ${grp}${sbj}${NCR} - ${wmneck} has been saved.\n"
	else
		printf "${GRN}[FSL & Image processing]${RED} ID: ${grp}${sbj}${NCR} - ${wmneck} has not been saved!!\n"
		exit 1
	fi

	# Subcortical areas
	# -----------------
	applywarp -i ${tmp}/fs_t1_subctx_mask.nii.gz -r ${ppsc}/${grp}/${sbj}/dwi_bcecmc_avg.nii.gz -o ${sub} --premat=${ppsc}/${grp}/${sbj}/dwi_to_fs_t1_invaffine.mat
	fslmaths ${sub} -thr 0.5 -bin ${sub}
	if [[ -f ${sub} ]]; then
		printf "${GRN}[FSL & Image processing]${RED} ID: ${grp}${sbj}${NCR} - ${sub} has been saved.\n"
	else
		printf "${GRN}[FSL & Image processing]${RED} ID: ${grp}${sbj}${NCR} - ${sub} has not been saved!!\n"
		exit 1
	fi

	# Cerebrospinal fluid (CSF)
	# -------------------------
	applywarp -i ${tmp}/fs_t1_csf_mask.nii.gz -r ${ppsc}/${grp}/${sbj}/dwi_bcecmc_avg.nii.gz -o ${csf} --premat=${ppsc}/${grp}/${sbj}/dwi_to_fs_t1_invaffine.mat
	fslmaths ${csf} -thr 0.5 -bin ${csf}
	if [[ -f ${csf} ]]; then
		printf "${GRN}[FSL & Image processing]${RED} ID: ${grp}${sbj}${NCR} - ${csf} has been saved.\n"
	else
		printf "${GRN}[FSL & Image processing]${RED} ID: ${grp}${sbj}${NCR} - ${csf} has not been saved!!\n"
		exit 1
	fi

	# Brain extraction mask (BET)
	# ---------------------------
	applywarp -i ${tmp}/fs_t1_gmwm_mask.nii.gz -r ${ppsc}/${grp}/${sbj}/dwi_bcecmc_avg.nii.gz -o ${ppsc}/${grp}/${sbj}/dwi_bcecmc_avg_bet_mask.nii.gz --premat=${ppsc}/${grp}/${sbj}/dwi_to_fs_t1_invaffine.mat
	fslmaths ${ppsc}/${grp}/${sbj}/dwi_bcecmc_avg_bet_mask.nii.gz -thr 0.5 -bin ${ppsc}/${grp}/${sbj}/dwi_bcecmc_avg_bet_mask.nii.gz
	if [[ -f ${ppsc}/${grp}/${sbj}/dwi_bcecmc_avg_bet_mask.nii.gz ]]; then
		printf "${GRN}[FSL & Image processing]${RED} ID: ${grp}${sbj}${NCR} - ${ppsc}/${grp}/${sbj}/dwi_bcecmc_avg_bet_mask.nii.gz has been saved.\n"
	else
		printf "${GRN}[FSL & Image processing]${RED} ID: ${grp}${sbj}${NCR} - ${ppsc}/${grp}/${sbj}/dwi_bcecmc_avg_bet_mask.nii.gz has not been saved!!\n"
		exit 1
	fi

	# Clear temporary files
	# ---------------------
	rm -f ${tmp}/temp_*.nii.gz

	# Elapsed time
	# ------------
	elapsedtime=$(($(date +%s) - ${startingtime}))
	printf "${GRN}[FSL]${RED} ID: ${grp}${sbj}${NCR} - Elapsed time = ${elapsedtime} seconds.\n"
	echo "    ${elapsedtime} Cortical masks" >> ${et}
fi

# Make 5TT (Five-type tissues)
# ----------------------------
if [[ -f ${ftt} ]]; then
	printf "${GRN}[FSL & Image processing]${RED} ID: ${grp}${sbj}${NCR} - 5TT image exists!!!\n"
else
	printf "${GRN}[FSL & Image processing]${RED} ID: ${grp}${sbj}${NCR} - Make a 5TT image.\n"
	cp ${csf} ${tmp}/temp.nii.gz
	fslmaths ${tmp}/temp.nii.gz -mul 0 -bin ${tmp}/temp.nii.gz
	fslmerge -t ${ppsc}/${grp}/${sbj}/5tt_xsub.nii.gz ${ctx} ${tmp}/temp.nii.gz ${wmneck} ${csf} ${tmp}/temp.nii.gz
	fslmerge -t ${ftt} ${ctx} ${sub} ${wmneck} ${csf} ${tmp}/temp.nii.gz
	if [[ -f ${ftt} ]]; then
		printf "${GRN}[FSL & Image processing]${RED} ID: ${grp}${sbj}${NCR} - ${ftt} has been saved.\n"
	else
		printf "${GRN}[FSL & Image processing]${RED} ID: ${grp}${sbj}${NCR} - ${ftt} has not been saved!!\n"
		exit 1
	fi
	rm -f ${tmp}/temp.nii.gz

	# Elapsed time
	# ------------
	elapsedtime=$(($(date +%s) - ${startingtime}))
	printf "${GRN}[FSL]${RED} ID: ${grp}${sbj}${NCR} - Elapsed time = ${elapsedtime} seconds.\n"
	echo "    ${elapsedtime} 5-tissue type images" >> ${et}
fi

echo "[-] SC preprocessing - $(date)" >> ${et}
