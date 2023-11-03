import os
from datetime import datetime

datestring = str(datetime.today().strftime('%Y-%m-%d'))

os.system("singularity build eMERLIN_CASA_Pipeline_Ubuntu_CASA56_"+datestring+".img emerlin_pipeline_ubuntu_casa56.def")
os.system("singularity build eMERLIN_CASA_Pipeline_Ubuntu_CASA58_"+datestring+".img emerlin_pipeline_ubuntu_casa58.def")
os.system("singularity build eMERLIN_CASA_Pipeline_Debian_CASA56_"+datestring+".img emerlin_pipeline_debian.def")
