{Adapter, TextMessage, User} = require 'hubot'
ColorcleClient = require './colorcle-client'

HOST = process.env.COLORCLE_HOST
SECURE =
  if process.env.COLORCLE_SECURE?
    !!process.env.COLORCLE_SECURE
  else
    null
TOKEN = process.env.COLORCLE_TOKEN


class ColorcleBot extends Adapter

  constructor: (@robot) ->
    @robot.logger.info 'Constructor'

  send: (envelope, strings...) ->
    @robot.logger.info "Send"
    for string in strings
      @client.send 'messages.create',
        message_room_id: envelope.room
        text: string

  reply: (envelope, strings...) ->
    @robot.logger.info "Reply"

  run: ->
    @robot.logger.info "Run!!"
    @emit "connected"

    @client = new ColorcleClient
      host: HOST
      secure: SECURE
      token: TOKEN

    @client.on 'websocket_rails.ping', =>

    @client.on 'messages.created', ({data: message}) =>
      return if message.author_account.id == @client.accountId

      user = @robot.brain.userForId message.author_account.id,
        name: message.author_account.name
        avatarImageUrl: message.author_account.avatar_thumb
        room: message.message_room_id
      @robot.receive new TextMessage user, message.text, message.id


exports.use = (robot) ->
  new ColorcleBot robot

exports.ColorcleBot = ColorcleBot
