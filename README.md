CSE 546 Project
===============

Nick Bolten and Sumit Mukherjee (equal partners!)

## Overview

This is an extension to the AccessMap project (www.accessmapseattle.com), an effort to provide safe, reliable trip planning focused on people with limited mobility.

Our goal is to automate data cleaning on raw sidewalk data provided by municipalities, for which the exact latitude-longitude coordinates are often noisy. Our objective is to classify the nearest endpoints of two sidewalks as either connected to one another (1), or disconnected (0). Our labeled dataset comes from algorithms generated over the summer by the UW DSSG program. The potential benefits to using machine learning are faster algorithms and a more generalizable solution for different cities.

There are two parts to our project: 1) generating features for sidewalk pairs (using SQL and a PostGIS database - the scripts are in the sql/ directory) and 2) learning using different approaches with scikit-learn. The preliminary analysis iPython notebooks contain our most recent attempts at learning. So far, we've been able to achieve ~99.99% precision + ~84% recall with logistic regression with an L1 norm (or 97% precision + 94% recall when relaxing the regularization parameter).

In the meantime, view the most recent 'errors' (false positives and false negatives)
at [at this github-mapped geojson file](https://github.com/nbolten/CSE546-project/blob/master/learndata-errors.geojson). Red lines are false positives and blue lines are false negatives.

## TODO

* Mock up learning problem that addresses the 'T' intersections or preprocess them away.
* Remove labels that intersect the street? Common false negatives cross the street.

#### Nick

* Explode the sidewalk MultiLineStrings, regenerate ground truth + our training data from it. This will prevent errors related to running ST_LineMerge on our data (weirdly-connected geometries).
* Add intersection-related features
* Look into crowdsourcing method for getting labeled train+test dataset

#### Sumit


## Feature Ideas
* Whether one of the sidewalks intersects a street all by itself (could help rule out false negatives where 'intersects_street' is true but it's due to the sidewalks being inaccurate).
* Average distance to nearest street intersection
* 
