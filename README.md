npdf2john_ruby
==============

A re-write of npdf2john in ruby which will be ported to python for JtR once finished

Works for all test pdfs available in john's sample non-hashes

#### Current Issues:

* Need a better way of dealing with escaped chars
	* Currently using a hash map to replace them bugs will occur if char not in the map

#### Test:
```
diff <(./npdf2john-master/npdf2john pdfs/*) <(ruby npdf2john.rb pdfs/*) | wc -l
```