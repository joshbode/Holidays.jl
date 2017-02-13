import Requests

DB_DIR = joinpath(dirname(@__FILE__), "db")

# clear out old database directory
if isdir(DB_DIR)
    rm(DB_DIR; recursive=true)
end
mkdir(DB_DIR)

"""Data source for data.gov.au"""
function get_australia(id)
    api_root = "https://data.gov.au/api/3/action"
    all_regions = Set{String}(["AU-$x" for x in ["ACT", "NSW", "NT", "QLD", "SA", "TAS", "VIC", "WA"]])  # ISO 3166-2:AU

    # get the package to find all resources (years)
    response = try
        Requests.get(joinpath(api_root, "package_show"); query=Dict(:id => id))
    catch e
        error("Unable to retrieve package $id: $e")
    end
    response = Requests.json(response; dicttype=Dict{Symbol, Any})
    if !response[:success]
        error("Unable to retrieve package $id: ", response[:error][:message])
    end
    # process all resources in the package, newest resources first
    SOURCE_DIR = joinpath(DB_DIR, "data.gov.au")
    if isdir(SOURCE_DIR)
        rm(SOURCE_DIR; recursive=true)
    end
    mkdir(SOURCE_DIR)
    # pick the newest resource for each hash
    for resource in unique((x) -> x[:hash], sort(response[:result][:resources]; by=(x) -> x[:created], rev=true))
        response = try
            Requests.get(joinpath(api_root, "datastore_search"); query=Dict(:resource_id => resource[:id]))
        catch e
            error("Unable to retrieve resource $(resource[:id]): $e")
        end
        info("Reading: data.gov.au:$id:$(resource[:id])")
        response = Requests.json(response; dicttype=Dict{Symbol, Any})
        if !response[:success]
            error("Unable to retrieve resource $(resource[:id]): ", response[:error][:message])
        end
        records = response[:result][:records]
        i = 0
        open(joinpath(SOURCE_DIR, resource[:id]), "w") do f
            for record in records
                # remove spaces in key names
                record = Dict{Symbol, Any}(Symbol(replace(string(k), " ", "")) => v for (k, v) in record)
                if record[:Date] == "TBC"
                    # ignore "to be confirmed" holidays
                    continue
                end
                if record[:ApplicableTo] == "NAT"
                    regions = copy(all_regions)
                else
                    regions = intersect(Set{String}(["AU-$x" for x in split(record[:ApplicableTo], "|")]), all_regions)
                end
                date = Date(record[:Date], "yyyymmdd")
                write(f, join([record[:HolidayName], record[:Information], join(regions, '|'), date], '\t'), '\n')
                i += 1
            end
        end
        info("Saved: $i/$(length(records)) records")
    end
end

# get data
get_australia("australian-holidays-machine-readable-dataset")
