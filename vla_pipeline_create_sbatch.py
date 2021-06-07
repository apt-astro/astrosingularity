import os
import sys
import glob
import getpass

#Change these variables as needed
containerpath = "/share/nas/athomson/bin/eMERLIN_CASA_Pipeline_Ubuntu_100521.img"
datapath = "/share/nas/athomson/NEP_VLA"
emailaddr = "alasdair.thomson@manchester.ac.uk"

#Hopefully nothing should need to be edited below this line?
tarfiles = glob.glob('*.tar')
#indir = os.getcwd()

user = getpass.getuser()

thresh = 100 #Size in GB of Measurement sets above which we want to process on IRIS

countlowmem = 0
counthighmem = 0

for tarfile in tarfiles:
    tarfilestring = tarfile.split('/')[-1][0:-4]
    #Create sbatch file
    f = open(str(tarfilestring)+'_preprocessing.sbatch', 'w')
    f.write("#!/bin/bash\n")
    f.write("#SBATCH --nodes=1\n")
    f.write("#SBATCH --exclusive\n")
    f.write("#SBATCH --time=120:00:00\n")
    f.write("#SBATCH --mail-type=ALL\n")
    datasize = os.path.getsize(tarfile)/(1024**3)
    print('Dataset '+str(tarfile)+', size: '+str(datasize)+'GB')
    if datasize >= thresh:
        if counthighmem == 0:
            f.write("#SBATCH --begin=now\n")
        else:
            f.write("#SBATCH --begin=now+"+str(int(counthighmem))+"hours\n")
        counthighmem += 1
        f.write("#SBATCH --constraint=rack-0,16CPUs\n")
    else:
        f.write("#SBATCH --begin=now+"+str(int(countlowmem*30))+"minutes\n")
        f.write("#SBATCH --constraint=rack-0,12CPUs|rack-0,24CPUs\n")
        countlowmem += 1
    f.write("#SBATCH --mail-user="+emailadde+"\n\n")
    f.write("mkdir -p /state/partition1/"+user+"/"+str(tarfilestring)+"_pipeline\n")
    f.write("mkdir -p /state/partition2/"+user+"/"+str(tarfilestring)+"_pipeline\n")
    f.write("export SINGULARITY_BIND=/state/partition1/"+user+",/state/partition2/"+user+"/,/share/nas/"+user+"\n")
    f.write("tar -xvf "+str(tarfile)+" -C /state/partition1/"+user+"/"+str(tarfilestring)+"_pipeline\n")
    f.write("cd /state/partition2/"+user+"/"+str(tarfilestring)+"_pipeline\n")
    f.write('wget https://raw.githubusercontent.com/apt-astro/astrosingularity/master/vla_pipeline_execute.py -O vla_pipeline_execute.py\n')
    f.write("singularity exec "+containerpath+" xvfb-run -a casa --nogui --pipeline -c vla_pipeline_execute.py\n")
    f.write("mv /state/partition2/"+user+"/"+str(tarfilestring)+"_pipeline "+str(datapath)+"\n")
    f.write("rm -r /state/partition1/"+user+"\n")
    f.write("rm -r /state/partition2/"+user+"\n")
    f.write("mv "+datapath+"/slurm-$SLURM_JOB_ID.out "+str(datapath)+"/"+str(tarfilestring)+"_pipeline/\n")
    f.close()

#Create the "doall.bash" file
sbatch = glob.glob('*.sbatch')

f = open('doall.bash', 'w')
for sbatchfile in sbatch:
    f.write('sbatch '+str(sbatchfile)+'\n')

f.close()

print('SLURM SBATCH files created - please check the contents of "doall.bash" and execute from the terminal when ready\n')
