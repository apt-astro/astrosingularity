#!/bin/bash
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --time=120:00:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=EMAIL
#^^^Please enter your own email address here if you wish to be notified when the pipeline run ends, otherwise delete the lines containing "--mail-type" and "--mail-user"

#####################################################################################################################################################
#                                                        EDITABLE PARAMETERS BELOW
#                                                                  ******
#      [1] user: your JBO Linux username
#      [2] PROJECT: a string describing this observing run, in the format CYXXXX_YYY_ZZZZZZZZ, for project code CYXXXX, run YYY on date ZZZZZZZZ
#      [3] INPUTFILE: path to a valid inputs.ini file. If none is given, or if this points to a non-existent file then the pipeline will *only* run
#          the pre_processing step *regardless* of what value is given for STEPS below
#      [4] DATAIN: path to inputs FITS directory. Any user flag commands should be placed here, as should your default_params.json file (if you 
#          wish to use something other than the observatory defaults). Processed data will be written back here.
#      [5] STEPS: which pipeline steps to run, e.g. pre_processing, calibration, all, etc. Note that if no inputs.ini is given in [3], then *only* 
#          pre_processing is run, *regardless* of what is set here.
#                                                                  ******
#      For further details on the pipeline, see https://github.com/e-merlin/eMERLIN_CASA_pipeline
#######################################################################################################################################################
export user=USERID
export PROJECT=PROJID
export DATAIN=DATADIR
export DATAOUT="$DATAIN"
export STEPS=all #Usual parameter to determine which pipeline steps to run, e.g. all, pre_processing, calibration, etc. Currently only "all" is supported
export MAKEWIDEFIELD=True #Image the primary beam using wsclean

#Execute the pipeline using these input parameters
bash $HOME/scripts/pipe_galahad.bash
