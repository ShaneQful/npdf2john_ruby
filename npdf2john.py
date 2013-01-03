#!/usr/bin/env python

import re
import sys

class PdfParser:
	def __init__(self,file_name):
		f = open(file_name, 'r')
		self.encrypted = f.read()
		f.close()
		psr = re.compile('PDF-\d\.\d')
		self.pdf_spec = psr.findall(self.encrypted)[0]

	def parse(self):
		trailer = self.get_trailer()
		print trailer

	def get_trailer(self):
		trailer = self.get_data_between("trailer", ">>")
		if(trailer == ""):
			trailer = self.get_data_between("DecodeParms", "stream")
			if(trailer == ""):
				raise "Can't find trailer"
		if(trailer != "" and trailer.find("Encrypt") == -1):
			raise "File not encrypted"
		return trailer
		
	def get_data_between(self,s1, s2):
		output = ""
		inside_first = False
		lines = self.encrypted.split('\n')
		for line in lines:
			inside_first = inside_first or line.find(s1) != -1
			if(inside_first):
				output += line
				if(line.find(s2) != -1):
					break
		return output


c = 0
for arg in sys.argv:
	if(c != 0):
		parser = PdfParser(arg)
		parser.parse()
	c+=1