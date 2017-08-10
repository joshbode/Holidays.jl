__precompile__(true)

"""
Public holiday database
"""
module Holidays

export Holiday, upcoming, recent, nearest

using Base: Dates, Order

using DataStructures

abstract type Source end

"""Holiday type"""
type Holiday
    name::String
    description::String
    regions::Set{String}
    date::Date
end
Holiday(
    name::AbstractString, description::AbstractString,
    regions::AbstractString, date::AbstractString
) = Holiday(name, description, Set{String}(split(regions, '|')), Date(date))

"""Store for holidays"""
type HolidayStore
    holidays::Dict{String, SortedDict{Date, Set{Holiday}}}
    HolidayStore() = new(Dict{String, SortedDict{Date, Set{Holiday}}}())
end

Base.getindex(store::HolidayStore, region::String) = haskey(store.holidays, region) ? store.holidays[region] : error("Unknown region: $region")
Base.getindex(store::HolidayStore, x::Tuple{String, Date}) = get(store.holidays[first(x)], last(x), Set{Holiday}())
Base.getindex(store::HolidayStore, x::Tuple{String, DateTime}) = getindex(store, (first(x), Date(last(x))))
Base.getindex(store::HolidayStore, x::Date) = Set{Holiday}(v for region in keys(store.holidays) for v in store[(region, x)])

"""Gets next upcoming holiday date for region."""
function upcoming(store::HolidayStore, region::String, date::Date; value::Bool=false)
    holidays = store[region]
    date = try deref_key((holidays, searchsortedfirst(holidays, date))) catch lastdayofyear(today()) + Day(1) end
    value ? holidays[date] : date
end

"""Gets most recent holiday date for region."""
function recent(store::HolidayStore, region::String, date::Date; value::Bool=false)
    holidays = store[region]
    date = try deref_key((holidays, searchsortedlast(holidays, date))) catch firstdayofyear(today()) end
    value ? holidays[date] : date
end

"""Gets nearest holiday date for region. Returns upcoming holiday date if tied."""
function nearest(store::HolidayStore, region::String, date::Date; value::Bool=false)
    x, y = recent(store, region, date), upcoming(store, region, date)
    date = (y - date) <= (date - x) ? y : x
    value ? store[region][date] : date
end

"""Loads holidays from a source into the store."""
function load!(store::HolidayStore, holidays::Vector{Holiday})
    for holiday in holidays
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

global const _store = HolidayStore()

"""Load the prepared holiday database"""
function __init__()
    DB_DIR = joinpath(@__DIR__, "..", "deps", "db")
    for source in readdir(DB_DIR)
        files = [joinpath(DB_DIR, source, x) for x in readdir(joinpath(DB_DIR, source))]
        holidays = [Holiday(split(strip(line), '\t')...) for file in files for line in readlines(file)]
        # pick newest version for region/date/name
        holidays = unique((x) -> (x.regions, x.date, replace(lowercase(x.name), " ", "")), holidays)
        load!(_store, holidays)
    end
end

# bind to internal store
upcoming(region::String, date::Date; value::Bool=false) = upcoming(_store, region, date; value=value)
recent(region::String, date::Date; value::Bool=false) = recent(_store, region, date; value=value)
nearest(region::String, date::Date; value::Bool=false) = nearest(_store, region, date; value=value)

end
