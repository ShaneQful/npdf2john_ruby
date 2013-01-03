#!/usr/bin/ruby

#Hacky have to find a better way
#All bugs come from here :(
$escape_seq_map = Hash['\n' => "\n", '\s' => "\s", '\e' => "\e", '\r' => "\r", '\t' => "\t", '\v' => "\v", '\f' => "\f", '\b' => "\b", '\a' => "\a", '\e' => "\e", "\\)" => ")", "\\(" => "(", "\\\\" => "\\" ]

class PdfParser
	def initialize file_name
		file = File.open(file_name,'rb')
		@encrypted = ''
		file.readlines.each do |line|
			@encrypted += line
		end
		@pdf_spec = @encrypted[/PDF-\d\.\d/]
	end
	
	def parse
		trailer = get_trailer
		object_id = get_encrypted_object_id(trailer)
		encryption_dictionary = get_encryption_dictionary(object_id)
		output_for_JtR = "$npdf$"
		v = encryption_dictionary[/\/V \d/][/\d/]
		r = encryption_dictionary[/\/R \d/][/\d/]
		longest = 0
		length = ""
		# Not sure which length I should be taking but longest seems to line up with
		# old npdf2john
		encryption_dictionary.scan(/\/Length \d+/).each do |len|
			if(len[/\d+/].to_i > longest)
				longest = len[/\d+/].to_i
				length = len[/\d+/]
			end
		end
		p_ = encryption_dictionary[/\/P -\d+/][/-\d+/] #p is a key word in ruby
		meta = is_meta_data_encrypted(encryption_dictionary)
		output_for_JtR += "#{v}*#{r}*#{length}*#{p_}*#{meta}*"
		id = trailer[/\/ID\s*\[\s*<\w+>\s*<\w+>\s*\]/].scan /<\w+>/
		# Just taking the first one because that's what the old npdf2john does 
		# but it may not be the correct way to go
		id = id[0]
		id.delete! "<"
		id.delete! ">"
		output_for_JtR += "#{id.size/2}*#{id.downcase}*"
		output_for_JtR += get_passwords_for_JtR(encryption_dictionary)
		return output_for_JtR
	end

	private
	
	def is_meta_data_encrypted encryption_dictionary
		encryption_dictionary[/\/EncryptMetadata\s\w+/]
		if(encryption_dictionary[/\/EncryptMetadata\s\w+/])
			is_encrypted = encryption_dictionary[/\/EncryptMetadata\s\w+/].scan(/\w+/)[-1]
			if(is_encrypted == "false")
				return "0"
			else
				return "1"
			end
		else
			return "1"
		end
	end
	
	#Uses search as original regexs all broke on later specifications
	#May change back to regexs later if I make a more robust one
	def get_trailer 
		trailer = get_data_between "trailer", ">>"
		if(trailer == "")
			trailer = get_data_between "DecodeParms", "stream"
			if(trailer == "")
				raise "Can't find trailer"
			end
		end
		if(trailer != "" && !trailer.include?("Encrypt") )
			raise "File not encrypted"
		end
		return trailer
	end
	
	def get_data_between s1, s2
		output = ""
		inside_first = false
		lines = @encrypted.split "\n"
		lines.each do |line|
			inside_first = inside_first || line.include?(s1)
			if(inside_first)
				output += line
				if(line.include? s2)
					break
				end
			end
		end
		return output
	end
	
	def get_encrypted_object_id trailer
		object_id = trailer[/\/Encrypt\s\d+\s\d\sR/]
		object_id = object_id[/\d+ \d/]
		return object_id
	end
	
	def get_encryption_dictionary object_id
		encryption_dictionary = get_data_between "#{object_id} obj", "endobj"
		encryption_dictionary.split("endobj").each do |object|
			if(object.include? "#{object_id} obj")
				encryption_dictionary = object
			end
		end
		return encryption_dictionary
	end
	
	def get_passwords_for_JtR encryption_dictionary
		output = ""
		letters = ["U","O"]
		if(@pdf_spec.include? "1.7")
			letters = ["U","O","UE","OE"]
		end
		letters.each do |let|
			pass = encryption_dictionary[/\/#{Regexp.quote(let)}\((\\\)|[^)])+\)/]
			if(pass)
				output +=  "#{get_password_from_byte_string pass}*"
			else
				pass = encryption_dictionary[/\/#{Regexp.quote(let)}\s*<\w+>/][/<\w+>/]
				pass.delete! "<"
				pass.delete! ">"
				output += "#{pass.size/2}*#{pass.downcase}*"
			end
		end
		return output.chop
	end
	
	def get_password_from_byte_string o_or_u
		pass = ""
		escape_seq = false
		escapes = 0
		excluded_indexes = [0,1,2]
		#For UE & OE in 1.7 spec
		if(o_or_u[2] != "("[0])
			excluded_indexes.push 3
		end
		o_or_u.size.times do |i|
			if(!excluded_indexes.include? i)
				if(o_or_u[i].to_s(16).size == 1 && o_or_u[i] != "\\"[0])
					pass += "0"#need to be 2 digit hex numbers
				end
				if(o_or_u[i] != "\\"[0] || escape_seq)
					if(escape_seq)
						esc = "\\"+o_or_u[i].chr
						#need a better way of dealing with escaped chars
						esc = $escape_seq_map[esc]
						if(esc[0].to_s(16).size == 1)
							pass += "0"
						end
						pass += esc[0].to_s(16)
						escape_seq = false
					else
						pass += o_or_u[i].to_s(16)
					end
				else
					escape_seq = true
					escapes += 1
				end
			end
		end
		"#{o_or_u.size-(excluded_indexes.size+1)-escapes}*#{pass.chop.chop}"
	end
end

ARGV.each do |arg|
	begin
		parser = PdfParser.new arg
		puts arg+":#{parser.parse}"
	rescue => e
		puts arg+":"+e.message
	end
end
#For debugging purposes:
# parser = PdfParser.new ARGV[0]
# puts ARGV[0]+":#{parser.parse}"