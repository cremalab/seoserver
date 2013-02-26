### Welcome!
Seo Server is a command line tool that runs a server that allows GoogleBot(and any other crawlers) to crawl your heavily Javascript built websites. The tool works with very little changes to your server or client side code.


### How it works
<img src="http://yuml.me/5b1b60bb" />

Seo Server runs <a href="http://phantomjs.org/">PhantomJs</a>(headless webkit browser) which renders the page fully and returns the fully executed code to GoogleBot.

### Getting started
* Install npm dependencies <br/>
<code>sudo npm install -g seoserver</code>
* Start the main process on port 10300 and with default memcached conf:<br/>
<code>bin/seoserver start -p 10300</code>


### Internals
The crawler has three parts:

**lib/phantom-server.js** A small js file loaded into PhantomJS, for grabbing the webpage and returning the response along with the headers in serialized form. Can be executed via:

<code>phantomjs lib/phantom-server.js http://moviepilot.com/stories</code>

**lib/seoserver.js** An express node server, accepting the requests, poking memcached for a cached version of the page, otherwise calling phantom-server.js to fetch the content and return the response. You can start it locally by:

<code>node lib/seoserver.js 10300 \<memcached-host\></code>

And test it by:

<code>curl -v http://localhost:10300/stories</code>

**bin/seoserver** Forever-monitor script, for launching and monitoring the main process.

<code>bin/seoserver start -p 10300</code>
