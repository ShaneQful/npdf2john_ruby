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
		@encryption_dictionary = get_encryption_dictionary(get_encrypted_object_id)
	end
	
	def to_s
		@trailer+"\n"+@encryption_dictionary
	end
	private
	
	def get_trailer
		trailer = @encrypted[/trailer\s<<(\s|\S)*\/Encrypt(\s|\S)*>>/]
		if(trailer == nil)
			abort "File not encrypted"
		end
		return trailer
	end
	
	def get_encrypted_object_id
		object_id = @trailer[/\/Encrypt\s\d+\s\d\sR/]
		object_id = object_id[/\d+ \d/]
		return object_id
	end
	
	def get_encryption_dictionary object_id
		encryption_dictionary = @encrypted[/#{Regexp.quote(object_id)}\sobj(\s|\S)+endobj/]
		return encryption_dictionary
	end
end

parser = PdfParser.new ARGV[0]
parser.parse
puts parser.to_s

=begin
#get_passwords
u = encryption_dictionary[/\/U\((\s|\S)+\)/]
puts u[3]
puts u.size-4

o = encryption_dictionary[/\/O\([^)]+\)/]
owner_pass = ""
o.size.times do |i|
  if(![0,1,2,35].include? i)# && o[i] != o[-1])
    owner_pass += o[i].to_s(16)
  end
end
puts "#{o.size-4}*#{owner_pass}"
#JtR npdf format:
# =begin
$npdf$(/V)*(/R)*(/Length)*(/P)*1(FIK)*
16(guessing length of /ID in ascii ie half /ID.size)*(/ID from trailer)*
(length_of /O)*
hex_representation_of /O*
(length_of /U)*
hex_representation_of /U

both owner & user passwords 32 in length
both large hex numbers are 64 in length

puts "Trailer:"
puts trailer
puts
puts "Object ID:"
puts object_id
puts
puts "Encryption Dictionary:"
puts encryption_dictionary
=end
