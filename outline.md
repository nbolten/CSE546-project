# Overview

The goal is to generate a dataset derived from the data.seattle.gov SDOT sidewalks dataset. The learning goal is to classify the relationship between two sidewalks as either connected (1) or disconnected (0), and therefore lends itself to classification algorithms like logistic regression.

### Features

There is the potential to use and generate a lot of interesting features. By default, the sidewalks dataset has a large number of features in addition to the geometrical description of the sidewalks, like the street it's associated with, the length of the sidewalk, the condition of the sidewalk, the type of curb, the width of the sidewalk, the side of the street that it's on, the existence of a curb ramp, and more. We will eventually try to use all of these, but for the first round we are most interested in geometrical relationships.

We want our predicted variable to be 1-dimensional - a classification of two sidewalks being connected together. Therefore, each row represents two sidewalks in the SDOT database and the features are either relationships between the two sidewalks or the individual features for each sidewalk. Here's our current plan for the features:

1. The minimum distance between the two sidewalks - i.e. how close together are the closest points between the sidewalks.
2. The angle between the two sidewalks - we get angles for individual sidewalks based on the vector pointing out of the end.
