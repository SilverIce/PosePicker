local T = {}

function T.foldl(collection, init, binary_function)
    for _,v in pairs(collection) do
        init = binary_function(v, init)
    end
    return init
end

return T
