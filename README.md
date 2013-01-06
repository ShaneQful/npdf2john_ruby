npdf2john_ruby
==============

A re-write of npdf2john in ruby which has also been ported to python for JtR

Works for all test pdfs available in john's sample non-hashes

#### Current Issues:

* Need a better way of dealing with escaped chars
	* Currently using a hash map to replace them bugs will occur if char not in the map

#### Test:
```
diff <(./npdf2john-master/npdf2john pdfs/*) <(ruby npdf2john.rb pdfs/*) | wc -l
```

#### License:

* This software is MIT licensed see link for details

* http://www.opensource.org/licenses/MIT

* If you want to add npdf2john.rb to john itself please feel free to disregard the license.
