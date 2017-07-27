% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/IntronRetention.R
\name{findIntronContainingTranscripts}
\alias{findIntronContainingTranscripts}
\title{Given the location of a whole retained intron, find transcripts which splice out this intron}
\usage{
findIntronContainingTranscripts(intronRanges, gtf.exons)
}
\arguments{
\item{intronRanges}{GRanges object with ranges for introns}

\item{gtf.exons}{GRanges object made from a GTF with ONLY exon annotations (no gene, transcript, CDS etc.)}
}
\value{
data.frame with all flanking exon pairs
}
\description{
Given the location of a whole retained intron, find transcripts which splice out this intron
}
\author{
Beth Signal
}