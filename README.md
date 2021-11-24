RADISH.jl
--
Construct minimal-footprint spatial datasets and serve queries on contiguous spatial regions.

## Motivation and Attribution
radish is a companion project to <a href="https://github.com/archmagethanos/turnip">turnip</a> and <a href="https://github.com/georgeglidden/rutabaga">rutabaga</a> (wip), towards understanding and expositing the Q polynomials found in hyperbolic knot theory.

These projects are supported by the <a href="http://urmath.org/curm/">Center for Undergraduate Research in Mathematics</a>, the University of Montana, and Montana State University, and are the result of work by students under <a href="https://www.umt.edu/people/Chesebro">Dr. Eric Chesebro</a> and <a href="https://math.montana.edu/rgrady/">Dr. Ryan Grady</a>.

We were inspired by the art and artful math communication of John Baez, Dan Christensen, and Sam Derbyshire.
* https://www.scientificamerican.com/article/math-polynomial-roots/
* http://jdc.math.uwo.ca/roots/
* https://math.ucr.edu/home/baez/roots/

## Installation
radish has no external dependencies!

You need an installation of Julia compatible with version 1.6.3:
* https://julialang.org/downloads/platform/

Then, download this repository &mdash; either via the green "Code" button, or with git:

`git clone https://github.com/georgeglidden/RADISH.jl`


## Operation

TO BE IMPLEMENTED

~~Create a spatial database:~~

`julia RADISH.jl [path/to/source.csv] [path/to/database_root_directory] [resolution] [row delimiter='\n'] [column delimiter=',']`

~~Query a rectangular interval from a spatial database:~~

`julia RADISH.jl [path/to/database_root_directory] [left] [upper] [right] [lower]`

WIP:
* implement rudimentary CLI, GUI
* optimize resolution from dataset parameters
* enriched metadata queries / reverse lookup
* n>2-dimensional implementation
