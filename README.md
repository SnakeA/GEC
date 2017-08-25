Angelos Constantinides, 2017
Domain Adpatation for Grammatical Error Correction

This repository(https://github.com/SnakeA/GEC) contains scripts and helper scripts that we used throughout the time-frame of this project in order to apply various domain adpatation techniques to the Grammatical Error Correction system.

The most important files are detailed in the Implmentation chapter of my thesis. However they are also explained below. 

-- copy_to_tempdrive.sh
-----------------------------------------------------------------------------------------------
This script was run every time an MS Azure instance was reastrted. It mounts a shared disk and copies the required files for Moses training scripts, training data and language models from that disk in the local disk for better performance

-- create_cc_lm.sh
-----------------------------------------------------------------------------------------------
This is an out-of-the-box script that trains a LM on the common crawl data that I (Angelos Constantinides) implemented from scratch. It downloads the common crawl data (part 0-99), preprocess them (tokenization, truecasing), samples them (if specified) and scores them with the help of other scripts. The top scoring NUM_OF_LINES lines of each file are extracted and then are combined to a big single (filtered) data file. A language model is then trained on those filtered data and it is finally binarized. To do so Moses tokeziner script is required, which can be found under the compiled Moses directory, the truecasing script is that of Junczys-Dowmunt and Grundkiewicz (2016) for consistency, the scroing mml-score_mono.perl script that computes the cross-entropy of each line given language model, the score_extract.py script that extracts the specified top scoring senteces and the files to build and binarize a language model, which can be found under the Moses compiled dir. These dependencies are specified as variables at the top of the file. These are also detailed in Chpater 4 - Implementation of our theseis

-- create_wiked_lm.sh
-----------------------------------------------------------------------------------------------
This was also implemented by me (Angelos Constantinides). This is similar to create_cc_lm.sh script although it creates 3 filtered sub-corpora of different sizes from the WikEd corpus and trains a languaguage model on the one consisting of 20% of original corpus. It then binarizes it to be used as a feature. Since preprocessing was performed on the WikEd corpus, before running this script we had to ensure that the corpus (since it is bilingual, unlike to the common crawl one) is in two files format (source and target text). If this is not the case we can run split_merge.py in order to do so. Then this script takes place and scores the files using Bilingual cross-entropy and takes the top specified number of sentences in order to create three sub-corpora consisting of 5%, 10% and 20%, respectiveley of the original WikEd corpus. This also requires some helper scripts including mml-score_bi.perl that performs scoring, split_merge.py script in order to merge back to a single file format the filtered corpus and the language model building and binarizing scripts found under the Moses compiled directory. The dependencies are specified as vaiables at the top of the file and these are also detailed in Chapter 4 - Implementation of our thesis.

-- in-source.blm
-----------------------------------------------------------------------------------------------
This is a binarized version of a language model trained on the source side (erroneous) in-domain (NUCLE) data. Since this is required by the scoring scripts mml-score_mono.perl and mml-score_bi.perl we decided to include this. We trained a 5-gram KenLM language model and then binarized it.

-- in-target.blm
-----------------------------------------------------------------------------------------------
This is a binarized version of a language model trained on the target side (erroneous) in-domain (NUCLE) data and it is also required by the scoring scripts.

-- install_moses.sh
-----------------------------------------------------------------------------------------------
We built this script at the time we migrated from Google Cloud to MS Azure. This was run when a new instance was created in order to install the Moses toolkit with the appropriate dependencies.

-- install_moses-gleu.sh
-----------------------------------------------------------------------------------------------
We built this script at the time we migrated from Google Cloud to MS Azure. It requires the install_moses.sh script to be run first. This downloads and installs a specific version of moses that was proved to be more stable with the training scripts that we were using.

-- mml-score_bi.perl
-----------------------------------------------------------------------------------------------
This file is part of Moses. We took it as it was and made a few changes so that the output matched our requirements. The script is used by create_wiked_lm.sh and implements the Bilingual cross-entropy scoring method. It requires the in-domain language models (in-source.blm and in-target.blm) from NUCLE and also the corresponding out of domain ones (trained on the WikEd corpus) which are not included due to their size. 

To run the script:
- mml-score_bi.perl -corpus wiked.corpus -query ~/mosesdecoder/bin/query -input-extension err -output-extension cor 
where wiked.corpus is the corpus stem (i.e. wiked.coprus.cor and wiked.corpurs.err refer to the target and source side respectively)
      err and cor refer to the input and output extensions of the corpus file, respectively
      qurey is the query script that is found under the moses compiled directory
The script outputs the same number of lines as that of the corpus. Each line contains the line number and the score, separated by tap.

-- mml-score_mon.perl
-----------------------------------------------------------------------------------------------
This is a copy of mml-score_bi.perl which we refactored in order to implement a simpler monolingual cross-entropy scoring. This was used in create_cc_lm.sh script. It requiredo nly the in-domain target side language model.

To run the script:   
- mml-score_mono.perl -corpus cclm.corpus -query ~/mosesdecoder/bin/query 
where the corpus refers to the single corpus file (since this is monolingual)
      and query to the query script under Moses, as with the previous script

-- score_extract.py
-----------------------------------------------------------------------------------------------
This is a script that I (Angelos Constantinides) have implemented in order to extract the specified sentences, given the file that contains the scores (output of the scoring scripts) and the corpus. Finally an output file need to be specified to write the extracted sentences. The script is used in both create_cc_lm.sh and create_wiked_lm.sh

To run the script:
- python score_extract.py score_file corpus_file output_file


-- split_merge.py
-----------------------------------------------------------------------------------------------
This script takes a bilingual corpus in a single file format and splits it into two files containing the target and source side. It also performs the inverse of this operation and it is used in the create_wiked_lm.sh script.

To run the script (in order to split to two files):
- python split_merge.py corpus output
where corpus refers to the input corpus to be splitted
  and output referes to the output file stem (i.e. if 'wiked', then wiked.source and wiked.target files will be created)

To run the script (in order to merge to a single file):
- python split_merge.py corpus output --corpus_target 
where corpus refers to the input source side of the corpus
      corpus_target to the input target side of the corpus 
  and output refers to the output file name


