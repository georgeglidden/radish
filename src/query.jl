include("grid.jl")

struct RectangularQuery
    rootdir::String
    interval::Matrix{Float64}
end

function querytiles(query, metadata)
    resolution = metadata[1]
    width, height = metadata[4,:]
    left, top = metadata[3,:] .- (metadata[4,:] ./ 2)
    println("\tresolution ", (width, height))
    queryleft, queryright = query.interval[1,:]
    leftidx = max(round(Int64, resolution*(queryleft-left)/width), 0)
    rightidx = round(Int64, resolution*(queryright-left)/width)
    querytop, querybottom = query.interval[2,:]
    topidx = max(round(Int64, resolution*(querytop-top)/height), 0)
    bottomidx = round(Int64, resolution*(querybottom-top)/height)
    println("\tquery interval", (queryleft, queryright, querytop, querybottom))
    println("\tquery indices", (leftidx, rightidx, topidx, bottomidx))
    return ((r,c) for r in leftidx:rightidx for c in topidx:bottomidx)
end

function restrict_query(query::RectangularQuery, subdir::String)
    metadata = read_metadata(subdir)
    resolution = metadata[1]
    gridleft, gridtop = metadata[3,:] .- (metadata[4,:] ./ 2)
    gridright, gridbottom = [gridleft, gridtop] .+ metadata[4,:]
    queryleft, queryright = query.interval[1,:]
    querytop, querybottom = query.interval[2,:]
    restricted_interval_vectors = [
        [max(gridleft, queryleft), min(gridright, queryright)],
        [max(gridtop, querytop), min(gridbottom, querybottom)]
    ]
    restricted_interval = transpose(reduce(hcat, restricted_interval_vectors))
    return RectangularQuery(subdir, restricted_interval)
end

"Recursively solve for the comprising tiles of a query, by BFS traversal of grid directories"
function resolve_tiles(query::RectangularQuery)
    metadata = read_metadata(query.rootdir)
    println("dir ", query.rootdir, " meta ", metadata)
    tilepaths = String[]
    for idx in querytiles(query, metadata)
        path = tilelabel(query.rootdir, idx)
        if isdir(path)
            println("idx ", path, " is a subgrid")
            # restrict query to subgrid
            subquery = restrict_query(query, path)
            # recurse
            subtilepaths = resolve_tiles(subquery)
            union!(tilepaths, subtilepaths)
        else
            # terminate recursion
            path *= ".csv"
            if isfile(path)
                println("idx ", path, " is a file")
                push!(tilepaths, path)
            else
                println("idx ", path, " does not exist")
            end
        end
    end
    return tilepaths
end

function serve(query::RectangularQuery)
    paths = resolve_tiles(query)
end

function testquery(xb, yb)
    interval = Matrix{Float64}(undef, (2,2))
    interval[1,:] = xb
    interval[2,:] = yb
    query = RectangularQuery("db", interval)
    print(query)
    metadata = read_metadata(query.rootdir)
    print(metadata)
    print([x for x in querytiles(query, metadata)])
    resolve_tiles(query)
end
