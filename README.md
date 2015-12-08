CSE 546 Project
===============

Nick Bolten and Sumit Mukherjee (equal partners!)

## Overview

This is an extension to the AccessMap project (www.accessmapseattle.com). More descriptions to come.

In the meantime, view the most recent 'errors' (false positives and false negatives)
at [at this github-mapped geojson file](https://github.com/nbolten/CSE546-project/blob/master/learndata-errors.geojson). Red lines are false positives and blue lines are false negatives.

## TODO

#### Nick

* Explode the sidewalk MultiLineStrings, regenerate ground truth + our training data from it. This will prevent errors related to running ST_LineMerge on our data (weirdly-connected geometries).
* Add intersection-related features
* Look into crowdsourcing method for getting labeled train+test dataset

#### Sumit
