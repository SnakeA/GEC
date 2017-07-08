#!/bin/bash
NUM_OF_CORES=32
DATA_DIR=cc_datae #Name of the folder to process data
LAZYDIR=~/lazy
SCRIPTS=~/baselines-emnlp2016/train/scripts
TRUECASE_LM=/home/angelconstantinides/commoncrawllm/cc.kenlm
MML_MONO_SCRIPT=/home/angelconstantinides/scripts
NUM_OF_LINES=3809960
NUCLE_LINES=57151
CC_PART_LINES=380996016
SAMPLE=true # Sample instead of using the original file 
SAMPLE_SIZE=19050000 #3810000 - 1% or 19050000 - 5% of the original size

if [ ! -d $DATA_DIR ]; then
   echo "Creating Directory $data_dir"
   mkdir $DATA_DIR
fi
for i in {5..5}
do
   for j in {0..9}
   do
      if [ ! -f ./$DATA_DIR/en.$i$j.deduped.xz ]; then
         echo "File en.$i$j.deduped.xz not found!"
         echo "Downloading en.$i$j.deduped.xz ....."
         echo "===================================="
         wget -N -P ./$DATA_DIR/ http://web-language-models.s3-website-us-east-1.amazonaws.com/ngrams/en/deduped/en.$i$j.deduped.xz &
      fi
   done
   wait
   
   #Uncompress
   for k in {0..9}
   do
      unxz -v ./$DATA_DIR/en.$i$k.deduped.xz &
   done
   wait
   
   #Remove Compressed Files 
   for l in {0..9}
   do
      rm ./$DATA_DIR/en.$i$l.deduped.xz
   #   mv en.$i$l.deduped $data_dir/.
   done
   
   #Sample
   if [ "$SAMPLE" = true ] ; then 
      echo "SAMPLING ................."
      for o in {0..9}
      do
         shuf -n $SAMPLE_SIZE ./$DATA_DIR/en.$i$o.deduped > ./$DATA_DIR/en.$i$o.deduped.samp
         rm ./$DATA_DIR/en.$i$o.deduped
         mv ./$DATA_DIR/en.$i$o.deduped.samp ./$DATA_DIR/en.$i$o.deduped
      done
   fi

   #Tokenize
   echo "TOKENIZING ................."
   for m in {0..9}
   do
      if [ ! -f ./$DATA_DIR/en.$i$m.deduped.tok ]; then
         echo "File en.$i$m.deduped.tok not found!"
         echo "Tokenizing en.$i$m.deduped ....."
         echo "===================================="
         ~/mosesdecoder/scripts/tokenizer/tokenizer.perl -threads $NUM_OF_CORES -time < ./$DATA_DIR/en.$i$m.deduped > $DATA_DIR/en.$i$m.deduped.tok &
      fi
   done
   wait
   
   # Truecasing
   echo "TRUECASING ................."
   for n in {0..9}
   do
      cat ./$DATA_DIR/en.$i$n.deduped.tok | parallel --no-notice --pipe -k -j 4 --block 1M perl $SCRIPTS/case_graph.perl --threads $NUM_OF_CORES --lm $TRUECASE_LM --decode $LAZYDIR/bin/decode > ./$DATA_DIR/en.$i$n.deduped.lc
      rm ./$DATA_DIR/en.$i$n.deduped
      rm ./$DATA_DIR/en.$i$n.deduped.tok
      echo "SCORING ................."
      $MML_MONO_SCRIPT/mml-score_mono.perl -corpus ./$DATA_DIR/en.$i$n.deduped.lc -query ~/mosesdecoder/bin/query | sort --parallel $NUM_OF_CORES -t $'\t' -k 2,2 -nr | head -$NUM_OF_LINES > ./sorted_score$i$n.out &
   done
done
