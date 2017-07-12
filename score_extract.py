# The script reads the top-N (if specified) or all the line numbers from the score file
# and then goes through the actual corpus(monolingual or bilingual), extracting those lines to the output file

__author__ = 'Angelos Constantinides'
import sys
import argparse

def main():

	parser = argparse.ArgumentParser()
	parser.add_argument("score", help="The name of the file containing the score of each sentence")
	parser.add_argument("corpus", help="The name of the file that contains the coprpus")
	parser.add_argument("output", help="The name of the file that the extracted sentences will be written to")
	args = parser.parse_args()

	
	score_fileName = args.score
	corpus_fileName = args.corpus
	output_fileName = args.output
	
	lines_set=set()

	# Read Scores
	with open(score_fileName,'r') as file_score:
		for line in file_score:
			lines_set.add(int(line.split('\t')[0]))


	with open(corpus_fileName,'r') as file_in, open(output_fileName,'w') as file_out:


		for i, line in enumerate(file_in, start=1):
			if i in lines_set:
				file_out.write(line)

if __name__ == "__main__": 
	main()