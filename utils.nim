import dimscord

import asyncdispatch, strutils, options, tables, times, strformat

proc handleUtil*(s: Shard, m: Message;
                args: seq[string], command: string;
                channel: GuildChannel) {.async.} =
    let discord = s.client

    case command.toLowerAscii():
    of "ping":
        let
            content = "Pong.  Gateway: " & $s.latency() & "ms."
            epochBefore = epochTime() * 1000
            msg = await discord.api.sendMessage(m.channel_id, content)

        discard await discord.api.editMessage(
            m.channel_id, msg.id,
            content & " | API: " & $int(epochTime() * 1000 - epochBefore) &
            "ms."
        )
    of "info":
        discard await discord.api.sendMessage(
            m.channel_id,
            embeds = @[Embed(
                title: some "Here's some information about me.",
                description: some "I am a Discord Bot written in the " &
                    "[Nim programming language](https://nim-lang.org)",
                fields: some @[
                    EmbedField(
                        name: "Running on",
                        value: "Kali Linux",
                        inline: some true),
                    EmbedField(
                        name: "Lib",
                        value: "Dimscord (" & libVer & ")",
                        inline: some true)
                ]
            )]
        )
    of "poop":
        await discord.api.addMessageReaction(m.channel_id, m.id, "💩")
    of "nopoop":
        for msg in channel.messages.values:
            if "💩" in msg.reactions and msg.reactions["💩"].reacted:
                await discord.api.deleteMessageReaction(
                    m.channel_id,
                    msg.id, "💩"
                )
    of "typing":
        await discord.api.triggerTypingIndicator(m.channel_id)
        discard await discord.api.sendMessage(
            m.channel_id, "I finished typing.")
    of "msginfo":
        var
            msg: Message
            mess_id = m.id

        if args.len == 3:
            mess_id = args[2]
            if mess_id notin channel.messages:
                discard await discord.api.sendMessage(
                    m.channel_id, "I'm unable to find the cached message.")
                return

        msg = channel.messages[mess_id]

        discard await discord.api.sendMessage(
            m.channel_id, &"```Message{msg[]}```")
    of "guildinfo":
        var guil_id = m.guild_id.get

        discard await discord.api.sendMessage(m.channel_id, files = @[
            DiscordFile(
                name: "guild.txt",
                body: $s.cache.guilds[guil_id][]
            )
        ])
    of "avatar":
        var
            id = m.author.id
            user = m.author

        if args.len > 2:
            id = args[2]
            if id notin s.cache.users:
                try:
                    user = await discord.api.getUser(id)
                except:
                    discard await discord.api.sendMessage(
                        m.channel_id, "Invalid user.")

        discard await discord.api.sendMessage(
            m.channel_id, user.avatarUrl("png", size = 256))
    else:
        discard
