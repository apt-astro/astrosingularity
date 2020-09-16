#!/bin/bash
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --time=120:00:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=MYEMAIL
#^^^Please enter your own email address here instead of "MYEMAIL" if you wish to be notified when the pipeline run ends,
# otherwise delete the lines containing "--mail-type" and "--mail-user"

#####################################################################################################################################################
#                                                        EDITABLE PARAMETERS BELOW
#                                                                  ******
#      [1] user: your JBO Linux username
#      [2] PROJECT: a string describing this observing run, in the format CYXXXX_YYY_ZZZZZZZZ, for project code CYXXXX, run YYY on date ZZZZZZZZ
#      [3] DATAIN: path to inputs FITS directory. Any user flag commands should be placed here, as should your default_params.json file (if you 
#          wish to use something other than the observatory defaults). Processed data will be written back here by default.
#      [4] DATAOUT: if you wish to write the data out to a directory other than "DATAIN" this can be specified here (experimental)
#      [5] STEPS: which pipeline steps to run, e.g. pre_processing, calibration, all, etc. Currently only "ALL" is fully debugged.
#      [6] MAKEWIDEFIELD: True/False. Determines whether or not to use WSCLEAN to map the primary beam of each of the target fields in the observation.
#                                                                  ******
#      For further details on the pipeline, see https://github.com/e-merlin/eMERLIN_CASA_pipeline
#######################################################################################################################################################
export user=USERID
export PROJECT=PROJID
export DATAIN=DATADIR
export DATAOUT="$DATAIN"
export STEPS=all #Usual parameter to determine which pipeline steps to run, e.g. all, pre_processing, calibration, etc. Currently only "all" is supported
export MAKEWIDEFIELD=True #Image the target field out to the primary beam using wsclean
export IMAGECALIBRATORS=False #Image the calibrator sources

#Execute the pipeline using these input parameters
#(DO NOT EDIT BELOW THIS LINE)
bash $HOME/scripts/pipe_galahad.bash
