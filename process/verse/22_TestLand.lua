-- PID Kh-PHmaRt0bykGUgyK4euVSknML6yHIwQPyR5xPvXxg

--#region Model

VerseInfo = {
  Dimensions = 2,
  Name = 'ExampleVerse',
  ['Render-With'] = '2D-Tile-0',
}

VerseParameters = {
  ['2D-Tile-0'] = {
    Version = 0,
    Spawn = { 5, 7 },
    -- This is a tileset themed to Llama Land main island
    Tileset = {
      Type = 'Fixed',
      Format = 'PNG',
      TxId = 'h5Bo-Th9DWeYytRK156RctbPceREK53eFzwTiKi0pnE', -- TxId of the tileset in PNG format
    },
    -- This is a tilemap of sample small island
    Tilemap = {
      Type = 'Fixed',
      Format = 'TMJ',
      TxId = 'koH7Xcao-lLr1aXKX4mrcovf37OWPlHW76rPQEwCMMA', -- TxId of the tilemap in TMJ format
      -- Since we are already setting the spawn in the middle, we don't need this
      -- Offset = { -10, -10 },
    },
  },
}

VerseEntitiesStatic = {
  ['bv3UY40_zEg9gPnk1vVlzn01EFhVPvwAaKP7AfqHwpA'] = {
    Type = "Avatar",
    Position = { 8, 8 },
    Metadata = {
      DisplayName = "Warpmaster",
      SkinNumber = 3,
      Interaction = {
        Type = 'SchemaExternalForm',
        Id = 'WarpVote',
      },
    },
  }
}

--#endregion

return print("Loaded Verse Template")