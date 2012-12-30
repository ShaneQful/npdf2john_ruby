#!/usr/bin/ruby

#Hacky have to find a better way
#All bugs come from here :(
$escape_seq_map = Hash['\n' => "\n", '\s' => "\s", '\e' => "\e", '\t' => "\t", '\v' => "\v", '\f' => "\f", '\b' => "\b", '\a' => "\a", '\e' => "\e", "\\(" => "(", "\\\\" => "\\" ]

class PdfParser
	def initialize file_name
		file = File.open(file_name,'rb')
		@encrypted = ''
		file.readlines.each do |line|
			@encrypted += line
		end
	end
	
	def parse
		trailer = get_trailer
		encryption_dictionary = get_encryption_dictionary(get_encrypted_object_id(trailer))
		output_for_JtR = "$npdf$"
		v = encryption_dictionary[/\/V \d/][/\d/]
		r = encryption_dictionary[/\/R \d/][/\d/]
		length =  encryption_dictionary[/\/Length \d+/][/\d+/]
		p_ = encryption_dictionary[/\/P -\d+/][/-\d+/] #p is a key word in ruby
		output_for_JtR += "#{v}*#{r}*#{length}*#{p_}*1*"
		#TODO: What the don't know what this 1 is supposed to be
		id = trailer[/\/ID\s*\[\s*<\w+>\s*<\w+>\s*\]/].scan /<\w+>/
		#Just taking the first on because that's what the old npdf2john does but it may not be the correct way to go
		id = id[0]
		id.delete! "<"
		id.delete! ">"
		output_for_JtR += "#{id.size/2}*#{id.downcase}*"
# 		puts encryption_dictionary
# 		puts trailer
# 		puts output_for_JtR
		output_for_JtR += get_passwords_for_JtR encryption_dictionary
		return output_for_JtR
	end

	private
	
	def get_trailer #Manual search as regexs all broke on later specifications
		trailer = ""
		inside_trailer = false
		lines = @encrypted.split "\n"
		lines.each do |line|
			inside_trailer = inside_trailer || line.include?("trailer")
			if(inside_trailer)
				trailer += line
				if(line.include? ">>")
					break
				end
			end
		end
		if(trailer == "" || !trailer.include?("Encrypt") )
			raise "File not encrypted"
		end
		return trailer
	end
	
	def get_encrypted_object_id trailer
		object_id = trailer[/\/Encrypt\s\d+\s\d\sR/]
		object_id = object_id[/\d+ \d/]
		return object_id
	end
	
	def get_encryption_dictionary object_id
		encryption_dictionary = @encrypted[/#{Regexp.quote(object_id)}\sobj(\s|\S)+endobj/]
		return encryption_dictionary
	end
	
	def get_passwords_for_JtR encryption_dictionary
		output = ""
		["U","O"].each do |let|
			pass = encryption_dictionary[/\/#{Regexp.quote(let)}\([^)]+\)/]
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
		o_or_u.size.times do |i|
			if(![0,1,2].include? i)
				if(o_or_u[i].to_s(16).size == 1 && o_or_u[i] != "\\"[0])
					pass += "0"
				end
				if(o_or_u[i] != "\\"[0] || escape_seq)
					if(escape_seq)
						esc = "\\"+o_or_u[i].chr
						esc = $escape_seq_map[esc]#esc nil need a better way of dealing with od chars
						if(esc[0].to_s(16).size == 1)
							pass += "0"
						end
						pass += esc[0].to_s(16)
						escape_seq = false
					else
						pass += o_or_u[i].to_s(16)#need to be 2 digit hex numbers
					end
				else
					escape_seq = true
					escapes += 1
				end
			end
		end
		"#{o_or_u.size-4-escapes}*#{pass.chop.chop}"
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
# parser = PdfParser.new ARGV[0]
# puts ARGV[0]+":#{parser.parse}"