# when defined(dimscordStable):
import dimscord
# else:
#     import  ../../dimscord/dimscord

import asyncdispatch, strutils, sequtils, options, tables, json

let
    powerhouse = "222794789567987712" # krisppurg#3211 AKA me
    api_guild = "81384788765712384" # Discord API Guild

proc `$`(m: Member): string =
    $m[]

proc handleMod*(s: Shard, m: Message;
                args: seq[string], command: string;
                channel: GuildChannel) {.async.} =
    let discord = s.client

    case command.toLowerAscii():
    of "purge":
        if powerhouse != m.author.id:
            discard await discord.api.sendMessage(m.channel_id,
                "You do not have permission to access this command!")
            return

        let messages = await discord.api.getChannelMessages(
            m.channel_id,
            limit = max(2,
                min(100,
                    if args.len < 3: 5 else: args[2].parseInt
                )
            ),
            before = m.id
        )
        await discord.api.bulkDeleteMessages(
            m.channel_id, messages.mapIt(it.id)
        )
        await sleepAsync 5000
        await discord.api.deleteMessage(
            m.channel_id, m.id,
            reason = "Prune requested by " & $m.author &
                    " | Message: \"" & m.content & "\""
        )
    of "pin":
        if powerhouse != m.author.id:
            discard await discord.api.sendMessage(
                m.channel_id,
                "You do not have permission to access this command!"
            )
            return

        if args.len >= 2:
            case args[2]:
            of "add":
                if args.len == 3:
                    discard await discord.api.sendMessage(
                        m.channel_id,
                        "You need to specify a message ID!"
                    )
                else:
                    let id = args[3]

                    try:
                        await discord.api.addChannelMessagePin(
                            m.channel_id, id)
                    except:
                        discard await discord.api.sendMessage(
                            m.channel_id,
                            "Incorrect ID provided."
                        )
            of "remove":
                if args.len == 3:
                    discard await discord.api.sendMessage(
                        m.channel_id,
                        "You need to specify a message ID!"
                    )
                else:
                    let id = args[3]

                    try:
                        await discord.api.deleteChannelMessagePin(
                            m.channel_id, id)
                    except:
                        discard await discord.api.sendMessage(
                            m.channel_id, "Incorrect ID provided.")
            else:
                discard
        else:
            discard await discord.api.sendMessage(m.channel_id, "nope")
    of "deletemsg":
        if m.author.id != powerhouse:
            discard await discord.api.sendMessage(
                m.channel_id,
                "You do not have permission to access this command!"
            )
            return

        if args.len == 3:
            await discord.api.deleteMessage(m.channel_id, args[2])
    of "rltest":
        if powerhouse != m.author.id or m.guild_id.get == api_guild:
            discard await discord.api.sendMessage(m.channel_id, "No.")
        let amount = if args.len == 3: parseInt(args[2]) else: 5

        if amount > 15:
            discard await discord.api.sendMessage(
                m.channel_id, "I'm too lazy to spam.")
            return

        for i in 1..amount:
            asyncCheck discord.api.sendMessage(m.channel_id, $i)
    of "disconnect":
        if m.author.id == powerhouse:
            discard await discord.api.sendMessage(
                m.channel_id, "Disconnecting...")
            await discord.endSession()
    of "block":
        if m.guild_id.isNone or args.len == 2: return
        let guild = s.cache.guilds[m.guild_id.get]
        let channel = s.cache.guildChannels[m.channel_id]
        await s.requestGuildMembers(
            get m.guild_id,
            user_ids = @[m.author.id]
        )
        discord.events.guild_members_chunk = proc (s: Shard, g: Guild,
                    gm: GuildMembersChunk) {.async.} =
            let perms = guild.computePerms(
                guild.members[m.author.id],
                channel
            )

            echo perms

            discord.events.guild_members_chunk = proc (s: Shard, g: Guild,
                        gm: GuildMembersChunk) {.async.} =
                discard

            if permManageChannels in perms.allowed:
                let config = readFile("config.json").parseJson
                config["denied"].add(%args[2])
                writeFile("config.json", config.pretty(4))
                discard await discord.api.sendMessage(m.channel_id, "👌")
    of "unblock":
        if m.guild_id.isNone or args.len == 2: return
        let guild = s.cache.guilds[m.guild_id.get]
        let channel = s.cache.guildChannels[m.channel_id]
        await s.requestGuildMembers(
            get m.guild_id,
            user_ids = @[m.author.id]
        )
        discord.events.guild_members_chunk = proc (s: Shard, g: Guild,
                    gm: GuildMembersChunk) {.async.} =
            let perms = guild.computePerms(
                guild.members[m.author.id],
                channel
            )

            echo perms

            discord.events.guild_members_chunk = proc (s: Shard, g: Guild,
                        gm: GuildMembersChunk) {.async.} =
                discard

            if permManageChannels in perms.allowed:
                let config = readFile("config.json").parseJson
                if %args[2] notin config["denied"].elems: return

                config["denied"].elems.delete(
                    config["denied"].elems.find(%args[2])
                )
                echo config["denied"]
                echo config["denied"].elems

                writeFile("config.json", config.pretty(4))
                discard await discord.api.sendMessage(m.channel_id, "👌")

    else:
        discard