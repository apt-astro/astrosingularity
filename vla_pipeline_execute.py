import glob
import pipeline.recipes.hifv as hifv

datain = glob.glob("/state/partition1/athomson/*/18A-338*")

print('Input dataset is: '+str(datain))
hifv.hifv(datain)
