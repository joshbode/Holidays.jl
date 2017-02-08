module Holidays

__precompile__()

export Holiday, HolidayStore, upcoming, recent, load!, data

using Base: Dates, Order

using DataStructures
import Requests

abstract Source

"""Holiday type"""
type Holiday
    name::String
    description::String
    source::Source
    regions::Set{String}
    date::Date
end

"""Store for holidays"""
type HolidayStore
    holidays::Dict{String, SortedDict{Date, Set{Holiday}, ForwardOrdering}}
    HolidayStore() = new(Dict{String, SortedDict{Date, Set{Holiday}, ForwardOrdering}}())
end

Base.getindex(store::HolidayStore, region::String) = haskey(store.holidays, region) ? store.holidays[region] : error("Unknown region: $region")
Base.getindex(store::HolidayStore, x::Tuple{String, Date}) = get(store.holidays[first(x)], last(x), Set{Holiday}())
Base.getindex(store::HolidayStore, x::Tuple{String, DateTime}) = getindex(store, (first(x), Date(last(x))))
Base.getindex(store::HolidayStore, x::Date) = Set{Holiday}(v for region in keys(store.holidays) for v in store[(region, x)])

"""Gets upcoming holidays for region."""
function upcoming(store::HolidayStore, region::String, date::Date)
    holidays = store[region]
    try deref_key((holidays, searchsortedfirst(holidays, date))) catch lastdayofyear(today()) + Day(1) end
end

"""Gets recent holidays for region."""
function recent(store::HolidayStore, region::String, date::Date)
    holidays = store[region]
    try deref_key((holidays, searchsortedlast(holidays, date))) catch firstdayofyear(today()) end
end

"""Loads holidays from a source into the store."""
function load!(store::HolidayStore, source::Source)
    for holiday in data(source)
        for region in holiday.regions
            if !haskey(store.holidays, region)
                target = store.holidays[region] = valtype(store.holidays)()
                target[holiday.date] = valtype(target)()
            else
                target = store.holidays[region]
                if !haskey(target, holiday.date)
                    target[holiday.date] = valtype(target)()
                end
            end
            push!(target[holiday.date], holiday)
        end
    end
    store
end

# sources

"""Data source for data.gov.au"""
type DataGovAustralia <: Source
    id::String
    api_root::String
    const _api_root::AbstractString="https://data.gov.au/api/3/action"
    DataGovAustralia(id::AbstractString="australian-holidays-machine-readable-dataset") = new(id, _api_root)
end

function data(source::DataGovAustralia)
    # get the package to find all resources (years)
    response = try
        Requests.get(joinpath(source.api_root, "package_show"); query=Dict(:id => source.id))
    catch e
        error("Unable to retrieve package $id: $e")
    end
    response = Requests.json(response; dicttype=Dict{Symbol, Any})
    if !response[:success]
        error("Unable to retrieve package $id: ", response[:error][:message])
    end
    all_regions = Set{String}(["AU-$x" for x in ["ACT", "NSW", "NT", "QLD", "SA", "TAS", "VIC", "WA"]])  # ISO 3166-2:AU
    # process all resources in the package, newest resources first
    holidays = Holiday[]
    for resource in unique((x) -> x[:hash], sort(response[:result][:resources]; by=(x) -> x[:created], rev=true))
        response = try
            Requests.get(joinpath(source.api_root, "datastore_search"); query=Dict(:resource_id => resource[:id]))
        catch e
            error("Unable to retrieve resource $(resource[:id]): $e")
        end
        response = Requests.json(response; dicttype=Dict{Symbol, Any})
        if !response[:success]
            error("Unable to retrieve resource $(resource[:id]): ", response[:error][:message])
        end
        for record in response[:result][:records]
            # remove spaces in key names
            record = Dict{Symbol, Any}(Symbol(replace(string(k), " ", "")) => v for (k, v) in record)
            if record[:Date] == "TBC"
                continue
            end
            if record[:ApplicableTo] == "NAT"
                regions = copy(all_regions)
            else
                regions = intersect(Set{String}(["AU-$x" for x in split(record[:ApplicableTo], "|")]), all_regions)
            end
            date = Date(record[:Date], "yyyymmdd")
            push!(holidays, Holiday(record[:HolidayName], record[:Information], source, regions, date))
        end
    end
    # pick newest version for region/date/name
    unique((x) -> (x.regions, x.date, replace(lowercase(x.name), " ", "")), holidays)
end

const _store = HolidayStore()

function setup()
    for source in [DataGovAustralia()]
        load!(_store, source)
    end
end

setup()

# bound to internal store
upcoming(region::String, date::Date) = upcoming(_store, region, date)
recent(region::String, date::Date) = recent(_store, region, date)

end
