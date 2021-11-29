using DelimitedFiles

struct GridStructure
    resolution::Int64
    cardinality::Int64
    spatialindex::Vector{Int64}
    center::Tuple{Float64,Float64}
    shape::Tuple{Float64,Float64}
end

struct Grid
    rootdir::String
    tiles::Dict{Tuple{Int64,Int64}, IOStream}
    structure::GridStructure
    tilecardinality::Matrix{Int64}
    function Grid(rootdir, resolution, cardinality, spatialindex, center, shape)
        structure = GridStructure(resolution, cardinality, spatialindex,
            center, shape)
        tiles = Dict{Tuple{Int64,Int64}, IOStream}()
        tilecardinality = zeros(Int64, (resolution, resolution))
        return new(rootdir, tiles, structure, tilecardinality)
    end
end

function corner(structure::GridStructure)
    center = structure.center
    shape = structure.shape
    return center .- (shape ./ 2)
end

function corner(grid::Grid)
    return corner(grid.structure)
end

function tilebounds(structure::GridStructure, idx::Tuple{Int64, Int64})
    gridcorner = corner(structure)
    shape = grid.structure.shape ./ grid.structure.resolution
    corner = gridcorner .+ (idx .* tileshape)
    center = tilecorner .+ (tileshape ./ 2)
    return shape, center, corner
end

function cardinality(grid::Grid, idx::Tuple{Int64, Int64})
    return grid.tilecardinality[1+idx[1],1+idx[2]]
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
function read_structure(rootdir::String)
    mat = read_metadata(rootdir)
    return GridStructure(mat[1,1],mat[1,2],mat[2,:],mat[3,:],mat[4,:])
end

"Associate a position tuple to its tile index."
function index(position::Tuple{Float64,Float64}, structure::GridStructure, epsilon::Float64 = 1e-10)
    relpos = ((position .- structure.center) ./ ((1 + epsilon) .* structure.shape)) .+ 0.5
    fzyidx = relpos .* structure.resolution
    return (floor(Int64, fzyidx[1]), floor(Int64, fzyidx[2]))
end

"Wraps index"
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

function format_row(x, leadingindex::Vector{Int64})
    return join(x, ',')*'\n'
end

function tilelabel(rootdir::String, idx::Tuple{Int64, Int64})
    return join([rootdir, string("r", idx[1], "c", idx[2])], '/')
end

function write_and_open!(grid::Grid, idx::Tuple{Int64, Int64}, row)
    if !haskey(grid.tiles, idx)
        path = tilelabel(grid.rootdir, idx)*".csv"
        grid.tiles[idx] = open(path, "w")
    end
    write(grid.tiles[idx], row)
    grid.tilecardinality[1+idx[1],1+idx[2]] += 1
end

function write!(grid::Grid, row)
    pos = Tuple{Float64, Float64}(row[grid.structure.spatialindex])
    idx = index(pos, grid)
    frow = format_row(row, grid.structure.spatialindex)
    write_and_open!(grid, idx, frow)
end

function write_grid!(grid::Grid, rows)
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
    item = ""
    while !eof(ldf.file)
        chr = read(ldf.file, Char)
        if chr==ldf.delim
            return split(item, ldf.sep), missing
        else
            item = join([item, chr])
        end
    end
end

function parse_row!(row, index::Vector{Int64})
    parsed_row = Vector{Any}()
    for i in 1:length(row)
        if i in index
            val = parse(Float64, row[i])
        else
            val = row[i]
        end
        push!(parsed_row, val)
    end
    return parsed_row
end

function tiledata(f::IOStream, spatialindex::Vector{Int64})
    return Iterators.map(x -> parse_row!(x, spatialindex), LazyDelimitedFile(f, '\n', ','))
end

function decompose_tile(grid::Grid, idx::Tuple{Int64, Int64}, resolution::Int64, spatialindex::Vector{Int64})
    tileshape, tilecenter = tilebounds(grid.structure, idx)[1:2]
    label = tilelabel(grid.rootdir, idx)
    subdir = mkdir(label)
    subgrid = Grid(subdir, resolution, cardinality(grid, idx), spatialindex, tilecenter, tileshape)
    path = label*".csv"
    open(path, "r") do tilefile
        data = tiledata(tilefile, spatialindex)
        write_grid!(subgrid, data)
    end
    rm(path)
    return subgrid
end

function refine_grid(grid::Grid, threshold::Int64, resolution::Int64, spatialindex::Vector{Int64})
    subgrids = Grid[]
    for idx in keys(grid.tiles)
        n = cardinality(grid, idx)
        if n > threshold
            refinedgrid = decompose_tile(grid, idx, resolution, spatialindex)
            push!(subgrids, refinedgrid)
        end
    end
    return subgrids
end

function testgrid()
    n = 3500
    r = 9
    points = ((x, y, "meta", 'd', 4, 't', 4) for x in 0:n for y in 0:n)
    if isdir("db")
        rm("db", recursive=true)
    end
    mkdir("db")
    grid = Grid("db", r, (n+1)^2, [1, 2], (n/2, n/2), (n,n))
    println("writing ", (n+1)^2, " rows...")
    write_grid!(grid, points)
    println("refining grid")
    refine_grid(grid, round(Int64, grid.structure.cardinality / (2*r^2)), r, [1, 2])
end
