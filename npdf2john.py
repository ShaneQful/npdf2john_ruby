#!/usr/bin/env python

# Copyright (c) 2013 Shane Quigley, < shane at softwareontheside.info >

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

import re
import sys

PY3 = sys.version_info[0] == 3

class PdfParser:
    def __init__(self, file_name):
        self.file_name = file_name
        f = open(file_name, 'rb')
        self.encrypted = f.read()
        f.close()
        self.process = True
        psr = re.compile(b'PDF-\d\.\d')
        try:
            self.pdf_spec = psr.findall(self.encrypted)[0]
        except IndexError:
            sys.stderr.write("%s is not a PDF file!\n" % file_name)
            self.process = False

    def parse(self):
        if not self.process:
            return

        try:
            trailer = self.get_trailer()
        except RuntimeError:
            e = sys.exc_info()[1]
            sys.stdout.write("%s : %s\n" % (self.file_name, str(e)))
            return
        object_id = self.get_encrypted_object_id(trailer)
        encryption_dictionary = self.get_encryption_dictionary(object_id)
        dr = re.compile(b'\d+')
        vr = re.compile(b'\/V \d')
        rr = re.compile(b'\/R \d')
        v = dr.findall(vr.findall(encryption_dictionary)[0])[0]
        r = dr.findall(rr.findall(encryption_dictionary)[0])[0]
        lr = re.compile(b'\/Length \d+')
        longest = 0
        length = ''
        for le in lr.findall(encryption_dictionary):
            if(int(dr.findall(le)[0]) > longest):
                longest = int(dr.findall(le)[0])
                length = dr.findall(le)[0]
        pr = re.compile(b'\/P -\d+')
        p = pr.findall(encryption_dictionary)[0]
        pr = re.compile(b'-\d+')
        p = pr.findall(p)[0]
        meta = self.is_meta_data_encrypted(encryption_dictionary)
        idr = re.compile(b'\/ID\s*\[\s*<\w+>\s*<\w+>\s*\]')
        try:
            i_d = idr.findall(trailer)[0] # id key word
        except IndexError:
            # some pdf files use () instead of <>
            idr = re.compile(b'\/ID\s*\[\s*\(\w+\)\s*\(\w+\)\s*\]')
            i_d = idr.findall(trailer)[0] # id key word
        idr = re.compile(b'<\w+>')
        try:
            i_d = idr.findall(trailer)[0]
        except IndexError:
            idr = re.compile(b'\(\w+\)')
            i_d = idr.findall(trailer)[0]
        i_d = i_d.replace(b'<',b'')
        i_d = i_d.replace(b'>',b'')
        i_d = i_d.lower()
        passwords = self.get_passwords_for_JtR(encryption_dictionary)
        output = self.file_name+':$pdf$'+v.decode('ascii')+'*'+r.decode('ascii')+'*'+length.decode('ascii')+'*'
        output += p.decode('ascii')+'*'+meta+'*'
        output += str(int(len(i_d)/2))+'*'+i_d.decode('ascii')+'*'+passwords
        sys.stdout.write("%s\n" % output)

    def get_passwords_for_JtR(self, encryption_dictionary):
        output = ""
        letters = [b"U", b"O"]
        if(b"1.7" in self.pdf_spec):
            letters = [b"U", b"O", b"UE", b"OE"]
        for let in letters:
            pr_str = b'\/' + let + b'\s*\([^)]+\)'
            pr = re.compile(pr_str)
            pas = pr.findall(encryption_dictionary)
            if(len(pas) > 0):
                pas = pr.findall(encryption_dictionary)[0]
                #Because regexs in python suck
                while(pas[-2] == '\\'):
                    pr_str += b'[^)]+\)'
                    pr = re.compile(pr_str)
                    pas = pr.findall(encryption_dictionary)[0]
                output +=  self.get_password_from_byte_string(pas)+"*"
            else:
                pr = re.compile(let + b'\s*<\w+>')
                pas = pr.findall(encryption_dictionary)[0]
                pr = re.compile(b'<\w+>')
                pas = pr.findall(pas)[0]
                pas = pas.replace(b"<",b"")
                pas = pas.replace(b">",b"")
                if PY3:
                    output += str(int(len(pas)/2))+'*'+str(pas.lower(),'ascii')+'*'
                else:
                    output += str(int(len(pas)/2))+'*'+pas.lower()+'*'
        return output[:-1]

    def is_meta_data_encrypted(self, encryption_dictionary):
        mr = re.compile(b'\/EncryptMetadata\s\w+')
        if(len(mr.findall(encryption_dictionary)) > 0):
            wr = re.compile(b'\w+')
            is_encrypted = wr.findall(mr.findall(encryption_dictionary)[0])[-1]
            if(is_encrypted == "false"):
                return "0"
            else:
                return "1"
        else:
            return "1"

    def get_encryption_dictionary(self, object_id):
        encryption_dictionary = \
                self.get_data_between(object_id+b" obj", b"endobj")
        for o in encryption_dictionary.split(b"endobj"):
            if(object_id+b" obj" in o):
                encryption_dictionary = o
        return encryption_dictionary

    def get_encrypted_object_id(self, trailer):
        oir = re.compile(b'\/Encrypt\s\d+\s\d\sR')
        object_id = oir.findall(trailer)[0]
        oir = re.compile(b'\d+ \d')
        object_id = oir.findall(object_id)[0]
        return object_id

    def get_trailer(self):
        trailer = self.get_data_between(b"trailer", b">>")
        if(trailer == b""):
            trailer = self.get_data_between(b"DecodeParms", b"stream")
            if(trailer == ""):
                raise RuntimeError("Can't find trailer")
        if(trailer != "" and trailer.find(b"Encrypt") == -1):
            print(trailer)
            raise RuntimeError("File not encrypted")
        return trailer

    def get_data_between(self, s1, s2):
        output = b""
        inside_first = False
        lines = self.encrypted.split(b'\n')
        for line in lines:
            inside_first = inside_first or line.find(s1) != -1
            if(inside_first):
                output += line
                if(line.find(s2) != -1):
                    break
        return output

    def get_hex_byte(self, o_or_u, i):
        if PY3:
            return hex(o_or_u[i]).replace('0x', '')
        else:
            return hex(ord(o_or_u[i])).replace('0x', '')

    def get_password_from_byte_string(self, o_or_u):
        pas = ""
        escape_seq = False
        escapes = 0
        excluded_indexes = [0, 1, 2]
        #For UE & OE in 1.7 spec
        if(o_or_u[2] != '('):
            excluded_indexes.append(3)
        for i in range(len(o_or_u)):
            if(i not in excluded_indexes):
                if(len(self.get_hex_byte(o_or_u, i)) == 1 \
                   and o_or_u[i] != "\\"[0]):
                    pas += "0"  # need to be 2 digit hex numbers
                if(o_or_u[i] != "\\"[0] or escape_seq):
                    if(escape_seq):
                        esc = "\\"+o_or_u[i]
                        esc = self.unescape(esc)
                        if(len(self.get_hex_byte(o_or_u, i)) == 1):
                            pas += "0"
                        pas += self.get_hex_byte(o_or_u, i)
                        escape_seq = False
                    else:
                        pas += self.get_hex_byte(o_or_u, i)
                else:
                    escape_seq = True
                    escapes += 1
        output = len(o_or_u)-(len(excluded_indexes)+1)-escapes
        return str(output)+'*'+pas[:-2]

    def unescape(self, esc):
        escape_seq_map = {'\\n':"\n", '\\s':"\s", '\\e':"\e",
                '\\r':"\r", '\\t':"\t", '\\v':"\v", '\\f':"\f",
                '\\b':"\b", '\\a':"\a", "\\)":")",
                "\\(":"(", "\\\\":"\\" }

        return escape_seq_map[esc]


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.stderr.write("Usage: %s <PDF file(s)>\n" % \
                         sys.argv[0])
        sys.exit(-1)
    for j in range(1, len(sys.argv)):
        # sys.stderr.write("Analyzing %s\n" % sys.argv[j])
        parser = PdfParser(sys.argv[j])
        parser.parse()
