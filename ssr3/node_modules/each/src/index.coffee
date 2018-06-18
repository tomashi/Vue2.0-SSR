
###
Each is an async iterator encapsultated in one elegant function. The execution
can be controlled over multiple functions accessible as a chained API.

each(elements)
.parallel(false|true|integer)
.sync(false)
.times(1)
.repeat(1)
.push(element)
.unshift(element)
.write(element)
.pause()
.resume()
.close()
.call(callback)
.error(callback)
.next(callback)
###
Each = (@_elements, @options={}) ->
  # @options, 
  # Arguments
  # if arguments.length is 1
  #   @_elements = @options
  #   @options = {}
  @options.concurrency = 1
  @options.repeat = false
  @options.sync = false
  @options.times = 1
  # Internal state
  type = typeof @_elements
  if @_elements is null or type is 'undefined'
    @_elements = []
  else if type is 'number' or type is 'string' or type is 'function' or type is 'boolean'
    @_elements = [@_elements]
  else unless Array.isArray @_elements
    isObject = true
  @_keys = Object.keys @_elements if isObject
  @_errors = []
  @_close = false
  @_endable = 1
  @_listeners = []
  # Public state
  @total = if @_keys then @_keys.length else @_elements.length
  @started = 0
  @done = 0
  @paused = 0
  @readable = true
  setImmediate =>
    @_run()
  @
Each.prototype._has_next_handler = ->
  @_listeners[0]?[0] is 'call'
Each.prototype._get_current_handler = ->
  throw Error 'No Found Handler' unless @_listeners[0]?[0] is 'call'
  @_listeners[0][1]
Each.prototype._call_next = (error, count) ->
  @_listeners.shift() while @_listeners[0]?[0] not in ['error', 'next', 'promise'] if error
  if @_listeners[0]?[0] is 'error'
    @_listeners[0][1].call null, error if error
    if @_listeners[1]?[0] is 'next'
      @_listeners.shift()
      @_listeners[0]?[1].call null, count unless error
    else if @_listeners[1]?[0] is 'promise'
      @_listeners[1][1].resolve.call null
    return
  if @_listeners[0]?[0] is 'next'
    @_listeners[0][1].call null, error, count
    if @_listeners[1]?[0] is 'promise'
      @_listeners[1][1].resolve.call null
    return
  if @_listeners[0]?[0] is 'promise'
    if error
    then @_listeners[0][1].reject.call null, error
    else @_listeners[0][1].resolve.call null
    return
  throw Error 'Invalid State: error or next not defined'
Each.prototype._run = () ->
  return if @paused
  handlers = @_get_current_handler() unless @_errors.length
  # This is the end
  error = null
  if @_endable is 1 and (@_close or (handlers and @done is @total * @options.times * handlers.length) or (@_errors.length and @started is @done) )
    @_listeners.shift()
    if @_errors.length or not @_has_next_handler()
      # Give a chance for end to be called multiple times
      @readable = false
      if @_errors.length
        if @options.concurrency isnt 1
          if @_errors.length is 1
            error = @_errors[0]
          else 
            error = new Error("Multiple errors (#{@_errors.length})")
            error.errors = @_errors
        else
          error = @_errors[0]
      else
        args = []
      @_call_next error, @done
      return
    handlers = @_get_current_handler()
    @_endable = 1
    @started = 0
    @done = 0
    @paused = 0
    @readable = true
  return if @_errors.length isnt 0
  while (if @options.concurrency is true then (@total * @options.times * handlers.length - @started) > 0 else Math.min( (@options.concurrency - @started + @done), (@total * @options.times * handlers.length - @started) ) )
    # Stop on synchronously sent error
    break if @_errors.length isnt 0
    break if @_close
    # Time to call our iterator
    if @options.repeat
      index = @started % @_elements.length
    else
      index = Math.floor(@started / (@options.times * handlers.length))
    @started += handlers.length
    try
      for handler, i in handlers
        l = handler.length
        l++ if @options.sync
        switch l
          when 1
            args = []
          when 2
            if @_keys
            then args = [@_elements[@_keys[index]]]
            else args = [@_elements[index]]
          when 3
            if @_keys
            then args = [@_keys[index], @_elements[@_keys[index]]]
            else args = [@_elements[index], index]
          when 4
            if @_keys
            then args = [@_keys[index], @_elements[@_keys[index]], index]
            else return @_next new Error 'Invalid arguments in item callback'
          else
            return @_next new Error 'Invalid arguments in item callback'
        unless @options.sync
          args.push ( =>
            count = 0
            (err) =>
              return @_next err if err
              unless ++count is 1
                err = new Error 'Multiple call detected'
                return if @readable then @_next err else throw err
              @_next()
          )()
        err = handler args...
        @_next err if @options.sync
    catch err
      # prevent next to be called if an error occurend inside the
      # error, end or both callbacks
      if @readable then @_next err else throw err
  null
Each.prototype._next = (err) ->
  @_errors.push err if err? and err instanceof Error
  @done++
  @_run()
Each::run = (callback) ->
  console.log 'DEPRECATED: use `call` instead of `run`'
  @call callback
Each::call = (callback) ->
  callback = [callback] unless Array.isArray callback
  @_listeners.push ['call', callback]
  @
Each::promise = ->
  deferred = {}
  promise = new Promise (resolve, reject)->
    deferred.resolve = resolve
    deferred.reject = reject
  @_listeners.push ['promise', deferred]
  promise
Each::next = (callback) ->
  @_listeners.push ['next', callback]
  @
Each::end = (callback) ->
  @_listeners.push ['end', callback]
  @
Each::error = (callback) ->
  @_listeners.push ['error', callback]
  @
Each::end = ->
  console.log 'Function `end` deprecated, use `close` instead.'
  @close()
Each::close = ->
  @_close = true
  @_next()
  @
Each::sync = (s) ->
  @options.sync = s? or true
  @
Each::repeat = (t) ->
  @options.repeat = true
  @options.times = t
  @write null if @_elements.length is 0
  @
Each::times = (t) ->
  @options.times = t
  @write null if @_elements.length is 0
  @
Each::files = (base, pattern) ->
  throw Error "Depracated API: each.files"
Each::write = Each::push = (item) ->
  l = arguments.length
  if l is 1
    @_elements.push arguments[0]
  else if l is 2
    @_keys = [] if not @_keys
    @_keys.push arguments[0]
    @_elements[arguments[0]] = arguments[1]
  @total++
  @
Each::unshift = (item) ->
  l = arguments.length
  if @options.repeat
    index = @started % @_elements.length
  else
    index = Math.floor(@started / @options.times)
  if l is 1
    @_elements.splice index, 0, arguments[0]
  else if l is 2
    @_keys = [] if not @_keys
    @_keys.splice index, 0, arguments[0]
    @_elements[arguments[0]] = arguments[1]
  @total++
  @
Each::pause = ->
  @paused++
Each::resume = ->
  @paused--
  @_run()
Each::parallel = (mode) ->
  # Concurrent
  if typeof mode is 'number' then @options.concurrency = mode
  # Parallel
  else if mode then @options.concurrency = mode
  # Sequential (in case parallel is called multiple times)
  else @options.concurrency = 1
  @

module.exports = (elements) ->
  new Each elements
module.exports.Each = Each
