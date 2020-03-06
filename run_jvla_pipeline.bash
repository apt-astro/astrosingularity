while read -r line; do CORES="$line"; done < ncores.txt
xvfb-run --auto-servernum mpicasa -n $CORES /casa-pipeline-release-5.6.2-2.el7/bin/casa --nogui --pipeline -c /run_jvla_pipeline.py
