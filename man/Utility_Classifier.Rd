% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/Utility_Classifier.R
\name{Utility_Classifier}
\alias{Utility_Classifier}
\alias{rocPlot}
\alias{prcPlot}
\alias{calibPlot}
\alias{cumGainPlot}
\alias{classifierDiagnosticPlots}
\alias{compute_auc}
\title{Utility functions for creating diagnostic plots for binary classifiers.}
\usage{
rocPlot(trueClass, predProb, groups = NA, colors = NA)

prcPlot(trueClass, predProb, groups = NA, colors = NA)

calibPlot(trueClass, predProb, groups = NA, colors = NA)

cumGainPlot(trueClass, predProb, groups = NA, colors = NA)

classifierDiagnosticPlots(trueClass, predProb, groups = NA,
  colors = NA, plotTypes = c("ROC", "PRC", "Calibration", "CumGain"))

compute_auc(trueClass, predProb)
}
\arguments{
\item{trueClass}{A factor of true class labels.}

\item{predProb}{A numeric vector of predicted scores etc.}

\item{groups}{A vector indicating strata. Disable by setting NA.}

\item{colors}{A set of colors. The length should be the same with the number of groups.}

\item{plotTypes}{A character vector indicating which types of plots should be generated.}
}
\description{
Utility functions for creating diagnostic plots for binary classifiers.
}
