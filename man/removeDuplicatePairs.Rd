% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/helpers.R
\name{removeDuplicatePairs}
\alias{removeDuplicatePairs}
\title{remove any duplicate pairs of events/reference transcripts (i.e. long event range which overlaps 2+ exons)}
\usage{
removeDuplicatePairs(betweenExons)
}
\arguments{
\item{betweenExons}{data.frame with related differential splicing event ids and reference transcript_ids}
}
\value{
data.frame with related differential splicing event ids and reference transcript_ids
}
\description{
remove any duplicate pairs of events/reference transcripts (i.e. long event range which overlaps 2+ exons)
}
\seealso{
Other rmats data processing: 
\code{\link{altIntronRmats}()},
\code{\link{altSpliceSiteRmats}()},
\code{\link{annotateEventCoords}()},
\code{\link{annotateOverlapRmats}()},
\code{\link{betweenNumbers}()},
\code{\link{duplicateReference}()},
\code{\link{exonsToIntrons}()},
\code{\link{extractEvent}()},
\code{\link{filterRmatsEvents}()},
\code{\link{readRmatsDataSet}()},
\code{\link{reformatExons}()},
\code{\link{removeExonsBetween}()},
\code{\link{rmatsTranscriptChangeSummary}()},
\code{\link{skipExonByJunction}()},
\code{\link{splitLongExons}()}
}
\author{
Beth Signal
}
\concept{rmats data processing}
\keyword{internal}
