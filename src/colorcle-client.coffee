{EventEmitter} = require 'events'
request = require 'superagent'

{client: WebSocketClient} = require 'websocket'


genId = ->
  Math.random() * 1000000 | 0

class ColorcleClient extends EventEmitter

  RETRY_INTERVAL: 1000 * 10
  MAX_RETRIES: 100

  constructor: (options) ->
    {@token, @host, @secure} = options
    @host or= 'api.colorcle.com'
    @secure = true unless @secure?

    @wsProtocol = if @secure then 'wss' else 'ws'
    @httpProtocol = if @secure then 'https' else 'http'

    @on 'websocket_rails.ping', =>
      @send 'websocket_rails.pong',
        id: Math.random() * 100000 | 0,
        data: {}

    request
      .get "#{@httpProtocol}://#{@host}/api/accounts/my_info"
      .set 'Authorization', @token
      .end (err, res) =>
        return if err or not res.ok
        @accountId = res.body.id
        @connect()

  connect: ->
    @ws = new WebSocketClient

    @ws.on 'connectFailed', (error) =>
      console.log 'Failed to connect:', error
      @reconnect()

    @ws.on 'connect', (@conn) =>
      console.log 'Connected'

      @send 'auth', auth_token: @token

      @conn.on 'error', (error) =>
        console.log 'Connection Error:', error

      @conn.on 'close', =>
        console.log 'Closed'
        @reconnect()

      @conn.on 'message', (message) =>
        return unless message.type is 'utf8'

        dataList = JSON.parse message.utf8Data
        for data in dataList
          [type, body] = data
          console.log 'Receive:', type, body
          @emit type, body

    @uri = "#{@wsProtocol}://#{@host}/websocket"
    @ws.connect @uri

  send: (type, data) ->
    return unless @conn

    console.log 'Send:', type, data

    @conn.sendUTF JSON.stringify [type, {
      id: genId()
      data: data
    }]

  reconnect: ->
    @conn = null
    @_reconnection or= 0
    setTimeout =>
      console.log 'Trying to re-connect...'
      @connect()
    , @RETRY_INTERVAL

module.exports = ColorcleClient
