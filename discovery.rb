require 'persistent_http'
require 'pry'
require 'colorize'
require 'json'

HTTP_POOL_SIZE = 5
CEP_MIN = 1000000
CEP_MAX = 10000000
RANGE_STEP = 50000
RETRY_STEP = 1000

ENDPOINT_PATH_TEMPLATE = "/api/postal/pub/address/BRA/%{cep}"
ENDPOINT_HOST = "postalcode.vtexcommercestable.com.br"

@http = PersistentHTTP::Connection.new(
    force_retry: true,
    use_ssl: false,
    host: ENDPOINT_HOST,
    default_path: '/',
    pool_size: HTTP_POOL_SIZE 
)

def check_response(response)
    puts response
    return false if response.code != "200"
    begin
        body = JSON response.body
        return body["properties"][0]["value"]["address"]["street"] != ""
    rescue e
        return false
    end
end

def build_ranges(min, max, step)
    ranges = (1..((max - min)/step)).to_a.map do |index|
        range_min = min + (index - 1)*step
        range_max = (min + index*step) - 1
        {
            cep_start: range_min,
            cep_end: range_max
        }
    end
end

def cep_normalize(cep)
    s = cep.to_s
    if s.lenght == 7
        return "0#{s}"
    else
        return s
    end
end

ranges = build_ranges(CEP_MIN, CEP_MAX, RANGE_STEP)

ranges.map! do |rng|
    puts "Starting search on #{rng[:cep_start]} -> #{rng[:cep_end]}".yellow.bold
    found = false
    current = rng[:cep_start]
    while (current < rng[:cep_end])  do
        
        path = ENDPOINT_PATH_TEMPLATE % { cep: cep_normalize(current) }
        puts path
        req = Net::HTTP::Get.new(path)
        response = @http.request(req)
        found = check_response(response)
        
        if found
            puts "#{current} => #{found}".green.bold
            break
        else
            puts "#{current} => #{found}"
        end
        current += RETRY_STEP
    end
    found_at = found ? current : 0
    rng.merge({ found: found, found_at: found_at })
end

output = ranges.select{|r| r.found }.map { |r| r[:found_at] }

File.open("discovery.json", 'w') { |file| file.write(output.to_json) }

binding.pry