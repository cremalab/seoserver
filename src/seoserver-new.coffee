express = require('express')
memcached = require('memcached')
$ = require('jquery')
logentries = require('node-logentries')

class SeoServer

  config:
    host: 'http://moviepilot.com'
    default_port: 10300
    memcached:
      enabled: true
      default_host: 'localhost'
      default_port: 11211
      max_value: 2097152
      connect_retries: 5
      key: 'moviepilot.com'
    logentries:
      enabled: true
      token: '25ebab68-8d2f-4382-a28c-7ed0a3cd255e'

  constructor: ->
    #@initLogentries()
    memcached = @initMemcached()

    memcached.fail (error) ->
      console.log(error)
    memcached.done (connection) =>
      console.log "Connected to memcached"
    memcached.always =>
      @startServer()

  startServer: =>
    console.log("Express server started at port #{@config.default_port}")
    @app = express()
    @app.get(/(.*)/, @responseHandler)
    @app.listen(@config.default_port)

  responseHandler: (request, response) =>
    @timer = 0
    @now = +new Date()
    @fetchPage(request, response).done @deliverResponse

  fetchPage: (request, response) ->
    dfd = $.Deferred()
    url = @config.host + request.url

    if @memcachedClient
      fetchDfd = @fetchFromMemcached(request, response)
    else
      fetchDfd = @fetchFromPhantom(url)

    fetchDfd.done (url, response, headers, content) =>
      @setCache(request, headers, content)
      dfd.resolve(url, response, headers, content)

    dfd.promise()

  setCache: (request, headers, content) =>
    return unless @memcachedClient
    if headers.status is 301
      content = "301 #{headers.location}"

    uri = @config.host + request.path
    key = @config.memcached.key + uri

    if  headers.status >= 200 and (headers.status < 300 or headers.status == 301)
      @memcachedClient.set key, content, 0, (err) ->
        console.log err

  deliverResponse: (url, response, headers, content) =>
    response.status(headers.status or 500)
    response.header("Access-Control-Allow-Origin", "*")
    response.header("Access-Control-Allow-Headers", "X-Requested-With")
    if headers.location?
      response.set('Location', headers.location)
      response.send('')
    else
      console.log(content)
      response.send(content)

  fetchFromMemcached: (request, response) ->
    dfd = $.Deferred()
    url = @config.host + request.url
    uri = @config.host + request.path
    key = @config.memcached.key + uri
    clearCache = request.query.plan is 'titanium'
    @memcachedClient.get key, (error, cachedContent) =>
      if error
        return dfd.reject("memcached error: #{error}")
      if cachedContent and not clearCache
        headers = {}
        if /^301/.test(cachedContent)
          matches = cachedContent.match(/\s(.*)$/)
          response.status(301)
          headers.location = matches[1]
        dfd.resolve(url, response, headers, cachedContent)
      else
        @fetchFromPhantom(url).done dfd.resolve
    dfd.promise()

  fetchFromPhantom: (url) ->
    dfd = $.Deferred()
    timeout = null
    headers = {}
    content = ''

    phantom = require('child_process').
      spawn('phantomjs', [__dirname + '/phantom-server.js', url])

    timeout = setTimeout ->
      phantom.kill()
    , 30000

    phantom.stdout.on 'data', (data) ->
      data = data.toString()
      if match = data.match(/({.*?})\n\n/)
        response = JSON.parse(match[1])
        headers.status = response.status unless headers.status
        headers.location = response.redirectURL if response.status is 301
        data = data.replace(/(.*?)\n\n/, '')
      if data.match(/^\w*error/i)
        headers.status = 503
        console.log "Phantom js error: " + data.toString()
      else
        content += data.toString()

    phantom.stderr.on 'data', (data) ->
      console.log 'stderr: ' + data

    phantom.on 'exit', (code) =>
      clearTimeout(timeout)
      if code
        console.log('Error on Phantomjs process')
        dfd.fail()
      else
        content = @removeScriptTags(content)
        dfd.resolve(url, {}, headers, content)

    dfd.promise()

  initMemcached: ->
    dfd = $.Deferred()

    unless @config.memcached.enabled
      dfd.reject('memcached is disabled')
      return dfd.promise()

    memcached.config.retries = @config.memcached.connect_retries
    memcached.config.maxValue = @config.memcached.max_value

    server = "#{@config.memcached.default_host}:#{@config.memcached.default_port}"
    client = new memcached(server)

    client.on 'failure', (details) ->
      error = "Memcached connection failure on: #{details.server}
        due to: #{details.messages.join(' ')}"
      dfd.reject(error)
    client.on 'reconnecting', (details) ->
      console.log("memcached: Total downtime caused by server
       #{details.server} : #{details.totalDownTime} ms")

    console.log("Trying to connect to memcached server #{server}")

    client.connect server, (error, connection) =>
      if error
        dfd.reject(error)
      else
        @memcachedClient = client
        dfd.resolve()
    dfd.promise()

  logResponse: ->
    # moved into helper
    crawler = if /RedSnapper/.test(request.headers['user-agent'])
      'Crawler'
    else
      'GoogleBot'

  removeScriptTags: (content) ->
    content.replace(/<script[\s\S]*?<\/script>/gi, '')

new SeoServer()
