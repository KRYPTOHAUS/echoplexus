# customize me:
exports.Configuration =
  host:
    SCHEME: "http" # used in generating URLs
    FQDN: "localhost"
    PORT: 8080
    USE_PORT_IN_URL: true

  redis:
    host: "127.0.0.1"
    port: 6379
    select: 15

  ssl:
    USE_NODE_SSL: false # only necessary if you're not having nginx proxy through to node
    PRIVATE_KEY: "/path/to/server.key"
    CERTIFICATE: "/path/to/certificate.crt"

  features:
    SERVER_NICK: "Server"
    irc_server: false # beta atm, you may not want to enable this as server stability isn't guaranteed

  chat:
    log: true # keeps a log server-side for participants who may have been offline

    webshot_previews: # requires phantomjs to be installed
      enabled: true # http://www.youtube.com/watch?feature=player_detailpage&v=k3-zaTr6OUo#t=23s
      PHANTOMJS_PATH: "/usr/bin/phantomjs" # sudo apt-get install phantomjs

    rate_limiting: # slows down spammers
      enabled: true
      rate: 5.0 # # allowed messages
      per: 8000.0 # per # of seconds

    edit: # can users edit sent messages?
      enabled: true
      allow_unidentified: true # whether anonymous users can edit their messages within the context of the same session
      maximum_time_delta: (1000 * 60 * 60 * 2) # after 2 hours, chat messages will not be editable, delete property to enable indefinitely

  server_hosted_file_transfer:
    enabled: false
    size_limit: "10mb" # nginx user? make sure this matches your nginx configuration: e.g., look for line `client_max_body_size 10M;`

  DEBUG: false
