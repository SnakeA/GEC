lines_set=set()

with open("scoreHigh.out") as file_score:
	for line in file_score:
		lines_set.add(int(line.split('\t')[0]))

print len(lines_set)

with open("lang8.lc.cor") as file_in, open("out",'w') as file_out:
    for i, line in enumerate(file_in):
    	if (i+1) in lines_set:
    		file_out.write(line)
