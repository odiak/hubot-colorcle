{EventEmitter} = require 'events'
request = require 'superagent'
Log = require 'log'

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

    @logger = new Log options.logLebel or process.env.HUBOT_LOG_LEVEL or 'info'

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
      @logger.info 'Failed to connect:', error
      @reconnect()

    @ws.on 'connect', (@conn) =>
      @logger.info 'Connected'

      @send 'auth', auth_token: @token

      @conn.on 'error', (error) =>
        @logger.info 'Error:', error

      @conn.on 'close', =>
        @logger.info 'Disconnected'
        @reconnect()

      @conn.on 'message', (message) =>
        return unless message.type is 'utf8'

        dataList = JSON.parse message.utf8Data
        for data in dataList
          [type, body] = data
          @emit type, body

    @uri = "#{@wsProtocol}://#{@host}/websocket"
    @ws.connect @uri

  send: (type, data) ->
    return unless @conn

    @conn.sendUTF JSON.stringify [type, {
      id: genId()
      data: data
    }]

  reconnect: ->
    @conn = null
    @_reconnection or= 0
    setTimeout =>
      @logger.info 'Trying to re-connect...'
      @connect()
    , @RETRY_INTERVAL

module.exports = ColorcleClient
