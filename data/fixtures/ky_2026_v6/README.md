# Kentucky 2026 v6 preparation-file excerpts

These are authentic excerpts from the six official XML downloads saved manually
through Safari on October 30, 2026. All included vote totals are zero. They are
preparation data, not election returns or synthetic votes.

Source menu: https://vrsws.sos.ky.gov/liveresults/Data
Schema guide: https://vrsws.sos.ky.gov/liveresults/Documentation/DataWebsiteGuidev6.pdf

The complete source files remain git-ignored in `data/live/ky-downloads/`.
`original-file-hashes.csv` records their MD5 hashes. This fixture retains the
Elections and Political Parties files and excerpts of the other four datasets:
the KY-06 contest, its candidates, the Kentucky state unit and a county/precinct
branch, and their corresponding result records. Records were copied with xml2;
serialization/whitespace may differ from the originals.

The fixture preserves two details that are easy to miss in the guide: unit types
are serialized as enum names such as `State`, and the `SummaryReport` contains a
`CandidateData` collection with child records also named `CandidateData`.
Nonzero synthetic tests separately exercise aggregation and double counting.
