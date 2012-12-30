#!/usr/bin/ruby

#Hacky have to find a better way
$escape_seq_map = Hash['\n' => "\n", '\s' => "\s", '\e' => "\e", '\t' => "\t", '\v' => "\v", '\f' => "\f", '\b' => "\b", '\a' => "\a", '\e' => "\e", '\\' => "\\" ]

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
		v = encryption_dictionary[/\/V \d\//][/\d/]
		r = encryption_dictionary[/\/R \d\//][/\d/]
		length =  encryption_dictionary[/\/Length \d+\//][/\d+/]
		p_ = encryption_dictionary[/\/P -\d+/][/-\d+/] #p is a key word in ruby
		output_for_JtR += "#{v}*#{r}*#{length}*#{p_}*1*"
		#TODO: What the don't know what this 1 is supposed to be
		id = trailer[/\/ID \[ <\w+>\s<\w+> \]/].scan /<\w+>/
		if(id[0] == id[1])
			id = id[0]
			id.delete! "<"
			id.delete! ">"
		else
			puts "Something may have gone wrong"
		end
		output_for_JtR += "#{id.size/2}*#{id.downcase}*"
		u = encryption_dictionary[/\/U\([^)]+\)/]
		output_for_JtR += (get_passwords_for_JtR u)+"*"
		o = encryption_dictionary[/\/O\([^)]+\)/]
		puts o[-2].to_s(16)
		puts o[-3].chr
		output_for_JtR += get_passwords_for_JtR o
# 		puts o[21].chr
# 		puts  get_passwords_for_JtR o
		return output_for_JtR
	end

	private
	
	def get_trailer
		trailer = @encrypted[/trailer\s<<(\s|\S)*\/Encrypt(\s|\S)*>>/]
		if(trailer == nil)
# 			puts "File not encrypted"
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
	
	def get_passwords_for_JtR o_or_u
		pass = ""
		escape_seq = false
		escapes = 0
		o_or_u.size.times do |i|
			if(![0,1,2,35].include? i)# && o[i] != o[-1])
				if(o_or_u[i].to_s(16).size == 1 && o_or_u[i] != "\\"[0])
					pass += "0"
				end
				if(o_or_u[i] != "\\"[0] || escape_seq)
					if(escape_seq)
						esc = "\\"+o_or_u[i].chr
						esc = $escape_seq_map[esc]
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
		"#{o_or_u.size-4-escapes}*#{pass}"
	end
end

# ARGV.each do |arg|
# 	begin
# 		parser = PdfParser.new arg
# 		puts arg+":#{parser.parse}"
# 	rescue => e
# 		puts arg+":"+e.message
# 	end
# end
parser = PdfParser.new ARGV[0]
puts ARGV[0]+":#{parser.parse}"