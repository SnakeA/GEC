#!/bin/bash
num_of_cores=32
data_dir=cc_data
for i in {0..9}
do
   for j in {0..9}
   do
      if [ ! -f ./$data_dir/en.$i$j.deduped.tok ]; then
         echo "File en.$i$j.deduped.tok not found!"
         echo "Tokenizing en.$i$j.deduped ....."
         echo "===================================="
         ~/mosesdecoder/scripts/tokenize/tokenizer/tokenizer.perl -threads $num_of_cores -time < ./$data_dir/en.$i$j.deduped > $data_dir/en.$i$j.deduped.tok &
      fi
   done
   wait
   
   for k in {0..9}   
   do
      echo "Removing en.$i$k.deduped"
      rm ./$data_dir/en.$i$k.deduped
   done

done
