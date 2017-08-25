# The script simply merges a bilingual corpus from two files into a single file. Each 
# line contains source and target language pairs separated by '\t' --corpus_target 
# needs to be specified

# If --corpus_target is not specified the script works vice-versa. It assumes a bilingual 
# corpus in a single file (each line containing source and target language pairs seprated
# by '\t') and splits it into two files each containing either source or target sentences


__author__ = 'Angelos Constantinides'
import sys
import argparse
from itertools import izip


def main():

	parser = argparse.ArgumentParser()
	parser.add_argument("corpus", help="The name of the file that contains the coprpus --monolingual-- or source side --bilingual--")
	parser.add_argument("output", help="The name of the file that the extracted sentences will be written to")
	parser.add_argument("--corpus_target", help="The target side of the corpus, if merging (optional)")
	args = parser.parse_args()

	print ("corpus " + args.corpus)
	print ("output " + args.output)
	if args.corpus_target:
		print ("corpus_target " + args.corpus_target)

	if args.corpus_target:
		with open(args.corpus,'r') as f_in_source, open(args.corpus_target,'r') as f_in_target, open(args.output,'w') as f_out:

			for source_line, targe_line in izip(f_in_source, f_in_target):
				source_line = source_line.rstrip('\n')
				#targe_line = targe_line.rstrip('\n')
				f_out.write("{0}\t{1}".format(source_line, targe_line))

	else:
		with open(args.corpus, 'r') as f_in_source, open(args.output+".source", 'w') as f_out_source, open(args.output+".target",'w') as f_out_target:
			content = f_in_source.readlines()

			for line in content:
				
				temp = line.split('\t')
				
				f_out_target.write(temp[-1])
				
				source_line = "{0}\n".format(temp[0])
				f_out_source.write(source_line)

if __name__ == "__main__": 
	main()