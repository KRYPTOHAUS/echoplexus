Client                    = require('../client.js.coffee')
ClientModel               = Client.ClientModel
ClientsCollection         = Client.ClientsCollection
Loader                    = require('../loader.js.coffee').Loader
channelSelectorTemplate   = require('../templates/channelSelector.html')

# Clients:
# abstract this to config.coffee
ChatClient                = require('../modules/chat/client.js.coffee').ChatClient
CodeClient                = require('../modules/code/client.js.coffee').CodeClient
DrawingClient             = require('../modules/draw/client.js.coffee').DrawingClient
CallClient                = require('../modules/call/client.js.coffee').CallClient
InfoClient                = require('../modules/info/client.js.coffee').InfoClient
utility                   = require("../utility.js.coffee")

module.exports.ChannelSwitcher = class ChannelSwitcher extends Backbone.View

  className: "channelSwitcher"
  template: channelSelectorTemplate

  loader: (new Loader()).modules
  modules: [ChatClient, CodeClient, DrawingClient, CallClient, InfoClient]

  initialize: ->
    self = this
    joinChannels = window.localStorage.getObj("joined_channels") or []
    _.bindAll this
    @sortedChannelNames = []
    @loading = 0 #Wether scripts are loading (async lock)
    @channels = {}
    joinChannels = []  unless joinChannels.length

    # some users don't like being in channel '/' on start
    joinChannels.push "/"  if OPTIONS.join_default_channel
    joinChannels.push window.location.pathname  unless window.ua.node_webkit
    _.each _.uniq(joinChannels), (chan) ->
      self.joinChannel chan

    if window.localStorage.getObj("activeChannel")
      self.showChannel window.localStorage.getObj("activeChannel")
    else
      self.showChannel "/" # show the default
    @attachEvents()
    $(window).on "unload", @quickKill

  attachEvents: ->
    self = this
    window.events.on "joinChannel", (channel) ->
      self.joinAndShowChannel channel

    window.events.on "leaveChannel", (channel) ->
      self.leaveChannel channel

    window.events.on "channelPassword", (data) =>
      window.events.trigger "channelPassword:#{@activeChannel}",
        password: data.password

    # show an input after clicking "+ Join Channel"
    @$el.on "click", ".join", =>
      if utility.isMobile()
        channelName = prompt("Which channel?")
        @joinAndShowChannel channelName
      else
        @$el.find("input.channelName").toggle()

    # join a channel by typing in the name after clicking the "+ Join Channel" button and clicking enter
    @$el.on "keydown", "input.channelName", (ev) ->
      if ev.keyCode is 13 # enter key
        channelName = $(this).val()
        ev.preventDefault()
        self.joinAndShowChannel channelName


    # kill the channel when clicking the channel button's close icon
    @$el.on "click", ".channels .channelBtn .close", (ev) ->
      $chatButton = $(this).parents(".channelBtn")
      channel = $chatButton.data("channel")
      ev.stopPropagation() # prevent the event from bubbling up to the .channelBtn bound below
      ev.preventDefault()
      self.leaveChannel channel


    # make the channel corresponding to the clicked channel button active:
    @$el.on "click", ".channels .channelBtn", (ev) ->
      channel = $(this).data("channel")
      self.showChannel channel

    window.events.on "nextChannel", @showNextChannel
    window.events.on "previousChannel", @showPreviousChannel
    window.events.on "leaveChannel", =>
      @leaveChannel @activeChannel

    window.events.on "chat:activity", (data) =>
      @channelActivity data


  quickKill: ->

    # https://github.com/qq99/echoplexus/issues/118
    # so the server doesn't attempt to keep them alive for any more than necessary, the client should be nice and tell us it's leaving
    _.each @channels, (channel) ->
      _.each channel.modules, (module) ->
        module.view.kill()



  leaveChannel: (channelName) ->

    # don't leave an undefined channel or the last channel
    return  if (typeof channelName is "undefined") or (@sortedChannelNames.length is 1)
    channelViews = @channels[channelName].modules
    $channelButton = @$el.find(".channelBtn[data-channel='" + channelName + "']")

    # remove the views, then their $els
    _.each channelViews, (module, key) ->
      module.view.kill()
      module.view.$el.remove()


    # update / delete references:
    @sortedChannelNames = _.without(@sortedChannelNames, channelName)
    delete @activeChannel

    delete @channels[channelName]


    # click on the button closest to this channel's button and activate it before we delete this one:
    if $channelButton.prev().length
      $channelButton.prev().click()
    else
      $channelButton.next().click()
    @sortedChannelNames = _.uniq(@sortedChannelNames)

    # update stored channels for revisit/refresh
    window.localStorage.setObj "joined_channels", @sortedChannelNames

    # remove the button in the channel switcher too:
    $channelButton.remove()

  showNextChannel: ->
    return  unless @hasActiveChannel()
    activeChannelIndex = _.indexOf(@sortedChannelNames, @activeChannel)
    targetChannelIndex = activeChannelIndex + 1

    # prevent array OOB
    targetChannelIndex = targetChannelIndex % @sortedChannelNames.length
    @showChannel @sortedChannelNames[targetChannelIndex]

  showPreviousChannel: ->
    return  unless @hasActiveChannel()
    activeChannelIndex = _.indexOf(@sortedChannelNames, @activeChannel)
    targetChannelIndex = activeChannelIndex - 1

    # prevent array OOB
    targetChannelIndex = @sortedChannelNames.length - 1  if targetChannelIndex < 0
    @showChannel @sortedChannelNames[targetChannelIndex]

  hasActiveChannel: ->
    typeof @activeChannel isnt "undefined"

  showChannel: (channelName) ->
    self = this

    channel = @channels[channelName]
    if channel.isPrivate && !channel.authenticated
      showPrivateOverlay()
    else
      hidePrivateOverlay()

    channelsToDeactivate = _.without(_.keys(@channels), channelName)

    # tell the views to deactivate
    _.each channelsToDeactivate, (channelName) ->
      _.each self.channels[channelName].modules, (module) ->
        module.view.$el.hide()
        module.view.trigger "hide"



    # style the buttons depending on which view is active
    $(".channels .channelBtn", @$el).removeClass "active"
    $(".channels .channelBtn[data-channel='" + channelName + "']", @$el).addClass("active").removeClass "activity"

    # send events to the view we're showing:
    _.each channel.modules, (module) ->
      module.view.$el.show()
      module.view.trigger "show"

    # keep track of which one is currently active
    @activeChannel = channelName

    # allow the user to know that his channel can be joined via URL slug by updating the URL

    # replaceState rather than pushing to keep Back/Forward intact && because we have no other option to perform here atm
    history.replaceState null, "", channelName  if not window.ua.node_webkit and history.replaceState

    # keep track of which one we were viewing:
    window.localStorage.setObj "activeChannel", channelName

  channelActivity: (data) ->
    fromChannel = data.channelName

    # if we hear that there's activity from a channel, but we're not looking at it, add a style to the button to notify the user:
    $(".channels .channelBtn[data-channel='" + fromChannel + "']").addClass "activity"  if fromChannel isnt @activeChannel

  joinChannel: (channelName) ->
    self = this

    if !@channels[channelName]?
      channel =
        clients: new ClientsCollection()
        modules: []
        authenticated: false
        isPrivate: false

      # create an instance of each module:
      _.each @modules, (ClientModule, idx) =>
        if !_.isFunction(ClientModule)
          console.error 'Supplied module is not a callable function'
          return

        return  unless _.isFunction(ClientModule)
        modInstance =
          view: new ClientModule(
            channel: channel
            room: channelName
            config:
              host: window.SOCKET_HOST

            module: @loader[idx]
          )
          config: @loader[idx]

        modInstance.view.$el.hide()
        channel.modules.push modInstance

      self.channels[channelName] = channel
      self.loading -= 1
      self.render()

    @sortedChannelNames.push channelName
    @sortedChannelNames = _.sortBy(@sortedChannelNames, (key) ->
      key
    )
    @sortedChannelNames = _.uniq(@sortedChannelNames)

    # listen for leave events for the newly created channel
    window.events.on "leave:" + channelName, ->
      self.leaveChannel channelName


    # update stored channels for revisit/refresh
    window.localStorage.setObj "joined_channels", @sortedChannelNames

  render: ->
    channelNames = _.sortBy(_.keys(@channels), (key) ->
      key
    )
    @$el.html @template(channels: channelNames)

    # clear out old pane:
    _.each @channels, (channel, channelName) ->
      channelViews = channel.modules
      _.each channelViews, (module) ->
        if module.config?
          $("#" + module.config.section).append module.view.$el  unless $("." + module.view.className + "[data-channel='" + channelName + "']").length



  joinAndShowChannel: (channelName) ->
    self = this
    return  if typeof channelName is "undefined" or channelName is null # prevent null channel names
    # keep channel names consistent with URL slug
    channelName = "/" + channelName  if channelName.charAt(0) isnt "/"
    @joinChannel channelName
    @showChannel channelName

