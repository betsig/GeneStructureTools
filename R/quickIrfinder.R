#' Import IRFinder results files as a irfDataSet
#' @param filePath path to IRFinder differential splicing output file
#' @return irfDataSet
#' @export
#' @import methods
#' @family IRFinder data processing
#' @author Beth Signal
#' @examples
readIrfDataSet <- function(path){

    irf <- new("irfDataSet", filePath=path)

    irfResultsFile <- fread(path, data.table=F)
    irfResultsFile$FDR <- p.adjust(irfResultsFile$`p-diff`, "fdr")
    irfResultsFile$psi_diff <- irfResultsFile$`A-IRratio` - irfResultsFile$`B-IRratio`
    irfResultsFile$gene_name <- unlist(lapply(str_split(irfResultsFile$`Intron-GeneName/GeneID`, "/"), "[[", 1))
    irfResultsFile$gene_id <- unlist(lapply(str_split(irfResultsFile$`Intron-GeneName/GeneID`, "/"), "[[", 2))
    irfResultsFile$status <- unlist(lapply(str_split(irfResultsFile$`Intron-GeneName/GeneID`, "/"), "[[", 3))
    irfResultsFile$intron_id <- paste0(irfResultsFile$Chr, ":", irfResultsFile$Start, "-", irfResultsFile$End)


    events.RI <- GRanges(seqnames=irfResultsFile$Chr,
                        ranges=IRanges(start=irfResultsFile$Start+1, end=irfResultsFile$End),
                        strand=irfResultsFile$Direction,
                        id=irfResultsFile$intron_id)

    slot(irf, "IRFresults") <- irfResultsFile
    slot(irf, "coordinates") <- events.RI

    return(irf)
}
#' Filter out significant events from a irfDataSet
#' @param irfDataSet irfDataSet generated from \code{readIrfDataSet()}
#' @param FDR maximum FDR required to call event as significant
#' @param psiDelta minimum change in psi required to call an event as significant
#' @param idList (optional) list of gene ids to filter for
#' @return filtered irfDataSet
#' @export
#' @importFrom stats median
#' @family IRFinder data processing
#' @author Beth Signal
#' @examples
filterIrfEvents <- function(irfDataSet,
                              FDR=0.05,
                              psiDelta=0.1,
                              idList=NA){

    #set FDR/psiDelta if NA
    if(is.na(FDR[1])){
        FDR <- 1
    }
    if(is.na(psiDelta[1])){
        psiDelta <- 0
    }

    tmp <- slot(irfDataSet, "IRFresults")
    significantEventsIndex <- which(tmp$FDR <= FDR & abs(tmp$psi_diff) > psiDelta)
    slot(irfDataSet, "IRFresults") <- tmp[significantEventsIndex,]


    if(!is.na(idList[1])){
        tmp <- slot(irfDataSet, "IRFresults")
        significantEventsIndex <- which(tmp$gene_name %in% idList | tmp$gene_id %in% idList)
        slot(irfDataSet, "IRFresults") <- tmp[significantEventsIndex,]
    }

    tmpCoords <- slot(irfDataSet, "coordinates")
    tmpCoords <- tmpCoords[which(tmpCoords$id %in% slot(irfDataSet, "IRFresults")$intron_id),]
    slot(irfDataSet, "coordinates") <- tmpCoords

    return(irfDataSet)

}

#' Compare open reading frames for RMATS differentially spliced events
#' @param irfDataSet irfsDataSet generated from \code{readIrfDataSet()}
#' @param eventTypes which event type to filter for? default="all"
#' @param exons GRanges gtf annotation of exons
#' @param BSgenome BSGenome object containing the genome for the species analysed
#' @param intronMatchType what type of matching to perform in findIntronContainingTranscripts?
#' @param NMD Use NMD predictions?
#' @param exportGTF file name to export alternative isoform GTFs (default=NULL)
#' @return data.frame containing significant IRFinder differential splicing data and ORF change summaries
#' @export
#' @import GenomicRanges
#' @importFrom rtracklayer export.gff
#' @family IRFinder data processing
#' @author Beth Signal

irfTranscriptChangeSummary <- function(irfDataSet,
                                       exons=NULL,
                                       BSgenome,
                                       intronMatchType="exact",
                                       NMD=TRUE,
                                       exportGTF=NULL){

    irfCoords <- slot(irfDataSet, "coordinates")

    seqlevelsStyle(irfCoords) <- seqlevelsStyle(exons)[1]

    exons.intronRetention <- findIntronContainingTranscripts(input=irfCoords, exons, match=intronMatchType )
    isoforms.RI <- addIntronInTranscript(flankingExons=exons.intronRetention, exons, match="retain")

    orfChanges.RI <- transcriptChangeSummary(isoforms.RI[isoforms.RI$set == "retained_intron"],
                                             isoforms.RI[isoforms.RI$set == "spliced_intron"],
                                             BSgenome=g, NMD=NMD, exportGTF=NULL, dataSet=irfDataSet)

    irf.signif <- irfResults(irfDataSet)
    m <- match(orfChanges.RI$id, irf.signif$intron_id)

    orfChanges <- cbind(irf.signif[m,c('intron_id', 'gene_id', 'gene_name', 'p-diff','FDR', 'psi_diff')], type="RI", orfChanges.RI)


    if(!is.null(exportGTF)){
        rtracklayer::export.gff(isoforms.RI, con=exportGTF, format="gtf")
    }

    return(orfChanges)
}



