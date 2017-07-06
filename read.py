corpus_stem="train"
with open("{}.txt".format(corpus_stem)) as f, open("{}.cor".format(corpus_stem),'w') as f2, open("{}.err".format(corpus_stem),'w') as f3:
    content = f.readlines()

    for line in content:
    	line = line.strip()
	temp = line.split('\t')
	line = temp[-1]
    	line = line+'\n'
    	f2.write(line)
	line2 = temp[0]
	line2 = line2+'\n'
	f3.write(line2)
