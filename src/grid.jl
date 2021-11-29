using DelimitedFiles

struct GridStructure
    resolution::Int64
    cardinality::Int64
    spatialindex::Vector{Int64}
    center::Tuple{Float64,Float64}
    shape::Tuple{Float64,Float64}
end

mutable struct Substructure
    cardinality::Int64
    center::Tuple{Float64,Float64}
    shape::Tuple{Float64,Float64}
end

struct Grid
    rootdir::String
    tiles::Dict{Tuple{Int64,Int64}, IOStream}
    structure::GridStructure
    substructure::Dict{Tuple{Int64,Int64}, Substructure}
    function Grid(rootdir, resolution, cardinality, spatialindex, center, shape)
        structure = GridStructure(resolution, cardinality, spatialindex,
            center, shape)
        tiles = Dict{Tuple{Int64,Int64}, IOStream}()
        substructure = Dict{Tuple{Int64,Int64}, Substructure}()
        return new(rootdir, tiles, structure, substructure)
    end
end

"Associate a position tuple to its tile index."
function index(position::Tuple{Float64,Float64}, structure::GridStructure,
        epsilon::Float64 = 1e-10)
    relpos = ((position .- structure.center) ./ ((1 + epsilon) .* structure.shape)) .+ 0.5
    fzyidx = relpos .* structure.resolution
    return (floor(Int64, fzyidx[1]), floor(Int64, fzyidx[2]))
end

"Wraps index(position::Tuple{Float64,Float64}, structure::GridStructure, ..."
function index(position::Tuple{Float64,Float64}, grid::Grid,
        epsilon::Float64 = 1e-10)
    return index(position, grid.structure, epsilon)
end

# https://stackoverflow.com/questions/64957524/how-can-i-obtain-the-complement-of-list-of-indexes-in-julia
function mysetdiff(y, x)
    res = Vector{eltype(y)}(undef, length(y) - length(x))
    i = 1
    @inbounds for el in y
        el ∈ x && continue
        res[i] = el
        i += 1
    end

    res
end

""
function formatrow(x, leadingindex::Vector{Int64})
    return join(x, ',')*'\n'
end

function tilelabel(rootdir::String, idx::Tuple{Int64, Int64})
    return join([rootdir, string("r", idx[1], "c", idx[2])], '/')
end

function write_and_open!(grid::Grid, idx::Tuple{Int64, Int64}, row)
    if !haskey(grid.tiles, idx)
        path = tilelabel(grid.rootdir, idx)*".csv"
        grid.tiles[idx] = open(path, "w")
        n = grid.structure.resolution
        shape = grid.structure.shape ./ n
        center = grid.structure.shape .* (idx ./ n) .+ (shape ./ 2)
        grid.substructure[idx] = Substructure(0, shape, center)
    end
    write(grid.tiles[idx], row)
    grid.substructure[idx].cardinality += 1
end

function format_metadata(structure::GridStructure)
    return [
        [structure.resolution, structure.cardinality],
        structure.spatialindex,
        structure.center,
        structure.shape]
end

function write_metadata(grid::Grid)
    path = join([grid.rootdir, "structure.csv"], '/')
    metadata = format_metadata(grid.structure)
    open(path, "w") do f
        DelimitedFiles.writedlm(f, metadata)
    end
end

function read_metadata(rootdir::String)
    path = join([rootdir, "structure.csv"], '/')
    open(path, "r") do f
        return DelimitedFiles.readdlm(f)
    end
end

function write!(grid::Grid, row)
    pos = Tuple{Float64, Float64}(row[grid.structure.spatialindex])
    idx = index(pos, grid)
    frow = formatrow(row, grid.structure.spatialindex)
    write_and_open!(grid, idx, frow)
end

function writegrid!(grid::Grid, rows)
    #map(x -> write_to_tile!(grid, x), rows)
    for x in rows
        write!(grid, x)
    end
    for f in values(grid.tiles)
        close(f)
    end
    write_metadata(grid)
end

"A memory-optimized alternative to Julia's readdml."
struct LazyDelimitedFile
    # delimited file
    file::IOStream
    # row delimiter
    delim::Char
    # column delimiter
    sep::Char
end

"Accumulate chars until `ldf.delim` is encountered, then split by `ldf.sep`."
function Base.iterate(ldf::LazyDelimitedFile, state=missing)
    item = ""::String
    while !eof(ldf.file)
        chr = read(ldf.file, Char)
        if chr==ldf.delim
            return split(item, ldf.sep), missing
        else
            item = join([item, chr])
        end
    end
end

"."
function parserow!(row, index::Vector{Int64})
    for i in index
        row[i] = parse(Float64, row[i])
    end
    return row
end

function tiledata(f::IOStream, spatialindex::Vector{Int64})
    return Iterators.map(x -> parserow!(x, spatialindex),
        LazyDelimitedFile(f, '\n', ','))
end

function refinetile(grid::Grid, idx::Tuple{Int64, Int64}, resolution::Int64,
        spatialindex::Vector{Int64})
    substructure = grid.substructure[idx]
    n = substructure.cardinality
    subcenter = substructure.center
    subshape = substructure.shape
    label = tilelabel(grid.rootdir, idx)
    subdir = mkdir(label)
    subgrid = Grid(subdir, resolution, n, spatialindex, subcenter, subshape)
    path = label*".csv"
    open(path, "r") do tilefile
        data = tiledata(tilefile, spatialindex)
        writegrid!(subgrid, data)
    end
    rm(path)
    return subgrid
end

function refinegrid(grid::Grid, threshold::Int64, resolution::Int64,
        spatialindex::Vector{Int64})
    subgrids = Grid[]
    for idx in keys(grid.tiles)
        n = grid.substructure[idx].cardinality
        if n > threshold
            refinedgrid = refinetile(grid, idx, resolution, spatialindex)
            push!(subgrids, refinedgrid)
        end
    end
    return subgrids
end

function dotest()
    n = 5000
    r = 9
    points = ((x, y, "meta", 'd', 4, 't', 4) for x in 0:n for y in 0:n)
    grid = Grid("db", r, (n+1)^2, [1, 2], (n/2, n/2), (n,n))
    print("writing ", (n+1)^2, " rows...")
    @time writegrid!(grid, points)
    @time refinegrid(grid, parse(Int64, grid.structure.cardinality / (r^2)), r)
end
