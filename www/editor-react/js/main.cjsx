React = require 'react/addons'
GoogleMap = require 'google-map-react'
{markdown} = require 'markdown'
for k, v of require '../../shared/aris.js'
  window[k] = v

renderMarkdown = (str) ->
  __html: markdown.toHTML str

countContributors = (notes) ->
  user_ids = {}
  for note in notes
    user_ids[note.user.user_id] = true
    for comment in note.comments
      user_ids[comment.user.user_id] = true
  Object.keys(user_ids).length

App = React.createClass
  getInitialState: ->
    auth: null
    games: []
    tags: {}
    notes: {}
    username: ''
    password: ''
    edit_game: null

  componentDidMount: ->
    @login undefined, undefined
    @applyHash()
    window.addEventListener 'hashchange', => @applyHash()

  applyHash: ->
    hash = window.location.hash[1..]
    if hash[0..3] is 'edit'
      game_id = parseInt hash[4..]
      matchingGames =
        game for game in @state.games when game.game_id is game_id
      if matchingGames.length is 1
        @setState edit_game: matchingGames[0]
      else
        @setState edit_game: null
    else
      @setState edit_game: null

  login: (username, password) ->
    @props.aris.login username, password, => @updateLogin()

  logout: ->
    window.location.hash = '#'
    @props.aris.logout()
    @updateLogin()

  updateLogin: ->
    @setState auth: @props.aris.auth
    @updateGames()

  updateGames: ->
    if @props.aris.auth?
      @props.aris.getGamesForUser {}, (result) =>
        if result.returnCode is 0 and result.data?
          @setState
            games:
              game for game in result.data when game.is_siftr
            tags: {}
            notes: {}
          @applyHash()
          @updateTags result.data
          @updateNotes result.data
        else
          @setState games: []
    else
      @setState games: []

  updateNotes: (games) ->
    games.forEach (game) =>
      @props.aris.searchNotes
        game_id: game.game_id
      , (result) =>
        if result.returnCode is 0 and result.data?
          @setState (previousState, currentProps) =>
            React.addons.update previousState,
              notes:
                $merge: do =>
                  obj = {}
                  obj[game.game_id] = result.data
                  obj

  updateTags: (games) ->
    games.forEach (game) =>
      @props.aris.getTagsForGame
        game_id: game.game_id
      , (result) =>
        if result.returnCode is 0 and result.data?
          @setState (previousState, currentProps) =>
            React.addons.update previousState,
              tags:
                $merge: do =>
                  obj = {}
                  obj[game.game_id] = result.data
                  obj

  handleSave: ->
    @props.aris.updateGame @state.edit_game
    , (result) =>
      window.location.hash = '#'
      if result.returnCode is 0 and result.data?
        newGame = result.data
        @setState (previousState, currentProps) =>
          React.addons.update previousState,
            games:
              $apply: (games) =>
                for game in games
                  if game.game_id is newGame.game_id
                    newGame
                  else
                    game

  render: ->
    <div>
      <div id="the-nav-bar">
        <div id="the-logo">Siftr</div>
        <div id="the-discover-button">Discover</div>
        <div id="the-my-account-button">My Account</div>
        <div id="the-my-siftrs-button">My Siftrs</div>
      </div>
      { if @state.auth?
          <form>
            <p><code>{ JSON.stringify @state.auth }</code></p>
            <button type="button" onClick={@logout}>Logout</button>
            {
              if @state.edit_game?
                <EditSiftr
                  game={@state.edit_game}
                  onChange={(game) => @setState edit_game: game}
                  onSave={@handleSave}
                  />
              else
                <SiftrList
                  games={@state.games}
                  notes={@state.notes}
                  tags={@state.tags}
                  />
            }
          </form>
        else
          <form>
            <p>
              <input type="text" placeholder="Username" value={@state.username} onChange={(e) => @setState username: e.target.value} />
            </p>
            <p>
              <input type="password" placeholder="Password" value={@state.password} onChange={(e) => @setState password: e.target.value} />
            </p>
            <p>
              <button type="button" onClick={=> @login @state.username, @state.password}>Login</button>
            </p>
          </form>
      }
    </div>

SiftrList = React.createClass
  render: ->
    <ul>
      { for game in @props.games
          do (game) =>
            notes = @props.notes[game.game_id]
            <li key={"game-#{game.game_id}"}>
              <p>
                { game.name }
                {' '} <a href={"#{SIFTR_URL}#{game.siftr_url or game.game_id}"}>[View]</a>
                {' '} <a href={"\#edit#{game.game_id}"}>[Edit]</a>
              </p>
              <p>
                { notes?.length ? '...' } items
                {' | '} { if notes? then countContributors(notes) else '...' } contributors
                {' | '} { if game.published then 'Public' else 'Private' }
                {' | '} { if game.moderated then 'Moderated' else 'Non-Moderated' }
              </p>
            </li>
      }
    </ul>

EditSiftr = React.createClass
  render: ->
    <form>
      <p>
        <label>
          Name <br />
          <input ref="name" type="text" value={@props.game.name} onChange={@handleChange} />
        </label>
      </p>
      <p>
        <label>
          Description <br />
          <textarea ref="description" value={@props.game.description} onChange={@handleChange} />
        </label>
      </p>
      <div dangerouslySetInnerHTML={renderMarkdown @props.game.description} />
      <p>
        <label>
          URL <br />
          <input ref="siftr_url" type="text" value={@props.game.siftr_url} onChange={@handleChange} />
        </label>
      </p>
      <p>
        Your Siftr's URL will be <code>{"#{SIFTR_URL}#{@props.game.siftr_url or @props.game.game_id}"}</code>
      </p>
      <p>
        <label>
          <input ref="published" type="checkbox" checked={@props.game.published} onChange={@handleChange} />
          Published
        </label>
      </p>
      <p>
        <label>
          <input ref="moderated" type="checkbox" checked={@props.game.moderated} onChange={@handleChange} />
          Moderated
        </label>
      </p>
      <div style={width: '500px', height: '500px'}>
        <GoogleMap
          ref="map"
          center={[@props.game.latitude, @props.game.longitude]}
          zoom={@props.game.zoom}
          onBoundsChange={@handleMapChange}>
        </GoogleMap>
      </div>
      <p>
        <button type="button" onClick={@props.onSave}>Save changes</button>
      </p>
      <p><a href="#">Back to Siftr list</a></p>
    </form>

  handleChange: ->
    game = React.addons.update @props.game,
      name:
        $set: @refs['name'].getDOMNode().value
      description:
        $set: @refs['description'].getDOMNode().value
      siftr_url:
        $set: @refs['siftr_url'].getDOMNode().value or null
      published:
        $set: @refs['published'].getDOMNode().checked
      moderated:
        $set: @refs['moderated'].getDOMNode().checked
    @props.onChange game

  handleMapChange: ([lat, lng], zoom, bounds, marginBounds) ->
    game = React.addons.update @props.game,
      latitude:
        $set: lat
      longitude:
        $set: lng
      zoom:
        $set: zoom
    @props.onChange game

document.addEventListener 'DOMContentLoaded', (event) ->
  React.render <App aris={new Aris} />, document.body
