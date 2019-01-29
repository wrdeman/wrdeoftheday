---
title: "Average House Prices"
date: 2019-01-28T20:05:42Z
draft: true
---

### What's the average house price in a school's catchment area?

In order to calculate the average house price in a school's catchment area, we are going to use PostGIS and OpenStreetMap. We'll need to know the price and location of houses sold in that area, and the location of the schools and it's catchment area. The former can be determined from the land registry and although this does not provide any geocoding we can do this using data provided by OpenStreetMap's Nominatim. The location of the schools can be found in OpenStreetMap's polygon table.

#### OpenStreetMap

There are good instructions on how to setup OpenStreetMap [here](https://switch2osm.org/manually-building-a-tile-server-18-04-lts/).


For the postcode data, first get the data:
```bash
wget https://www.nominatim.org/data/gb_postcode_data.sql.gz
gunzip gb_postcode_data.sql.gz
```

Create a PostGIS table: 
```sql
CREATE TABLE gb_postcode (
    id integer,
    postcode character varying(9),
    geometry geometry,
    CONSTRAINT enforce_dims_geometry CHECK ((st_ndims(geometry) = 2)),
    CONSTRAINT enforce_srid_geometry CHECK ((st_srid(geometry) = 4326))
);
```

Ingest the data:
```bash
psql -dgis -f data/gb_postcode_data.sql
```

#### House prices.

UK house prices are recorded by the Land Registry and they have a nice SPARQL console interface [http://landregistry.data.gov.uk/app/qonsole](http://landregistry.data.gov.uk/app/qonsole). Here we get the house prices for properties in Bristol in 2018 using the following SPARQL query:

```
prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix owl: <http://www.w3.org/2002/07/owl#>
prefix xsd: <http://www.w3.org/2001/XMLSchema#>
prefix sr: <http://data.ordnancesurvey.co.uk/ontology/spatialrelations/>
prefix ukhpi: <http://landregistry.data.gov.uk/def/ukhpi/>
prefix lrppi: <http://landregistry.data.gov.uk/def/ppi/>
prefix skos: <http://www.w3.org/2004/02/skos/core#>
prefix lrcommon: <http://landregistry.data.gov.uk/def/common/>

SELECT ?paon ?saon ?street ?town ?county ?postcode ?amount ?date ?category
WHERE
{
  VALUES ?town {"BRISTOL"^^xsd:string}
FILTER (
    ?date > "2018-11-01"^^xsd:date &&
    ?date < "2018-12-31"^^xsd:date
  )
  ?addr lrcommon:town ?town.

  ?transx lrppi:propertyAddress ?addr ;
          lrppi:pricePaid ?amount ;
          lrppi:transactionDate ?date ;
          lrppi:transactionCategory/skos:prefLabel ?category.

  OPTIONAL {?addr lrcommon:county ?county}
  OPTIONAL {?addr lrcommon:paon ?paon}
  OPTIONAL {?addr lrcommon:saon ?saon}
  OPTIONAL {?addr lrcommon:street ?street}
  OPTIONAL {?addr lrcommon:postcode ?postcode}

}
ORDER BY ?amount
```

To get the housing data into PostGIS we first create a table for the house prices, the copy the data from a csv, and finally copy the appropriate postcode geometry onto the house table. This is a bit of a shortcut cut to make subsequent lookups easier. 
```sql
CREATE TABLE house (
    postcode character varying(9),
    geometry geometry,
    paon     | character varying     
    saon     | character varying     
    street   | character varying     
    town     | character varying     
    county   | character varying     
    postcode | character varying     
    amount   | numeric               
    date     | date                  
    category | character varying     
);
```

Copy the postcode geometry onto the house table
```sql
UPDATE house 
SET geometry=gb_postcode.geometry 
FROM gb_postcode WHERE gb_postcode.postcode LIKE house.postcode;
```

The final thing to do is to transform the data to transform the postcode table to have the same projection as the OpenStreetMap tables.  
```sql
ALTER TABLE house 
ALTER COLUMN geometry TYPE geometry(point, 3857) 
USING ST_Transform(ST_SETSRID(geometry,4326),3857);
```

 

```sql
SELECT min(h.amount), avg(h.amount), max(h.amount) 
FROM house as h 
WHERE ST_DWITHIN(
    (
        SELECT way 
        FROM planet_osm_polygon 
        WHERE name ILIKE '%henleaze infant%'
    ), 
    h.geometry, 
    800
);
```
gis=# select  min(h.amount), avg(h.amount), max(h.amount) from house h left join planet_osm_polygon pa ON st_dwithin(st_centroid(pa.way), h.geometry, 800) where pa.name ilike '%henleaze infant%';
  min   |         avg         |  max   
--------+---------------------+--------
 220000 | 581765.051724137931 | 988200
(1 row)

Time: 641.007 ms
gis=# select min(h.amount), avg(h.amount), max(h.amount) from house as h where ST_Dwithin((select way from planet_osm_polygon where name ilike '%henleaze infant%'), h.geometry, 800);
  min   |         avg         |  max   
--------+---------------------+--------
 195000 | 563852.402777777778 | 988200
(1 row)

Time: 644.310 ms

