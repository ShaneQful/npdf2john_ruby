#!/usr/bin/ruby

class PdfParser
	def initialize file_name
		file = File.open(file_name,'rb')
		@encrypted = ''
		file.readlines.each do |line|
			@encrypted += line
		end
	end
	
	def parse
		@trailer = get_trailer
		@encryption_dictionary = get_encryption_dictionary(get_encrypted_object_id(@trailer))
		output_for_JtR = "$npdf$"
		v = @encryption_dictionary[/\/V \d\//][/\d/]
		r = @encryption_dictionary[/\/R \d\//][/\d/]
		length =  @encryption_dictionary[/\/Length \d+\//][/\d+/]
		p_ = @encryption_dictionary[/\/P -\d+/][/-\d+/] #p is a key word in ruby
		output_for_JtR += "#{v}*#{r}*#{length}*#{p_}*1*"
		#TODO: What the don't know what this 1 is supposed to be
		id = @trailer[/\/ID \[ <\w+>\s<\w+> \]/].scan /<\w+>/
		if(id[0] == id[1])
			id = id[0]
			id.delete! "<"
			id.delete! ">"
		else
			puts "Something may have gone wrong"
		end
		output_for_JtR += "#{id.size/2}*#{id}*"
		u = @encryption_dictionary[/\/U\([^)]+\)/]
		output_for_JtR += (get_passwords_for_JtR u)+"*"
		o = @encryption_dictionary[/\/O\([^)]+\)/]
		output_for_JtR += get_passwords_for_JtR o
		return output_for_JtR
	end

	private
	
	def get_trailer
		trailer = @encrypted[/trailer\s<<(\s|\S)*\/Encrypt(\s|\S)*>>/]
		if(trailer == nil)
			abort "File not encrypted"
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
		o_or_u.size.times do |i|
			if(![0,1,2,35].include? i)# && o[i] != o[-1])
				pass += o_or_u[i].to_s(16)
			end
		end
		"#{o_or_u.size-4}*#{pass}"
	end
end

parser = PdfParser.new ARGV[0]
puts ARGV[0]+":#{parser.parse}"
