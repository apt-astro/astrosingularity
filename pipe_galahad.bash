export PIPELINEVER=/share/nas/emadmin/Pipeline/eMERLIN_CASA_pipeline_011020.img

#Set up directory structure on compute node
echo "I will try to clear up any files that belong to you before we begin. You will likely see a 'permission denied' error as I try to look inside the /lost+found/ directory:"
echo "DON'T PANIC :)"
echo ""
rm -rf /state/partition1/$user
mkdir /state/partition1/$user
rm -rf /state/partition2/$user
mkdir /state/partition2/$user

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
#echo "Output of swapon --show:"
#swapon --show
#echo ""
#echo "Files on local hard drive at the start of run: "
#ls -ltrkh /state/partition1
#echo ""

echo "Here is a run-down of the available disk space at the start of the run:"
df -h

#Check what size the input data directory is and decide where to process
echo "The input directory (DATAIN) is: $DATAIN"
CHECK=$(du -cb $DATAIN/*.fits | grep total | cut -f1)
export THRESH=270000000000
echo "The dataset is $((CHECK / 1000000000))GB"
echo "Threshold size: $((THRESH / 1000000000))GB"

if [ "$CHECK" -lt "$THRESH" ]; then
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

#echo "Files now on local hard drives after cleaning: "
#ls -ltrkh /state/partition1
#ls -ltrkh /state/partition2
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
    echo "Copying manual flag file $DATAIN\/manual_avg.flags to $WORKINGDIR"
    cp $DATAIN\/manual_avg.flags $WORKINGDIR
else
    echo "No manual_avg.flags file will be used."
fi
#MANUAL_NARROW
export MANUALNARROW=$DATAIN\/manual_narrow.flags
if [ -f "$MANUALNARROW" ]; then
    echo "Copying manual flag file $DATAIN\/manual_narrow.flags to $WORKINGDIR"
    cp $DATAIN\/manual_narrow.flags $WORKINGDIR
else
    echo "No manual_narrow.flags file will be used."
fi
#MANUAL
export MANUALFLAGS=$DATAIN\/manual.flags
if [ -f "$MANUALFLAGS" ]; then
    echo "Copying manual flag file: $DATAIN\/manual.flags to $WORKINGDIR"
    cp $DATAIN\/manual.flags $WORKINGDIR
else
    echo "No manual.flags file will be used."
fi

#Check to see if a customised version of default_params.json exists
export PARAMFILE=$DATAIN\/default_params.json
if [ -f "$PARAMFILE" ]; then
    echo "Copying custom parameters file $DATAIN\/default_params.json to $WORKINGDIR"
    cp $DATAIN\/default_params.json $WORKINGDIR
else
    echo "No custom parameters file was given. Using observatory defaults."
fi

#Check to see if a customised inputs.ini file was found - this is *REQUIRED* for a full pipeline run, but we can run the import steps without
export INPUTFILE=$DATAIN\/inputs.ini
if [ -f "$INPUTFILE" ]; then
    echo "Using $INPUTFILE"
    export INPUTFILE=/raw_data/inputs.ini
    cp $DATAIN\/inputs.ini $WORKINGDIR
else 
    echo "No valid inputs.ini file was given: I will run the import steps of the pipeline *only*."
    export STEPS=run_importfits
    singularity exec $PIPELINEVER bash -c "cp /eMERLIN_CASA_pipeline/inputs.ini /raw_data/"
    sed -i -e 's/\/path\/to\/fits\/files\//\/raw\_data\//g' $DATAIN\/inputs.ini
    sed -i -e "s/project_name/$PROJECT/g" $DATAIN\/inputs.ini
    export INPUTFILE=/raw_data/inputs.ini
fi

#Do utime to show what resources are available
#echo ""
#echo "Here's the output of ulimit -a to  show what resources are available at the start of the run. Has it changed from before?"
#ulimit -a
#echo ""


#Run the pipeline (this step also copies the latest observatory flags from a NAS drive which is updated hourly from Javier's master)
echo "This is the command that is being executed (uncludes ulimit -a inside the container): "
echo singularity exec $PIPELINEVER bash -c "ulimit -a && cd /workingdir && wget -O antenna_monitor.log http://www.e-merlin.ac.uk/distribute/antenna_log_rsync/antenna_monitor.log && xvfb-run -a casa --nogui -c /eMERLIN_CASA_pipeline/eMERLIN_CASA_pipeline.py -i $INPUTFILE -r $STEPS"
singularity exec $PIPELINEVER bash -c "ulimit -a && cd /workingdir && wget -O antenna_monitor.log http://www.e-merlin.ac.uk/distribute/antenna_log_rsync/antenna_monitor.log && xvfb-run -a casa --nogui -c /eMERLIN_CASA_pipeline/eMERLIN_CASA_pipeline.py -i $INPUTFILE -r $STEPS"

if [ "$MAKEWIDEFIELD" == "True" ]; then
    #echo "Using Python from:"
    #which python
    echo "Now attempting to build and execute WSCLEAN file."
    singularity exec $PIPELINEVER bash -c "cd /workingdir && cp /scripts/dowsclean_target.py . && /conda/bin/python3 dowsclean_target.py"
    if [ "$IMAGECALIBRATORS" == "True" ]; then
	singularity exec $PIPELINEVER bash -c "cd /workingdir && cp /scripts/dowsclean_calibrators.py . && /conda/bin/python3 dowsclean_calibrators.py"
	singularity exec $PIPELINEVER rm /workingdir/dowsclean_calibrators.py
    fi
    if [ -d $DATAIN/widefield_images ]; then
	echo "Found an old widefield_images directory - deleting now"
	rm -r $DATAIN/widefield_images
    fi
    mkdir $WORKINGDIR/widefield_images
    mv $WORKINGDIR/*.fits $WORKINGDIR/widefield_images
    mv $WORKINGDIR/*.bash $WORKINGDIR/widefield_images
    #singularity exec $PIPELINEVER rm /workingdir/wsclean_commands.bash
    singularity exec $PIPELINEVER rm /workingdir/dowsclean_target.py
fi

#Kill any stray XVfb processes
echo "Running XVfb processes:"
ps aux | grep Xvfb
echo "Executing killall command:"
killall Xvfb -v -u $user

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
if [ -d "$DATAOUT/widefield\_images" ]; then
    rm -r $DATAOUT/widefield\_images
fi

echo "Here is a run-down of the available disk space at the end of the run:"
df -h

#Check to see if an old version of the data exists on the NAS drive; if so, delete it
export PROCESSED="$DATAOUT/$PROJECT"
echo "Check to see if there is a directory called $PROCESSED"
if [ -d "$PROCESSED" ]; then
    echo "Found some old data on the NAS drive - clearing that up now"
    rm -rf $PROCESSED
    rm -rf $PROCESSED.tar
    echo "Done!"
else
    echo "Target directory seems to be clear -- proceeding to copy"
fi

#Tar everything up
echo "tar -C $PARENT -cvf $DATAIN/$PROJECT.tar $PROJECT"
bash -c "tar -C $PARENT -cvf $DATAIN/$PROJECT.tar $PROJECT"

#Move pipelined dataset back to NAS drive
echo ""
echo "Now moving data back to NAS:"
date
echo mv $WORKINGDIR $DATAOUT
mv $WORKINGDIR $DATAOUT
if [ -d "$WORKINGDIR/widefield\_images" ]; then
    mv $WORKINGDIR/widefield\_images $DATAOUT
fi
#mv /state/partition2/$PROJECT $DATAOUT

#Copy SLURM output file
echo "Copying SLURM output file:"
echo "$(cd $DATAIN; cd ../../; pwd)"/slurm-$SLURM_JOB_ID.out $DATAOUT
cp "$(cd $DATAIN; cd ../../; pwd)"/slurm-$SLURM_JOB_ID.out $DATAOUT

#Change permissions on the processed data
#echo chmod 777 $DATAOUT/$WORKINGDIR.tar
#chmod 777 $DATAOUT/$WORKINGDIR.tar
#echo chmod -R 777 $DATAOUT/$WORKINGDIR
#chmod -R 777 $DATAOUT/$WORKINGDIR
echo "Now changing the file permissions on Galahad to allow copying to pipeline NAS drive:"
echo chmod 777 $DATAOUT/$PROJECT.tar
chmod 777 $DATAOUT/$PROJECT.tar
echo chmod -R 777 $DATAOUT/$PROJECT
chmod -R 777 $DATAOUT/$PROJECT

#Clear up any directories that may exist on the compute node
if [ -d /state/partition1/$user ]; then
    rm -r /state/partition1/$user
fi
if [ -d /state/partition2/$user ]; then
    rm -r /state/partition2/$user
fi
echo "Job finished at: "
date
