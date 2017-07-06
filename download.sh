#!/bin/bash
num_of_cores=32
data_dir=cc_dataa
LAZYDIR=~/lazy
SCRIPTS=~/baselines-emnlp2016/train/scripts
TRUECASE_LM=/home/angelconstantinides/commoncrawllm/cc.kenlm
MML_MONO_SCRIPT=/home/angelconstantinides/scripts
NUM_OF_LINES=3809960
NUCLE_LINES=57151
CC_PART_LINES=380996016

if [ ! -d $data_dir ]; then
   echo "Creating Directory $data_dir"
   mkdir $data_dir
fi
for i in {1..1}
do
   for j in {0..9}
   do
      if [ ! -f ./$data_dir/en.$i$j.deduped.xz ]; then
         echo "File en.$i$j.deduped.xz not found!"
         echo "Downloading en.$i$j.deduped.xz ....."
         echo "===================================="
         wget -N -P ./cc_dataa/ http://web-language-models.s3-website-us-east-1.amazonaws.com/ngrams/en/deduped/en.$i$j.deduped.xz &
      fi
   done
   wait
   
   #Uncompress
   for k in {0..9}
   do
      unxz -v $data_dir/en.$i$k.deduped.xz &
   done
   wait
   
   #Remove Compressed Files 
   for l in {0..9}
   do
      rm ./$data_dir/en.$i$l.deduped.xz
   #   mv en.$i$l.deduped $data_dir/.
   done
   
   #Tokenize
   echo "TOKENIZING ................."
   for m in {0..9}
   do
      if [ ! -f ./$data_dir/en.$i$m.deduped.tok ]; then
         echo "File en.$i$m.deduped.tok not found!"
         echo "Tokenizing en.$i$m.deduped ....."
         echo "===================================="
         ~/mosesdecoder/scripts/tokenizer/tokenizer.perl -threads $num_of_cores -time < ./$data_dir/en.$i$m.deduped > $data_dir/en.$i$m.deduped.tok &
      fi
   done
   wait
   
   # Truecasing
   echo "TRUECASING ................."
   for n in {0..9}
   do
      TRUECASE= $(cat ./$data_dir/en.$i$n.deduped.tok | parallel --no-notice --pipe -k -j 4 --block 1M perl $SCRIPTS/case_graph.perl --threads $num_of_cores --lm $TRUECASE_LM --decode $LAZYDIR/bin/decode > ./$data_dir/en.$i$n.deduped.lc)
      eval $TRUECASE
      rm ./$data_dir/en.$i$n.deduped
      rm ./$data_dir/en.$i$n.deduped.tok
      echo "SCORING ................."
      MML_SCORE= $($MML_MONO_SCRIPT/mml-score_mono.perl -corpus ./$data_dir/en.$i$n.deduped.lc -query ~/mosesdecoder/bin/query | sort --parallel $num_of_cores -t $'\t' -k 2,2 -nr | head -$NUM_OF_LINES > ./sorted_score$i$n.out ) &
      eval $MML_SCORE
   done
done
