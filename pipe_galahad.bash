export PIPELINEVER=/share/nas/emadmin/Pipeline/eMERLIN_CASA_pipeline_080620.img

ulimit
echo "This is SLURM job ID $SLURM_JOB_ID"
echo "With SLURM job name $SLURM_JOB_NAME"
echo ""
echo "This job was started by $user at "
date

echo "Source user .login or .bashrc if they exist:"
if [ -f "$HOME/.bashrc" ]; then
    echo "Sourcing bashrc:"
    source $HOME/.bashrc
fi
if [ -f "$HOME/.login" ]; then
    echo "Sourcing .login:"
    source $HOME/.login
fi

echo "The compute machine is: " && cat /proc/sys/kernel/hostname
echo ""
echo "Current activity:"
uptime
echo ""
echo "Users currently logged in:"
who
echo ""

echo "Here is a run-down of the available disk space at the start of the run:"
df -h

#Check what size the input data directory is and decide where to process
CHECK=$(du -sb $DATAIN | cut -f1)
if [ $CHECK \< 280000000000 ]; then
    echo ""
    echo "This is a fairly small dataset. I will process it on the internal disks"
    export WORKINGDIR=/state/partition1/$user/$PROJECT
    export PARENT=/state/partition1/$user
    echo "WORKINGDIR: $WORKINGDIR"
    if [ -d $WORKINGDIR ]; then
	echo "$WORKINGDIR exists. Clearing contents..."
	rm -rf $WORKINGDIR
    fi
    mkdir -p $WORKINGDIR
else
    echo "This is a large dataset. I will process it on the NAS drive"
    export WORKINGDIR=/share/nas/$user/pipe_tmp/$PROJECT
    export PARENT=/share/nas/$user/pipe_tmp
    echo "WORKINGDIR: $WORKINGDIR"
    if [ -d $WORKINGDIR ]; then
	echo "$WORKINGDIR exists. Clearing contents..."
	rm -rf $WORKINGDIR
	mkdir -p $WORKINGDIR
	echo "Done!"
    else 
	echo "$WORKINGDIR does not exist. Creating now..."
	mkdir -p $WORKINGDIR
	echo "Done!"
    fi
fi

echo "The output directory is $DATAOUT"

#Bind the input data directory to the container
export SINGULARITY_BIND=$WORKINGDIR:/workingdir,/state/partition2,$DATAIN:/raw_data

#Set up directory structure on compute node
echo "I will try to clear up any files that belong to you before we begin. You may see a 'permission denied' error as I try to look inside the /lost+found/ directory: DON'T PANIC"
echo ""
rm -rf /state/partition2/$user
mkdir /state/partition2/$user

echo "Contents of PARENT dir at start of run:"
ls -ltrkh $PARENT
echo "Contents of WORKING dir: at start of run"
ls -ltrkh $WORKINGDIR
echo ""

echo "Current output from ulimit -a:"
ulimit -a

echo "Now tweeking ulimit:"
export OMP_NUM_THREADS=24
ulimit -c unlimited
ulimit -u 8192

#Check to see if there are any manual flags present and if so copy them to the processing directory
#MANUAL_AVG
export MANUALAVG=$DATAIN\/manual_avg.flags
if [ -f "$MANUALAVG" ]; then
    echo "Copying manual flag file: $DATAIN\/manual_avg.flags"
    cp $DATAIN\/manual_avg.flags $WORKINGDIR
else
    echo "No manual_avg.flags file will be used."
fi
#MANUAL_NARROW
export MANUALNARROW=$DATAIN\/manual_narrow.flags
if [ -f "$MANUALNARROW" ]; then
    echo "Copying manual flag file: $DATAIN\/manual_narrow.flags"
    cp $DATAIN\/manual_narrow.flags $WORKINGDIR
else
    echo "No manual_narrow.flags file will be used."
fi
#MANUAL
export MANUALFLAGS=$DATAIN\/manual.flags
if [ -f "$MANUALFLAGS" ]; then
    echo "Copying manual flag file: $DATAIN\/manual.flags"
    cp $DATAIN\/manual.flags $WORKINGDIR
else
    echo "No manual.flags file will be used."
fi

#Check to see if a customised version of default_params.json exists
export PARAMFILE=$DATAIN\/default_params.json
if [ -f "$PARAMFILE" ]; then
    echo "Copying custom parameters file: $DATAIN\/default_params.json"
    cp $DATAIN\/default_params.json $WORKINGDIR
else
    echo "No custom parameters file was given. Using observatory defaults."
fi

#Check to see if a customised inputs.ini file was found - this is *REQUIRED* for a full pipeline run, but we can run the import steps without
export INPUTFILE=$DATAIN\/inputs.ini
if [ -f "$INPUTFILE" ]; then
    echo "Using $INPUTFILE"
    export INPUTFILE=/raw_data/inputs.ini
else 
    echo "No valid inputs.ini file was given: I will run the import steps of the pipeline *only*."
    export STEPS=run_importfits
    singularity exec $PIPELINEVER bash -c "cp /eMERLIN_CASA_pipeline/inputs.ini /raw_data/"
    sed -i -e 's/\/path\/to\/fits\/files\//\/raw\_data\//g' $DATAIN\/inputs.ini
    sed -i -e "s/project_name/$PROJECT/g" $DATAIN\/inputs.ini
    export INPUTFILE=/raw_data/inputs.ini
fi

#Run the pipeline (this step also copies the latest observatory flags from a NAS drive which is updated hourly from Javier's master)
echo "This is the command that is being executed (uncludes ulimit -a inside the container): "
echo singularity exec $PIPELINEVER bash -c "ulimit -a && cd /workingdir && wget -O antenna_monitor.log http://www.e-merlin.ac.uk/distribute/antenna_log_rsync/antenna_monitor.log && xvfb-run -a casa --nogui -c /eMERLIN_CASA_pipeline/eMERLIN_CASA_pipeline.py -i $INPUTFILE -r $STEPS"
singularity exec $PIPELINEVER bash -c "ulimit -a && cd /workingdir && wget -O antenna_monitor.log http://www.e-merlin.ac.uk/distribute/antenna_log_rsync/antenna_monitor.log && xvfb-run -a casa --nogui -c /eMERLIN_CASA_pipeline/eMERLIN_CASA_pipeline.py -i $INPUTFILE -r $STEPS"

if [ "$MAKEWIDEFIELD" == "True" ]; then
    echo "Using Python from:"
    which python
    echo "Now attempting to build and execute WSCLEAN file."
    singularity exec $PIPELINEVER bash -c "cd /workingdir && cp /scripts/dowsclean.py . && /conda/bin/python3 dowsclean.py"
    mkdir $WORKINGDIR/widefield_images
    mv $WORKINGDIR/*.fits $WORKINGDIR/widefield_images
    singularity exec $PIPELINEVER rm /workingdir/wsclean_commands.bash
    singularity exec $PIPELINEVER rm /workingdir/dowsclean.py
fi

#If there is an averaged MS then delete the unaveraged MS
export AVERAGEDMS=$WORKINGDIR/$PROJECT\_avg.ms
echo "Looking for $AVERAGEDMS..."
if [ -d "$AVERAGEDMS" ]; then
    echo "An averaged Measurement Set exists, therefore I will remove the unaveraged Measurement Set"
    echo "rm -rf $WORKINGDIR/$PROJECT.ms"
    rm -rf $WORKINGDIR/$PROJECT.ms
    echo "rm -rf $WORKINGDIR/$PROJECT.ms.flagversions"
    rm -rf $WORKINGDIR/$PROJECT.ms.flagversions
else
    echo "I could not find $AVERAGEDMS"
fi

#If the user specified $DATAOUT directory then send the data there, 
#otherwise write the data back to the directory from whence they came
if [ "$DATAOUT" == "" ]; then
    export DATAOUT="$DATAIN"
fi

#Move the wide-field images out of the directory being sent to the PI
#delete any old copies first
if [ -d "$WORKINGDIR/widefield\_images" ]; then
    rm -r $WORKINGDIR/widefield\_images
fi
mv $WORKINGDIR/widefield\_images $DATAOUT

#Copy SLURM output file
cp /home/$user/pipeline/slurm-$SLURM_JOB_ID.out $WORKINGDIR/

#Tar everything up
echo "tar -C $PARENT -cvf $DATAIN/$PROJECT.tar $PROJECT"
bash -c "tar -C $PARENT -cvf $DATAIN/$PROJECT.tar $PROJECT"

echo "Here is a run-down of the available disk space at the end of the run:"
df -h

#Check to see if an old version of the data exists on the NAS drive; if so, delete it
export PROCESSED="$DATAOUT/$PROJECT"
echo "Check to see if there is a directory called $PROCESSED"
if [ -d "$PROCESSED" ]; then
    echo "Found some old data on the NAS drive - clearing that up now"
    rm -r $PROCESSED
    rm -r $PROCESSED.tar
    echo "Done!"
else
    echo "Target directory seems to be clear -- proceeding to copy"
fi

#Move pipelined dataset back to NAS drive
echo ""
echo "Now moving data back to NAS:"
date
mv $WORKINGDIR $DATAOUT
mv $WORKINGDIR.tar $DATAOUT

#Clear up any directories that may exist on the compute node
if [ -d /state/partition1/$user ]; then
    rm -r /state/partition1/$user
fi
if [ -d /state/partition2/$user ]; then
    rm -r /state/partition2/$user
fi
echo "Job finished at: "
date
