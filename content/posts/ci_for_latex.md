---
title: "CI for LaTex"
date: 2019-08-26T19:38:50Z
draft: False
---

## How to use bitbucket pipelines to generate LaTex documents


Why do this? It’s a handy way to have LaTex documents on the go and 
collaboration.

<!--more-->

## Docker container

The typical way of installing LaTex is texlive and one would normally install the full version.
Whilst, this is great it is pretty big.
So I have created a container with a basic LaTex installation: <https://hub.docker.com/r/wrdeman/docker-min-tex>
This may or may not meet your requirements. 


{{< highlight docker >}}
FROM ubuntu:bionic
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update -q \
    && apt-get install --no-install-recommends -qy \ 
    libfontconfig1 \
    texlive-base \
    texlive-extra-utils \
    texlive-generic-recommended \
    texlive-fonts-recommended \
    texlive-font-utils \
    texlive-latex-base \
    texlive-latex-recommended \
    texlive-latex-extra \
    && rm -rf /var/lib/apt/lists/*

ENV HOME /data
WORKDIR /data
VOLUME ["/data"]
{{< /highlight >}}


Using the image on docker hub, we create a pdf document as:

{{< highlight bash >}}
docker run --rm -i --net=none -v "$PWD":/data wrdeman/docker-min-tex pdflatex a-document.tex
{{< /highlight >}}

So far so good ...

## Bitbucket pipeline

We can use bitbucket's pipeline to build our document and save the output as an downloadable file.
First we need to create git repo with a latex file and bitbucket-pipelines.yml.

The pipeline needs to 

* run our previous docker command
* mark the output file as an artifact in the step
* send the output file to the download API endpoint 

as the following yml

{{< highlight yml >}}
pipelines:
  default:
    - step:
        services:
          - docker
        script: 
          - docker run --rm -i --net=none -v "$PWD":/data wrdeman/docker-min-tex pdflatex a-document.tex
        artifacts:
          - a-document.pdf
    - step:
        script:   
          - curl -X POST --user "${BB_STRING}" "https://api.bitbucket.org/2.0/repositories/${BITBUCKET_USERNAME}/${BITBUCKET_REPO_SLUG}/downloads" --form files=@"a-document.pdf" 
{{< /highlight >}}

We need to set some variables, in the repo's settings->reposity variables.
These are:

* BB_STRING is the "USERNAME:APP_PASSWORD"
* BITBUCKET_USERNAME
* BITBUCKET_REPO_SLUG

The APP_PASSWORD can be create in you bitbucket account settings->App passwords.

Now when you commit the repo the pipeline will run and a document will appear in the repo's download directory.
