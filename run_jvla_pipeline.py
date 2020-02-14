import glob, os
import pipeline.recipes.hifv as hifv
infile = glob.glob("*.tar")
os.system("tar -xvf "+infile[0])
os.system("rm "+infile[0])
fileuntar = os.path.splitext(infile[0])
hifv.hifv([fileuntar[0]])
os.system("rm -r "+fileuntar[0])

#Identify the target field, split out (5s averaging) and tar up
listfile = glob.glob('pipeline-*/*/*/*/*listobs.txt')[0]
f = open(listfile, "r")
#outfile = open('split_calibrated.py', "w")
fieldnames = []
fieldids = []
aftermin = 0
beforemax = 1
for line in f:
    chars = line.split()
    if len(chars) > 0:
        if chars[0] == 'Fields:':
            print("There are "+str(chars[1])+" fields in this MS:")
        if chars[0] == 'Observed' and chars[1] == 'from':
            obsdate = chars[2]
            obsdate = obsdate.split('/')
            print('Date: '+obsdate[0])
        if chars[0] == 'ID' and chars[1] == 'Code':
            aftermin = 1
        if chars[0] == 'Spectral' and chars[1] == 'Windows:':
            beforemax = 0
        if aftermin == 1 and beforemax == 1:
            if chars[0] != 'ID':
                fieldids.append(str(chars[0]))
                fieldnames.append(str(chars[2]))

for i in range(0,len(fieldnames)):
    split(vis=fileuntar[0]+".ms",outputvis=fieldnames[i]+"_"+obsdate[0]+".ms",keepmms=False,field=fieldids[i],spw="",scan="",antenna="",correlation="",timerange="",intent="",array="",uvrange="",observation="",feed="",datacolumn="corrected",keepflags=True,width=2,timebin="5s",combine="")
                
#outfile.close()

#Tar up the output files along with the logs
projectcode = fileuntar[0].split('.')
os.system("tar -zcvf "+str(projectcode[0])+"_"+str(obsdate[0])+"_logs.tar.gz pipeline-*/")
for i in range(0,len(fieldnames)):
    os.system('tar -zcvf '+str(fieldnames[i])+'_'+str(obsdate[0])+'.ms.tar.gz '+str(fieldnames[i])+'_'+str(obsdate[0])+'.ms')

#Clear up everything else
os.system('rm -r '+str(fileuntar[0])+'.ms pipeline-* *.log *.last oussid* finalcalibrators.ms flux* *flagversions *hifv* *txt calibrators.ms *.tmp *.png')
