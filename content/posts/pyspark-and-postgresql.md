---
title: "Trying out Apache Spark: part 2"
date: 2020-10-15T09:00:42Z
draft: false
---
### Spark and Postgresql

How to connect to apache spark to postgresql.

<!--more-->

#### pyspark notebook and docker-compose
For this I will be using the jupyter all-spark notebook and define it with a postgres container in docker-compose. First I extend the all-spark dockerfile to include the jdbc jar:


`Dockerfile`
```
FROM jupyter/pyspark-notebook
RUN wget https://jdbc.postgresql.org/download/postgresql-42.2.17.jar
ENV SPARK_OPTS=$SPARK_OPTS:" --packages org.postgresql:postgresql:42.2.17"
```

The docker-compose file is then:

```
version: '3' 
services: 
  db: 
    image: 'postgres' 
    environment: 
      - POSTGRES_USER=postgres 
      - POSTGRES_PASSWORD=postgres 
      - POSTGRES_DB=postgres 
    volumes: 
      - database-data:/var/lib/postgresql/data/ 
      - ./data/:/data 
    ports: 
      - "5432:5432" 
  spark: 
    build: . 
    volumes: 
      - ./data/:/data 
      - ./notebooks/:/home/jovyan/notebook 
    environment: 
      - SPARK_OPTS="--driver-java-options=-Xms1024M --driver-java-options=-Xmx4096M --driver-java-options=-Dlog4j.logLevel=info --packages=io.delta:delta-core_2.12:0.7.0 --conf=spark.sql.extensions=io.delta    .sql.DeltaSparkSessionExtension --conf=spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog --packages org.postgresql:postgresql:42.2.17" 
    ports: 
      - "8888:8888" 
 
volumes: 
  database-data: 
  data: 
  notebooks:
```

#### juypter notebook

We can now connect to postgres through pyspark:

```python
from pyspark.sql import SparkSession

jdbc = '/home/jovyan/postgresql-42.2.17.jar'

spark = SparkSession \
    .builder \
    .config("spark.driver.extraClassPath", jdbc) \
    .getOrCreate()

df = spark.read \
    .format("jdbc") \
    .option("url", "jdbc:postgresql://db:5432/postgres") \
    .option("driver", "org.postgresql.Driver") \
    .option("dbtable", "timing") \
    .option("user", "postgres") \
    .option("password", "postgres") \
    .load()

df.show()
```

    +---+--------------------+
    | id|             updated|
    +---+--------------------+
    |  1|2020-10-15 05:53:...|
    |  2|2020-10-15 05:53:...|
    |  3|2020-10-15 05:53:...|
    +---+--------------------+
   
