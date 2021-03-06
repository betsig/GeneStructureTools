% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/longestORF.R
\name{getUOrfs}
\alias{getUOrfs}
\title{Get upstream open reading frames for transcripts with annotated main ORFs}
\usage{
getUOrfs(transcripts, BSgenome = NULL, orfs, findExonB = FALSE)
}
\arguments{
\item{transcripts}{GRanges object with ONLY exon annotations
(no gene, transcript, CDS etc.) with all transcripts for orf retrevial}

\item{BSgenome}{BSgenome object}

\item{orfs}{orf annotation for the transcripts object. Generated by getOrfs(transcripts, ...)}

\item{findExonB}{find the distance to and exon number of the downstream (B) junction?}
}
\value{
data.frame with all upstream ORF details.
}
\description{
Get upstream open reading frames for transcripts with annotated main ORFs
}
\examples{
gtf <- rtracklayer::import(system.file("extdata", "gencode.vM25.small.gtf",
    package = "GeneStructureTools"
))
transcript <- gtf[gtf$type == "exon" & gtf$gene_name == "Tmem208"]
g <- BSgenome.Mmusculus.UCSC.mm10::BSgenome.Mmusculus.UCSC.mm10
# longest ORF for each transcripts
orfs <- getOrfs(transcript, BSgenome = g, returnLongestOnly = FALSE)
uORFS <- getUOrfs(transcript, BSgenome = g, orfs = orfs, findExonB = TRUE)
}
\seealso{
Other ORF annotation: 
\code{\link{getOrfs}()},
\code{\link{maxLocation}()},
\code{\link{orfSimilarity}()}
}
\author{
Beth Signal
}
\concept{ORF annotation}
