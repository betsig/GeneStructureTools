#' Compare open reading frames for two sets of paired transcripts
#' @param transcriptsX GRanges object with exon annotations for
#' all transcripts to be compared for the 'normal' condition
#' @param transcriptsY GRanges object with exon annotations for
#' all transcripts to be compared for the 'alternative' condition
#' @param BSgenome BSGenome object containing the genome for the species analysed
#' @param exons GRanges object made from a GTF containing exon coordinates
#' @param NMD Use NMD predictions? This will filter ORFs out of comparisons if they are likely to be NMD-targeted.
#' @param orfPrediction What type of orf predictions to return. default= \code{"allFrames"}
#' @param compareBy compare isoforms by 'transcript' id, or aggregate all changes occurring by 'gene'
#' @param compareToGene compare alternative isoforms to all normal gene isoforms (in exons)
#' @param dataSet whippetDataSet/rMATSDataSet generated from \code{readWhippetDataSet()} or \code{readrMATSDataSet()}
#' Use if PSI directionality should be taken into account when comparing isoforms.
#' @param exportGTF file name to export alternative isoform GTFs (default=\code{NULL})
#' @param selectLongest passed to getORFs()
#' @return Summarised ORF changes data.frame
#' @export
#' @import GenomicRanges
#' @importFrom rtracklayer import
#' @importFrom utils installed.packages
#' @importFrom dplyr distinct
#' @family transcript isoform comparisons
#' @author Beth Signal
#' @examples
#' gtf <- rtracklayer::import(system.file("extdata", "gencode.vM25.small.gtf",
#'     package = "GeneStructureTools"
#' ))
#' exons <- gtf[gtf$type == "exon"]
#' g <- BSgenome.Mmusculus.UCSC.mm10::BSgenome.Mmusculus.UCSC.mm10
#'
#' whippetFiles <- system.file("extdata", "whippet_small/",
#'     package = "GeneStructureTools"
#' )
#' wds <- readWhippetDataSet(whippetFiles)
#'
#' wds.exonSkip <- filterWhippetEvents(wds, eventTypes = "CE", psiDelta = 0.2)
#'
#' exons.exonSkip <- findExonContainingTranscripts(wds.exonSkip, exons,
#'     variableWidth = 0, findIntrons = FALSE
#' )
#' ExonSkippingTranscripts <- skipExonInTranscript(exons.exonSkip, exons, whippetDataSet = wds.exonSkip)
#' transcriptChangeSummary(ExonSkippingTranscripts[ExonSkippingTranscripts$set == "included_exon"],
#'     ExonSkippingTranscripts[ExonSkippingTranscripts$set == "skipped_exon"],
#'     BSgenome = g, exons
#' )
transcriptChangeSummary <- function(transcriptsX,
                                    transcriptsY,
                                    BSgenome,
                                    exons,
                                    dataSet = NULL,
                                    exportGTF = NULL,
                                    NMD = FALSE,
                                    compareBy = "gene",
                                    orfPrediction = "allFrames",
                                    compareToGene = FALSE,
                                    selectLongest = 1) {
    if (!is.null(dataSet)) {
        if (class(dataSet)[1] == "whippetDataSet") {
            whippetEvents <- diffSplicingResults(dataSet)

            allTranscripts <- c(transcriptsX, transcriptsY)
            txEvents <- unlist(lapply(str_split(lapply(str_split(allTranscripts$transcript_id, "[+]AS"), "[[", 2), "[ ]"), "[[", 1))

            if (any(txEvents %in% c("TEU", "TED", "TSU", "TSD"))) {
                transcriptsX <- allTranscripts[txEvents %in% c("TED", "TSD")]
                transcriptsY <- allTranscripts[txEvents %in% c("TEU", "TSU")]
                allTranscripts <- allTranscripts[-which(txEvents %in% c("TED", "TSD", "TEU", "TSU"))]
            } else {
                # clear transcripts X/Y
                transcriptsX <- transcriptsX[-(seq_along(transcriptsX))]
                transcriptsY <- transcriptsY[-(seq_along(transcriptsY))]
            }

            # for non-TS/TE events
            if (length(allTranscripts) > 0) {
                type <- gsub("_X", "", gsub("_Y", "", allTranscripts$set))
                type <- gsub("skipped_exon", "CE", gsub("included_exon", "CE", type))
                type <- gsub("retained_intron", "RI", gsub("spliced_intron", "RI", type))

                m <- match(
                    paste0(allTranscripts$event_id, "_", type),
                    paste0(
                        whippetEvents$coord, "_",
                        whippetEvents$type
                    )
                )
                # A -- psi in condition 1 (A) is higher (i.e. included -- > skipped)
                normA <- which(whippetEvents$psi_a > whippetEvents$psi_b)
                # B -- psi in condition 2 (B) is higher (i.e. skipped -- > included)
                normB <- which(whippetEvents$psi_a < whippetEvents$psi_b)

                # sets for X (+A)
                setsX <- c(paste0(unique(type), "_Y"), "included_exon", "retained_intron")
                # sets for Y (+B)
                setsY <- c(paste0(unique(type), "_X"), "skipped_exon", "spliced_intron")

                transcriptsX <- c(transcriptsX, allTranscripts[
                    which((m %in% normA & allTranscripts$set %in% setsX) |
                        (m %in% normB & allTranscripts$set %in% setsY))
                ])

                transcriptsY <- c(transcriptsY, allTranscripts[
                    which((m %in% normA & allTranscripts$set %in% setsY) |
                        (m %in% normB & allTranscripts$set %in% setsX))
                ])
            }
        }

        if (class(dataSet)[1] == "rmatsDataSet") {

            # combine all events (only PSI direction/eventID)
            allEvents <- NULL
            for (eventType in c("SE", "MXE", "RI", "A3SS", "A5SS")) {
                psiDiffs <- slot(dataSet, eventType)[, c("ID", "GeneID", "geneSymbol", "PValue", "FDR", "IncLevelDifference")]
                if (nrow(psiDiffs) > 0) {
                    psiDiffs$type <- eventType
                    allEvents <- rbind(allEvents, psiDiffs)
                }
            }

            allTranscripts <- c(transcriptsX, transcriptsY)
            allTranscripts$type <- NA
            allTranscripts$type[allTranscripts$set %in% c("included_exon", "skipped_exon")] <- "SE"
            allTranscripts$type[allTranscripts$set %in% c("included_exon1", "included_exon2")] <- "MXE"
            allTranscripts$type[allTranscripts$set %in% c("spliced_intron", "retained_intron")] <- "RI"
            allTranscripts$type[allTranscripts$set %in% c("alt3_splicesite_long", "alt3_splicesite_short")] <- "A3SS"
            allTranscripts$type[allTranscripts$set %in% c("alt5_splicesite_long", "alt5_splicesite_short")] <- "A5SS"

            eventId <- unlist(lapply(str_split(lapply(str_split(allTranscripts$transcript_id, "[ ]"), "[[", 2), "[-]"), "[[", 1))

            allEvents$event_id <- allTranscripts$transcript_id[match(
                paste0(allEvents$ID, "_", allEvents$type),
                paste0(eventId, "_", allTranscripts$type)
            )]

            allEvents$event_id[which(!is.na(allEvents$event_id))] <- unlist(lapply(str_split(
                allEvents$event_id[which(!is.na(allEvents$event_id))],
                "[ ]"
            ), "[[", 2))

            m <- match(
                paste0(eventId, "_", allTranscripts$type),
                paste0(allEvents$ID, "_", allEvents$type)
            )

            normA <- which(allEvents$IncLevelDifference > 0)
            normB <- which(allEvents$IncLevelDifference < 0)

            setsA <- c("included_exon", "included_exon2", "retained_intron", "alt3_splicesite_long", "alt5_splicesite_long")
            setsB <- c("skipped_exon", "included_exon1", "spliced_intron", "alt3_splicesite_short", "alt5_splicesite_short")

            transcriptsX <- allTranscripts[
                which((m %in% normA & allTranscripts$set %in% setsA) |
                    (m %in% normB & allTranscripts$set %in% setsB))
            ]

            transcriptsY <- allTranscripts[
                which((m %in% normA & allTranscripts$set %in% setsB) |
                    (m %in% normB & allTranscripts$set %in% setsA))
            ]
        }
        if (class(dataSet)[1] == "irfDataSet") {

            # combine all events (only PSI direction/eventID)
            allEvents <- slot(dataSet, "IRFresults")
            allEvents$type <- "RI"

            allTranscripts <- c(transcriptsX, transcriptsY)
            allTranscripts$type <- NA
            allTranscripts$type[allTranscripts$set %in% c("spliced_intron", "retained_intron")] <- "RI"

            eventId <- unlist(lapply(str_split(allTranscripts$transcript_id, "[ ]"), "[[", 2))

            allEvents$event_id <- unlist(lapply(str_split(
                allTranscripts$transcript_id[match(
                    paste0(allEvents$intron_id, "_", allEvents$type),
                    paste0(eventId, "_", allTranscripts$type)
                )],
                "[ ]"
            ), "[[", 2))

            m <- match(
                paste0(eventId, "_", allTranscripts$type),
                paste0(allEvents$intron_id, "_", allEvents$type)
            )

            normA <- which(allEvents$psi_diff > 0)
            normB <- which(allEvents$psi_diff < 0)

            setsA <- c("retained_intron")
            setsB <- c("spliced_intron")

            transcriptsX <- allTranscripts[
                which((m %in% normA & allTranscripts$set %in% setsA) |
                    (m %in% normB & allTranscripts$set %in% setsB))
            ]

            transcriptsY <- allTranscripts[
                which((m %in% normA & allTranscripts$set %in% setsB) |
                    (m %in% normB & allTranscripts$set %in% setsA))
            ]
        }
    }

    if (!is.null(exportGTF)) {
        transcriptsX$comp_set <- "X"
        transcriptsY$comp_set <- "Y"
        transcriptsXY <- c(transcriptsX, transcriptsY)

        rtracklayer::export.gff(transcriptsXY, con = exportGTF, format = "gtf")

        transcriptsX$comp_set <- NULL
        transcriptsY$comp_set <- NULL
    }

    if (orfPrediction == "allFrames") {
        orfsX <- getOrfs(transcriptsX, BSgenome,
            returnLongestOnly = FALSE,
            allFrames = TRUE, uORFs = TRUE,
            selectLongest = selectLongest
        )
        orfsY <- getOrfs(transcriptsY, BSgenome,
            returnLongestOnly = FALSE,
            allFrames = TRUE, uORFs = TRUE,
            selectLongest = selectLongest
        )
    } else {
        orfsX <- getOrfs(transcriptsX, BSgenome,
            returnLongestOnly = TRUE,
            uORFs = TRUE, selectLongest = selectLongest
        )
        orfsY <- getOrfs(transcriptsY, BSgenome,
            returnLongestOnly = TRUE,
            uORFs = TRUE, selectLongest = selectLongest
        )
    }

    if (all(!grepl("[+]", orfsX$id))) {
        if (orfPrediction == "allFrames") {
            Yid.withFrame <- paste0(unlist(lapply(
                str_split(orfsY$id, "[+]"), "[[", 1
            )), "_", orfsY$frame)
            Xid.withFrame <- paste0(orfsX$id, "_", orfsX$frame)
            m <- match(Yid.withFrame, Xid.withFrame)
        } else {
            m <- match(
                unlist(lapply(str_split(orfsY$id, "[+]"), "[[", 1)),
                orfsX$id
            )
        }

        orfsX <- orfsX[m, ]
        orfsX$id <- orfsY$id
        # orfsX <- orfsX[which(!duplicated(orfsX$id)),]
    }

    orfsX <- orfsX[which(!is.na(orfsX$orf_length)), ]
    orfsY <- orfsY[which(!is.na(orfsY$orf_length)), ]

    if (NMD == TRUE) {
        orfsX <- manualNMD(orfsX)
        orfsY <- manualNMD(orfsY)
    }

    if (compareToGene == TRUE) {
        orfAllGenes <- getOrfs(exons[exons$gene_id %in% unique(c(transcriptsX$gene_id, transcriptsY$gene_id)) & exons$transcript_type == "protein_coding"],
            BSgenome = BSgenome, returnLongestOnly = TRUE
        )

        if (NMD == TRUE) {
            orfAllGenes <- manualNMD(orfAllGenes)
        }

        orfChange <- orfDiff(orfsX, orfsY,
            filterNMD = NMD, compareBy = "gene",
            geneSimilarity = TRUE,
            allORFs = orfAllGenes, compareUTR = TRUE
        )
    } else {
        orfChange <- orfDiff(orfsX, orfsY,
            filterNMD = NMD, compareBy = "gene",
            compareUTR = TRUE
        )
    }


    if (NMD == TRUE) {
        nmdChangeMan <- attrChangeAltSpliced(orfsX,
            orfsY,
            attribute = "nmd_prob_manual",
            compareBy = "gene",
            useMax = FALSE
        )
        m <- match(orfChange$id, nmdChangeMan$id)
        orfChange <- cbind(orfChange, nmdChangeMan[m, -1])
    }

    if (!is.null(dataSet)) {
        if (class(dataSet)[1] == "whippetDataSet") {
            m <- match(orfChange$id, whippetEvents$coord)

            # for TS/TE events
            # need to collapse/re-match to a 'group' id, otherwise you get lots of doubleups
            if (all(is.na(m))) {
                tidToEvent <- data.frame(
                    tid = c(transcriptsX$transcript_id, transcriptsY$transcript_id),
                    event_id = c(transcriptsX$event_id, transcriptsY$event_id)
                )
                tidToEvent <- dplyr::distinct(tidToEvent)

                # m <- match(orfChange$id, unlist(lapply(str_split(tidToEvent$tid, "[ ]"), "[[", 2)))
                m <- match(whippetEvents$coord, tidToEvent$event_id)
                whippetEvents <- whippetEvents[which(!is.na(m)), ]
                m <- match(whippetEvents$coord, tidToEvent$event_id)
                whippetEvents$group_id <- unlist(lapply(str_split(tidToEvent$tid[m], "[ ]"), "[[", 2))
                whippetEvents <- whippetEvents[order(whippetEvents$group_id, whippetEvents$probability, abs(whippetEvents$psi_delta) * -1), ]
                whippetEvents <- whippetEvents[!duplicated(whippetEvents$group_id), ]

                m <- match(orfChange$id, whippetEvents$group_id)

                orfChange <- cbind(whippetEvents[m, ], orfChange)
                orfChange$group_id <- NULL
            } else {
                orfChange <- cbind(whippetEvents[m, ], orfChange)
            }
        } else if (class(dataSet)[1] == "rMATSDataSet") {
            m <- match(orfChange$id, allEvents$event_id)
            orfChange <- cbind(allEvents[m, ], orfChange[, -1])
        }
    }
    return(orfChange)
}

#' Compare open reading frames for whippet differentially spliced events
#' @param leafcutterEvents  data.frame containing information from the
#' per_intron_results.tab file output from leafcutter.
#' @param exons GRanges gtf annotation of exons
#' @param FDR minimum FDR for events. If left as default (NA), will use FDR=0.05. To stop FDR filtering set to 1.
#' @param combineGeneEvents combine clusters occurring in the same gene?
#' Currently not recommended.
#' @param BSgenome BSGenome object containing the genome for the species analysed
#' @param NMD Use NMD predictions? (Note: notNMD must be installed to use this feature)
#' @param showProgressBar show a progress bar of alternative isoform generation?
#' @param junctions junctions GRanges object from readLeafcutterJunctions()
#' @param exportGTF file name to export alternative isoform GTFs (default=NULL)
#' @return data.frame containing significant whippet diff data and ORF change summaries
#' @export
#' @importFrom utils setTxtProgressBar
#' @importFrom utils txtProgressBar
#' @importFrom stringr str_split
#' @importFrom rtracklayer import
#' @import GenomicRanges
#' @family leafcutter data processing
#' @author Beth Signal
#' @examples
#' leafcutterFiles <- list.files(system.file("extdata", "leaf_small/", package = "GeneStructureTools"), full.names = TRUE)
#' leafcutterIntrons <- read.delim(leafcutterFiles[grep("intron_results", leafcutterFiles)], stringsAsFactors = FALSE)
#' gtf <- rtracklayer::import(system.file("extdata", "gencode.vM25.small.gtf", package = "GeneStructureTools"))
#' exons <- gtf[gtf$type == "exon"]
#' g <- BSgenome.Mmusculus.UCSC.mm10::BSgenome.Mmusculus.UCSC.mm10
#' leafcutterTranscriptChangeSummary(leafcutterEvents = leafcutterIntrons, exons = exons, BSgenome = g, NMD = FALSE)
leafcutterTranscriptChangeSummary <- function(leafcutterEvents,
                                              exons,
                                              FDR = NA,
                                              combineGeneEvents = FALSE,
                                              BSgenome,
                                              NMD = FALSE,
                                              showProgressBar = TRUE,
                                              junctions = NULL,
                                              exportGTF = NULL) {
    if (is.na(FDR)) {
        warning("You haven't selected a FDR cutoff...")
        warning("Using FDR<0.05 to reduce runtime. Change to FDR=1 to model all events.")
        FDR <- 0.05
    }

    leafcutterEvents <- leafcutterEvents[leafcutterEvents$FDR <= FDR, ]
    leafcutterEvents$cluster <- gsub("[_][+-]", "", leafcutterEvents$cluster)
    leafcutterEvents$clusterID <- gsub("[_][+-]", "", leafcutterEvents$clusterID)
    leafcutterEvents$intron <- gsub("[_][+-]", "", leafcutterEvents$intron)


    ## find actual event strand
    leafcutterGranges <- GRanges(
        seqnames = leafcutterEvents$chr,
        ranges = IRanges(start = leafcutterEvents$start, end = leafcutterEvents$end),
        strand = "*", clusterID = leafcutterEvents$clusterID, genes = leafcutterEvents$genes
    )

    introns <- exonsToIntrons(exons)
    ol.intron <- as.data.frame(findOverlaps.junc(leafcutterGranges, introns))
    ol.intron$leaf <- leafcutterGranges$clusterID[ol.intron$queryHits]
    ol.intron$leaf_gene <- leafcutterGranges$genes[ol.intron$queryHits]
    ol.intron$ref <- introns$gene_id[ol.intron$subjectHits]
    ol.intron$ref_name <- introns$gene_name[ol.intron$subjectHits]
    ol.intron$ref_strand <- as.character(strand(introns))[ol.intron$subjectHits]

    ol.intron <- ol.intron[!(duplicated(paste0(ol.intron$leaf, ol.intron$ref))), ]
    ol.intron$leaf_strand <- str_sub(ol.intron$leaf, -1, -1)

    refStrand <- aggregate(ref_strand ~ leaf, ol.intron, function(x) paste0(sort(unique(x)), collapse = ","))
    refStrand <- refStrand[(refStrand$ref_strand %in% c("+", "-")), ]

    noJuncMatch <- unique(leafcutterGranges$clusterID)[which(!(unique(leafcutterGranges$clusterID) %in% refStrand$leaf))]

    if (length(noJuncMatch) > 0) {
        leafcutterGranges.nomatch <- leafcutterGranges[leafcutterGranges$clusterID %in% noJuncMatch]
        ol.intron <- as.data.frame(findOverlaps(leafcutterGranges.nomatch, introns))
        ol.intron$leaf <- leafcutterGranges.nomatch$clusterID[ol.intron$queryHits]
        ol.intron$leaf_gene <- leafcutterGranges.nomatch$genes[ol.intron$queryHits]
        ol.intron$ref <- introns$gene_id[ol.intron$subjectHits]
        ol.intron$ref_name <- introns$gene_name[ol.intron$subjectHits]
        ol.intron$ref_strand <- as.character(strand(introns))[ol.intron$subjectHits]

        ol.intron <- ol.intron[!(duplicated(paste0(ol.intron$queryHits, ol.intron$ref))), ]
        ol.intron <- as.data.frame(table(ol.intron$leaf, ol.intron$ref, ol.intron$ref_strand))
        ol.intron <- ol.intron[ol.intron$Freq > 0, ]
        ol.intron <- ol.intron[order(ol.intron$Var1, ol.intron$Freq * -1), ]
        ol.intron <- ol.intron[!duplicated(ol.intron$Var1), c(1, 3)]
        refStrandv2 <- ol.intron
        colnames(refStrandv2) <- colnames(refStrand)
        refStrand <- rbind(refStrandv2, refStrand)
    }

    leafcutterEvents$strand <- as.character(refStrand$ref_strand[match(leafcutterEvents$clusterID, as.character(refStrand$leaf))])
    ## DONE

    geneEvents <- as.data.frame(table(leafcutterEvents$clusterID))

    geneEvents <- geneEvents[geneEvents$Freq != 0, ]

    if (combineGeneEvents == FALSE) {
        if (showProgressBar) {
            message(paste0(
                "Generating alternative isoforms for ",
                nrow(geneEvents), " clusters:"
            ))
            pb <- utils::txtProgressBar(
                min = 0, max = nrow(geneEvents),
                style = 3
            )
        }

        altIso <- alternativeIntronUsage(
            altIntronLocs = leafcutterEvents[leafcutterEvents$clusterID == geneEvents$Var1[1], ],
            exons, junctions = junctions
        )

        if (showProgressBar) {
            utils::setTxtProgressBar(pb, 1)
        }

        if (nrow(geneEvents) > 1) {
            for (i in 2:nrow(geneEvents)) {
                altIntronLocs <- leafcutterEvents[
                    leafcutterEvents$clusterID == geneEvents$Var1[i],
                ]
                if (all(altIntronLocs$deltapsi < 0) | all(altIntronLocs$deltapsi > 0)) {
                    altIntronLocs <- altIntronLocs[-(seq_len(nrow(altIntronLocs))), ]
                }

                if (nrow(altIntronLocs) > 1) {
                    altIso1 <- alternativeIntronUsage(altIntronLocs, exons, junctions = junctions)
                    if (!is.null(altIso1)) {
                        altIso <- c(altIso, altIso1)
                    }
                }
                if (showProgressBar) {
                    utils::setTxtProgressBar(pb, i)
                }
            }
        }
    } else {
        genes <- unique(geneEvents$Var1)
        if (showProgressBar) {
            message(paste0(
                "Generating alternative isoforms for ",
                nrow(geneEvents), " genes:"
            ))
            pb <- utils::txtProgressBar(min = 0, max = length(genes), style = 3)
        }
        for (j in seq_along(genes)) {
            clusters <- geneEvents[geneEvents$Var1 == genes[j], ]

            altIso <- alternativeIntronUsage(
                leafcutterEvents[
                    leafcutterEvents$clusterID == clusters$Var2[1],
                ],
                exons
            )

            if (nrow(clusters) > 1) {
                for (i in 2:nrow(clusters)) {
                    altIntronLocs <- leafcutterEvents[
                        leafcutterEvents$clusterID == clusters$Var2[i],
                    ]
                    altIntronLocs <- altIntronLocs[altIntronLocs$verdict ==
                        "annotated", ]
                    if (nrow(altIntronLocs) > 1) {
                        altIso1 <- alternativeIntronUsage(
                            altIntronLocs,
                            c(exons, altIso)
                        )
                        altIso <- c(altIso, altIso1)
                    }
                }
            }
            if (showProgressBar) {
                utils::setTxtProgressBar(pb, j)
            }
        }
    }
    if (is.list(altIso)) {
        if (length(altIso) > 1) {
            altIso <- do.call("c", altIso)
        }
    }

    altIso$spliced_id <- unlist(lapply(
        stringr::str_split(altIso$transcript_id, " "), "[[", 2
    ))

    transcriptsX <- altIso[grep("dnre", altIso$transcript_id)]
    transcriptsY <- altIso[grep("upre", altIso$transcript_id)]

    if (!is.null(exportGTF)) {
        rtracklayer::export.gff(altIso, con = exportGTF, format = "gtf")
    }

    orfDiff <- transcriptChangeSummary(transcriptsX,
        transcriptsY,
        BSgenome = BSgenome,
        NMD = NMD
    )
    m <- match(gsub("_", "", leafcutterEvents$clusterID), orfDiff$id)
    leafcutterEvents.withORF <- cbind(leafcutterEvents, orfDiff[m, -1])
    # leafcutterEvents.withORF <- leafcutterEvents.withORF[!duplicated(m),]

    return(leafcutterEvents.withORF)
}
