util             = require "util"
{EventEmitter}   = require "events"
{MailParser}     = require "mailparser"
{ImapConnection} = require "imap"

# MailListener class. Can `emit` events in `node.js` fashion.
class MailListener extends EventEmitter

  constructor: (options) ->
    # TODO add validation for required parameters
    @imap = new ImapConnection
      username: options.username
      password: options.password
      host: options.host
      port: options.port
      secure: options.secure
    @mailbox = options.mailbox || "INBOX"
  
  getmail: =>
    @imap.search ["UNSEEN"], (err, searchResults) =>
      if err
        console.log "error searching unseen emails #{err}"
        @emit "error", err
      else              
        console.log "found #{searchResults.length} emails"
        # 5. fetch emails
        if searchResults.length > 0
          @imap.fetch searchResults, { markSeen: true },
            headers:
              parse: false
            body: true
            cb: (fetch) =>
              # 6. email was fetched. Parse it!   
              fetch.on "message", (msg) =>
                parser = new MailParser
                parser.on "end", (mail) =>
                  #console.log "parsed mail" + util.inspect mail, false, 5
                  @emit "mail:parsed", mail
                msg.on "data", (data) -> parser.write data.toString()
                msg.on "end", ->
                  #console.log "fetched message: " + util.inspect(msg, false, 5)
                  parser.end()
  
  # start listener
  start: => 
    # 1. connect to imap server  
    @imap.connect (err) =>
      if err
        console.log "error connecting to mail server #{err}"
        @emit "error", err
      else
        #console.log "successfully connected to mail server"
        @emit "server:connected"
        # 2. open mailbox
        @imap.openBox @mailbox, false, (err) =>
          if err
            console.log "error opening mail box '#{@mailbox}'  #{err}"
            @emit "error", err
          else
            #console.log "successfully opened mail box '#{@mailbox}'"  
            do @getmail
            # 3. listen for new emails in the inbox
            @imap.on "mail", (id) =>
              console.log "new mail arrived with id #{id}"
              @emit "mail:arrived", id
              do @getmail
              
  # stop listener
  stop: =>
    @imap.logout =>
      @emit "server:disconnected"

module.exports = MailListener
