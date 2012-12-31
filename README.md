npdf2john_ruby
==============

A re-write of npdf2john in ruby which will be ported to python for JtR once finished

Currently working for the <= 1.6 pdf specification still need work to get 1.7 specification working


#### Current Issues:
* Need a better way of dealing with escaped chars
	* Currently using a hash map to replace them bugs will occur if char not in the map
* Need to get 1.7 onwards fully working 
* Investigate how the 1.7 standard works and how it differs from 1.6 & 1.4

#### Test:
```
diff <(./npdf2john-master/npdf2john pdfs/*) <(ruby npdf2john.rb pdfs/*) | wc -l
```