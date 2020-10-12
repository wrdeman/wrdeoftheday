---
title: "Trying out Apache Spark 1"
date: 2020-09-28T20:05:42Z
draft: false
---
### Spark and IMDB data

Using this to try out some techniqkues with Apache Spark. The data is a subset of the IMDB dataset: https://www.imdb.com/interfaces/

<!--more-->



```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, split, explode
from pyspark.sql.types import ArrayType, StringType
```


```python
# create spark session
spark = SparkSession.builder.getOrCreate()
```


```python
# read in names 
fnames = '/data/name.basics.tsv'
names = spark.read.csv(fnames, sep=r'\t', header=True)
```


```python
names.count()
```




    10375296




```python
names.printSchema()
```

    root
     |-- nconst: string (nullable = true)
     |-- primaryName: string (nullable = true)
     |-- birthYear: string (nullable = true)
     |-- deathYear: string (nullable = true)
     |-- primaryProfession: string (nullable = true)
     |-- knownForTitles: string (nullable = true)
    



```python
names.show()
```

    +---------+-------------------+---------+---------+--------------------+--------------------+
    |   nconst|        primaryName|birthYear|deathYear|   primaryProfession|      knownForTitles|
    +---------+-------------------+---------+---------+--------------------+--------------------+
    |nm0000001|       Fred Astaire|     1899|     1987|soundtrack,actor,...|tt0031983,tt00504...|
    |nm0000002|      Lauren Bacall|     1924|     2014|  actress,soundtrack|tt0038355,tt01170...|
    |nm0000003|    Brigitte Bardot|     1934|       \N|actress,soundtrac...|tt0054452,tt00599...|
    |nm0000004|       John Belushi|     1949|     1982|actor,soundtrack,...|tt0077975,tt00725...|
    |nm0000005|     Ingmar Bergman|     1918|     2007|writer,director,a...|tt0083922,tt00509...|
    |nm0000006|     Ingrid Bergman|     1915|     1982|actress,soundtrac...|tt0036855,tt00345...|
    |nm0000007|    Humphrey Bogart|     1899|     1957|actor,soundtrack,...|tt0043265,tt00338...|
    |nm0000008|      Marlon Brando|     1924|     2004|actor,soundtrack,...|tt0070849,tt00787...|
    |nm0000009|     Richard Burton|     1925|     1984|actor,soundtrack,...|tt0087803,tt00611...|
    |nm0000010|       James Cagney|     1899|     1986|actor,soundtrack,...|tt0042041,tt00355...|
    |nm0000011|        Gary Cooper|     1901|     1961|actor,soundtrack,...|tt0044706,tt00279...|
    |nm0000012|        Bette Davis|     1908|     1989|actress,soundtrac...|tt0056687,tt00312...|
    |nm0000013|          Doris Day|     1922|     2019|soundtrack,actres...|tt0060463,tt00540...|
    |nm0000014|Olivia de Havilland|     1916|     2020|  actress,soundtrack|tt0040806,tt00414...|
    |nm0000015|         James Dean|     1931|     1955| actor,miscellaneous|tt0049261,tt00432...|
    |nm0000016|    Georges Delerue|     1925|     1992|composer,soundtra...|tt0057345,tt00963...|
    |nm0000017|   Marlene Dietrich|     1901|     1992|soundtrack,actres...|tt0055031,tt00512...|
    |nm0000018|       Kirk Douglas|     1916|     2020|actor,producer,so...|tt0054331,tt00494...|
    |nm0000019|   Federico Fellini|     1920|     1993|writer,director,a...|tt0050783,tt00711...|
    |nm0000020|        Henry Fonda|     1905|     1982|actor,producer,so...|tt0082846,tt00325...|
    +---------+-------------------+---------+---------+--------------------+--------------------+
    only showing top 20 rows
    



```python
ftitles = '/data/title.basics.tsv'
titles = spark.read.csv(ftitles, sep=r'\t', header=True)
```


```python
titles.count()
```




    7179817




```python
titles.printSchema()
```

    root
     |-- tconst: string (nullable = true)
     |-- titleType: string (nullable = true)
     |-- primaryTitle: string (nullable = true)
     |-- originalTitle: string (nullable = true)
     |-- isAdult: string (nullable = true)
     |-- startYear: string (nullable = true)
     |-- endYear: string (nullable = true)
     |-- runtimeMinutes: string (nullable = true)
     |-- genres: string (nullable = true)
    



```python
''' 
name.knownForTimes >- titles.tconst

so we will create a name for each knownForTitle entry
'''
names = names.withColumn(
    'knownForTitles', 
    split(
        col('knownForTitles'), ','
    ).cast(ArrayType(StringType())).alias('knownForTitles')
).withColumn(
    'knownForTitle',
    explode('knownForTitles')
)
```


```python
# now join denormalized names with titles
names = names.join(titles, names.knownForTitle == titles.tconst)
names.write.mode('overwrite').parquet('/data/test.parquet')
```


```python
names.printSchema()
```

    root
     |-- nconst: string (nullable = true)
     |-- primaryName: string (nullable = true)
     |-- birthYear: string (nullable = true)
     |-- deathYear: string (nullable = true)
     |-- primaryProfession: string (nullable = true)
     |-- knownForTitles: array (nullable = true)
     |    |-- element: string (containsNull = true)
     |-- knownForTitle: string (nullable = true)
     |-- tconst: string (nullable = true)
     |-- titleType: string (nullable = true)
     |-- primaryTitle: string (nullable = true)
     |-- originalTitle: string (nullable = true)
     |-- isAdult: string (nullable = true)
     |-- startYear: string (nullable = true)
     |-- endYear: string (nullable = true)
     |-- runtimeMinutes: string (nullable = true)
     |-- genres: string (nullable = true)
    



```python
# Find Fred Astaire's films
names.filter(names.nconst=='nm0000001').select('primaryTitle').show()
```

    +--------------------+
    |        primaryTitle|
    +--------------------+
    |          Funny Face|
    |        On the Beach|
    |The Towering Inferno|
    |The Story of Vern...|
    +--------------------+
    
