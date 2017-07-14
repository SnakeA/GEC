#!/bin/bash

NUM_OF_CORES=16
WIKED_DIR=wiked
MOSES_BIN=/home/angelconstantinides/mosesdecoder/bin
MML_BI_SCRIPT=/home/angelconstantinides/scripts
NUM_OF_LINES5=1219638
NUM_OF_LINES10=2439276
NUM_OF_LINES20=4878553


# Size of WikEd : 24392765
# 5%    - 1219638
# 10% - 2439276
# 20% - 4878553


# In the same dir as the script there should exist Four Language Models with the following naming convention:
# - in-source.blm (i.e. NUCLE)
# - in-target.blm
# - out-source.blm (i.e. WikEd)
# - out-target.blm

echo "Scoring WikEd Corpus ................."
$MML_BI_SCRIPT/mml-score_bi.perl -corpus ./$WIKED_DIR/wiked.tc.clean -query ~/mosesdecoder/bin/query -input-extension err -output-extension cor | sort --parallel $NUM_OF_CORES -t $'\t' -k 2,2 -nr > score_wiked.out

echo "Sorting Scores ................."
cat score_wiked.out | head -$NUM_OF_LINES5 > ./wiked_score5.out
cat score_wiked.out | head -$NUM_OF_LINES10 > ./wiked_score10.out
cat score_wiked.out | head -$NUM_OF_LINES20 > ./wiked_score20.out


#Check if wiked.corpus exists, otherwise merge .err and .cor to create it
if [ ! -f ./$WIKED_DIR/wiked.corpus ]; then
   echo "Creating Directory Wiked.Corpus file"
   python split_merge.py ./$WIKED_DIR/wiked.tc.clean.err ./$WIKED_DIR/wiked.corpus --corpus_target ./$WIKED_DIR/wiked.tc.clean.cor
fi

# Extract Top Scoring Sentences
echo "Extracting Sentences from the corpus ................."
python score_extract.py ./wiked_score5.out ./$WIKED_DIR/wiked.corpus ./wiked_pseudo5.corpus &
python score_extract.py ./wiked_score10.out ./$WIKED_DIR/wiked.corpus ./wiked_pseudo10.corpus &
python score_extract.py ./wiked_score20.out ./$WIKED_DIR/wiked.corpus ./wiked_pseudo20.corpus &
wait

python split_merge.py ./wiked_pseudo20.corpus ./wiked_pseudo20

# Train a Language Model
echo "Training a KenLM Language Model ................."
$MOSES_BIN/lmplz -o 5 -S 80% -T /tmp < wiked_pseudo20.target > wiked_pseudo20.arpa

# Binarize it
echo "Binarizing Language Model ................."
$MOSES_BIN/build_binary wiked_pseudo20.arpa wiked_pseudo20.blm


