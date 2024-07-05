local json = require("json")
local sqlite3 = require('lsqlite3')

BankerDb = BankerDb or sqlite3.open_memory()
BankerDbAdmin = BankerDbAdmin or require('DbAdmin').new(BankerDb)

WAITLIST_PROCESS = WAITLIST_PROCESS or "TODO: WaitlistProcessId"

LLAMA_TOKEN_PROCESS = LLAMA_TOKEN_PROCESS or "TODO: LlamaTokenProcessId"
LLAMA_TOKEN_DENOMINATION = LLAMA_TOKEN_DENOMINATION or 12
LLAMA_TOKEN_MULTIPLIER = 10 ^ LLAMA_TOKEN_DENOMINATION

HOURLY_EMISSION_LIMIT = 100 * LLAMA_TOKEN_MULTIPLIER

WRAPPED_ARWEAVE_TOKEN_PROCESS = WRAPPED_ARWEAVE_TOKEN_PROCESS or "TODO: WarProcessId"
WRAPPED_ARWEAVE_DENOMINATION = 12
WRAPPED_ARWEAVE_MULTIPLIER = 10 ^ WRAPPED_ARWEAVE_DENOMINATION
WRAPPED_ARWEAVE_MIN_QUANTITY = 1000000000   -- 1 Billion
WRAPPED_ARWEAVE_CAP_QUANTITY = 1000000000   -- 1 Billion
WRAPPED_ARWEAVE_MAX_QUANTITY = 100000000000 -- 100 Billion

MAXIMUM_PETITIONS_PER_DAY = MAXIMUM_PETITIONS_PER_DAY or 1

LLAMA_KING_PROCESS = LLAMA_KING_PROCESS or "TODO: LlamaKingProcessId"

LLAMA_FED_CHAT_PROCESS = LLAMA_FED_CHAT_PROCESS or "TODO: ChatProcessId"

--#region Initialization

SQLITE_TABLE_AUTHORISED = [[
  CREATE TABLE IF NOT EXISTS Authorised (
    WalletId TEXT PRIMARY KEY,
    Timestamp INTEGER
  );
]]

SQLITE_TABLE_WAR_CREDIT = [[
  CREATE TABLE IF NOT EXISTS WarCredit (
    MessageId TEXT PRIMARY KEY,
    Timestamp INTEGER,
    Sender TEXT,
    Quantity INTEGER
  );
]]

SQLITE_TABLE_EMISSIONS = [[
  CREATE TABLE IF NOT EXISTS Emissions (
    Amount INTEGER,
    Recipient TEXT,
    Timestamp INTEGER
  );
]]

function InitDb()
  BankerDb:exec(SQLITE_TABLE_AUTHORISED)
  BankerDb:exec(SQLITE_TABLE_WAR_CREDIT)
  BankerDb:exec(SQLITE_TABLE_EMISSIONS)
end

BankerInitialized = BankerInitialized or false
if (not BankerInitialized) then
  InitDb()
  BankerInitialized = true
end

--#endregion

function AuthoriseWallet(walletId, timestamp)
  print("Authorising: " .. walletId)
  if timestamp == nil then
    timestamp = 0
  end
  local stmt = BankerDb:prepare("INSERT INTO Authorised (WalletId, Timestamp) VALUES (?, ?)")
  stmt:bind_values(walletId, timestamp)
  stmt:step()
  stmt:finalize()
end

Handlers.add(
  "Authorise",
  Handlers.utils.hasMatchingTag("Action", "Authorise"),
  function(msg)
    print("Authorise")
    if msg.From ~= WAITLIST_PROCESS then
      return print("Authorise not from WaitlistProcessId")
    end

    local walletId = msg.Tags.WalletId

    -- Check if already Authorized
    local authorised = BankerDbAdmin:exec(
      "SELECT * FROM Authorised WHERE WalletId = '" .. walletId .. "'"
    )
    if (#authorised > 0) then
      return print("Already Authorised: " .. walletId)
    end

    AuthoriseWallet(walletId, msg.Timestamp)
  end
)

function IsAuthorised(walletId)
  local authorised = BankerDbAdmin:exec(
    "SELECT * FROM Authorised WHERE WalletId = '" .. walletId .. "'"
  )
  return #authorised > 0
end

function ValidateWarQuantity(quantity)
  return quantity ~= nil
      and quantity >= WRAPPED_ARWEAVE_MIN_QUANTITY
      and quantity <= WRAPPED_ARWEAVE_CAP_QUANTITY
end

function ValidateSenderName(senderName)
  return senderName ~= nil
      and string.len(senderName) > 0
      and string.len(senderName) <= 20
end

function ValidatePetition(petition)
  return petition ~= nil
      and string.len(petition) > 0
      and string.len(petition) <= 250
end

function FormatWarTokenAmount(amount)
  return string.format("%.3f", amount / WRAPPED_ARWEAVE_MULTIPLIER)
end

Handlers.add(
  "CreditNoticeHandler",
  Handlers.utils.hasMatchingTag("Action", "Credit-Notice"),
  function(msg)
    -- print("CreditNoticeHandler")
    if msg.From ~= WRAPPED_ARWEAVE_TOKEN_PROCESS then
      return print("Credit Notice not from wrapped $AR")
    end

    -- Sender is from a trusted process
    local sender = msg.Tags.Sender
    if IsAuthorised(sender) ~= true then
      return print("Sender not Authorised: " .. sender)
    end

    local messageId = msg.Id

    local quantity = tonumber(msg.Tags.Quantity)
    if not ValidateWarQuantity(quantity) then
      return print("Invalid quantity")
    end

    local senderName = msg.Tags['X-Sender-Name']
    if not ValidateSenderName(senderName) then
      return print("Invalid sender name")
    end

    local petition = msg.Tags['X-Petition']
    if not ValidatePetition(petition) then
      return print("Invalid petition")
    end

    -- Check last day credits in Db
    -- Sender is generated from a trusted process
    local lastDayCredits = BankerDbAdmin:exec(
      "SELECT * FROM WarCredit WHERE Sender = '" .. sender
      .. "' AND Timestamp > " .. (msg.Timestamp - 23 * 60 * 60 * 1000)
      .. " ORDER BY Timestamp DESC"
    )
    print("Last day credits: " .. #lastDayCredits)
    if (#lastDayCredits >= MAXIMUM_PETITIONS_PER_DAY) then
      -- Return $wAR to sender
      Send({
        Target = WRAPPED_ARWEAVE_TOKEN_PROCESS,
        Tags = {
          Action = 'Transfer',
          Target = msg.Tags.Sender,
          Quantity = msg.Tags.Quantity,
        },
      })
      -- Write in chat
      Send({
        Target = LLAMA_FED_CHAT_PROCESS,
        Tags = {
          Action = 'ChatMessage',
          ['Author-Name'] = 'Llama Banker',
        },
        Data = 'Sorry ' ..
            (senderName or sender) ..
            ', but you can only petition the Llama King ' ..
            tostring(MAXIMUM_PETITIONS_PER_DAY) .. ' times per day!' ..
            ' But don\'t worry, I\'ll return your ' .. FormatWarTokenAmount(quantity) .. ' wrapped $AR to you 🦙🤝🪙' ..
            ' Come back and try again tomorrow!',
      })
      return -- Don't save to db or forward to the Llama King
    end

    -- Save metadata
    local stmt = BankerDb:prepare(
      "INSERT INTO WarCredit (MessageId, Timestamp, Sender, Quantity) VALUES (?, ?, ?, ?)"
    )
    stmt:bind_values(messageId, msg.Timestamp, sender, quantity)
    stmt:step()
    stmt:finalize()

    -- Dispatch to the LlamaKing
    Send({
      Target = LLAMA_KING_PROCESS,
      Tags = {
        Action = 'Petition',
        ['Original-Sender'] = sender,
        ['Original-Sender-Name'] = senderName,
        ['Original-Message'] = messageId,
      },
      Data = petition,
    })

    -- Write in Chat
    Send({
      Target = LLAMA_FED_CHAT_PROCESS,
      Tags = {
        Action = 'ChatMessage',
        ['Author-Name'] = 'Llama Banker',
      },
      Data = 'The court acknowledges an offering of ' ..
          FormatWarTokenAmount(quantity) .. ' wrapped $AR from ' .. (senderName or sender) .. '!' ..
          ' This is petition ' ..
          tostring(#lastDayCredits + 1) .. ' out of ' .. MAXIMUM_PETITIONS_PER_DAY .. ' from your allowance for today.',
    })
  end
)

function CalculateBaseEmissions(currentTime)
  local totalHourlyEmissions = BankerDbAdmin:exec(
    "SELECT SUM(Amount) as Value FROM Emissions WHERE Timestamp > " .. currentTime - 3600
  )[1].Value or 0
  local remainingEmissions = math.max(HOURLY_EMISSION_LIMIT - totalHourlyEmissions, 0)
  local baseEmissions = remainingEmissions / 10
  return baseEmissions
end

function RecordEmissionsAndSendLlamaToken(amount, recipient, currentTime)
  BankerDbAdmin:exec(
    string.format(
      "INSERT INTO Emissions (Amount, Recipient, Timestamp) VALUES (%d, '%s', %d)",
      amount,
      recipient,
      currentTime
    )
  )
  ao.send({
    Target = LLAMA_TOKEN_PROCESS,
    Action = "Grant",
    Recipient = recipient,
    Quantity = tostring(amount)
  })
end

function FormatLlamaTokenAmount(amount)
  return string.format("%.2f", amount / LLAMA_TOKEN_MULTIPLIER)
end

Handlers.add(
  "GradePetitionHandler",
  Handlers.utils.hasMatchingTag("Action", "Grade-Petition"),
  function(msg)
    -- print("GradePetitionHandler")
    if msg.From ~= LLAMA_KING_PROCESS then
      return print("Petition not from LlamaKing")
    end
    local originalMessageId = msg['Original-Message']
    local creditEntries = BankerDbAdmin:exec(
      "SELECT * FROM WarCredit WHERE MessageId = '" .. originalMessageId .. "'"
    )
    if (#creditEntries == 0) then
      return print("Credit not found")
    end

    local originalQuantity = creditEntries[1].Quantity
    local quantityMultiplier = originalQuantity / WRAPPED_ARWEAVE_MAX_QUANTITY

    local grade = tonumber(msg.Tags.Grade) -- 0 to 5
    -- local gradeMultiplier = grade / 10

    -- local baseEmissions = CalculateBaseEmissions(msg.Timestamp)
    -- local weightedEmissions = math.floor(baseEmissions * gradeMultiplier * quantityMultiplier)

    local gradeMultiplier = 0
    if (grade > 0) then
      gradeMultiplier = 10 ^ (grade - 1)
    end
    local baseEmissions = 1 * LLAMA_TOKEN_MULTIPLIER
    local weightedEmissions = math.floor(baseEmissions * quantityMultiplier * gradeMultiplier)

    -- TODO: Message chat / DM

    local originalSender = msg.Tags['Original-Sender']
    local originalSenderName = msg.Tags['Original-Sender-Name']
    local useSenderName = originalSenderName or originalSender

    RecordEmissionsAndSendLlamaToken(weightedEmissions, originalSender, msg.Timestamp)

    local chatMessage = 'Sorry ' ..
        useSenderName ..
        ', the king specifically requested that you receive no $LLAMA coin... maybe you could try again?'
    if (grade > 0) then
      if (weightedEmissions > 0) then
        chatMessage = 'Congratulations ' ..
            useSenderName .. ', you have been granted ' .. FormatLlamaTokenAmount(weightedEmissions) .. ' $LLAMA coins!'
      else
        chatMessage = 'I\'m sorry ' ..
            useSenderName ..
            ', but it looks like I have no more $LLAMA coins to give... maybe try again in an hour or so?'
      end
    end

    -- Write in Chat
    Send({
      Target = LLAMA_FED_CHAT_PROCESS,
      Tags = {
        Action = 'ChatMessage',
        ['Author-Name'] = 'Llama Banker',
      },
      Data = chatMessage,
    })
  end
)

Handlers.add(
  'RequestBalanceMessage',
  Handlers.utils.hasMatchingTag('Action', 'RequestBalanceMessage'),
  function(msg)
    print('RequestBalanceMessage')
    -- If the user has no emissions, the token process might
    -- send the balance of the banker instead!!

    Send({
      Target = LLAMA_TOKEN_PROCESS,
      Tags = {
        Action = 'Balance',
        Recipient = msg.From,
      },
    })
  end
)

Handlers.add(
  'TokenBalanceResponse',
  function(msg)
    local fromToken = msg.From == LLAMA_TOKEN_PROCESS
    local hasBalance = msg.Tags.Balance ~= nil
    return fromToken and hasBalance
  end,
  function(msg)
    -- print('TokenBalanceResponse')
    local account = msg.Tags.Account
    local balance = tonumber(msg.Tags.Balance)
    print('Account: ' .. account .. ', Balance: ' .. balance)
    -- TODO: DM ?
    Send({
      Target = LLAMA_FED_CHAT_PROCESS,
      Tags = {
        Action = 'ChatMessage',
        ['Author-Name'] = 'Llama Banker',
      },
      Data = 'Address ' .. account .. ', you currently have ' .. FormatLlamaTokenAmount(balance) .. ' $LLAMA coins!',
    })
  end
)

-- Handlers.add(
--   "CronHandler",
--   Handlers.utils.hasMatchingTag("Action", "Cron-Tick"),
--   function(msg)
--     clearOldEmissions(msg.Timestamp)
--   end
-- )

-- Declare Schema for UI

RequestBalanceMessageSchemaTags = [[
{
  "type": "object",
  "required": [
    "Action",
  ],
  "properties": {
    "Action": {
      "type": "string",
      "const": "RequestBalanceMessage"
    }
  }
}
]]

Schema = {
  Balance = {
    Title = "Check your $LLAMA Balance",
    Description =
    "Llama Banker will check your $LLAMA account and write your balance in the chat.", -- TODO: nil Descriptions?
    Schema = {
      Tags = json.decode(RequestBalanceMessageSchemaTags),
      -- Data
      -- Result?
    },
  },
}

Handlers.add(
  'Schema',
  Handlers.utils.hasMatchingTag('Read', 'Schema'),
  function(msg)
    print('Schema')
    Send({ Target = msg.From, Tags = { Type = 'Schema' }, Data = json.encode(Schema) })
  end
)

-- PROFILE = "SNy4m-DrqxWl01YqGM4sxI8qCni-58re8uuJLvZPypY"
-- Send({ Target = PROFILE, Action = "Create-Profile", Data = '{"UserName":"Llama Banker","DateCreated":1718653250836,"DateUpdated":1718653250836,"ProfileImage":"","CoverImage":"","Description":"","DisplayName":"Llama Banker"}' })
