# Handles Aris v2 authentication and API calls.
class Aris
  constructor: ->
    @storage = window.localStorage?
    @auth =
      if @storage
        auth = localStorage['aris-auth']
        if auth? then JSON.parse auth else null
      else
        $.cookie.json = true
        $.cookie 'aris-auth'

  # Given the JSON result of users.logIn, if it was successful,
  # creates and stores the authentication object.
  parseLogin: ({data: user, returnCode}) ->
    if returnCode is 0 and user.user_id isnt null
      @auth =
        user_id:    parseInt user.user_id
        permission: 'read_write'
        key:        user.read_write_key
        username:   user.user_name
      if @storage
        localStorage['aris-auth'] = JSON.stringify @auth
      else
        $.cookie 'aris-auth', @auth, path: '/', expires: 365
    else
      @logout()

  # Logs in with a username and password, or logs in with the existing
  # known `auth` object if you pass `undefined` for the username and password.
  login: (username, password, cb = (->)) ->
    @call 'users.logIn',
      user_name: username
      password: password
      permission: 'read_write'
    , (res) =>
      @parseLogin res
      cb()

  logout: ->
    @auth = null
    if @storage
      localStorage.removeItem 'aris-auth'
    else
      $.removeCookie 'aris-auth', path: '/'

  # Calls a function from the Aris v2 API.
  # The callback receives the entire JSON-decoded response.
  call: (func, json, cb) ->
    if @auth?
      json.auth = @auth
    $.ajax
      contentType: 'application/x-www-form-urlencoded'
      data: JSON.stringify json
      dataType: 'json'
      success: cb
      error: -> cb false
      processData: false
      type: 'POST'
      url: "#{ARIS_URL}/json.php/v2.#{func}"

window.Aris = Aris
