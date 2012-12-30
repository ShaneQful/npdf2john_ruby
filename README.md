npdf2john_ruby
==============

A re-write of npdf2john in ruby which will be ported to python for JtR once finished

Currently only working for the 1.4 pdf specification and for some document in the 1.6-1.7 specification


#### Current Issues:
* Need a better way of dealing with escaped chars
* Need to get 1.6 onwards fully working 
* Have to look for decode params because trailer may not exist

#### Test:
```
diff <(./npdf2john-master/npdf2john pdfs/*) <(ruby npdf2john.rb pdfs/*) | wc -l
```