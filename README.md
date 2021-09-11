# Containerized structural connectivity (SC) pipeline

## REQUIREMENTS

1. To use the containerized SC pipeline, please install 'singularity' on your computing system: https://sylabs.io/guides/3.3/user-guide/installation.html

2. This pipeline uses Freesurfer. If you do not have a license, please register for Freesurfer: https://surfer.nmr.mgh.harvard.edu/registration.html

3. Essential files

- `code/Singularity`: Recipe file to be used with `singularity build` to generate a container image
- `code/input.txt`: Example pipeline parameter specification
- `code/container_SC_pipeline_JURECA.sh`: Example SLURM submission scripts for the JURECA HPC system

## INSTRUCTION

### 1. ARGUMENTS

There are three main paths for this pipeline: working path, raw data path, and target (result) path. These paths have to be specified by the end-users based on their own computing system.

The containerized SC pipeline consists of 4 modules: preprocessing, tractography, atlas transformation, and reconstruction. The containerized SC pipeline uses 2 arguments (module script and input file) as below.

    singularity exec --bind /mount/path:/mnt_sc Container_dwMRI.simg /usr/local/bin/container_SC_pipeline.sh /mnt_sc/working/path/input.txt

You can also run a sigle module as below.

    singularity exec --bind /mount/path:/mnt_sc Container_dwMRI.simg /usr/local/bin/container_SC_preprocess.sh /mnt_sc/working/path/input.txt
    singularity exec --bind /mount/path:/mnt_sc Container_dwMRI.simg /usr/local/bin/container_SC_tractography.sh /mnt_sc/working/path/input.txt
    singularity exec --bind /mount/path:/mnt_sc Container_dwMRI.simg /usr/local/bin/container_SC_atlas_transformation.sh /mnt_sc/working/path/input.txt
    singularity exec --bind /mount/path:/mnt_sc Container_dwMRI.simg /usr/local/bin/container_SC_reconstruct.sh /mnt_sc/working/path/input.txt

The first argument specifies a module script and the second argument specifies an input file of it.

### 2. INPUT

An example of an input text file is the following.

    # Freesurfer license
    # ------------------
    email=end.user@your-institute.de
    digit=xxxxx
    line1=xxxxxxxxxxxxx
    line2=xxxxxxxxxxxxx

    # Input variables
    # ---------------
    grp=INM                                 # Name of dataset
    tract=100000                            # Total number of streamlines for whole-brain tractography
    atlname=atlas_prefix                    # Name of atlas for prefixing results
    numparc=100                             # Total number of regions in a given atlas
    shells=0,1000,2000,3000                 # shells=0,1000,2000,3000 for HCP dwMRI, i.e., b-values
    non_zero_shells=1000,2000,3000          # shells=1000,2000,3000 for HCP dwMRI

    # Paths setting
    # -------------
    tp=/mnt_tp                                                  # Target (result) path
    sp=/mnt_sp                                                  # Source (raw) data path
    fp=/mnt_fp                                                  # Subject's path for freesurfer
    ap=/mnt_ap                                                  # Atlas path
    atlas=atlas.nii.gz                                          # Atlas on the MNI 1mm space (6th generation in FSL)
    mni=/usr/share/fsl/5.0/data/standard/MNI152_T1_1mm.nii.gz   # Standard template for registration

The parameters can be modified by the end-users. For licensing Freesurfer, they should get a license code via a registration with a license agreement and put the license code in the input text file. Input files should be prepared for each subject and each condition. For example, a process of 8 subjects with 2 conditions needs 16 input text files. All input text files should be in the working path, 'wp=/mount/path/to/scripts'.

### 3. DATA STRUCTURE

The raw data path should have a data structure (BIDS) as below (in case of /mnt_sp=/path/to/DATA_DIR, grp=INM-BIDS, and sbj=sub-01).

    /mnt_sp/INM-BIDS/sub-01/anat/sub-01_T1w.json
    /mnt_sp/INM-BIDS/sub-01/anat/sub-01_T1w.nii.gz
    /mnt_sp/INM-BIDS/sub-01/dwi/sub-01_dwi.bval
    /mnt_sp/INM-BIDS/sub-01/dwi/sub-01_dwi.bvec
    /mnt_sp/INM-BIDS/sub-01/dwi/sub-01_dwi.json
    /mnt_sp/INM-BIDS/sub-01/dwi/sub-01_dwi.nii.gz
    
    DATA_DIR (/mnt_sp)
    ├── INM-BIDS
    │   ├── sub-01
    │   │   ├── anat
    │   │   │   ├── sub-01_T1w.json
    │   │   │   └── sub-01_T1w.nii.gz
    │   │   ├── dwi
    │   │   │   ├── sub-01_dwi.bval
    │   │   │   ├── sub-01_dwi.bvec
    │   │   │   ├── sub-01_dwi.json
    │   │   │   └── sub-01_dwi.nii.gz
    .   .   .
    .   .   .
    .   .   .

### 4. EXAMPLE SCRIPT FOR THE CONDOR

    #!/bin/bash

    CPUS='2'
    RAM='8G'
    DISK='90G'
    LOGS_DIR='/path/to/condor/logs/directory'
    VBC_DWMRI='/path/to/container/Container_SC_pipeline.simg'
    DATA_DIR='/path/to/data/directory/prior/to/BIDS'
    ATLAS_DIR='/path/to/atlas/directory'
    OUTPUT_DIR='/path/to/output/directory'
    FREESURFER_OUTPUT='/path/to/freesurfer/subjects/directory'
    FREESURFER_LICENSE='/opt/freesurfer/6.0/license.txt'
    INPUT_PARAMETERS='/path/to/input/text/file'

    # create the logs dir if it doesn't exist
    [ ! -d "${LOGS_DIR}" ] && mkdir -p "${LOGS_DIR}"

    # print the .submit header
    printf "# The environment
    universe       = vanilla
    getenv         = True
    request_cpus   = ${CPUS}
    request_memory = ${RAM}
    request_disk   = ${DISK}

    # Execution
    initial_dir    = \$ENV(HOME)/htcondor-templates/vbc_dwmri
    executable     = /usr/bin/singularity
    \n"

    # loop over all subjects
    for sub in 110411; do
        printf "arguments = exec --cleanenv \
                            -B ${DATA_DIR}:/mnt_sp,${OUTPUT_DIR}:/mnt_tp,${FREESURFER_OUTPUT}:/mnt_fp,${ATLAS_DIR}:/mnt_ap,${FREESURFER_LICENSE}:/opt/freesurfer/license.txt,${INPUT_PARAMETERS}:/opt/input.txt \
                            ${VBC_DWMRI} \
                            /usr/local/bin/container_SC_pipeline.sh \
                            /opt/input.txt \
                            ${CPUS} \
                            ${sub}\n"
        printf "log       = ${LOGS_DIR}/\$(Cluster).\$(Process).${sub}.log\n"
        printf "output    = ${LOGS_DIR}/\$(Cluster).\$(Process).${sub}.out\n"
        printf "error     = ${LOGS_DIR}/\$(Cluster).\$(Process).${sub}.err\n"
        printf "Queue\n\n"
    done

### 5. EXAMPLE SCRIPT FOR THE SLURM

Based on the optimized configuration for the containerized SC pipeline on JURECA at Forschungszentrum Jülich, we provide a script to run the SC pipeline, container_SC_pipeline_JURECA.sh. With a modification of three lines in it, you can use the script on JURECA. This script uses 9 arguments: a module name, 8 subject IDs.

    simg_path=/path/to/container/Container_dwMRI.simg
    wp=/mnt_sc/path/to/scripts
    mnt=/local/path/to/mount

The following example is a script for the slurm system on JURECA. You can copy the following lines and create a file for 'sbatch', for instance, 'run_sc_pipeline.sbatch', then execute like this, 'sbatch run_sc_pipeline.sbatch'.

Prepare 8 input files for each subject in the working path (wp=/mnt_sc/path/to/scripts) as below.

    input_sub-01.txt
    input_sub-02.txt
    input_sub-03.txt
    input_sub-04.txt
    input_sub-05.txt
    input_sub-06.txt
    input_sub-07.txt
    input_sub-08.txt

Then, make a script for 'sbatch' as below.

    #!/bin/bash
    #SBATCH -J SC_pipeline
    #SBATCH -o slurm_logs/SC_pipeline-out.%j
    #SBATCH -e slurm_logs/SC_pipeline-err.%j
    #SBATCH -A ${project_account}
    #SBATCH --nodes=1
    #SBATCH --time=16:00:00
    #SBATCH --mail-user=end.user@your-institute.de
    #SBATCH --mail-type=All
    #SBATCH --partition=batch
    
    bash container_SC_pipeline_JURECA.sh Preprocess sub-01 sub-02 sub-03 sub-04 sub-05 sub-06 sub-07 sub-08
    wait
    
    bash container_SC_pipeline_JURECA.sh Tractography sub-01 sub-02 sub-03 sub-04 sub-05 sub-06 sub-07 sub-08
    wait
    
    bash container_SC_pipeline_JURECA.sh Atlas_transformation sub-01 sub-02 sub-03 sub-04 sub-05 sub-06 sub-07 sub-08
    wait
    
    bash container_SC_pipeline_JURECA.sh Reconstruction sub-01 sub-02 sub-03 sub-04 sub-05 sub-06 sub-07 sub-08
    wait

Each module can perform independently. For instance, if the preprocessing module was already performed for considered subjects, then you can continue to perform on the tractography module for the given subjects. An advanced version will have more parameters such as tracking algorithms, tracking steps, tracking angles, and so forth.

## TROUBLESHOOT

If you have a problem to use the containerized SC pipeline. Please contact Kyesam Jung (k.jung@fz-juelich.de).

## Acknowledgements

This development was supported by European Union’s Horizon 2020 research and innovation programme under grant agreement [VirtualBrainCloud (H2020-EU.3.1.5.3, grant no. 826421)](https://cordis.europa.eu/project/id/826421).
