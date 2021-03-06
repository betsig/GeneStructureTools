% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/longestORF.R
\name{getOrfs}
\alias{getOrfs}
\title{Get open reading frames for transcripts}
\usage{
getOrfs(
  transcripts,
  BSgenome = NULL,
  returnLongestOnly = TRUE,
  allFrames = FALSE,
  longest = 1,
  exportFasta = FALSE,
  fastaFile = NULL,
  uORFs = FALSE,
  selectLongest = 1
)
}
\arguments{
\item{transcripts}{GRanges object with ONLY exon annotations
(no gene, transcript, CDS etc.) with all transcripts for orf retrevial}

\item{BSgenome}{BSgenome object}

\item{returnLongestOnly}{only return longest ORF?}

\item{allFrames}{return longest ORF for all 3 frames?}

\item{longest}{return x longest ORFs (regardless of frames)}

\item{exportFasta}{export a .fa.gz file with nucleotide sequences for each transcript?}

\item{fastaFile}{file name for .fa.gz export}

\item{uORFs}{get uORF summaries?}

\item{selectLongest}{proportion of ORFs for each gene to find uORFs for. Value between 0 and 1.
Speeds up uORF calculations but will only return results for the longest ORFs.}
}
\value{
data.frame with longest orf details
}
\description{
Get open reading frames for transcripts
}
\examples{
gtf <- rtracklayer::import(system.file("extdata", "gencode.vM25.small.gtf",
    package = "GeneStructureTools"
))
transcript <- gtf[gtf$type == "exon" & gtf$gene_name == "Tmem208"]
g <- BSgenome.Mmusculus.UCSC.mm10::BSgenome.Mmusculus.UCSC.mm10
# longest ORF for each transcripts
orfs <- getOrfs(transcript, BSgenome = g, returnLongestOnly = TRUE)
# longest ORF in all 3 frames for each transcript
orfs <- getOrfs(transcript, BSgenome = g, allFrames = TRUE)
# longest 3 ORFS in eacht transcript
orfs <- getOrfs(transcript, BSgenome = g, returnLongestOnly = FALSE, longest = 3)
}
\seealso{
Other ORF annotation: 
\code{\link{getUOrfs}()},
\code{\link{maxLocation}()},
\code{\link{orfSimilarity}()}
}
\author{
Beth Signal
}
\concept{ORF annotation}
