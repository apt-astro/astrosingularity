## README

This repository contains some useful(?) build scripts for Singularity containers used in the processing of (mostly radio) astronomical data. 

## Container images
1. ___kerndef.def___ Contains some of the radio astronomy software packages I use most frequently from Gijs Molenaar's KERN Suite (https://kernsuite.info/).
2. ___emerlin\_pipeline.def___ Contains many of the KERN packages, but additionally includes a full install of CASA (https://casa.nrao.edu/ -- currently v5.6.2-2) along with Javier Moldon's eMERLIN CASA pipeline (https://github.com/e-merlin/eMERLIN_CASA_pipeline). Please see the README on Javier's github page for detailed instructions on how to use the pipeline. 
3. ___jvla\_pipeline.def___ Another variant of the KERN + CASA image, with an additional Python control script to enable automated processing of VLA data using the NRAO VLA CASA pipeline (https://science.nrao.edu/facilities/vla/data-processing/pipeline).

Each of these containers can be built with Singularity (version >= 3.0.0) using (e.g.)

> sudo singularity build [imagename] emerlin\_pipeline.def

Where "[imagename]" is an arbitrary name of your choosing. These container  images contain largely overlapping sets of software packages - the chief differences between them are in the behaviour of the command:

> singularity run [imagename]

with ___emerlin\_pipeline.def___ automatically scripting and initialising an eMERLIN calibration run, and ___jvla\_pipeline.def___ scripting and initialising a VLA calibration run. Further information on how to use these images are to be found in the respective %help sections of each build script. These can also be called from the built Singularity container image using

> singularity run-help [imagename]

## Quick start
#### eMERLIN data processing quick start

If you are in possession of raw eMERLIN FITS-IDI files and wish to process them, then the simplest way to do this using the Singularity container image is:

1. Create a working directory and place your FITS-IDI file(s) and the Singularity container image in it
2. Identify the target, phase reference, bandpass, flux and point source calibrator sources in your file. If you do not already know the correct source names then you can derive these by running the initial import steps of the pipeline and inspecting the results:

	> singularity exec [imagename] xvfb-run /casa --nogui -c /eMERLIN\_CASA\_pipeline/eMERLIN\_CASA\_pipeline.py -r run_importfits
	
	When the execution is finished, open the weblog and go to the tab "Observation Summary", where you will find all targets observed during this observation. See Javier's eMERLIN CASA pipeline README for more information about how to determine which source is which. If you are on a machine without X11, then search for a file called "listobs.txt" in the weblog directory and read it from the terminal with "more".
	
3. Now that you know which sources are which, I would recommend deleting all files generated from this initial run:

	> rm -rf *.ms weblog/ \*last \*.log
	
	and then dump out a pipeline parameter file from the Singularity container using:
	
	> singularity exec [imagename] cp /eMERLIN\_CASA\_pipeline/inputs.ini .
	
	Then, using your favourite text editor, edit the variable *fitsinpath* to "./", and edit the source names to correspond with your actual target and calibrator source names.
	
4. Finally, run the pipeline. By default, the pipeline will operate in the present working directory, using the FITS-IDI file and inputs.ini file (i.e. the one you just created):

	> singularity run [imagename]
	
	If all goes according to plan, you will have pipelined eMERLIN data in 12-24 hours' time.

**Optional:** By default, the pipeline does some averaging of the data to (a) save disk space, (b) speed up processing, and (c) boost the signal-to-noise of the data by "binning-up", improving both the flagging fidelity and the likelihood of deriving suitable calibration solutions. This averaging is usually good for observations over a relatively modest field of view (i.e. a few arcminutes) however if you wish to exploit the full eMERLIN field of view (15x15 arcminutes for the Lovell Telescope; 45x45 arcminutes for the 25m antennas) then this averaging **will* induce smearing effects in the data. You can alter (or completely disable) this averaging by changing the pipeline behaviour before you run it (Step 4):

	> singularity exec [imagename] cp /eMERLIN\_CASA\_pipeline/default\_params.json .
	
And then edit the default\_params.json file using your favourite text editor. Run the pipeline as normal (Step 4). The default\_params.json you just edited will be used in preference to the standard version bundled with the pipeline.

#### JVLA data processing quick start

Compared with the eMERLIN CASA pipeline, there are relatively few "knobs and dials" that can be tweeked with the JVLA CASA pipeline. To pipeline JVLA data using this container image, I recommend that when downloading your data from the NRAO archive you select SDM-BDF data format and check "create SDM or MS tar file". Then wait for the email from NRAO indicating your data are available for download, download the tar file (e.g. using wget) and then place the data inside a directory with your JVLA CASA pipeline Singularity container image. Then do

> singularity run [imagename]

And wait (typically 18-24 hours) for the pipeline to run on your data. When run in this manner, the container executes a little Python script which untars the SDM-BDF tar file and then initialises and runs the JVLA CASA pipeline on the dataset you downloaded. You do not need to start CASA yourself, or tell it which dataset to operate on - any *.tar file (and there should be only one...) located in the current working directory will be assumed to be a VLA observation, and will be untarred and fed to the CASA pipeline automatically.

## Behavior on headless/X11-less systems

Neither the eMERLIN nor VLA CASA pipelines require human interaction once running, and indeed both can be run without creating pop-up windows by calling
> casa --nologger --log2term

or
> casa --nogui

However even in "no GUI" mode, CASA still appears to require that a $DISPLAY variable be set, which can cause issues running these pipelines on truly headless systems (e.g. HPC nodes with SLURM queue systems). To circumvent this issue, these container images contain Xvfb () to create a "black hole" down which CASA can send its requests for a DISPLAY without impacting functionality. This is seamlessly implemented within the container using 
>xvfb-run casa --nologger --log2term [normal arguments]...

--- 
*This repository is under development -- please submit an issue or pull request if you would like to contribute or make suggestions!!*

*N.B. in future it is envisaged that the jvla\_pipeline.def script will be developed to identify the target field, split it off from the calibrated Measurement Set and tar it up for download. This option is being looked at...* 
