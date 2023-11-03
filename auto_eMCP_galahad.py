#!/usr/bin/env python

import os, sys 
import pprint
import time
import numpy as np

def write_prepare_scripts(run):
    project = run['project']
    subproject = run['subproject']
    data_location = run['data_location']
    project_dir = global_path+project
    output_dir = project_dir +'/'+ subproject
    prepare_script = 's1_prepare_'+subproject+'.sh'
    source_tag = ['target_name','phscal_name','fluxcal_name','bpcal_name','ptcal_name']
    for s in source_tag:
        name = run[s]
        #f.write("sed -i \'s/{0}/{1}/g\' {2}\n".format(s, name, 'inputs.ini'))
    return prepare_script

def write_additional_export(run, s, outfile):
    location = run['additional'][s]
    data = '/home/emerlin/observations/sub_array_jobs/'+location
    os.system('data_tool -m fobs -f {} > contents.txt'.format(data))
    scans = open('contents.txt','rb').readlines()
    for scan in scans:
        if s in scan:
            time0 = scan.split(' ')[0]
            time1 = scan.split(' ')[1]
    command = 'data_tool -m x-fits -d {0} -e {1} -w {2} -f {3}'.format(time0, time1, outfile, data)
    return command

def select_date(run, i):
    try:
        date_ini = np.atleast_1d(run['date_ini'])[i]
        ini_str = '-d {0}'.format(date_ini)
    except KeyError:
        ini_str = ''
    try:
        date_end = np.atleast_1d(run['date_end'])[i]
        end_str = '-e {0}'.format(date_end)
    except KeyError:
        end_str = ''
    return '{0} {1}'.format(ini_str, end_str)

def write_export_script(run):
    project = run['project']
    subproject = run['subproject']
    data_location = run['data_location']
    export_script = 's2_exports_'+run['subproject']+'.sh'
    f = open(export_script, 'wb')
    project = run['project']
    subproject = run['subproject']
    data_location = np.atleast_1d(run['data_location'])
    project_dir = global_path + project
    f.write('mkdir -p {0}/{1}/{2}/DATA\n'.format(fits_path, project, subproject))
    output_dir = '{0}/{1}/{2}/DATA/'.format(fits_path, project, subproject)
    datasize = 0.0
    for i in range(len(data_location)):
        time_sel = select_date(run, i)
        outfile = output_dir+subproject+'_{0:02d}.fits'.format(i)
        data = '/home/emerlin/observations/sub_array_jobs/'+data_location[i]
        dataabspath = os.path.realpath(data+".data") 
        datasize += os.path.getsize(dataabspath)/(1024**3)
        f.write('data_tool -m x-fits {0} -w {1} -f {2}\n'.format(time_sel, outfile, data))
    if 'additional' in run.keys():
        for i,s in enumerate(run['additional'].keys()):
            outfile = output_dir+subproject+'_{0}_{1}.fits'.format(i,s)
            add_command = write_additional_export(run, s, outfile)
            f.write(add_command+'\n')
    f.write('cp -pr {0}/inputs.ini {1}\n'.format(pipeline_path, output_dir))
    data_path = fits_path+project+'/'+subproject+'/DATA/'
    f.write("sed -i \'s/project_name/{0}/g\' {1}\n".format(subproject, output_dir+'inputs.ini'))
    f.write("sed -i \'s/\/path\/to\/fits\/files\//{0}/g\' {1}\n".format('\/raw_data\/', output_dir+'inputs.ini'))
    source_tag = ['target_name','phscal_name','fluxcal_name','bpcal_name','ptcal_name']
    for s in source_tag:
        name = run[s]
        f.write("sed -i \'s/{0}/{1}/g\' {2}\n".format(s, name, output_dir+'inputs.ini'))
    
    f.write('touch {0}/export_finished\n'.format(output_dir))

    #Set up SLURM script for Galahad
    f.write('wget https://raw.githubusercontent.com/apt-astro/astrosingularity/master/galahad_job_script.sbatch -O '+fits_path+project+'/'+subproject+'.sbatch\n')
    f.write("sed -i -e 's/MYEMAIL/"+emailaddr+"/g' "+fits_path+project+'/'+subproject+".sbatch\n")
    f.write("sed -i -e 's/USERID/emadmin/g' "+fits_path+project+'/'+subproject+".sbatch\n")
    f.write("sed -i -e 's/PROJID/"+subproject+"/g' "+fits_path+project+'/'+subproject+".sbatch\n")
    f.write("sed -i -e 's/DATADIR/{0}/g' {1}.sbatch\n".format(str('/share/nas/emadmin/'+project+'/'+subproject+'/DATA/').replace('/','\/'), fits_path+project+'/'+subproject))
    f.write("#Absolute size of exported data in GB: {0}\n".format(datasize))
    if datasize >= 400:
        #If this is a large dataset, process it on a high-mem node
        f.write("sed -i -e 's/rack-0,12CPUs|rack-0,24CPUs/rack-0,8CPUs|rack-0,16CPUs/g' "+fits_path+project+'/'+subproject+".sbatch\n")
    f.write("chmod -R 777 "+fits_path+project+"/")
    f.close()

    #Create script for moving data to NAS drive
    if project[0] == 'C' and project[1] == 'Y':
        if project[2] in '123456789' and len(project) == 6:
            outbase = '/share/nas/emerlin/external/CY'+project[2]+'/'+project
        else:
            outbase = '/share/nas2/emerlin/external2/CY'+project[2]+project[3]+'/'+project
    if project[0] == 'D' and project[1] == 'D':
        if project[2] in '123456789' and len(project) == 6:
            outbase = '/share/nas/emerlin/external/CY'+project[2]+'/'+project
        else:
            outbase = '/share/nas2/emerlin/external2/CY'+project[2]+project[3]+'/'+project
    if project[0] == 'L' and project[1] == 'E':
        outbase = '/share/nas2/emerlin/external2/LEGACY/'+project
    #Commands to move the processed data back to the NAS drive.
    if len(outbase) >0:
        os.system('mkdir -p '+fits_path+project+'/')
        f = open(fits_path+project+'/'+subproject+'_to_nas.bash', 'wb')
        f.write("mkdir -p "+outbase+"\n")
        f.write("rm -r "+fits_path+project+"/"+subproject+"/DATA/"+subproject+"/*.ms\n")
        f.write("rm -r "+fits_path+project+"/"+subproject+"/DATA/"+subproject+"/*.flagversions\n")
        f.write("rm -r "+fits_path+project+"/"+subproject+"/DATA/splits/\n")
        f.write("if [ -d "+outbase+"/"+subproject+" ]; then\n")
        f.write('\techo -e "\e35mA dataset with a conflicting name already exists on the NAS drive:"\n')
        f.write('\techo -e "'+outbase+'/'+subproject+'"\n')
        f.write('\techo -e "Please inspect its contents and decide for yourself which version to keep. I will *NOT* copy the updated directory from Galahad\e[0m"\n')
        f.write("else\n")
        f.write('\techo -e "The distribution NAS drive has no conflicting dataset. I will now move the data from Galahad on to the external NAS drive."\n')
        f.write("\tmv {0} {1}\n".format(fits_path+project+"/"+subproject+"/DATA/"+subproject+".tar", outbase))
        f.write("\tmv {0} {1}\n".format(fits_path+project+"/"+subproject+"/DATA/"+subproject+"/", outbase))
        f.write("\trm -r "+fits_path+project+"/"+subproject+"\n")
        f.write("fi")    
        f.close()
    else:
        print "There was a problem setting outbase - the script for moving data to the NAS drive has not been created."
    return

def write_run_pipeline(run):
    project = run['project']
    subproject = run['subproject']
    project_dir = global_path+project
    output_dir = project_dir +'/'+ subproject
    pipeline_script = 's3_execute_'+subproject+'.sh'
    return 




def run_auto(runs):
    print "There are "+str(len(runs))+" runs"
    # Prepare scripts 
    for run in runs:
        if run['do_prepare_1']:
            prepare_script = write_prepare_scripts(run)
            write_export_script(run)
            write_run_pipeline(run)
            #os.system('sh '+ prepare_script)
    # Export data
    print "EXPORT BEGINS"
    for run in runs:
        print "Exporting data for "+str(run)
        if run['do_exports_2']:
            export_script = 's2_exports_'+run['subproject']+'.sh'
            print "Running the export script now"
            os.system('sh '+export_script)
            #sys.exit('Debugging')
        
    # Run pipeline
    for run in runs:
        if run['do_execute_3']:
            project = run['project']
            subproject = run['subproject']
            data_path = fits_path+project+'/'+subproject+'/DATA/'
            finished_local = data_path + 'export_finished'
            while not os.path.isfile(finished_local):
                print('Waiting for data to be exported to: {0}'.format(data_path))
                time.sleep(20)
            print('export_finished found for project {}. Proceeding...'.format(subproject))
            print('Starting pipeline...')
            execute_script = 's3_execute_'+run['subproject']+'.sh'
            os.system('sh '+execute_script)


if __name__ == '__main__':
    input_file = sys.argv[-1]
    execfile(input_file)
    print('FITS PATH: {0}'.format(fits_path))
    print('GLOBAL PATH: {0}'.format(global_path))
    #Check that fits_path and global_path
    #both end in forward-slashes
    if fits_path[-1] != '/':
        fits_path = fits_path+'/'
    if global_path[-1] != '/':
        global_path = global_path+'/'
    pprint.pprint(runs)
    run_auto(runs)

