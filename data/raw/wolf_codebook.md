Spatiotemporal Congressional District Data
============================================
Levi John Wolf
DOI 10.17605/OSF.IO/MJVKB 

This data product extends Prof. Gary King's database of US Congressional Elections [(ICPSR 6311)](http://www.icpsr.umich.edu/icpsrweb/ICPSR/studies/6311) with data put together by Prof. Ken Kollman (and many others) in the [Constituency Level Electoral Archive](http://www.electiondataarchive.org/datacenter.html), merged together with the [district shapefiles](cdmaps.polisci.ucla.edu) mantained by Prof. Jeffrey Lewis at UCLA. All data on vote shares after 1992 come from the CLEA and incumbency info after 1992 was hand-coded. The complete data is contained in `extended_6311.csv`. In addition, the data is provided split into pre-1948 and post-1948 sections. The field explanations below apply to all of the comma-separated value files.

Codebook for extended_6311.csv
-------------------------------

### `congress`
The integer describing the number of the congress in which the district was used. For instance, if a district were used in the 113th congress, the field would be `113`. 

### `delsouth`

A binary integer describing whether the state was a member of the confederacy. Coding form is retained from ICSPR 6311. 

### `fips`

An integer containing the Federal Information Processing (FIPS) number of the state in which the district was used. 

### `contest_uid`

A unique identifying integer for each contest. A contest is a single election, when at least one winner is picked to represent a district in an election year. The right three digits describe the number of the district within a given state. These are zero-padded from the left to always be three digits long. The middle three digits are the `fips` code, zero-padded from the left to always be three digits. Finally, the leftmost digits are the `congress` number. 

### `inc`

An ordinal variable with three states. If exactly one Republican incumbent is running for reelection in the district, this variable is -1. If exactly one Democrat incumbent is running for reelection in the district, the variable is 1. Otherwise, when no incumbent is running or two incumbents are contesting in a new district, the entry is 0. 

### `king_dist`

The district number, coded using the standards from ICPSR 6311. the redistricting commission in the state. If an at-large district exists, it is numbered as 99. 

### `lewis_dist`

The district number, coded using the standards from Lewis et al (2013)'s collection of congressional districts. This will number the districts sequentially according to the number assigned by the redistricting commission in the state. If an at-large district exists, it is numbered as 0. 

### `state_name`

The lower-case name of the state in which a district is used. 

### `turnout`

The integer describing the number of individuals voting in the district in a given election. If the data is missing, the field will not be populated. 

### `vote_share`

The fraction of the vote won by the Democrat candidate. Drawn directly from ICPSR 6311 for years before 1992, and constructed from the CLEA afterward. For races where minor party candidates exist, this reflects the two-party vote only, so all votes cast for third parties are discarded. 

### `year`

The year in which the election occurred. In this dataset, these years are all even-numbered years. 

### `geom_uid`

The unique identifier from Lewis et al (2013)'s congressional shapes registry. The rightmost three digits are the `lewis_dist` identifier, zero-padded from the left. Then, the middle six digits contain two three-digit numbers; the left one reflects the congress in which the district was first used, and the right the congress in which the district was last used. If the district is currently used, the congress will be the latest in the dataset. The leftmost identifier is the state FIPS code, which may be one or two digits long. 

### `wkb`

A hex-encoded well-known binary string describing the shape of the district. The well-known binary standard is defined by the Open Geographic Consortium, and these geometries are all encoded unprojected using the 1983 North American Datum, retained from Lewis et al (2013). 