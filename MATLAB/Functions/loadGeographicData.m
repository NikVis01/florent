function geoData = loadGeographicData(countryCode, config)
    % LOADGEOGRAPHICDATA Loads geographic data for country/countries
    %
    % Usage:
    %   geoData = loadGeographicData('BRA')
    %   geoData = loadGeographicData('BRA', config)
    %
    % Inputs:
    %   countryCode - ISO 3166-1 alpha-3 country code (e.g., 'BRA', 'USA')
    %                 or cell array of codes for multiple countries
    %   config - Configuration structure (optional)
    %
    % Output:
    %   geoData - Structure with:
    %     .countries - Cell array of country data structs
    %     .coordinates - [lat, lon] matrix (approximate centroids)
    %     .names - Cell array of country names
    
    if nargin < 2
        config = loadFlorentConfig();
    end
    
    % Load countries JSON
    countriesFile = fullfile(config.paths.pythonDataDir, 'geo', 'countries.json');
    
    if ~exist(countriesFile, 'file')
        warning('Countries file not found: %s\nUsing default coordinates', countriesFile);
        geoData = createDefaultGeoData(countryCode);
        return;
    end
    
    try
        % Read JSON file
        jsonText = fileread(countriesFile);
        allCountries = jsondecode(jsonText);
    catch ME
        warning('Failed to load countries data: %s\nUsing default coordinates', ME.message);
        geoData = createDefaultGeoData(countryCode);
        return;
    end
    
    % Handle single country code or cell array
    if ischar(countryCode) || isstring(countryCode)
        countryCodes = {char(countryCode)};
    else
        countryCodes = countryCode;
    end
    
    % Find matching countries
    geoData = struct();
    geoData.countries = {};
    geoData.coordinates = [];
    geoData.names = {};
    
    for i = 1:length(countryCodes)
        code = upper(char(countryCodes{i}));
        
        % Search for country by a3 code
        found = false;
        for j = 1:length(allCountries)
            if isfield(allCountries(j), 'a3') && strcmpi(allCountries(j).a3, code)
                country = allCountries(j);
                geoData.countries{end+1} = country;
                geoData.names{end+1} = country.name;
                
                % Get approximate coordinates (country centroids)
                % Note: countries.json doesn't have lat/lon, so we use known centroids
                coords = getCountryCentroid(code);
                geoData.coordinates(end+1, :) = coords;
                
                found = true;
                break;
            end
        end
        
        if ~found
            warning('Country code not found: %s', code);
            % Use default coordinates
            coords = getCountryCentroid(code);
            geoData.countries{end+1} = struct('a3', code, 'name', code);
            geoData.names{end+1} = code;
            geoData.coordinates(end+1, :) = coords;
        end
    end
    
    % Convert to arrays if single country
    if length(geoData.countries) == 1
        geoData.countries = geoData.countries{1};
        geoData.names = geoData.names{1};
    end
end

function coords = getCountryCentroid(countryCode)
    % GETCOUNTRYCENTROID Returns approximate lat/lon centroid for country
    %
    % This is a simplified lookup table for common countries
    % In production, you'd use a proper geocoding service or database
    
    centroids = containers.Map();
    
    % Common country centroids (approximate)
    centroids('BRA') = [-14.2350, -51.9253]; % Brazil
    centroids('USA') = [37.0902, -95.7129]; % United States
    centroids('CHN') = [35.8617, 104.1954]; % China
    centroids('IND') = [20.5937, 78.9629]; % India
    centroids('ARE') = [23.4241, 53.8478]; % UAE
    centroids('GBR') = [55.3781, -3.4360]; % United Kingdom
    centroids('DEU') = [51.1657, 10.4515]; % Germany
    centroids('FRA') = [46.2276, 2.2137]; % France
    centroids('JPN') = [36.2048, 138.2529]; % Japan
    centroids('RUS') = [61.5240, 105.3188]; % Russia
    
    % Default: return center of world if not found
    if isKey(centroids, countryCode)
        coords = centroids(countryCode);
    else
        % Use a default location (center of world)
        coords = [0, 0];
    end
end

function geoData = createDefaultGeoData(countryCode)
    % Create default geographic data when file loading fails
    
    if ischar(countryCode) || isstring(countryCode)
        countryCodes = {char(countryCode)};
    else
        countryCodes = countryCode;
    end
    
    geoData = struct();
    geoData.countries = {};
    geoData.coordinates = [];
    geoData.names = {};
    
    for i = 1:length(countryCodes)
        code = upper(char(countryCodes{i}));
        coords = getCountryCentroid(code);
        
        geoData.countries{end+1} = struct('a3', code, 'name', code);
        geoData.names{end+1} = code;
        geoData.coordinates(end+1, :) = coords;
    end
    
    if length(geoData.countries) == 1
        geoData.countries = geoData.countries{1};
        geoData.names = geoData.names{1};
    end
end

