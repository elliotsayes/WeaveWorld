import { test } from 'node:test'
import * as assert from 'node:assert'
import { Send } from '../aos.helper.js'
import fs from 'node:fs'

test('load DbAdmin module', async () => {
  const dbAdminCode = fs. readFileSync('./blueprint/DbAdmin.lua', 'utf-8')
  const result = await Send({
  Action: 'Eval',
  Data: `
local function _load()
  ${dbAdminCode}
end
_G.package.loaded["DbAdmin"] = _load()
return "ok"`,
  })
  assert.equal(result.Output.data.output, "ok")
})

test('load source', async () => {
  const code = fs.readFileSync('./blueprint/Chat.lua', 'utf-8')
  const result = await Send({ Action: "Eval", Data: code })

  assert.equal(result.Output.data.output, "Loaded Chat Protocol")
})

test('ChatMessage no author', async () => {
  const result = await Send({
    From: "Some hacker ID",
    Action: "ChatMessage",
    Data: "Hello, World!",
  });

  assert.equal(result.Output.data, "Invalid Author Name")
});

test('ChatMessage bad author', async () => {
  const result = await Send({
    From: "Some hacker ID",
    Action: "ChatMessage",
    ['Author-Name']: ";SomeHacker",
    Data: "Hello, World!",
  });

  assert.equal(result.Output.data, "Invalid Author Name")
});

test('ChatMessage bad message', async () => {
  const result = await Send({
    From: "Some hacker ID",
    Action: "ChatMessage",
    ['Author-Name']: "--Some_-Hacker09",
    Data: "",
  });

  assert.equal(result.Output.data, "Invalid Content")
});

test('ChatMessage valid', async () => {
  const result = await Send({
    From: "Some hacker ID",
    Action: "ChatMessage",
    ['Author-Name']: "--Some_-Hacker09",
    Data: "Hello, World!",
  });

  assert.equal(result.Output.data, "Message saved")

  const countRes = await Send({
    Action: "Eval",
    Data: `ChatDbAdmin:count('Messages')`
  })
  assert.equal(countRes.Output.data.output, "1")
  
  const queryRes = await Send({
    Action: "Eval",
    Data: `require('json').encode(ChatDbAdmin:exec('SELECT * FROM Messages')[1])`
  })
  assert.deepEqual(JSON.parse(queryRes.Output.data.output), {
    Id: '1234',
    Timestamp: 10003,
    AuthorId: 'Some hacker ID',
    AuthorName: '--Some_-Hacker09',
    Content: 'Hello, World!',
  })
});

test('ChatHistory no timestamps', async () => {
  const result = await Send({
    Action: "ChatHistory",
  });

  const reply = result.Messages[0]
  const messages = JSON.parse(reply.Data)
  assert.equal(messages.length, 1)
  assert.deepEqual(messages[0], {
    Content: 'Hello, World!',
    AuthorName: '--Some_-Hacker09',
    Id: '1234',
    Timestamp: 10003,
    AuthorId: 'Some hacker ID',
  })
});

test('ChatMessage high valid', async () => {
  const result = await Send({
    Id: '5678',
    Timestamp: 20000,
    From: "Some hacker ID",
    Action: "ChatMessage",
    ['Author-Name']: "--Some_-Hacker09",
    Data: "Hello, World2!",
  });

  assert.equal(result.Output.data, "Message saved")

  const countRes = await Send({
    Action: "Eval",
    Data: `ChatDbAdmin:count('Messages')`
  })
  assert.equal(countRes.Output.data.output, "2")
  
  const queryRes = await Send({
    Action: "Eval",
    Data: `require('json').encode(ChatDbAdmin:exec('SELECT * FROM Messages')[2])`
  })
  assert.deepEqual(JSON.parse(queryRes.Output.data.output), {
    Id: '5678',
    Timestamp: 20000,
    AuthorId: 'Some hacker ID',
    AuthorName: '--Some_-Hacker09',
    Content: 'Hello, World2!',
  })
});

test('ChatMessage mid valid', async () => {
  const result = await Send({
    Id: '9000',
    Timestamp: 15000,
    From: "Some hacker ID",
    Action: "ChatMessage",
    ['Author-Name']: "--Some_-Hacker09",
    Data: "Hello, World3!",
  });

  assert.equal(result.Output.data, "Message saved")

  const countRes = await Send({
    Action: "Eval",
    Data: `ChatDbAdmin:count('Messages')`
  })
  assert.equal(countRes.Output.data.output, "3")
  
  const queryRes = await Send({
    Action: "Eval",
    Data: `require('json').encode(ChatDbAdmin:exec('SELECT * FROM Messages')[3])`
  })
  assert.deepEqual(JSON.parse(queryRes.Output.data.output), {
    Id: '9000',
    Timestamp: 15000,
    AuthorId: 'Some hacker ID',
    AuthorName: '--Some_-Hacker09',
    Content: 'Hello, World3!',
  })
});

test('ChatHistory with Timestamp-Start', async () => {
  const result = await Send({
    Action: "ChatHistory",
    ['Timestamp-Start']: 19999,
  });

  const reply = result.Messages[0]
  const messages = JSON.parse(reply.Data)
  assert.equal(messages.length, 1)
  assert.deepEqual(messages[0], {
    Content: 'Hello, World2!',
    AuthorName: '--Some_-Hacker09',
    Id: '5678',
    Timestamp: 20000,
    AuthorId: 'Some hacker ID',
  })
});

test('ChatHistory with Timestamp-End', async () => {
  const result = await Send({
    Action: "ChatHistory",
    ['Timestamp-End']: 10004,
  });

  const reply = result.Messages[0];
  const messages = JSON.parse(reply.Data);
  assert.equal(messages.length, 1);
  assert.deepEqual(messages[0], {
    Content: 'Hello, World!',
    AuthorName: '--Some_-Hacker09',
    Id: '1234',
    Timestamp: 10003,
    AuthorId: 'Some hacker ID',
  });
});

test('ChatHistory with Timestamp-Start and Timestamp-End', async () => {
  const result = await Send({
    Action: "ChatHistory",
    ['Timestamp-Start']: 10004,
    ['Timestamp-End']: 19999,
  });

  const reply = result.Messages[0];
  const messages = JSON.parse(reply.Data);
  assert.equal(messages.length, 1);
  assert.deepEqual(messages[0], {
    Content: 'Hello, World3!',
    AuthorName: '--Some_-Hacker09',
    Id: '9000',
    Timestamp: 15000,
    AuthorId: 'Some hacker ID',
  });
});
