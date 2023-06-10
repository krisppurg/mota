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
    dapi_guild = "81384788765712384" # Discord API Guild
    dimscord_guild = "571359938501410826" # Dimscord Guild
    private = "657178484875067402" # private
    testingwithothers = "590880974867529733" # testing-with-others
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
var cached_messages_sent = initTable[string, Message]()
var cached_messages_recv = initTable[string, string]()

randomize()

proc messageDeleteBulk(s: Shard, messages: seq[tuple[msg: Message, exists: bool]]) {.event(discord).} =
    var channel = messages[0].msg.channel_id
    when defined(relayTest):
        if channel == dimscord_chan:
            channel = nim_dimscord
        elif channel == nim_dimscord:
            channel = dimscord_chan
        else:
            return
    else:
        if channel == private:
            channel = testingwithothers
        elif channel == testingwithothers:
            channel = private
        else:
            return

    var relayed = messages.filterIt(it.msg.id in cached_messages_sent).mapIt(cached_messages_sent[it.msg.id])
    var unrelayed = messages.filterIt(it.msg.id notin cached_messages_sent)

    if relayed.len == 1: 
        cached_messages_recv.del(cached_messages_sent[relayed[0].id].id)
        cached_messages_sent.del(relayed[0].id)
        await discord.api.deleteWebhookMessage(
            webhook_id = config[channel]["webhook_id"].str,
            webhook_token = config[channel]["webhook_token"].str,
            relayed[0].id
        )
    else:
        if relayed.len != 0:
            let ids = relayed.mapIt(it.id)
            for id in ids:
                cached_messages_recv.del cached_messages_sent[id].id
                cached_messages_sent.del id

            try:
                await discord.api.bulkDeleteMessages(channel, ids)
            except:
                raise newException(Exception, getCurrentExceptionMsg())

    if unrelayed.len != 0:
        let ids = (await discord.api.getChannelMessages(
            channel,
            after = $(int64(unrelayed[0].msg.id.parseInt-7))
        )).mapIt(it.id)

        if ids.len == 0: return

        if ids.len == 1:
            await discord.api.deleteWebhookMessage(
                webhook_id = config[channel]["webhook_id"].str,
                webhook_token = config[channel]["webhook_token"].str,
                ids[0]
            )
        return

        try:
            await discord.api.bulkDeleteMessages(channel, ids)
        except:
            raise newException(Exception, getCurrentExceptionMsg())


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
 
    when not defined(relayTest):
        if m.guild_id.get == dimscord_guild:
            if m.channel_id != dimscord_chan: return
            channel = nim_dimscord
        elif m.guild_id.get == dapi_guild:
            if m.channel_id != nim_dimscord: return
            channel = dimscord_chan
        else:
            return
    else:
        if m.channel_id == private: # private
            channel = testingwithothers
        elif m.channel_id == testingwithothers: # testing with others
            channel = private

    if m.content != "" and m.id in cached_messages_sent:
        let msg = cached_messages_sent[m.id]
        if msg.webhook_id.isSome:
            discard await discord.api.editWebhookMessage(
                webhook_id = config[channel]["webhook_id"].str,
                webhook_token = config[channel]["webhook_token"].str,
                cached_messages_sent[m.id].id,
                content = some m.content
            )
    else:
        return

proc messageDelete(s: Shard, m: Message, exists: bool) {.event(discord).} =
    if m.author.isNil: return
    if %m.author.id in config["denied"].elems: return
    var
        channel = ""
        target = ""

 
    when not defined(relayTest):
        if m.guild_id.get == dimscord_guild:
            if m.channel_id != dimscord_chan: return
            channel = nim_dimscord
        elif m.guild_id.get == dapi_guild:
            if m.channel_id != nim_dimscord: return
            channel = dimscord_chan
        else:
            return
    else:
        if m.channel_id == private: # private
            channel = testingwithothers
        elif m.channel_id == testingwithothers: # testing-with-others
            channel = private

    if m.content != "":
        if m.id in cached_messages_sent:
            target = cached_messages_sent[m.id].id
            cached_messages_recv.del(target) # webhook relayed msg
            cached_messages_sent.del(m.id)
            await discord.api.deleteWebhookMessage(
                webhook_id = config[channel]["webhook_id"].str,
                webhook_token = config[channel]["webhook_token"].str,
                target
            )
        if m.id in cached_messages_recv:
            target = cached_messages_recv[m.id]
            cached_messages_sent.del(target)
            cached_messages_recv.del(m.id)
            await discord.api.deleteMessage(channel, target)
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
        channel = ""
        attachments: seq[Attachment] = @[]

    var avatar = m.author.avatarUrl

    if m.author.discriminator == "0": username = m.author.username

    when not defined(relayTest):
        if m.guild_id.get == dimscord_guild:
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
        if m.channel_id == private: # private
            channel = testingwithothers
        elif m.channel_id == testingwithothers: # testing-with-others
            channel = private

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

    if (m.content == "" and not m.attachments.len > 0) or channel == "": return
    cached_messages_sent[m.id] = get(await discord.api.executeWebhook(
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
    cached_messages_recv[cached_messages_sent[m.id].id] = m.id

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
