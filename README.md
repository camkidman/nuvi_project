### Redis pusher
I wasn't fully sure what was expected, so I just wrote a little ruby script that does what the instructions asked for.

It also maintains a list of URLs from the articles so we can check if an article has been added before by URL. 

### The dataset
I found out the data set in the target URL is *tremendously large*, so I modified the script so it looped through the first 5 zip files from the given URL, here are the results:

First run:

```
I, [2016-12-08T11:16:59.268303 #2221]  INFO -- : Added 8657 articles to the NEWS_XML list
I, [2016-12-08T11:16:59.268361 #2221]  INFO -- : Skipped 14582 articles
I, [2016-12-08T11:16:59.268617 #2221]  INFO -- : Total articles: 8657
```

Second run:

```
I, [2016-12-08T11:21:42.804449 #2333]  INFO -- : Added 0 articles to the NEWS_XML list
I, [2016-12-08T11:21:42.804508 #2333]  INFO -- : Skipped 19795 articles
I, [2016-12-08T11:21:42.804713 #2333]  INFO -- : Total articles: 8657
```

So it shouldn't duplicate articles (at least with checking uniqueness on the URL).

### Variations

There are a few different ways we could change this, depending on the requirements:

1. The saved "urls" redis set can be deleted between each run if we're confident the data sets will have entirely different articles-- this will save memory on the redis server
2. The logging device could stand to be something other than `STDOUT`
3. I'm not too familiar with redis passwords and auth, so I'm sure there can be more done in the validation section
4. Instead of a ruby script this could've been a rails app for someone to paste the URL into, authentication, etc. We could really get crazy with the cheese-whiz depending on what's needed for the project, but any dev should be able to run this

### Follow-up

I'd be happy to have any feedback on this script, so please let me know if there was something I could've done better!
