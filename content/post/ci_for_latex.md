---
title: "Ci for latex documents"
date: 2019-08-26T19:38:50Z
draft: False
---

## How to use bitbucket pipelines to generate LaTex documents


Why do this? It’s a handy way to have LaTex documents on the go and 
collaboration.

## Docker container

The typical way of installing LaTex is texlive and one would normally install the full version.
Whilst, this is great it is pretty big.
So I have created a container with a basic LaTex installation. 
This may or may not meet your requirements.


‘’’
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
‘’’

