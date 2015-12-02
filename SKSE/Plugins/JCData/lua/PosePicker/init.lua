local T = {}

function T.foldl(collection, init, binary_function)
    for _,v in pairs(collection) do
        init = binary_function(v, init)
    end
    return init
end

-----

function T.syncJSONFile(jLocalObj, filePath)
  local remoteObj = JValue.readFromFile(filePath)
  if jLocalObj == nil or remoteObj.fileVersion < jConfigTemplate.fileVersion then
    return remoteObj
  elseif jLocalObj.fileVersion > remoteObj.fileVersion then
    JValue.writeToFile(jLocalObj, filePath)
  end

  return jLocalObj
end

function T.syncLargeJSONFile(jLocalObj, filePath)
  local lightweightFilePath = filePath .. ".filedate"
  local jFileDate = JValue.readFromFile(lightweightFilePath)
  local jSelectedObj = jLocalObj

  local localDate = jLocalObj.fileVersion
  local fileDate = jFileDate.fileVersion

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
