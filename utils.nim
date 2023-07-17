import dimscord, dimscmd
import dimscmd/common

import asyncdispatch, strutils, options, tables, times, strformat

proc handleUtil*(discord: DiscordClient, cmd: CommandHandler) =
    cmd.addChat("ping") do (m: Message):
        ## Ping!
        let
            content = "Pong.  Gateway: " & $s.latency() & "ms."
            epochBefore = epochTime() * 1000
            msg = await discord.api.sendMessage(m.channel_id, content)

        discard await discord.api.editMessage(
            m.channel_id, msg.id,
            content & " | API: " & $int(epochTime() * 1000 - epochBefore) &
            "ms."
        )

    cmd.addChat("info") do (m: Message):
        discard await discord.api.sendMessage(
            m.channel_id,
            embeds = @[Embed(
                title: some "Here's some information about me.",
                description: some "I am a Discord Bot written in the " &
                    "[Nim programming language](https://nim-lang.org)",
                fields: some @[EmbedField(
                        name: "Running on", value: "Linux Mint",
                        inline: some true
                    ), EmbedField(
                        name: "Lib", value: "Dimscord (" & libVer & ")",
                        inline: some true)
                    ])])

    cmd.addChat("poop") do (m: Message):
        ## yes.
        await discord.api.addMessageReaction(m.channel_id, m.id, "💩")

    cmd.addChat("nopoop") do (m: Message):
        ## removes the poop emoji
        let channel = s.cache.guildChannels[m.channel_id]
        for msg in channel.messages.values:
            if "💩" in msg.reactions and msg.reactions["💩"].reacted:
                await discord.api.deleteMessageReaction(
                    msg.channel_id,
                    msg.id, "💩"
                )

    cmd.addChat("typing") do (m: Message):
        await discord.api.triggerTypingIndicator(m.channel_id)
        discard await discord.api.sendMessage(
            m.channel_id, "I finished typing.")

    cmd.addChat("msginfo") do (m: Message, id: Option[string]):
        ## get info of message stored cache of mine.
        let channel = s.cache.guildChannels[m.channel_id]
        var
            msg = m
            mid = id.get m.id

        if mid != msg.id:
            if mid notin channel.messages:
                discard await discord.api.sendMessage(
                    channel.id, "I'm unable to find the cached message.")
                return
            msg = channel.messages[mid]

        discard await discord.api.sendMessage(
            m.channel_id, &"```Message{msg[]}```")

    cmd.addChat("guildinfo") do (m: Message):
        ## get guild info that is printed terribly due to my laziness
        discard await discord.api.sendMessage(m.channel_id, files = @[
            DiscordFile(
                name: "guild.txt",
                body: $s.cache.guilds[m.guild_id.get][]
            )
        ])

    cmd.addChat("avatar") do (m: Message, id: Option[string]):
        ## get user avatar
        var
            user = m.author
            uid = id.get m.author.id

        if uid != user.id:
            if uid notin s.cache.users:
                try:
                    user = await discord.api.getUser(uid)
                except:
                    discard await discord.api.sendMessage(
                        m.channel_id, "Invalid user.")
                    return
            else:
                user = s.cache.users[uid]

        discard await discord.api.sendMessage(
            m.channel_id, user.avatarUrl("png", size = 256))

    cmd.addChat("defaultavatar") do (m: Message, id: Option[string]):
        ## get user default avatar
        var
            user = m.author
            uid = id.get m.author.id

        if uid != user.id:
            uid = get id
            if uid notin s.cache.users:
                try:
                    user = await discord.api.getUser(uid)
                except:
                    discard await discord.api.sendMessage(
                        m.channel_id, "Invalid user.")
                    return
            else:
                user = s.cache.users[uid]

        discard await discord.api.sendMessage(
            m.channel_id, user.defaultAvatarUrl())