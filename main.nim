import dimscord

import json, asyncdispatch, random, strutils
import tables, options, sequtils, httpclient

import "mod", "utils" # We have to quote mod, due to mod being a thing in Nim.

var config: JsonNode
when defined(relayTest):
    config = readFile("test_config.json").parseJson
else:
    config = readFile("config.json").parseJson
let discord = newDiscordClient(
    config["token"].str,
    rest_version = 10
)

let
    api_guild = "81384788765712384" # Discord API Guild
    r_danny = "80528701850124288" # Discord Bot
    dimscord_news = "743384158428069958" # News Role
    nim_dimscord = "743302883327606885" # From #nim_dimscord

    announcements = "576419090512478228" # Announcement channel
    dimscord_chan = "571359938501410828" # From #dimscord

    acceptable_prefixes = [ # im a bit lazy doing regex matches
        "<@!699969981714006127>",
        "<@699969981714006127>",
        "mota"
    ]
var cached_messages = initTable[string, Message]()

randomize()
proc purge(target: string, m: Message) {.async.} =
    let ids = (await discord.api.getChannelMessages(
        m.channel_id,
        after = $(1 - int64 m.id.parseInt)
    )).filterIt(it.author.id == m.author.id).mapIt(it.id)

    var payload = ids.distribute(2)
    if ids.distribute(2)[1].len <= 2:
        payload = @[ids]

    for msgs in payload:
        await discord.api.bulkDeleteMessages(
            target,
            msgs
        )
proc onDispatch(s: Shard, event: string, data: JsonNode) {.event(discord).} =
    var target = ""
    case event:
    of "MESSAGE_DELETE_BULK":
        if %"657178484875067402" == data["channel_id"]:
            target = "590880974867529733"
        elif %"590880974867529733" == data["channel_id"]:
            target = "657178484875067402"
        else:
            return
        
        let channel = s.cache.guildChannels[data["channel_id"].str]

        let ids = data["ids"].elems.mapIt(it.str)
        if ids[0] in channel.messages:
            await target.purge(channel.messages[ids[0]])
    else:
        discard


proc onReady(s: Shard, e: Ready) {.event(discord).} =
    echo "Mota is ready."
    await s.updateStatus(activity = some ActivityStatus(
        name: "mota help",
        kind: atListening
    ))

proc handleCommands(s: Shard, m: Message;
                    args: seq[string], command: string;
                    channel: GuildChannel) {.async.} =
    case command.toLowerAscii():
    of "help":
        discard await discord.api.sendMessage(
            m.channel_id,
            "Commands are `ping, pin, info, purge, poop, nopoop, typing, msginfo, guildinfo, status, avatar`"
        )
    else:
        asyncCheck s.handleMod(m, args, command, channel)
        await s.handleUtil(m, args, command, channel)
        return

proc messageUpdate(s: Shard, m: Message, o: Option[Message], exists: bool) {.event(discord).} =
    if m.author.isNil: return
    if %m.author.id in config["denied"].elems: return
    var channel = ""
    let dimscord_guild = "571359938501410826" # Dimscord Guild
 
    when not defined(relayTest):
        if m.guild_id.get == "571359938501410826":
            if m.channel_id != dimscord_chan:
                return
            channel = nim_dimscord
        elif m.guild_id.get == "81384788765712384":
            if m.channel_id != nim_dimscord:
                return
            channel = dimscord_chan
        else:
            return
    else:
        if m.channel_id == "657178484875067402": # private
            channel = "590880974867529733"
        elif m.channel_id == "590880974867529733": # testing-with-others
            channel = "657178484875067402"

    if m.content != "" and m.id in cached_messages:
        let msg = cached_messages[m.id]
        if msg.webhook_id.isSome:
            discard await discord.api.editWebhookMessage(
                webhook_id = config[channel]["webhook_id"].str,
                webhook_token = config[channel]["webhook_token"].str,
                cached_messages[m.id].id,
                content = some m.content
            )
        else:
            discard await discord.api.editMessage(channel, cached_messages[m.id].id, "From **" & $m.author & "**:\n" & m.content)
    else:
        return

proc relay(s: Shard, m: Message) {.async.} =
    if m.author.id == r_danny and dimscord_news in m.mention_roles:
        discard await discord.api.sendMessage(
            announcements,
            "From Discord API (#nim_dimscord): \n\n" &
            m.stripMentions.replace("@" & dimscord_news, "News")
        )
    if m.webhook_id.isSome or m.author.bot: return
    when defined(relayTest):
        config = readFile("test_config.json").parseJson
    else:
        config = readFile("config.json").parseJson
    let discord = s.client

    if %m.author.id in config["denied"].elems: return

    var
        username = $m.author
        channel, content = ""
        attachments: seq[Attachment] = @[]

    var avatar = m.author.avatarUrl
    var dimscord_guild = "571359938501410826" # Dimscord Guild
    when not defined(relayTest):
        if m.guild_id.get == "571359938501410826":
            if m.channel_id != dimscord_chan:
                return

            username &= "[FromServer]"
            channel = nim_dimscord

        elif m.guild_id.get == "81384788765712384":
            if m.channel_id != nim_dimscord:
                return

            username &= "[FromAPI]"
            channel = dimscord_chan
        else:
            return
    else:
        if m.channel_id == "657178484875067402": # private
            channel = "590880974867529733"
        elif m.channel_id == "590880974867529733": # testing-with-others
            channel = "657178484875067402"

    if m.attachments.len > 0:
        for i, a in m.attachments:
            let client = newAsyncHttpClient()
            let body = waitFor (waitFor client.get(a.url)).body
            var at = Attachment(
                id: $i,
                filename: a.filename,
                file: body
            )
            if a.description.isSome:
                at.description = some a.description.get
            attachments &= at

        # let prefix = "From **" & $m.author & "**:\n"
        # content = m.content

        # if prefix.len + content.len > 2000:
        #     content = content[0..2000]

        # cached_messages[m.id] = await discord.api.sendMessage(
        #     channel,
        #     prefix & content,
        #     attachments = attachments,
        #     allowed_mentions = some AllowedMentions(
        #         parse: @["users"]
        #     )
        # )
        # return

    if (m.content == "" and not m.attachments.len > 0) or channel == "": return
    cached_messages[m.id] = get(await discord.api.executeWebhook(
        config[channel]["webhook_id"].str,
        config[channel]["webhook_token"].str,
        username = some username,
        avatar_url = some avatar,
        content = m.content,
        attachments = attachments,
        allowed_mentions = some AllowedMentions(
            parse: @["users"]
        ),
    ))

proc messageCreate(s: Shard, m: Message) {.event(discord).} =
    await s.relay(m)

    let args = m.content.split(" ")
    if m.author.bot or args[0] notin acceptable_prefixes: return

    let
        command = args[1]
        channel = s.cache.guildChannels[m.channel_id]

    await s.handleCommands(m, args, command, channel)

waitFor discord.startSession(
    gateway_intents = {
    #   giGuildBans, to be continued...
      giGuilds, giGuildMembers, giGuildMessages, giMessageContent
    }
)
