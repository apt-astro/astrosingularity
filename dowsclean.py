import os
import glob
import getpass

#Get the user name
username = getpass.getuser()

#Find the eMCP.log file and open it to measure the central frequency
logfile = glob.glob('./eMCP.log', recursive=True)
    
with open(logfile[0], 'r') as log:
    line = log.readline()
    count = 0
    while line:
        linetok = line.split()
        if linetok[5] == 'Central' and linetok[6] == 'frequency':
            nucentre = float(linetok[10])
        line = log.readline()
        count += 1

#Find the listobs file and read it to determine which sources are present in the MS
try:
    listobs = glob.glob('/state/partition1/'+str(username)+'/**/*avg.ms.listobs.txt', recursive=True)
    listfile = open(listobs[0], 'r')
    print('Opened file '+listobs[0])
except:
    listobs = glob.glob('/state/partition1/'+str(username)+'/**/*listobs.txt', recursive=True)
    listfile = open(listobs[0], 'r')
    print('Opened file '+listobs[0])

fieldnames = []
fieldids = []
fieldcode = []
aftermin = 0
beforemax = 1
for line in listfile:
    chars = line.split()
    if len(chars) > 2:
        if chars[0] == 'MeasurementSet' and chars[1] == 'Name:':
            msname = chars[2]
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
                if chars[1] == 'PCAL' or chars[1] == 'ACAL' or chars[1] == 'CAL':
                    fieldnames.append(str(chars[2]))
                    fieldcode.append(str(chars[1]))
                else:
                    fieldnames.append(str(chars[1]))
                    fieldcode.append('TARGET')

#Parse the Measurement Set name and use this as the base for image names
mssplit = msname.split('/')
msroot = mssplit[(len(mssplit)-1)]
mssplit = msroot.split('.')
msroot = mssplit[0]

#Print a wsclean command to file depending on the band observing band
if nucentre >= 1000 and nucentre <= 2000:
    print('This is an L-band observation. Using L-band imaging strategy.')
    print('wsclean -name '+str(msroot)+'_'+str(fieldnames[i])+' -field '+str(fieldids[i])+' -size 14000 14000 -scale 0.045asec -weight natural -gain 0.10 -mgain 0.65 -auto-mask 3.0 -auto-threshold 0.5 -parallel-deconvolution 4000 -local-rms -local-rms-window 120 -local-rms-method rms-with-min -no-update-model-required -log-time -niter 75000 -temp-dir /state/partition2/'+str(username)+' '+str(msname))

if nucentre >= 4000 and nucentre <= 8000:
    print('This is a C-band observation. Using C-band imaging strategy.')
    f = open("wsclean_commands.bash", "w")
    f.write("#WSCLEAN commands for target fields:\n")
    for i in range(0,len(fieldids)):
        if fieldcode[i] == 'TARGET':
            f.write('wsclean -name '+str(msroot)+'_'+str(fieldnames[i])+' -field '+str(fieldids[i])+' -size 14000 14000 -scale 0.015asec -weight natural -gain 0.10 -mgain 0.65 -auto-mask 3.0 -auto-threshold 0.5 -parallel-deconvolution 4000 -local-rms -local-rms-window 120 -local-rms-method rms-with-min -no-update-model-required -log-time -niter 75000 -temp-dir /state/partition2/'+str(username)+' '+str(msname)+'\n')
    
    f.write("#WSCLEAN commands for calibrator fields -- these are currently not being run.\n")
    for i in range(0,len(fieldids)):
        if fieldcode[i] != 'TARGET':
            f.write('#wsclean -name '+str(msroot)+'_'+str(fieldnames[i])+' -field '+str(fieldids[i])+' -size 14000 14000 -scale 0.015asec -weight natural -gain 0.10 -mgain 0.65 -auto-mask 3.0 -auto-threshold 0.5 -parallel-deconvolution 4000 -local-rms -local-rms-window 120 -local-rms-method rms-with-min -no-update-model-required -log-time -niter 75000 -temp-dir /state/partition2/'+str(username)+' '+str(msname)+'\n')

    f.close()

if nucentre >= 19000 and nucentre <= 25000:
    print(' This is a K-band observation. Using K-band imaging strategy.')


print('Now attempting to execute "wsclean_commands.bash":')
os.system('bash wsclean_commands.bash')
