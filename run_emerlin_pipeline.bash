while read -r line; do CORES="$line"; done < ncores.txt
rm -r *.ms *.log *.flagversions weblog splits logs pre-cal_flag_stats.txt
#casa --nogui -c /eMERLIN_CASA_pipeline/eMERLIN_CASA_pipeline.py -r all -i inputs.ini
mpicasa -n $CORES /casa-pipeline-release-5.6.2-2.el7/bin/casa --nogui --pipeline -c /eMERLIN_CASA_pipeline/eMERLIN_CASA_pipeline.py -r all -i inputs.ini
mkdir pipelined
mv *log pipelined
mv *.ms pipelined
mv *.flagversions pipelined
mv *pre-cal_flag_stats.txt pipelined/
mv weblog/ pipelined/
mv splits/ pipelined/
mv logs/ pipelined/
tar -zcvf pipelined.tar.gz pipelined
rm -r pipelined
