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
		object_id = self.get_encrypted_object_id(trailer)
		encryption_dictionary = self.get_encryption_dictionary(object_id)
		output_for_JtR = '$npdf$'
		dr = re.compile('\d+')
		vr = re.compile('\/V \d')
		rr = re.compile('\/R \d')
		v = dr.findall(vr.findall(encryption_dictionary)[0])[0]
		r = dr.findall(rr.findall(encryption_dictionary)[0])[0]
		lr = re.compile('\/Length \d+')
		longest = 0
		length = ''
		for len in lr.findall(encryption_dictionary):
			if(int(dr.findall(len)[0]) > longest):
				longest = int(dr.findall(len)[0])
				length = dr.findall(len)[0]
		pr = re.compile('\/P -\d+')
		p = pr.findall(encryption_dictionary)[0]
		pr = re.compile('-\d+')
		p = pr.findall(encryption_dictionary)[0]
		meta = self.is_meta_data_encrypted(encryption_dictionary)
		print meta

	def is_meta_data_encrypted(self, encryption_dictionary):
		mr = re.compile('\/EncryptMetadata\s\w+')
		if(len(mr.findall(encryption_dictionary)) > 0):
			wr = re.compile('\w+')
			is_encrypted = wr.findall(mr.findall(encryption_dictionary)[0])[-1]
			if(is_encrypted == "false"):
				return "0"
			else:
				return "1"
		else:
			return "1"

	def get_encryption_dictionary(self,object_id):
		encryption_dictionary = self.get_data_between(object_id+" obj", "endobj")
		for o in encryption_dictionary.split("endobj"):
			if(object_id+" obj" in o):
				encryption_dictionary = o
		return encryption_dictionary

	def get_encrypted_object_id(self,trailer):
		oir = re.compile('\/Encrypt\s\d+\s\d\sR')
		object_id = oir.findall(trailer)[0]
		oir = re.compile('\d+ \d')
		object_id = oir.findall(object_id)[0]
		return object_id

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