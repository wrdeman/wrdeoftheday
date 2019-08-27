#!/bin/bash

echo "Generating site"
hugo -d docs

echo "Updating gh-pages branch"
cd git add --all && git commit -m "Publishing to gh-pages (publish.sh)"  

git push 
echo "Updated gh-pages branch"
