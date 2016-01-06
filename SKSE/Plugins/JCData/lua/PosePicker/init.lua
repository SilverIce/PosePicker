local T = {}

function T.foldl(collection, init, binary_function)
    for _,v in pairs(collection) do
        init = binary_function(v, init)
    end
    return init
end

-----

local function getKeyOrDef(defValue, key, tbl)
  local val = tbl and tbl[key] or nil
  return val ~= nil and val or defValue
end

function T.syncJSONFile(jLocalObj, filePath)
  local remoteObj = JValue.readFromFile(filePath)
  local remoteFileVersion = getKeyOrDef(0, 'fileVersion', remoteObj)
  local localFileVersion = getKeyOrDef(0, 'fileVersion', jLocalObj)

  if not remoteObj then
    return nil  -- if no remote file, then the file was deleted, local data should be set to nil too
  elseif not jLocalObj or localFileVersion < remoteFileVersion then
    return remoteObj
  elseif remoteObj and localFileVersion > remoteFileVersion then
    JValue.writeToFile(jLocalObj, filePath)
  end

  return jLocalObj
end

-- Does not select between local & remote version. Modifies local object instead!
function T.syncJSONFileInplace(jLocalObj, filePath)

  local selectedObj = T.syncJSONFile(jLocalObj, filePath)

  if jLocalObj and selectedObj and selectedObj ~= jLocalObj then
    JValue.clear(jLocalObj)
    for k,v in pairs(selectedObj) do
      jLocalObj[k] = v
    end
  end
end

function T.syncLargeJSONFile(jLocalObj, filePath)
  local lightweightFilePath = filePath .. ".filedate"
  local jFileDate = JValue.readFromFile(lightweightFilePath)
  local jSelectedObj = jLocalObj

  local localDate = fromMaybe(0, jLocalObj and jLocalObj.fileVersion or nil)
  local fileDate = fromMaybe(0, jFileDate and jFileDate.fileVersion or nil)

  if localDate < fileDate then
    
    local jRemoteFile = JValue.readFromFile(filePath)

    if jRemoteFile.fileVersion > localDate then
      --PrintConsole("Syncing " + filePath + ". Remote file chosen: " + jRemoteFile)
      jSelectedObj = jRemoteFile
    end

  elseif localDate > fileDate then
    if not jFileDate then
      jFileDate = JMap.object()
    end
    jFileDate.fileVersion = localDate
    JValue.writeToFile(jFileDate, lightweightFilePath)
    JValue.writeToFile(jLocalObj, filePath)
  end

  --JValue.zeroLifetime(jFileDate)
  --PrintConsole("Syncing " + filePath + ". Local file chosen: " + jLocalObj)

  return jSelectedObj
end


return T
