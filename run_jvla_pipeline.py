import glob, os
import pipeline.recipes.hifv as hifv
infile = glob.glob("*.tar")
os.system("tar -xvf "+infile[0])
os.system("rm "+infile[0])
fileuntar = os.path.splitext(infile[0])
hifv.hifv([fileuntar[0]])
os.system("rm -r "+fileuntar[0])
