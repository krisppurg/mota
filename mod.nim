import dimscord
import dimscmd, dimscmd/common

import asyncdispatch, strutils, sequtils, options, tables, json

let
    powerhouse = "222794789567987712" # krisppurg#3211 AKA me
    api_guild = "81384788765712384" # Discord API Guild

# proc `$`(m: Member): string =
#     $m[]

proc handleMod*(discord: DiscordClient, cmd: CommandHandler) =
    cmd.addChat("purge") do (m: Message, limit: int):
        ## normal purge command with limit up to 2..100
        if limit notin 2..100:
            discard discord.api.sendMessage(m.channel_id, "Limit is not in range 2..100")
            return

        if powerhouse != m.author.id:
            discard await discord.api.sendMessage(m.channel_id,
                "You do not have permission to access this command!")
            return

        let messages = await discord.api.getChannelMessages(
            m.channel_id,
            limit = limit,
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

    cmd.addChat("pin") do (m: Message, action: Option[string], id: string):
        ## Pin a message
        if powerhouse != m.author.id:
            discard await discord.api.sendMessage(
                m.channel_id,
                "You do not have permission to access this command!"
            )
            return

        if action.isSome:
            case action.get:
            of "add":
                try:
                    await discord.api.addChannelMessagePin(
                        m.channel_id, id)
                except:
                    discard await discord.api.sendMessage(
                        m.channel_id, "Incorrect ID provided.")
            of "remove":
                try:
                    await discord.api.deleteChannelMessagePin(
                        m.channel_id, id)
                except:
                    discard await discord.api.sendMessage(
                        m.channel_id, "Incorrect ID provided.")
            else:
                discard
        else:
            discard await discord.api.sendMessage(m.channel_id, "nope.")

    cmd.addChat("deletemsg") do (m: Message, id: string):
        if m.author.id != powerhouse:
            discard await discord.api.sendMessage(
                m.channel_id,
                "You do not have permission to access this command!"
            )
            return

            await discord.api.deleteMessage(m.channel_id, id)

    cmd.addChat("rltest") do (m: Message, amount: Option[int]):
        if powerhouse != m.author.id or m.guild_id.get == api_guild:
            discard await discord.api.sendMessage(m.channel_id, "No.")

        if amount.get > 15:
            discard await discord.api.sendMessage(
                m.channel_id, "I'm too lazy to spam.")
            return

        for i in 1..amount.get:
            asyncCheck discord.api.sendMessage(m.channel_id, $i)

    cmd.addChat("disconnect") do (m: Message, amount: int):
        if m.author.id == powerhouse:
            discard await discord.api.sendMessage(
                m.channel_id, "Disconnecting...")
            await discord.endSession()

    cmd.addChat("block") do (m: Message, id: string):
        let guild = s.cache.guilds[m.guild_id.get]
        let channel = s.cache.guildChannels[m.channel_id]

        await s.requestGuildMembers(
            get m.guild_id,
            user_ids = @[m.author.id]
        )
        discord.events.guild_members_chunk = proc (s: Shard, g: Guild,
                    gm: GuildMembersChunk) {.async.} =
            let perms = guild.computePerms(guild.members[m.author.id], channel)

            discord.events.guild_members_chunk = proc (s: Shard, g: Guild,
                        gm: GuildMembersChunk) {.async.} =
                discard

            if permManageChannels in perms.allowed:
                let config = readFile("config.json").parseJson
                config["denied"].add(%id)
                writeFile("config.json", config.pretty(4))
                discard await discord.api.sendMessage(m.channel_id, "👌")

    cmd.addChat("unblock") do (m: Message, id: string):
        let guild = s.cache.guilds[m.guild_id.get]
        let channel = s.cache.guildChannels[m.channel_id]
        await s.requestGuildMembers(
            get m.guild_id,
            user_ids = @[m.author.id]
        )
        discord.events.guild_members_chunk = proc (s: Shard, g: Guild,
                    e: GuildMembersChunk) {.async.} =
            let perms = guild.computePerms(
                guild.members[m.author.id],
                channel
            )

            discord.events.guild_members_chunk = proc (s: Shard, g: Guild,
                e: GuildMembersChunk) {.async.} = discard

            if permManageChannels in perms.allowed:
                let config = readFile("config.json").parseJson
                if %id notin config["denied"].elems: return

                config["denied"].elems.delete(
                    config["denied"].elems.find(%id)
                )
                echo config["denied"]
                echo config["denied"].elems

                writeFile("config.json", config.pretty(4))
                discard await discord.api.sendMessage(m.channel_id, "👌")