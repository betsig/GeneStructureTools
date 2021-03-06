% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/altSplicingrMATS.R
\name{skipExonByJunction}
\alias{skipExonByJunction}
\title{Generate isoforms with and without a skipped exon (or mutually exclusive exons)}
\usage{
skipExonByJunction(rmatsEvents, eventType = "SE", exons)
}
\arguments{
\item{rmatsEvents}{data.frame containing RMATS SE or MXE events}

\item{eventType}{type of event to skip exons for. "SE" - skipped exons, or "MXE" - mutually exclusive exons}

\item{exons}{reference exons GRanges}
}
\value{
data.frame with overlapping event/exons
}
\description{
Generate isoforms with and without a skipped exon (or mutually exclusive exons)
}
\examples{
gtf <- rtracklayer::import(system.file("extdata", "gencode.vM25.small.gtf", package = "GeneStructureTools"))
exons <- gtf[gtf$type == "exon"]
g <- BSgenome.Mmusculus.UCSC.mm10::BSgenome.Mmusculus.UCSC.mm10

rmats_directory <- system.file("extdata", "rmats_small/", package = "GeneStructureTools")
rds <- readRmatsDataSet(rmats_directory)
rds.filtered <- filterRmatsEvents(rds, FDR = 0.01, psiDelta = 0.1)

diffSplice.MXE <- extractEvent(rds.filtered, "MXE")
isoforms.MXE <- skipExonByJunction(diffSplice.MXE, eventType = "MXE", exons = exons)

diffSplice.SE <- extractEvent(rds.filtered, "SE")
isoforms.SE <- skipExonByJunction(diffSplice.SE, eventType = "SE", exons = exons)
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
\code{\link{removeDuplicatePairs}()},
\code{\link{removeExonsBetween}()},
\code{\link{rmatsTranscriptChangeSummary}()},
\code{\link{splitLongExons}()}
}
\author{
Beth Signal
}
\concept{rmats data processing}
