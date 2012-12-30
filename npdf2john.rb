#!/usr/bin/ruby

file = File.open(ARGV[0],'rb')
encrypted = ''
file.readlines.each do |line|
	encrypted += line
end

#get_trailer
trailer = encrypted[/trailer\s<<(\s|\S)*\/Encrypt(\s|\S)*>>/]
if(trailer == nil)
	abort "File not encrypted"
end
#get_encrypted_object_id
object_id = trailer[/\/Encrypt\s\d+\s\d\sR/]
object_id = object_id[/\d+ \d/]

#get_encryption_dictionary
encryption_dictionary = encrypted[/#{Regexp.quote(object_id)}\sobj(\s|\S)+endobj/]

#get_passwords
u = encryption_dictionary[/\/U\((\s|\S)+\)/]
puts u[3]
puts u.size-4

o = encryption_dictionary[/\/O\([^)]+\)/]
puts o[3]
puts o.size-4
#JtR npdf format:
=begin
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
