# Holidays.jl

Regional public holiday database for Julia.

Region is keyed using [ISO 3166-2](https://en.wikipedia.org/wiki/ISO_3166-2) codes.

Current sources:

- Australia: [data.gov.au](https://data.gov.au/dataset/australian-holidays-machine-readable-dataset)

# Usage

```julia
julia> using Holidays

# next holiday
julia> Holidays.upcoming("AU-VIC", Base.Dates.today())
2017-06-12

# most recent holiday
julia> Holidays.recent("AU-VIC", Base.Dates.today())
2017-04-25

# closest holiday to today
julia> Holidays.nearest("AU-VIC", Base.Dates.today())
2017-04-25

# get information about the holiday itself
julia> collect(Holidays.nearest("AU-VIC", Base.Dates.today(); value=true))
Set(Holidays.Holiday[
    Holidays.Holiday(
        "Anzac Day","Celebrated on the 25 April each year.",
        Set(String["AU-QLD","AU-WA","AU-NT","AU-SA","AU-TAS","AU-VIC","AU-NSW","AU-ACT"]),
        2017-04-25
    )
])
```
