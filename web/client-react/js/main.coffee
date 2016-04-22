React = require 'react'
ReactDOM = require 'react-dom'
update = require 'react-addons-update'
{markdown} = require 'markdown'
{Game, Colors, User, Tag, Comment, Note, Aris, ARIS_URL} = require '../../shared/aris.js'
GoogleMap = require 'google-map-react'
{fitBounds} = require 'google-map-react/utils'
$ = require 'jquery'
{make, child, raw, props, addClass} = require '../../shared/react-writer.js'
EXIF = require 'exif-js'
{ConicGradient} = require '../../shared/conic-gradient.js'
InfiniteScroll = require 'react-infinite-scroller'

T = React.PropTypes

renderMarkdown = (str) ->
  __html: markdown.toHTML str

# This is Haskell right? It uses indentation and everything
match = (val, branches, def = (-> throw 'Match failed')) ->
  for k, v of branches
    if k of val
      return v val[k]
  def()

# from http://stackoverflow.com/a/1119324
confirmOnPageExit = (msg) -> (e = window.event) ->
  if e
    e.returnValue = msg
  msg

ifCordova = (cordovaLink, normalLink) ->
  if window.cordova?
    cordovaLink
  else
    normalLink

# Cache of gradient PNG data URLs
allConicGradients = {}
getConicGradient = (opts) ->
  allConicGradients["#{opts.stops}_#{opts.size}"] ?= new ConicGradient(opts).png

# By Diego Perini. https://gist.github.com/dperini/729294
# MT: removed the ^ and $, and removed the \.? "TLD may end with dot"
# since it often breaks people's links
urlRegex = /(?:(?:https?|ftp):\/\/)(?:\S+(?::\S*)?@)?(?:(?!(?:10|127)(?:\.\d{1,3}){3})(?!(?:169\.254|192\.168)(?:\.\d{1,3}){2})(?!172\.(?:1[6-9]|2\d|3[0-1])(?:\.\d{1,3}){2})(?:[1-9]\d?|1\d\d|2[01]\d|22[0-3])(?:\.(?:1?\d{1,2}|2[0-4]\d|25[0-5])){2}(?:\.(?:[1-9]\d?|1\d\d|2[0-4]\d|25[0-4]))|(?:(?:[a-z\u00a1-\uffff0-9]-*)*[a-z\u00a1-\uffff0-9]+)(?:\.(?:[a-z\u00a1-\uffff0-9]-*)*[a-z\u00a1-\uffff0-9]+)*(?:\.(?:[a-z\u00a1-\uffff]{2,})))(?::\d{2,5})?(?:[/?#]\S*)?/i

linkableText = (str) ->
  md = str.match(urlRegex)
  if md?
    raw str[0 ... md.index]
    child 'a', href: md[0], target: '_blank', => raw md[0]
    linkableText str[(md.index + md[0].length)..]
  else
    raw str

SearchBox = React.createClass
  displayName: 'SearchBox'

  propTypes:
    placeholder: T.string
    onPlacesChanged: T.func

  render: ->
    make 'input', =>
      props @props
      props
        type: 'text'
        ref: 'input'

  onPlacesChanged: ->
    if @props.onPlacesChanged
      @props.onPlacesChanged @searchBox.getPlaces()

  componentDidMount: ->
    input = ReactDOM.findDOMNode @refs.input
    @searchBox = new google.maps.places.SearchBox input
    @listener = @searchBox.addListener 'places_changed', => @onPlacesChanged()

  componentWillUnmount: ->
    @listener.remove()

App = React.createClass
  displayName: 'App'

  propTypes:
    game: T.instanceOf Game
    aris: T.instanceOf Aris

  getInitialState: ->
    notes:        []
    map_notes:    []
    map_clusters: []
    more_notes: false
    page: 1
    latitude:  @props.game.latitude
    longitude: @props.game.longitude
    zoom:      @props.game.zoom
    min_latitude:  null
    max_latitude:  null
    min_longitude: null
    max_longitude: null
    search: ''
    mine: false
    order: 'recent'
    checked_tags: do =>
      o = {}
      for tag in @props.game.tags
        o[tag.tag_id] = false
      o
    modal: nothing: {}
    login_status:
      logged_out:
        username: ''
        password: ''
    view_focus: 'map' # 'map' or 'thumbnails'
    search_controls: null # null, 'not_time', or 'time'
    account_menu: false
    message: null
    date_1: 'min'
    date_2: 'max'
    liked: {}

  getColor: (x) ->
    if x instanceof Tag
      tag = x
    else if x.tag_id?
      tag = (tag for tag in @props.game.tags when tag.tag_id is parseInt(x.tag_id))[0]
    else if typeof x in ['number', 'string']
      tag = (tag for tag in @props.game.tags when tag.tag_id is parseInt x)[0]
    else
      return 'black'
    @props.game.colors["tag_#{@props.game.tags.indexOf(tag) % 8 + 1}"] ? 'black'

  updateState: (obj) ->
    @setState (previousState) =>
      update previousState, obj

  componentDidMount: ->
    @login()

  componentWillMount: ->
    @hashChanged()
    window.addEventListener 'hashchange', (=> @hashChanged()), false
    ['mouseup', 'touchend'].forEach (e) =>
      window.addEventListener e, =>
        if @dragListener?
          window.removeEventListener('mousemove', @dragListener)
          window.removeEventListener('touchmove', @dragListener)
          delete @dragListener
          @search()

  hashChanged: ->
    if md = window.location.hash.match /^#(\d+)$/
      note_id = parseInt md[1]
      alreadyViewing =
        if @state.modal.viewing_note?
          note_id is parseInt @state.modal.viewing_note.note.note_id
        else
          false
      unless alreadyViewing
        # fetch the right note and view it
        @props.aris.call 'notes.siftrSearch',
          game_id: @props.game.game_id
          note_id: note_id
          map_data: false
        , @successAt 'loading a note', (data) =>
          @viewNote data.notes[0]
    else
      # Close any note views
      if @state.modal.viewing_note?
        @setState modal: nothing: {}

  handleMapChange: ({center: {lat, lng}, zoom, bounds: {nw, se}}) ->
    @search 0,
      latitude:      $set: lat
      longitude:     $set: lng
      zoom:          $set: zoom
      min_latitude:  $set: se.lat
      max_latitude:  $set: nw.lat
      min_longitude: $set: nw.lng
      max_longitude: $set: se.lng

  searchParams: (state = @state, logged_in = @state.login_status.logged_in?) ->
    unixTimeToString = (t) ->
      new Date(t).toISOString().replace('T', ' ').replace(/\.\d\d\dZ$/, '')
      # ISO string is in format "yyyy-mm-ddThh:mm:ss.sssZ"
      # we change it into "yyyy-mm-dd hh:mm:ss" for the ARIS SQL format
    switch state.date_1
      when 'min'
        min_time = undefined
        switch state.date_2
          when 'min'
            max_time = undefined # whatever
          when 'max'
            max_time = undefined
          else
            max_time = unixTimeToString state.date_2
      when 'max'
        max_time = undefined
        switch state.date_2
          when 'min'
            min_time = undefined
          when 'max'
            min_time = undefined # whatever
          else
            min_time = unixTimeToString state.date_2
      else
        switch state.date_2
          when 'min'
            min_time = undefined
            max_time = unixTimeToString state.date_1
          when 'max'
            min_time = unixTimeToString state.date_1
            max_time = undefined
          else
            min_time = unixTimeToString Math.min(state.date_1, state.date_2)
            max_time = unixTimeToString Math.max(state.date_1, state.date_2)
    game_id: @props.game.game_id
    min_latitude: state.min_latitude
    max_latitude: state.max_latitude
    min_longitude: state.min_longitude
    max_longitude: state.max_longitude
    zoom: state.zoom
    limit: 48
    order: state.order
    filter: if state.mine and logged_in then 'mine' else undefined
    tag_ids:
      tag_id for tag_id, checked of state.checked_tags when checked
    search: state.search
    min_time: min_time
    max_time: max_time

  search: (wait = 0, updater = {}, logged_in = @state.login_status.logged_in?) ->
    @setState (previousState) =>
      newState = update update(previousState, updater), page: {$set: 1}
      thisSearch = @lastSearch = Date.now()
      setTimeout =>
        return unless thisSearch is @lastSearch
        @props.aris.call 'notes.siftrSearch',
          @searchParams(newState, logged_in)
        , @successAt 'performing your search', (data) =>
          return unless thisSearch is @lastSearch
          @setState
            notes:        data.notes
            map_notes:    data.map_notes
            map_clusters: data.map_clusters
            more_notes:   true # maybe
          @refs.theThumbs?.scrollTop = 0
      , wait
      newState

  loadPage: ->
    page = @state.page + 1
    thisSearch = @lastSearch = Date.now()
    params = update @searchParams(),
      offset: $set: (page - 1) * 48
      map_data: $set: false
    @props.aris.call 'notes.siftrSearch',
      params
    , @successAt 'loading your search results', (data) =>
      return unless thisSearch is @lastSearch
      @updateState
        notes:
          $push: data.notes
        page:
          $set: page
        more_notes:
          $set: data.notes.length is 48

  viewNote: (note) ->
    @setState
      modal:
        viewing_note:
          note: note
          comments: null
          new_comment: ''
          confirm_delete: false
          confirm_delete_comment_id: null
    @fetchComments note
    @checkLike note

  setLiked: (note, liked) ->
    @updateState liked: $merge: do =>
      obj = {}
      obj[note.note_id] = liked
      obj

  checkLike: (note) ->
    if @props.aris.auth?
      @props.aris.call 'notes.likedNote',
        game_id: @props.game.game_id
        note_id: note.note_id
      , ({data, returnCode}) =>
        @setLiked(note, data) if returnCode is 0

  likeNote: (note) ->
    if @props.aris.auth?
      @props.aris.call 'notes.likeNote',
        game_id: @props.game.game_id
        note_id: note.note_id
      , ({returnCode}) =>
        @setLiked(note, true) if returnCode is 0
    else
      @setState account_menu: true

  unlikeNote: (note) ->
    if @props.aris.auth?
      @props.aris.call 'notes.unlikeNote',
        game_id: @props.game.game_id
        note_id: note.note_id
      , ({returnCode}) =>
        @setLiked(note, false) if returnCode is 0
    else
      @setState account_menu: true

  fetchComments: (note) ->
    @props.aris.getNoteCommentsForNote
      game_id: @props.game.game_id
      note_id: note.note_id
    , @successAt 'fetching comments', (data) =>
      @updateState
        modal:
          $apply: (modal) =>
            if modal.viewing_note?.note is note
              update modal,
                viewing_note:
                  comments: $set: data
            else
              modal

  refreshEditedNote: (note_id = @state.modal.viewing_note.note.note_id) ->
    @search()
    @props.aris.call 'notes.siftrSearch',
      game_id: @props.game.game_id
      note_id: note_id
      map_data: false
    , @successAt 'refreshing this note', (data) =>
      @viewNote data.notes[0]

  login: ->
    loginWith = (username, password) =>
      @props.aris.login (username or undefined), (password or undefined), =>
        @search undefined, undefined, true if @props.aris.auth?
        failed_login = @state.account_menu and not @props.aris.auth?
        @setState
          login_status:
            if @props.aris.auth?
              logged_in:
                auth: @props.aris.auth
            else
              logged_out:
                username: username
                password: ''
          account_menu: failed_login
          message: if failed_login then 'Incorrect username or password.' else null
        @fetchUserPicture()
        if (note = @state.modal.viewing_note?.note)
          @checkLike note
    match @state.login_status,
      logged_out:     ({username, password}) => loginWith(username, password)
      create_account: ({username, password}) => loginWith(username, password)

  createAccount: ->
    match @state.login_status,
      create_account: ({email, username, password, password2}) =>
        alert = (msg) => @setState message: msg
        unless email
          alert 'Please enter your email address.'
        else unless '@' in email
          alert 'Your email address is not valid.'
        else unless username
          alert 'Please select a username.'
        else unless password or password2
          alert 'Please enter a password.'
        else unless password is password2
          alert 'Your passwords do not match.'
        else
          @props.aris.call 'users.createUser',
            user_name: username
            password: password
            email: email
          , ({returnCode, returnCodeDescription}) =>
            if returnCode isnt 0
              alert "Couldn't create account: #{returnCodeDescription}"
            else
              @login()

  fetchUserPicture: ->
    match @state.login_status,
      logged_out: => null
      logged_in: ({auth}) =>
        @props.aris.call 'media.getMedia',
          media_id: auth.media_id
        , @successAt 'fetching your user picture', (media) =>
          @updateState
            login_status:
              $apply: (status) =>
                if status.logged_in
                  logged_in:
                    auth: auth
                    media: media
                else
                  status

  logout: ->
    @props.aris.logout()
    @setState
      login_status:
        logged_out:
          username: ''
          password: ''
      mine: false
      modal: nothing: {}
      account_menu: false
      message: null
      liked: {}
    @search undefined, undefined, false

  successAt: (doingSomething, fn) -> (arisResult) =>
    {data, returnCode} = arisResult
    if returnCode is 0
      fn data
    else
      @setState message:
        "There was a problem #{doingSomething}. Please report this error: #{JSON.stringify arisResult}"

  uploadPhoto: (file) ->
    if file?
      name = file.name
      ext = name[name.indexOf('.') + 1 ..]
      @setState modal: uploading_photo: progress: 0
      $.ajax
        url: "#{ARIS_URL}/rawupload.php"
        type: 'POST'
        xhr: =>
          xhr = new window.XMLHttpRequest
          xhr.upload.addEventListener 'progress', (evt) =>
            if evt.lengthComputable
              @updateState modal: uploading_photo: progress: $set: evt.loaded / evt.total
          , false
          xhr
        success: (raw_upload_id) =>
          @props.aris.call 'media.createMediaFromRawUpload',
            file_name: "upload.#{ext}"
            raw_upload_id: raw_upload_id
            game_id: @props.game.game_id
            resize: 800
          , @successAt 'uploading your photo', (media) =>
            if @state.modal.uploading_photo?
              @setState
                modal:
                  enter_description:
                    media: media
                    tag: @props.game.tags[0]
                    description: ''
                    file: file
                message: null
        error: (jqXHR, textStatus, errorThrown) =>
          @setState message:
            """
            There was a problem uploading your photo. Please report this error:
            #{JSON.stringify [jqXHR, textStatus, errorThrown]}
            """
        data: do =>
          form = new FormData
          form.append 'raw_upload', file
          form
        cache: false
        contentType: false
        processData: false

  render: ->
    window.onbeforeunload =
      if @state.modal.enter_description? or @state.modal.move_point? or @state.modal.select_category?
        confirmOnPageExit "Are you sure you want to exit? Your photo will be lost!"
      else
        null

    hash =
      if @state.modal.viewing_note?
        "##{@state.modal.viewing_note.note.note_id}"
      else
        ""
    if window.location.hash isnt hash
      window.location.hash = hash

    make 'div#the-contained', =>
      addClass [
        if @state.search_controls? then 'searching' else 'notSearching'
        if @state.account_menu then 'accountMenuOpen' else ''
        if @state.view_focus is 'map' or @state.modal.move_point? then 'primaryMap' else 'primaryThumbs'
      ]

      # Map
      makePin = ({lat, lng, key, color, hovering, onClick, className, position}) =>
        width = if hovering then 35 else 20
        radius = width * 0.6
        child 'div', =>
          props
            style: position: position ? 'relative'
            lat: lat
            lng: lng
            key: key
            className: className
          child 'div', =>
            props
              style:
                backgroundColor: 'black'
                width: (width / 2)
                height: (width / 2) / 2
                left: -((width / 2) / 2)
                top: -((width / 2) / 4)
                borderRadius: (width / 2) / 2
                opacity: 0.4
                boxShadow: '0px 0px 20px 10px black'
                position: 'absolute'
          child 'div', =>
            props
              onClick: onClick
              style:
                position: 'absolute'
                top: -(width * Math.sqrt(2) * 0.95)
                left: -(width * Math.sqrt(2) * 0.45) + if hovering then 3 else 0
                # I'm not sure why the above hacks are necessary.
                # They should just be 1 and 0.5, not 0.95 and 0.4.
                # Weird CSS sizing rules probably
                width: width
                height: width
                backgroundColor: color
                border: '2px solid white'
                cursor: if onClick? then 'pointer' else undefined
                borderRadius: "#{radius}px #{radius}px #{radius}px 0"
                WebkitTransform: "rotate(-45deg)"
                MozTransform: "rotate(-45deg)"
                msTransform: "rotate(-45deg)"
                OTransform: "rotate(-45deg)"
                transform: "rotate(-45deg)"
      child 'div.theMap', ref: 'theMapDiv', =>
        child GoogleMap, =>
          props
            center: [@state.latitude, @state.longitude]
            zoom: Math.max 2, @state.zoom
            options: minZoom: 2
            draggable: true
            onChange: @handleMapChange
            options: (maps) =>
              mapTypeControl: true
              mapTypeControlOptions:
                style: maps.MapTypeControlStyle.HORIZONTAL_BAR
                position: maps.ControlPosition.LEFT_BOTTOM
                mapTypeIds: [maps.MapTypeId.ROADMAP, maps.MapTypeId.SATELLITE]
              zoomControlOptions:
                position: maps.ControlPosition.RIGHT_CENTER
              styles:
                # from https://snazzymaps.com/style/83/muted-blue
                [{"featureType":"all","stylers":[{"saturation":0},{"hue":"#e7ecf0"}]},{"featureType":"road","stylers":[{"saturation":-70}]},{"featureType":"transit","stylers":[{"visibility":"off"}]},{"featureType":"poi","stylers":[{"visibility":"off"}]},{"featureType":"water","stylers":[{"visibility":"simplified"},{"saturation":-60}]}]

          if @state.modal.move_point?
            null
            # do nothing; static centered pin is shown below
          else if @state.modal.select_category?
            modal = @state.modal.select_category
            color = @getColor modal.tag
            makePin
              lat: modal.editing_note?.latitude ? modal.latitude
              lng: modal.editing_note?.longitude ? modal.longitude
              color: color
          else
            for cluster, i in @state.map_clusters
              lat = cluster.min_latitude + (cluster.max_latitude - cluster.min_latitude) / 2
              lng = cluster.min_longitude + (cluster.max_longitude - cluster.min_longitude) / 2
              hovering = @state.hover_note_id? and @state.hover_note_id in cluster.note_ids
              width = if hovering then 45 else 30
              if -180 < lng < 180 && -90 < lat < 90
                do (cluster) =>
                  stops = []
                  percent = 0
                  for tag_id, tag_count of cluster.tags
                    percent += (tag_count / cluster.note_count) * 100
                    color = @getColor tag_id
                    stops.push "#{color} 1 #{percent}%"
                    last_color = color
                  stops.unshift "#{last_color} 1 0%"
                  gradient = "url(#{getConicGradient(stops: stops.join(', '), size: width)})"
                  child 'div', =>
                    props
                      key: "#{lat}-#{lng}"
                      lat: lat
                      lng: lng
                      onClick: =>
                        close = (x, y) => Math.abs(x - y) < 0.0001
                        if close(cluster.min_latitude, cluster.max_latitude) and close(cluster.min_longitude, cluster.min_longitude)
                          # Calling fitBounds on a single point breaks for some reason
                          @setState
                            latitude: cluster.min_latitude
                            longitude: cluster.min_longitude
                            zoom: 21
                        else
                          # adjust bounds if all the points are on a single orthogonal line
                          # (fitBounds also breaks in this case)
                          bounds =
                            if close(cluster.min_latitude, cluster.max_latitude)
                              nw:
                                lat: cluster.max_latitude + 0.0005
                                lng: cluster.min_longitude
                              se:
                                lat: cluster.min_latitude - 0.0005
                                lng: cluster.max_longitude
                            else if close(cluster.min_longitude, cluster.max_longitude)
                              nw:
                                lat: cluster.max_latitude
                                lng: cluster.min_longitude - 0.0005
                              se:
                                lat: cluster.min_latitude
                                lng: cluster.max_longitude + 0.0005
                            else
                              nw:
                                lat: cluster.max_latitude
                                lng: cluster.min_longitude
                              se:
                                lat: cluster.min_latitude
                                lng: cluster.max_longitude
                          size =
                            width: @refs.theMapDiv.clientWidth * 0.9
                            height: @refs.theMapDiv.clientHeight * 0.9
                            # we shrink the stated map size a bit,
                            # to make sure we end up with some buffer around the points
                          {center, zoom} = fitBounds bounds, size
                          @setState
                            latitude: center.lat
                            longitude: center.lng
                            zoom: zoom
                      style:
                        marginLeft: -(width / 2)
                        marginTop: -(width / 2)
                        width: width
                        height: width
                        background: gradient
                        color: 'white'
                        textShadow: '-1px 0 black, 0 1px black, 1px 0 black, 0 -1px black'
                        cursor: 'pointer'
                        textAlign: 'center'
                        display: 'table'
                        fontWeight: 'bold'
                        fontSize: "#{width / 2}px"
                        borderRadius: width / 2
                    child 'span', =>
                      props style: {display: 'table-cell', verticalAlign: 'middle'}
                      raw cluster.note_count
            @state.map_notes.forEach (note) =>
              makePin
                lat: note.latitude
                lng: note.longitude
                color: @getColor note
                hovering: @state.hover_note_id is note.note_id
                key: note.note_id
                onClick: => @viewNote note

        if @state.modal.move_point?
          makePin
            color: 'black'
            className: 'move-pin'
            position: 'absolute'

      # Search
      child 'div.searchPane', =>
        child 'p', =>
          child 'input.searchInput', =>
            props
              type: 'text'
              value: @state.search
              placeholder: 'Search...'
              onChange: (e) => @search 200, search: {$set: e.target.value}

        child 'hr'
        child 'p', => child 'b', => raw 'BY DATE:'

        minTimeSlider = @props.game.created.getTime()
        maxTimeSlider = Date.now()
        getTime = (t) -> switch t
          when 'min' then minTimeSlider
          when 'max' then maxTimeSlider
          else            t
        time1Fraction = (getTime(@state.date_1) - minTimeSlider) / (maxTimeSlider - minTimeSlider)
        time2Fraction = (getTime(@state.date_2) - minTimeSlider) / (maxTimeSlider - minTimeSlider)
        child 'div', =>
          minTime = getTime @state.date_1
          maxTime = getTime @state.date_2
          if minTime > maxTime
            [minTime, maxTime] = [maxTime, minTime]
          child 'span', style: {float: 'left'}, =>
            raw new Date(minTime).toLocaleDateString()
          child 'span', style: {float: 'right'}, =>
            raw new Date(maxTime).toLocaleDateString()
          child 'div', style: {clear: 'both'}
        child 'div', =>
          child 'div', =>
            props
              ref: 'timeSlider'
              style:
                height: 10
                width: 'calc(100% - 50px)'
                backgroundColor: '#888'
                marginTop: 10
                marginBottom: 10
                marginLeft: 25
                position: 'relative'
            [false, true].forEach (isSlider1) =>
              child 'div', =>
                pointerDown = (movement) => (e) =>
                  unless @dragListener?
                    @dragListener = (e) =>
                      rect = @refs.timeSlider.getBoundingClientRect()
                      switch movement
                        when 'mousemove'
                          frac = (e.clientX - (rect.left + 10)) / (rect.width - 20)
                        when 'touchmove'
                          frac = (e.touches[0].clientX - (rect.left + 10)) / (rect.width - 20)
                      frac = Math.max(0, Math.min(1, frac))
                      encodedTime = switch frac
                        when 0 then 'min'
                        when 1 then 'max'
                        else minTimeSlider + (maxTimeSlider - minTimeSlider) * frac
                      if isSlider1
                        @setState
                          date_1: encodedTime
                      else
                        @setState
                          date_2: encodedTime
                    window.addEventListener movement, @dragListener
                props
                  style:
                    height: 20
                    width: 20
                    backgroundColor: 'rgb(32,37,49)'
                    position: 'absolute'
                    top: -5
                    left: "calc((100% - 20px) * #{if isSlider1 then time1Fraction else time2Fraction})"
                    borderRadius: 4
                    cursor: 'pointer'
                  onMouseDown: pointerDown 'mousemove'
                  onTouchStart: pointerDown 'touchmove'

        child 'hr', style: marginTop: 15
        child 'p', => child 'b', => raw 'BY ACTIVITY:'

        child 'div.activityButtons', =>
          child 'div.activityButton', =>
            addClass 'activityOn' if @state.order is 'recent'
            props onClick: => @search 0, order: {$set: 'recent'}
            raw 'newest'
          child 'div.activityButton', =>
            addClass 'activityOn' if @state.order is 'popular'
            props onClick: => @search 0, order: {$set: 'popular'}
            raw 'popular'
          if @state.login_status.logged_in?
            child 'div.activityButton', =>
              addClass 'activityOn' if @state.mine
              props onClick: => @search 0, mine: {$apply: (x) => not x}
              raw 'mine'

        child 'hr', style: marginTop: 20
        child 'p', => child 'b', => raw 'BY CATEGORY:'

        child 'p', =>
          @props.game.tags.forEach (tag) =>
            checked = @state.checked_tags[tag.tag_id]
            color = @getColor tag
            child 'span', =>
              props
                key: tag.tag_id
                style:
                  margin: 5
                  padding: 5
                  border: "1px solid #{color}"
                  color: if checked then 'white' else color
                  backgroundColor: if checked then color else 'white'
                  borderRadius: 5
                  cursor: 'pointer'
                  whiteSpace: 'nowrap'
                  display: 'inline-block'
                onClick: =>
                  @search 0,
                    checked_tags: do =>
                      o = {}
                      o[tag.tag_id] =
                        $apply: (x) => not x
                      o
              raw "#{if checked then '✓' else '●'} #{tag.tag}"

      # Thumbnails
      child 'div.theThumbs', ref: 'theThumbs', =>
        child InfiniteScroll, =>
          props
            pageStart: 0
            loadMore: (page) => @loadPage()
            hasMore: @state.more_notes
            loader:
              make 'div.blueButton', =>
                props
                  style:
                    padding: 15
                    boxSizing: 'border-box'
                    cursor: 'default'
                raw 'Loading...'
            useWindow: false
          child 'div', style: {paddingLeft: 10, paddingRight: 10}, =>
            child 'h2.canSelect', => raw @props.game.name
            if @state.show_instructions
              child 'p', =>
                child 'span.blueButton', =>
                  props
                    style:
                      cursor: 'pointer'
                      paddingLeft: 15
                      paddingRight: 15
                      paddingTop: 6
                      paddingBottom: 6
                    onClick: =>
                      @setState show_instructions: false
                  raw 'Hide instructions'
              child 'div.canSelect',
                dangerouslySetInnerHTML: renderMarkdown @props.game.description
                style:
                  borderLeft: '2px solid black'
                  paddingLeft: 10
              for tag in @props.game.tags
                color = @getColor tag
                child 'p', =>
                  props
                    key: tag.tag_id
                    style:
                      margin: 5
                  child 'span', style:
                    backgroundColor: color
                    width: 12
                    height: 12
                    borderRadius: 6
                    display: 'inline-block'
                  raw " #{tag.tag}"
            else
              child 'p', =>
                child 'span.blueButton', =>
                  props
                    style:
                      cursor: 'pointer'
                      padding: '6px 15px'
                    onClick: =>
                      @setState show_instructions: true
                  raw 'Instructions'
          child 'div', style: {textAlign: 'center'}, =>
            @state.notes.forEach (note) =>
              child 'div.thumbnail', =>
                props
                  key: note.note_id
                  style:
                    backgroundImage: "url(#{note.media.big_thumb_url})"
                    backgroundSize: '100% 100%'
                    margin: 5
                    cursor: 'pointer'
                    position: 'relative'
                    display: 'inline-block'
                  onMouseOver: =>
                    @setState
                      hover_note_id: note.note_id
                  onMouseOut: =>
                    if @state.hover_note_id?
                      @setState hover_note_id: null
                  onClick: => @viewNote note
                child 'div',
                  style:
                    position: 'absolute'
                    right: 5
                    top: 5
                    width: 14
                    height: 14
                    borderRadius: 7
                    backgroundColor: @getColor note

      # Desktop menu, also mobile bottom bar
      child 'div.desktopMenu', =>

        child 'div.menuBrand', =>
          child 'a', href: ifCordova('../index.html', '..'), =>
            child 'img', src: 'img/brand.png', title: 'Siftr', alt: 'Siftr'

        child 'div.menuMap', style: {cursor: 'pointer'}, =>
          child 'img',
            title: 'View Map'
            alt: 'View Map'
            src: if @state.view_focus is 'map' then 'img/map-on.png' else 'img/map-off.png'
            onClick: =>
              setTimeout =>
                window.dispatchEvent new Event 'resize'
              , 500
              @updateState
                view_focus: $set: 'map'
                modal: $apply: (modal) =>
                  if modal.viewing_note?
                    nothing: {}
                  else
                    modal

        child 'div.menuThumbs', style: {cursor: 'pointer'}, =>
          child 'img',
            title: 'View Photos'
            alt: 'View Photos'
            src: if @state.view_focus is 'thumbnails' then 'img/thumbs-on.png' else 'img/thumbs-off.png'
            onClick: =>
              setTimeout =>
                window.dispatchEvent new Event 'resize'
              , 500
              @updateState
                view_focus: $set: 'thumbnails'
                modal: $apply: (modal) =>
                  if modal.viewing_note?
                    nothing: {}
                  else
                    modal

        child 'div.menuSift', style: {cursor: 'pointer'}, =>
          child 'img',
            title: 'Toggle Search Controls'
            alt: 'Toggle Search Controls'
            src: if @state.search_controls? then 'img/search-on.png' else 'img/search-off.png'
            onClick: =>
              setTimeout =>
                window.dispatchEvent new Event 'resize'
              , 500
              @setState search_controls: if @state.search_controls? then null else 'not_time'

        child 'div.menuDiscover.menuTable', =>
          child 'a.menuTableCell', href: ifCordova('../discover/index.html', '../discover'), =>
            raw 'DISCOVER'

        child 'div.menuMyAccount.menuTable', =>
          child 'div.menuTableCell', =>
            props onClick: => @setState account_menu: not @state.account_menu
            if @state.login_status.logged_in?
              raw 'MY ACCOUNT'
            else
              raw 'LOGIN'

        child 'div.menuMySiftrs.menuTable', =>
          child 'a.menuTableCell', href: ifCordova('../editor-react/index.html', '../editor'), =>
            raw 'MY SIFTRS'

      # Desktop and mobile add buttons
      clickAdd = =>
        if @state.login_status.logged_in?
          @setState modal: select_photo: {}
        else
          @setState account_menu: true
      if @state.search_controls is null and (@state.modal.nothing? or @state.modal.viewing_note?)
        child 'div.addItemDesktop', =>
          child 'img',
            alt: 'Add Item'
            src: 'img/add-item.png'
            onClick: clickAdd
      child 'img.addItemMobile',
        title: 'Add Item'
        alt: 'Add Item'
        src: 'img/mobile-plus.png'
        onClick: clickAdd

      # Account menu (stuff shared between desktop and mobile versions)
      makeBox = ({type, value, placeholder, onChange, onEnter}) =>
        child 'p', =>
          props style: width: '100%'
          child 'input', =>
            props
              autoCapitalize: 'off'
              autoCorrect: 'off'
              type: type
              value: value
              placeholder: placeholder
              onChange: (e) => onChange e.target.value
              style:
                width: '100%'
                boxSizing: 'border-box'
              onKeyDown: (e) => onEnter() if e.keyCode is 13
      loginFields = (username, password) =>
        child 'div', =>
          child 'p', style: {textAlign: 'center'}, =>
            raw 'Login with a Siftr or ARIS account'
          makeBox
            type: 'text'
            value: username
            placeholder: 'Username'
            onChange: (x) => @updateState login_status: logged_out: username: $set: x
            onEnter: => @login()
          makeBox
            type: 'password'
            value: password
            placeholder: 'Password'
            onChange: (x) => @updateState login_status: logged_out: password: $set: x
            onEnter: => @login()
          child 'div.blueButton.wideButton', =>
            props onClick: @login
            raw 'LOGIN'
          child 'div.blueButton.wideButton', =>
            props onClick: =>
              @setState login_status:
                create_account:
                  email: ''
                  username: username
                  password: ''
                  password2: ''
            raw 'CREATE ACCOUNT'
          child 'p', style: {textAlign: 'center'}, =>
            child 'a', href: ifCordova('../editor-react/index.html#forgot', '../editor#forgot'), =>
              props style:
                color: 'white'
                textDecoration: 'none'
              raw 'I forgot my password'
      signupFields = (email, username, password, password2) =>
        child 'div', =>
          child 'p', style: {textAlign: 'center'}, =>
            raw 'Create a Siftr account'
          makeBox
            type: 'email'
            value: email
            placeholder: 'Email'
            onChange: (x) => @updateState login_status: create_account: email: $set: x
            onEnter: => @createAccount()
          makeBox
            type: 'text'
            value: username
            placeholder: 'Username'
            onChange: (x) => @updateState login_status: create_account: username: $set: x
            onEnter: => @createAccount()
          makeBox
            type: 'password'
            value: password
            placeholder: 'Password'
            onChange: (x) => @updateState login_status: create_account: password: $set: x
            onEnter: => @createAccount()
          makeBox
            type: 'password'
            value: password2
            placeholder: 'Repeat password'
            onChange: (x) => @updateState login_status: create_account: password2: $set: x
            onEnter: => @createAccount()
          child 'div.blueButton.wideButton', =>
            props onClick: @createAccount
            raw 'SIGNUP'
          child 'div.blueButton.wideButton', =>
            props onClick: =>
              @setState login_status:
                logged_out:
                  username: username
                  password: ''
            raw 'CANCEL'

      # Desktop account menu
      child 'div.accountMenuDesktop', =>
        match @state.login_status,
          logged_out: ({username, password}) => loginFields(username, password)
          create_account: ({email, username, password, password2}) => signupFields(email, username, password, password2)
          logged_in: ({auth, media}) =>
            child 'div', style: {textAlign: 'center'}, =>
              child 'a', href: ifCordova('../editor-react/index.html#account', '../editor#account'), =>
                props
                  style:
                    color: 'white'
                    textDecoration: 'none'
                child 'p', =>
                  child 'span', style:
                    width: 100
                    height: 100
                    borderRadius: 50
                    backgroundColor: 'white'
                    backgroundImage: if media? then "url(#{media.thumb_url})" else undefined
                    backgroundSize: 'cover'
                    display: 'inline-block'
                child 'p', =>
                  raw auth.display_name
                child 'div.blueButton.wideButton', =>
                  raw 'ACCOUNT SETTINGS'
              child 'div.blueButton.wideButton', =>
                props onClick: @logout
                raw 'LOGOUT'

      # Mobile account menu
      child 'div.accountMenuMobile', =>
        child 'div', =>
          child 'img',
            title: 'Close'
            alt: 'Close'
            src: 'img/x-white.png'
            style: cursor: 'pointer'
            onClick: => @setState account_menu: false
        match @state.login_status,
          logged_out: ({username, password}) => loginFields(username, password)
          create_account: ({email, username, password, password2}) => signupFields(email, username, password, password2)
          logged_in: ({auth, media}) =>
            child 'div', style: {textAlign: 'center'}, =>
              unlink =
                color: 'white'
                textDecoration: 'none'
              child 'a', href: ifCordova('../editor-react/index.html#account', '../editor#account'), style: unlink, =>
                child 'p', =>
                  child 'span', style:
                    width: 80
                    height: 80
                    borderRadius: 40
                    backgroundColor: 'white'
                    backgroundImage: if media? then "url(#{media.thumb_url})" else undefined
                    backgroundSize: 'cover'
                    display: 'inline-block'
                child 'p', =>
                  raw auth.display_name
              child 'p', =>
                child 'a', href: ifCordova('../index.html', '..'), =>
                  child 'img', src: 'img/brand-mobile.png', title: 'Siftr', alt: 'Siftr'
              child 'p', => child 'a', style: unlink, href: ifCordova('../editor-react/index.html', '../editor'), => raw 'My Siftrs'
              child 'p', => child 'a', style: unlink, href: ifCordova('../discover/index.html', '../discover'), => raw 'Discover'
              child 'p', style: {cursor: 'pointer'}, onClick: @logout, => raw 'Logout'

      # Main modal
      match @state.modal,
        nothing: => null
        viewing_note: ({note, comments, new_comment, confirm_delete, confirm_delete_comment_id, edit_comment_id, edit_comment_text}) =>
          child 'div.primaryModal', =>
            props
              style:
                overflowY: 'scroll'
                # WebkitOverflowScrolling: 'touch'
                # ^ this breaks scrolling the first time you open a note
                backgroundColor: 'white'
            child 'img',
              title: 'Close'
              alt: 'Close'
              src: 'img/x-blue.png'
              style:
                position: 'absolute'
                top: 20
                right: 20
                cursor: 'pointer'
              onClick: => @setState modal: nothing: {}
            child 'div.noteView', =>
              child 'h4.canSelect', =>
                props
                  style:
                    width: 'calc(100% - 80px)'
                raw "#{note.display_name} at #{new Date(note.created.replace(' ', 'T') + 'Z').toLocaleString()}"
              child 'img', =>
                alt: 'A photo uploaded to Siftr'
                props
                  src: note.media.url
                  style:
                    width: '100%'
                    display: 'block'
              user_id =
                if @state.login_status.logged_in?
                  @state.login_status.logged_in.auth.user_id
                else
                  null
              owners =
                owner.user_id for owner in @props.game.owners
              barButton = (img, title, action) =>
                child 'img',
                  src: img
                  style:
                    marginTop: 9
                    marginBottom: 7
                    marginLeft: 12
                    cursor: 'pointer'
                  onClick: action
                  title: title
                  alt: title
              child 'div', =>
                props
                  style:
                    backgroundColor: 'rgb(97,201,226)'
                    width: '100%'
                if @state.liked[parseInt note.note_id]
                  barButton 'img/freepik/heart-filled.png', 'Unlike Note', =>
                    @unlikeNote note
                else
                  barButton 'img/freepik/heart.png', 'Like Note', =>
                    @likeNote note
                if user_id is parseInt(note.user_id) or user_id in owners
                  barButton 'img/freepik/delete81.png', 'Delete Note', =>
                    @updateState modal: viewing_note: confirm_delete: $set: true
                if user_id is parseInt(note.user_id)
                  barButton 'img/freepik/edit45.png', 'Edit Caption', =>
                    @setState modal: enter_description:
                      editing_note: note
                      description: note.description
                  barButton 'img/freepik/location73.png', 'Edit Location', =>
                    @setState
                      modal:
                        move_point:
                          editing_note: note
                      latitude: parseFloat note.latitude
                      longitude: parseFloat note.longitude
                  barButton 'img/freepik/tag79.png', 'Edit Category', =>
                    @setState
                      modal:
                        select_category:
                          editing_note: note
                          tag: do =>
                            for tag in @props.game.tags
                              return tag if tag.tag_id is parseInt note.tag_id
                      latitude: parseFloat note.latitude
                      longitude: parseFloat note.longitude
                noteVerb =
                  if parseInt(note.user_id) is @props.aris.auth?.user_id
                    'made'
                  else
                    'found'
                noteTag = do =>
                  for tag in @props.game.tags
                    if tag.tag_id is parseInt note.tag_id
                      return tag.tag
                  '???'
                noteLink = window.location.href # TODO: fix for Cordova
                barButton '../img/somicro/without-border/email.png', 'Email', =>
                  subject = "Interesting note on #{noteTag}"
                  email = """
                    Check out this note I #{noteVerb} about #{noteTag}:

                    #{note.description}

                    See the whole note at: #{noteLink}
                  """
                  link = "mailto:?subject=#{encodeURIComponent subject}&body=#{encodeURIComponent email}"
                  window.open link
                barButton '../img/somicro/without-border/facebook.png', 'Facebook', =>
                  link = "https://www.facebook.com/sharer/sharer.php?u=#{encodeURIComponent noteLink}"
                  window.open link, '_system'
                barButton '../img/somicro/without-border/googleplus.png', 'Google+', =>
                  link = "https://plus.google.com/share?url=#{encodeURIComponent noteLink}"
                  window.open link, '_system'
                barButton '../img/somicro/without-border/pinterest.png', 'Pinterest', =>
                  desc = "Check out this note I #{noteVerb} about #{noteTag}."
                  link = "http://www.pinterest.com/pin/create/button/"
                  link += "?url=#{encodeURIComponent noteLink}"
                  link += "&media=#{encodeURIComponent note.media.url}"
                  link += "&description=#{encodeURIComponent desc}"
                  window.open link, '_system'
                barButton '../img/somicro/without-border/twitter.png', 'Twitter', =>
                  tweet = "Check out this note I #{noteVerb} about #{noteTag}:"
                  link = "https://twitter.com/share?&url=#{encodeURIComponent noteLink}&text=#{encodeURIComponent tweet}"
                  window.open link, '_system'
              if @state.login_status.logged_in?
                if note.published is 'PENDING'
                  if user_id in owners
                    child 'p', => child 'b', => raw 'This note needs your approval to be visible.'
                    child 'p', =>
                      child 'span.blueButton', =>
                        props
                          style:
                            padding: 5
                          onClick: =>
                            @props.aris.call 'notes.approveNote',
                              note_id: note.note_id
                            , @successAt 'approving this note', => @refreshEditedNote()
                        raw 'APPROVE'
                  else
                    child 'p', => child 'b', =>
                      raw 'This note is only visible to you until an administrator approves it.'
                if confirm_delete
                  child 'p', => child 'b', => raw 'Are you sure you want to delete this note?'
                  child 'p', =>
                    child 'span.blueButton', =>
                      props
                        style:
                          padding: 5
                          marginRight: 10
                        onClick: =>
                          @props.aris.call 'notes.deleteNote',
                            note_id: note.note_id
                          , @successAt 'deleting this note', =>
                            @setState modal: nothing: {}
                            @search()
                      raw 'DELETE'
                    child 'span.blueButton', =>
                      props
                        style:
                          padding: 5
                        onClick: =>
                          @updateState
                            modal: viewing_note: confirm_delete: $set: false
                            message: $set: null
                      raw 'CANCEL'
              child 'p.canSelect', => linkableText note.description
              child 'hr'
              if comments?
                comments.forEach (comment) =>
                  child 'div', key: comment.comment_id, =>
                    child 'h4', =>
                      child 'span.canSelect', => raw "#{comment.user.display_name} at #{comment.created.toLocaleString()} "
                      if user_id is comment.user.user_id or user_id in owners
                        child 'img',
                          title: 'Delete Comment'
                          alt: 'Delete Comment'
                          src: 'img/freepik/delete81_blue.png'
                          style: cursor: 'pointer'
                          onClick: =>
                            @updateState modal: viewing_note: confirm_delete_comment_id: $set: comment.comment_id
                      raw ' '
                      if user_id is comment.user.user_id
                        child 'img',
                          title: 'Edit Comment'
                          alt: 'Edit Comment'
                          src: 'img/freepik/edit45_blue.png'
                          style: cursor: 'pointer'
                          onClick: =>
                            @updateState modal: viewing_note:
                              edit_comment_id: $set: comment.comment_id
                              edit_comment_text: $set: comment.description
                    if edit_comment_id is comment.comment_id
                      child 'p', =>
                        child 'textarea', =>
                          props
                            placeholder: 'Edit your comment...'
                            value: edit_comment_text
                            onChange: (e) => @updateState modal: viewing_note: edit_comment_text: $set: e.target.value
                            style:
                              width: '100%'
                              height: 75
                              resize: 'none'
                              boxSizing: 'border-box'
                      child 'p', =>
                        child 'span.blueButton', =>
                          props
                            style:
                              padding: 5
                              marginRight: 10
                            onClick: =>
                              if edit_comment_text isnt ''
                                @props.aris.updateNoteComment
                                  note_comment_id: comment.comment_id
                                  description: edit_comment_text
                                , @successAt 'editing your comment', (comment) =>
                                  @fetchComments note
                                  @updateState modal: viewing_note: edit_comment_id: $set: null
                          raw 'SAVE COMMENT'
                        child 'span.blueButton', =>
                          props
                            style:
                              padding: 5
                              marginRight: 10
                            onClick: =>
                              @updateState
                                modal: viewing_note: edit_comment_id: $set: null
                                message: $set: null
                          raw 'CANCEL'
                    else
                      if confirm_delete_comment_id is comment.comment_id
                        child 'p', => child 'b', => raw 'Are you sure you want to delete this comment?'
                        child 'p', =>
                          child 'span.blueButton', =>
                            props
                              style:
                                padding: 5
                                marginRight: 10
                              onClick: =>
                                @props.aris.call 'note_comments.deleteNoteComment',
                                  note_comment_id: comment.comment_id
                                , @successAt 'deleting this comment', =>
                                  @updateState modal: viewing_note: confirm_delete_comment_id: $set: null
                                  @fetchComments note
                            raw 'DELETE'
                          child 'span.blueButton', =>
                            props
                              style:
                                padding: 5
                              onClick: =>
                                @updateState
                                  modal: viewing_note: confirm_delete_comment_id: $set: null
                                  message: $set: null
                            raw 'CANCEL'
                      child 'p.canSelect', => linkableText comment.description
              else
                child 'p', => raw 'Loading comments...'
              if @state.login_status.logged_in?
                child 'p', =>
                  child 'textarea', =>
                    props
                      placeholder: 'Post a new comment...'
                      value: new_comment
                      onChange: (e) => @updateState modal: viewing_note: new_comment: $set: e.target.value
                      style:
                        width: '100%'
                        height: 75
                        resize: 'none'
                        boxSizing: 'border-box'
                child 'p', =>
                  child 'span.blueButton', =>
                    props
                      style:
                        padding: 5
                        marginRight: 10
                      onClick: =>
                        if new_comment isnt ''
                          @props.aris.createNoteComment
                            game_id: @props.game.game_id
                            note_id: note.note_id
                            description: new_comment
                          , @successAt 'posting your comment', (comment) =>
                            @fetchComments note
                            @updateState modal: viewing_note: new_comment: $set: ''
                    raw 'POST COMMENT'
              else
                child 'p', =>
                  child 'span.blueButton', =>
                    props
                      style:
                        padding: 5
                        marginRight: 10
                      onClick: => @setState account_menu: true
                    raw 'LOGIN'
                  raw 'to post a new comment'
        select_photo: ({file, orientation}) =>
          child 'div.primaryModal', =>
            props style: backgroundColor: 'white'
            child 'div.grayButton.prevNoteStepButton', =>
              props onClick: =>
                @setState
                  modal: nothing: {}
                  message: null
              child 'div.noteStepsButton', =>
                raw 'CANCEL'
            child 'div.blueButton.nextNoteStepButton', =>
              props
                onClick: => @uploadPhoto file
              child 'div.noteStepsButton', =>
                raw 'DESCRIPTION >'
            if file?
              child 'div', =>
                props
                  className: "exif-#{orientation or 1}"
                  style:
                    position: 'absolute'
                    top: '25%'
                    left: '25%'
                    height: '50%'
                    width: '50%'
                    backgroundImage: "url(#{URL.createObjectURL file})"
                    backgroundSize: 'contain'
                    backgroundRepeat: 'no-repeat'
                    backgroundPosition: 'center'
                    cursor: 'pointer'
                  onClick: => @refs.file_input.click()
            else
              child 'img', =>
                props
                  title: 'Select Image'
                  alt: 'Select Image'
                  src: 'img/select-image.png'
                  style:
                    position: 'absolute'
                    top: 'calc(50% - 56px)'
                    left: 'calc(50% - 69.5px)'
                    cursor: 'pointer'
                  onClick: => @refs.file_input.click()
            child 'form', =>
              props ref: 'file_form', style: {position: 'fixed', left: 9999}
              child 'input', =>
                props
                  type: 'file', name: 'raw_upload', ref: 'file_input'
                  onChange: (e) =>
                    if (newFile = e.target.files[0])?
                      EXIF.getData newFile, =>
                        @updateState modal: select_photo:
                          file:
                            $set: newFile
                          orientation:
                            $set: EXIF.getTag(newFile, 'Orientation') or 1
        uploading_photo: ({progress}) =>
          child 'div.primaryModal', style: {backgroundColor: 'white'}, =>
            child 'div.grayButton.prevNoteStepButton', =>
              props
                onClick: =>
                  @setState
                    modal: nothing: {}
                    message: null
              child 'div.noteStepsButton', =>
                raw 'CANCEL'
            child 'p', =>
              props style: {position: 'absolute', top: '50%', width: '100%', textAlign: 'center'}
              raw "Uploading... (#{Math.floor(progress * 100)}%)"
        enter_description: ({media, description, editing_note, saving, file}) =>
          child 'div.bottomModal', style: {height: 250}, =>
            child 'div.blueButton.prevNoteStepButton', =>
              props onClick: => @setState modal: select_photo: {}
              unless editing_note?
                child 'div.noteStepsButton', =>
                  raw '< IMAGE'
            child 'div.blueButton.nextNoteStepButton', =>
              props
                onClick: =>
                  return if saving
                  if description is ''
                    @setState message: 'Please type a caption for your photo.'
                  else if editing_note?
                    @updateState modal: enter_description: saving: $set: true
                    @props.aris.call 'notes.updateNote',
                      note_id: editing_note.note_id
                      game_id: @props.game.game_id
                      description: description
                    , @successAt 'editing your note', => @refreshEditedNote editing_note.note_id
                  else
                    fileLat = if file? then EXIF.getTag file, 'GPSLatitude'  else null
                    fileLng = if file? then EXIF.getTag file, 'GPSLongitude' else null
                    if fileLat? and fileLng?
                      readRat = (rat) -> rat.numerator / rat.denominator
                      readGPS = ([deg, min, sec]) ->
                        readRat(deg) + readRat(min) / 60 + readRat(sec) / 3600
                      lat = readGPS fileLat
                      lat *= -1 if EXIF.getTag(file, 'GPSLatitudeRef') is 'S'
                      lng = readGPS fileLng
                      lng *= -1 if EXIF.getTag(file, 'GPSLongitudeRef') is 'W'
                      can_reposition = false
                    else
                      lat = @props.game.latitude
                      lng = @props.game.longitude
                      can_reposition = true
                    @updateState
                      latitude: $set: lat
                      longitude: $set: lng
                      zoom: $set: @props.game.zoom
                      modal:
                        $apply: ({enter_description}) =>
                          if can_reposition and 'geolocation' of navigator
                            navigator.geolocation.getCurrentPosition (posn) =>
                              @setState (previousState) =>
                                if previousState.modal.move_point?.can_reposition
                                  update previousState,
                                    latitude: $set: posn.coords.latitude
                                    longitude: $set: posn.coords.longitude
                                else
                                  previousState
                          move_point:
                            update enter_description,
                              dragging: $set: false
                              can_reposition: $set: can_reposition
              child 'div.noteStepsButton', =>
                if editing_note?
                  if saving then raw 'SAVING...' else raw 'SAVE'
                else
                  raw 'LOCATION >'
            child 'img', =>
              props
                title: 'Close'
                alt: 'Close'
                src: 'img/x-blue.png'
                style:
                  position: 'absolute'
                  top: 20
                  right: 20
                  cursor: 'pointer'
                onClick: =>
                  if editing_note?
                    @viewNote editing_note
                  else
                    @setState modal: nothing: {}
            child 'textarea', =>
              props
                style:
                  position: 'absolute'
                  top: 20
                  left: 20
                  width: 'calc(100% - 86px)'
                  height: 'calc(100% - 100px)'
                  fontSize: '20px'
                value: description
                placeholder: @props.game.prompt or 'Enter a caption...'
                onChange: (e) =>
                  @updateState modal: enter_description: description: $set: e.target.value
        move_point: ({media, description, editing_note, saving}) =>
          child SearchBox,
            className: 'the-address-box'
            placeholder: 'Enter a place name or address'
            onPlacesChanged: (places) =>
              if places[0]?
                loc = places[0].geometry.location
                @setState
                  latitude:  loc.lat()
                  longitude: loc.lng()
          child 'div.bottomModal', style: {height: 150}, =>
            child 'p', =>
              props
                style:
                  width: '100%'
                  textAlign: 'center'
                  top: 30
                  position: 'absolute'
              raw 'Drag the map to drop a pin'
            child 'img', =>
              props
                title: 'Close'
                alt: 'Close'
                src: 'img/x-blue.png'
                style:
                  position: 'absolute'
                  top: 20
                  right: 20
                  cursor: 'pointer'
                onClick: =>
                  if editing_note?
                    @viewNote editing_note
                  else
                    @setState modal: nothing: {}
            unless editing_note?
              child 'div.blueButton.prevNoteStepButton', =>
                props
                  onClick: =>
                    @setState modal: enter_description: {media, description}
                child 'div.noteStepsButton', =>
                  raw '< DESCRIPTION'
            child 'div.blueButton.nextNoteStepButton', =>
              props
                onClick: =>
                  return if saving
                  if editing_note?
                    @updateState modal: move_point: saving: $set: true
                    @props.aris.call 'notes.updateNote',
                      note_id: editing_note.note_id
                      game_id: @props.game.game_id
                      trigger:
                        latitude: @state.latitude
                        longitude: @state.longitude
                    , @successAt 'editing your note', => @refreshEditedNote editing_note.note_id
                  else
                    @updateState
                      modal:
                        $apply: ({move_point}) =>
                          select_category:
                            update move_point,
                              latitude: $set: @state.latitude
                              longitude: $set: @state.longitude
                              tag: $set: @props.game.tags[0]
              child 'div.noteStepsButton', =>
                if editing_note?
                  if saving then raw 'SAVING...' else raw 'SAVE'
                else
                  raw 'CATEGORY >'
        select_category: ({media, description, latitude, longitude, tag, editing_note, saving}) =>
          child 'div.bottomModal', style: {paddingBottom: 55, paddingTop: 15}, =>
            child 'div', =>
              props style: {width: '100%', textAlign: 'center', top: 30}
              child 'p', => raw 'Select a Category'
              child 'p', =>
                @props.game.tags.forEach (some_tag) =>
                  checked = some_tag is tag
                  color = @getColor some_tag
                  child 'span', =>
                    props
                      key: some_tag.tag_id
                      style:
                        margin: 5
                        padding: 5
                        border: "1px solid #{color}"
                        color: if checked then 'white' else color
                        backgroundColor: if checked then color else 'white'
                        borderRadius: 5
                        cursor: 'pointer'
                        whiteSpace: 'nowrap'
                        display: 'inline-block'
                      onClick: => @updateState modal: select_category: tag: $set: some_tag
                    raw "#{if checked then '✓' else '●'} #{some_tag.tag}"
            child 'img', =>
              props
                title: 'Close'
                alt: 'Close'
                src: 'img/x-blue.png'
                style: {position: 'absolute', top: 20, right: 20, cursor: 'pointer'}
                onClick: =>
                  if editing_note?
                    @viewNote editing_note
                  else
                    @setState modal: nothing: {}
            unless editing_note? or saving
              child 'div.blueButton.prevNoteStepButton', =>
                props onClick: => @setState modal: move_point: {media, description, latitude, longitude}
                child 'div.noteStepsButton', =>
                  raw '< LOCATION'
            child 'div.blueButton.nextNoteStepButton', =>
              props
                onClick: =>
                  return if saving
                  @updateState modal: select_category: saving: $set: true
                  if editing_note?
                    @props.aris.call 'notes.updateNote',
                      note_id: editing_note.note_id
                      game_id: @props.game.game_id
                      tag_id: tag.tag_id
                    , @successAt 'editing your note', => @refreshEditedNote editing_note.note_id
                  else
                    @props.aris.call 'notes.createNote',
                      game_id: @props.game.game_id
                      description: description
                      media_id: media.media_id
                      trigger: {latitude, longitude}
                      tag_id: tag.tag_id
                    , @successAt 'creating your note', (note) => @refreshEditedNote note.note_id
              child 'div.noteStepsButton', =>
                if editing_note?
                  if saving then raw 'SAVING...' else raw 'SAVE'
                else
                  if saving then raw 'PUBLISHING...' else raw 'PUBLISH! >'

      # Message box (for errors)
      if @state.message?
        child 'div.messageBox', =>
          raw @state.message
          child 'div', =>
            props
              style: {position: 'absolute', left: 10, top: 10, cursor: 'pointer', fontSize: 20}
              onClick: => @setState message: null
            raw 'X'

      # Mobile title and hamburger menu button
      child 'div.mobileTitle', =>
        child 'span.hamburgerButton', =>
          props
            style: cursor: 'pointer'
            onClick: => @setState account_menu: not @state.account_menu
          raw '☰'
        raw ' '
        child 'span.canSelect', => raw @props.game.name

NoSiftr = React.createClass
  render: ->
    make 'div', =>
      child 'p', =>
        props
          style:
            padding: 10
        raw "Sorry, there's no Siftr at this URL."
      child 'p', =>
        props
          style:
            padding: 10
        raw "Want to make one? "
        child 'a', href: ifCordova('../index.html', '..'), =>
          raw 'Visit the Siftr homepage.'

document.addEventListener 'DOMContentLoaded', ->

  siftr_url = window.location.search.replace('?', '')
  if siftr_url.length is 0
    siftr_url = window.location.pathname.replace(/\//g, '')
  unless siftr_url.match(/[^0-9]/)
    siftr_id = parseInt siftr_url
    siftr_url = null

  aris = new Aris
  continueWithGame = (game) ->
    aris.getTagsForGame
      game_id: game.game_id
    , ({data: tags, returnCode}) =>
      if returnCode is 0 and tags?
        game.tags = tags

        aris.getColors
          colors_id: game.colors_id ? 1
        , ({data: colors, returnCode}) =>
          if returnCode is 0 and colors?
            game.colors = colors

            aris.getUsersForGame
              game_id: game.game_id
            , ({data: owners, returnCode}) =>
              if returnCode is 0 and owners?
                game.owners = owners

                document.title = "Siftr - #{game.name}"
                ReactDOM.render React.createElement(App, game: game, aris: aris), document.getElementById('the-container')

  if siftr_id?
    aris.getGame
      game_id: siftr_id
    , ({data: game, returnCode}) ->
      if returnCode is 0 and game?
        continueWithGame game
      else
        ReactDOM.render React.createElement(NoSiftr), document.getElementById('the-container')
  else if siftr_url?
    aris.searchSiftrs
      siftr_url: siftr_url
    , ({data: games, returnCode}) ->
      if returnCode is 0 and games.length is 1
        continueWithGame games[0]
      else
        ReactDOM.render React.createElement(NoSiftr), document.getElementById('the-container')
