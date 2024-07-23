-- Name: ConfusedLlama
-- PID: RgIs2u58lV3032gWhytemDNF2NmwZGKWQ0ClB0mqaK0

PALM_ISLAND_PID = "OqvzTvpHYrfswvVZdsSldVTNBnyBOk7kZf-oqDdvUjg"

CHAT_TARGET = PALM_ISLAND_PID

TIMESTAMP_LAST_MESSAGE_MS = TIMESTAMP_LAST_MESSAGE_MS or 0
COOLDOWN_MS = 5000

Handlers.add(
  'DefaultInteraction',
  Handlers.utils.hasMatchingTag('Action', 'DefaultInteraction'),
  function(msg)
    print('DefaultInteraction')
    if ((msg.Timestamp - TIMESTAMP_LAST_MESSAGE_MS) < COOLDOWN_MS) then
      return
    end

    Send({
      Target = CHAT_TARGET,
      Tags = {
        Action = 'ChatMessage',
        ['Author-Name'] = 'Confused Llama',
      },
      Data = "You call those Palm trees? What a disappointment",
    })

    TIMESTAMP_LAST_MESSAGE_MS = msg.Timestamp
  end
)