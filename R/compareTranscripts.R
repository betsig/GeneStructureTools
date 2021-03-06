#' Evaluate changes to ORFs caused by alternative splicing
#' @param orfsX orf information for 'normal' transcripts. Generated by getOrfs()
#' @param orfsY orf information for 'alternative' transcripts. Generated by getOrfs()
#' @param filterNMD filter orf information for transcripts not targeted by nmd first?
#' @param geneSimilarity compare orf to all orfs in gene?
#' @param compareUTR compare UTRs?
#' @param compareBy compare by 'transcript' isoforms or by 'gene' groups
#' @param allORFs orf information for all transcripts for novel sequence comparisons.
#' Generated by getOrfs()
#' @param uniprotData data.frame of uniprot sequence information
#' @param uniprotSeqFeatures data.frame of uniprot sequecne features
#' @return data.frame with orf changes
#' @export
#' @import stringr
#' @importFrom rtracklayer import
#' @importFrom stats aggregate
#' @family transcript isoform comparisons
#' @author Beth Signal
#' @examples
#'
#' gtf <- rtracklayer::import(system.file("extdata", "gencode.vM25.small.gtf", package = "GeneStructureTools"))
#' exons <- gtf[gtf$type == "exon"]
#' g <- BSgenome.Mmusculus.UCSC.mm10::BSgenome.Mmusculus.UCSC.mm10
#'
#' whippetFiles <- system.file("extdata", "whippet_small/",
#'     package = "GeneStructureTools"
#' )
#' wds <- readWhippetDataSet(whippetFiles)
#'
#' wds.exonSkip <- filterWhippetEvents(wds, eventTypes = "CE", psiDelta = 0.2)
#' exons.exonSkip <- findExonContainingTranscripts(wds.exonSkip, exons,
#'     variableWidth = 0, findIntrons = FALSE
#' )
#' ExonSkippingTranscripts <- skipExonInTranscript(exons.exonSkip, exons, whippetDataSet = wds.exonSkip)
#'
#' orfsSkipped <- getOrfs(ExonSkippingTranscripts[ExonSkippingTranscripts$set == "skipped_exon"],
#'     BSgenome = g
#' )
#' orfsIncluded <- getOrfs(ExonSkippingTranscripts[ExonSkippingTranscripts$set == "included_exon"],
#'     BSgenome = g
#' )
#' orfDiff(orfsSkipped, orfsIncluded, filterNMD = FALSE)
#'
#' orfsProteinCoding <- getOrfs(exons[exons$gene_name == "Tmem208" &
#'     exons$transcript_type == "protein_coding"], BSgenome = g)
#' orfsNMD <- getOrfs(exons[exons$gene_name == "Tmem208" &
#'     exons$transcript_type == "nonsense_mediated_decay"], BSgenome = g)
#' orfDiff(orfsProteinCoding, orfsNMD, filterNMD = FALSE)
orfDiff <- function(orfsX,
                    orfsY,
                    filterNMD = TRUE,
                    geneSimilarity = TRUE,
                    compareUTR = TRUE,
                    compareBy = "gene",
                    allORFs = NULL,
                    uniprotData = NULL,
                    uniprotSeqFeatures = NULL) {
    if (filterNMD == TRUE) {
        orfChanges <- attrChangeAltSpliced(orfsX[which(orfsX$nmd_prob_manual < 0.5), ],
            orfsY[which(orfsY$nmd_prob_manual < 0.5), ],
            attribute = "orf_length",
            compareBy = compareBy,
            useMax = TRUE,
            compareUTR = compareUTR
        )

        orfChanges.filterx <- attrChangeAltSpliced(
            orfsX[which(orfsX$nmd_prob_manual < 0.5), ],
            orfsY,
            attribute = "orf_length",
            compareBy = compareBy,
            useMax = TRUE,
            compareUTR = compareUTR
        )
        orfChanges.filtery <-
            attrChangeAltSpliced(orfsX,
                orfsY[which(orfsY$nmd_prob_manual < 0.5), ],
                attribute = "orf_length",
                compareBy = compareBy,
                useMax = TRUE,
                compareUTR = compareUTR
            )

        orfChanges.nofilter <-
            attrChangeAltSpliced(orfsX,
                orfsY,
                attribute = "orf_length",
                compareBy = compareBy,
                useMax = TRUE,
                compareUTR = compareUTR
            )

        if (nrow(orfChanges) > 0) {
            orfChanges$filtered <- "both"
        }
        if (nrow(orfChanges.filterx) > 0) {
            orfChanges.filterx$filtered <- "x"
        }
        if (nrow(orfChanges.filtery) > 0) {
            orfChanges.filtery$filtered <- "y"
        }
        if (nrow(orfChanges.nofilter) > 0) {
            orfChanges.nofilter$filtered <- "none"
        }
        add <- which(!(orfChanges.filterx$id %in% orfChanges$id))
        orfChanges <- rbind(orfChanges, orfChanges.filterx[add, ])
        add <- which(!(orfChanges.filtery$id %in% orfChanges$id))
        orfChanges <- rbind(orfChanges, orfChanges.filtery[add, ])
        add <- which(!(orfChanges.nofilter$id %in% orfChanges$id))
        orfChanges <- rbind(orfChanges, orfChanges.nofilter[add, ])
    } else {
        orfChanges <- attrChangeAltSpliced(orfsX, orfsY,
            attribute = "orf_length",
            compareBy = compareBy, useMax = TRUE,
            compareUTR = compareUTR
        )
        orfChanges$filtered <- FALSE
    }

    hasASidX <- grep("AS", orfsX$id)
    hasLeafIdX <- grep("dnre_", orfsX$id)
    orfsX$spliced_id <- orfsX$gene_id
    orfsX$transcript_id <- orfsX$id
    orfsX$spliced_id[hasASidX] <-
        unlist(lapply(str_split(orfsX$id[hasASidX], " "), "[[", 2))
    orfsX$transcript_id[hasASidX] <-
        unlist(lapply(str_split(orfsX$id[hasASidX], "[+]"), "[[", 1))
    orfsX$spliced_id[hasLeafIdX] <- gsub(
        "dnre_", "",
        orfsX$spliced_id[hasLeafIdX]
    )
    orfsX$spliced_id[hasLeafIdX] <-
        stringr::str_sub(gsub(
            "\\-[^]]\\:*", ":",
            paste0(gsub("[+-][-]", "-", orfsX$spliced_id[hasLeafIdX]), ":")
        ), 1, -2)
    hasASidY <- grep("AS", orfsY$id)
    hasLeafIdY <- grep("upre_", orfsY$id)
    orfsY$spliced_id <- orfsY$gene_id
    orfsY$transcript_id <- orfsY$id
    orfsY$spliced_id[hasASidY] <-
        unlist(lapply(str_split(orfsY$id[hasASidY], " "), "[[", 2))
    orfsY$transcript_id[hasASidY] <-
        unlist(lapply(str_split(orfsY$id[hasASidY], "[+]"), "[[", 1))
    orfsY$spliced_id[hasLeafIdY] <- gsub(
        "upre_", "",
        orfsY$spliced_id[hasLeafIdY]
    )
    orfsY$spliced_id[hasLeafIdY] <-
        stringr::str_sub(gsub(
            "\\-[^]]\\:*", ":",
            paste0(gsub("[+-][-]", "-", orfsY$spliced_id[hasLeafIdY]), ":")
        ), 1, -2)


    m <- match(
        paste0(orfsX$spliced_id, "_", orfsX$frame),
        paste0(orfsY$spliced_id, "_", orfsY$frame)
    )
    # check that there are matches if we ignore the frame (i.e 5'utr frame-shifts)
    m.noFrame <- match(paste0(orfsX$spliced_id), paste0(orfsY$spliced_id))
    m[which(is.na(m))] <- m.noFrame[which(is.na(m))]
    if (any(is.na(m))) {
        if (!(any(grepl("clu", orfsX$id)) | any(grepl("clu", orfsY$id)))) {
            # hasASidX <- grep("[+]", orfsX$id)
            if (length(hasASidX) > 0) {
                m2 <- match(
                    paste0(
                        orfsX$transcript_id[hasASidX], "_",
                        orfsX$frame[hasASidX]
                    ),
                    paste0(orfsY$transcript_id, "_", orfsY$frame)
                )
                orfsY2 <- orfsY[m2, ]
                orfsY2$id <- orfsX$id[hasASidX]
                orfsY2$spliced_id <- orfsX$spliced_id[hasASidX]
                orfsY <- rbind(orfsY, orfsY2)
            }
            # hasASidY <- grep("[+]", orfsY$id)
            if (length(hasASidY) > 0) {
                m2 <- match(
                    paste0(
                        orfsY$transcript_id[hasASidY], "_",
                        orfsY$frame[hasASidY]
                    ),
                    paste0(orfsX$transcript_id, "_", orfsX$frame)
                )
                orfsX2 <- orfsX[m2, ]
                orfsX2$id <- orfsY$id[hasASidY]
                orfsX2$spliced_id <- orfsY$spliced_id[hasASidY]
                orfsX <- rbind(orfsX, orfsX2)
            }

            if (length(hasASidY) == 0 & length(hasASidX) == 0) {
                attributeX$id <- attributeX$gene_id
                attributeY$id <- attributeY$gene_id
            } else {
                m2 <- match(
                    paste0(orfsX$spliced_id, "_", orfsX$frame),
                    paste0(orfsY$spliced_id, "_", orfsY$frame)
                )
                orfsX <- orfsX[which(!is.na(m2)), ]
                orfsY <- orfsY[m2[which(!is.na(m2))], ]
            }
        }
    }

    orfsY$id_with_len <- paste0(orfsY$spliced_id, "_", orfsY$orf_length)
    orfChanges$id_orf_length_y <- paste0(
        orfChanges$id, "_",
        orfChanges$orf_length_y
    )
    my <- match(orfChanges$id_orf_length_y, orfsY$id_with_len)

    orfsX$id_with_len <- paste0(orfsX$spliced_id, "_", orfsX$orf_length)
    orfChanges$id_orf_length_x <- paste0(
        orfChanges$id, "_",
        orfChanges$orf_length_x
    )
    mx <- match(orfChanges$id_orf_length_x, orfsX$id_with_len)

    x <- as.numeric(mapply(
        function(x, y) orfSimilarity(x, y),
        orfsX$orf_sequence[mx],
        orfsY$orf_sequence[my]
    ))

    orfChanges$percent_orf_shared <- x

    maxLength <- apply(orfChanges[, c(
        "orf_length_y",
        "orf_length_x"
    )], 1, max)

    orfChanges$max_percent_orf_shared <-
        (maxLength - abs(orfChanges$orf_length_x -
            orfChanges$orf_length_y)) / maxLength

    orfLengthShared <- orfChanges$percent_orf_shared * maxLength

    orfChanges$orf_percent_kept_x <- orfLengthShared /
        orfChanges$orf_length_x
    orfChanges$orf_percent_kept_y <- orfLengthShared /
        orfChanges$orf_length_y


    if (geneSimilarity == TRUE & !is.null(allORFs)) {
        orfChanges$gene_id <- orfsX$gene_id[match(
            orfChanges$id,
            orfsX$spliced_id
        )]

        keep.allORFs <- which(allORFs$gene_id %in% orfChanges$gene_id)
        allORFs <- allORFs[keep.allORFs, ]

        geneMatches <- lapply(
            orfChanges$gene_id,
            function(x) {
                  which(!is.na(match(allORFs$gene_id, x)))
              }
        )

        idMatches <- unlist(mapply(
            function(x, y) {
                  rep(x, length(y))
              }, (seq_along(length(orfChanges$gene_id))),
            geneMatches
        ))

        geneMatches <- unlist(geneMatches)

        idMatches.y <- match(
            orfChanges$id_orf_length_y[idMatches],
            orfsY$id_with_len
        )
        idMatches.x <- match(
            orfChanges$id_orf_length_x[idMatches],
            orfsX$id_with_len
        )

        orfSimBygene.y <- as.numeric(mapply(
            function(x, y) orfSimilarity(x, y),
            allORFs$orf_sequence[geneMatches],
            orfsY$orf_sequence[idMatches.y]
        ))

        orfSimBygene.x <- as.numeric(mapply(
            function(x, y) orfSimilarity(x, y),
            allORFs$orf_sequence[geneMatches],
            orfsX$orf_sequence[idMatches.x]
        ))

        orfSimilarity.bygene <-
            data.frame(
                gene_id = allORFs$gene_id[geneMatches],
                spliced_id_x = orfsX$spliced_id[idMatches.x],
                spliced_id_y = orfsY$spliced_id[idMatches.y],
                similarity_x = orfSimBygene.x,
                similarity_y = orfSimBygene.y,
                length_gene = allORFs$orf_length[geneMatches],
                length_x = orfsX$orf_length[idMatches.x],
                length_y = orfsY$orf_length[idMatches.y]
            )

        orfSimilarity.bygeneAggX <- aggregate(
            similarity_x ~ spliced_id_x,
            orfSimilarity.bygene, max
        )
        orfSimilarity.bygeneAggY <- aggregate(
            similarity_y ~ spliced_id_y,
            orfSimilarity.bygene, max
        )

        orfChanges$gene_similarity_x <-
            orfSimilarity.bygeneAggX$similarity_x[
                match(orfChanges$id, orfSimilarity.bygeneAggX$spliced_id_x)
            ]
        orfChanges$gene_similarity_y <-
            orfSimilarity.bygeneAggY$similarity_y[
                match(orfChanges$id, orfSimilarity.bygeneAggY$spliced_id_y)
            ]
    }

    if (!is.null(uniprotData) & !is.null(uniprotSeqFeatures)) {

        # make subsets of uniprot data for faster processing
        index <- uniprotData$ens_gene_id %in% c(
            removeVersion(orfsX$gene_id[match(
                paste0(
                    orfChanges$id, "_",
                    orfChanges$orf_length_x
                ),
                orfsX$id_with_len
            )]),
            removeVersion(orfsY$gene_id[match(
                paste0(
                    orfChanges$id, "_",
                    orfChanges$orf_length_y
                ),
                orfsY$id_with_len
            )])
        )
        seqFeats.sub <- uniprotSeqFeatures[uniprotSeqFeatures$prot_id %in%
            uniprotData$id[index], ]
        m <- match(seqFeats.sub$prot_id, uniprotData$id)
        seqFeats.sub$gene_id <- uniprotData$ens_gene_id[m]

        # find all features in the ORF sequences
        orfsX2 <- orfsX[match(paste0(orfChanges$id, "_", orfChanges$orf_length_x), orfsX$id_with_len), ]
        orfXContains <- apply(orfsX2[, c("orf_sequence", "gene_id")], 1, function(x) featureTypes(seqFeats.sub, x))

        orfsY2 <- orfsY[match(paste0(orfChanges$id, "_", orfChanges$orf_length_y), orfsY$id_with_len), ]
        orfYContains <- apply(orfsY2[, c("orf_sequence", "gene_id")], 1, function(x) featureTypes(seqFeats.sub, x))

        contains <- data.frame(x = orfXContains, y = orfYContains)
        # compare orfsX and orfsY
        comp <- t(apply(contains, 1, compareContains))

        orfChanges$domains_only_in_x <- comp[, 1]
        orfChanges$domains_only_in_y <- comp[, 2]
    }

    orfChanges$transcript_id <- NULL
    orfChanges$gene_id <- NULL
    orfChanges$id_orf_length_x <- NULL
    orfChanges$id_orf_length_y <- NULL

    return(orfChanges)
}

#' compare two strings of concatenated sequence features
#' @param contains orf vector of two concatenated sequence features strings
#' @return data.frame with orf changes
#' @keywords internal
#' @import stringr
#' @author Beth Signal
compareContains <- function(contains) {
    uX <- unique(unlist(stringr::str_split(contains[1], ";")))
    uY <- unique(unlist(stringr::str_split(contains[2], ";")))
    uXvals <- paste(uX[!uX %in% uY], collapse = ";")
    uYvals <- paste(uY[!uY %in% uX], collapse = ";")

    return(c(uXvals, uYvals))
}

#' Evaluate changes to ORFs caused by alternative splicing
#' @param seqFeatures data.frame of uniprot sequence features
#' @param orf vector with open reading frame (amino acid sequence) string and gene_id
#' @return data.frame with orf changes
#' @keywords internal
#' @author Beth Signal
featureTypes <- function(seqFeatures, orf) {
    m <- which(seqFeatures$gene_id %in% removeVersion(orf[2]))
    if (length(m) > 0) {
        seqFeatures <- seqFeatures[m, ]
        seqFeatures <- seqFeatures[!seqFeatures$feature_class %in%
            c("MOD_RES", "CONFLICT", "VAR_SEQ", "VARIANT"), ]

        features <- paste(apply(
            seqFeatures[which(unlist(lapply(
                seqFeatures$aa_seq, function(x) !grepl(x, orf[1], fixed = TRUE)
            ))), ],
            1, function(x) paste0(x[3], ":", x[4], "-", x[5])
        ), collapse = ";")
        features <- gsub("  *", "", features)
        return(features)
    } else {
        return(NA)
    }
}


#' Evaluate the change in an attribute between a set of 'normal' transcripts and
#' 'alternative' transcripts
#' @param orfsX orf information for 'normal' transcripts. Generated by getOrfs()
#' @param orfsY orf information for 'alternative' transcripts. Generated by getOrfs()
#' @param attribute attribute to compare
#' @param compareBy compare by 'transcript' isoforms or by 'gene' groups
#' @param useMax use max as the summary function when multiple isoforms are aggregated?
#' If FALSE, will use min instead.
#' @param compareUTR compare the UTR lengths between transcripts?
#' Only runs if attribute="orf_length"
#' @return data.frame with attribute changes
#' @export
#' @import stringr
#' @importFrom rtracklayer import
#' @importFrom stats aggregate
#' @family transcript isoform comparisons
#' @author Beth Signal
#' @examples
#' gtf <- rtracklayer::import(system.file("extdata", "gencode.vM25.small.gtf", package = "GeneStructureTools"))
#' exons <- gtf[gtf$type == "exon"]
#' g <- BSgenome.Mmusculus.UCSC.mm10::BSgenome.Mmusculus.UCSC.mm10
#'
#' whippetFiles <- system.file("extdata", "whippet_small/",
#'     package = "GeneStructureTools"
#' )
#' wds <- readWhippetDataSet(whippetFiles)
#'
#' wds.exonSkip <- filterWhippetEvents(wds, eventTypes = "CE", psiDelta = 0.2)
#' exons.exonSkip <- findExonContainingTranscripts(wds.exonSkip, exons,
#'     variableWidth = 0, findIntrons = FALSE
#' )
#' ExonSkippingTranscripts <- skipExonInTranscript(exons.exonSkip, exons, whippetDataSet = wds.exonSkip)
#'
#' orfsSkipped <- getOrfs(ExonSkippingTranscripts[ExonSkippingTranscripts$set == "skipped_exon"],
#'     BSgenome = g
#' )
#' orfsIncluded <- getOrfs(ExonSkippingTranscripts[ExonSkippingTranscripts$set == "included_exon"],
#'     BSgenome = g
#' )
#' attrChangeAltSpliced(orfsSkipped, orfsIncluded, attribute = "orf_length")
attrChangeAltSpliced <- function(orfsX,
                                 orfsY,
                                 attribute = "orf_length",
                                 compareBy = "gene",
                                 useMax = TRUE,
                                 compareUTR = FALSE) {
    if (nrow(orfsX) > 0 & nrow(orfsY) > 0) {
        if (useMax) {
            aggFun <- max
        } else {
            aggFun <- min
        }

        # fix ids so spliced isoforms have same id
        if (all(grepl("[+]", c(orfsX$id, orfsY$id)))) {
            asTypes <- unique(unlist(lapply(
                stringr::str_split(
                    lapply(stringr::str_split(
                        c(orfsX$id, orfsY$id), "[+]"
                    ), "[[", 2), " "
                ),
                "[[", 1
            )))

            for (asT in asTypes) {
                orfsX$id <- gsub(asT, "AS", orfsX$id)
                orfsY$id <- gsub(asT, "AS", orfsY$id)
            }
        }

        m <- match(c("id", "gene_id", attribute), colnames(orfsX))

        orfsX.part <- orfsX[, m]

        attributeX <- aggregate(. ~ id + gene_id, orfsX.part, aggFun)

        hasASidX <- grep("AS", attributeX$id)
        attributeX$as_group <- attributeX$gene_id
        attributeX$transcript_id <- attributeX$id

        hasLeafIdX <- grep("dnre_", attributeX$id)
        attributeX$id[hasLeafIdX] <-
            gsub("dnre_", "", attributeX$id[hasLeafIdX])
        attributeX$id[hasLeafIdX] <- stringr::str_sub(gsub("\\-[^]]\\:*", ":", paste0(gsub("[+-][-]", "-", attributeX$id[hasLeafIdX]), ":")), 1, -2)
        attributeX$as_group[hasASidX] <-
            unlist(lapply(str_split(attributeX$id[hasASidX], " "), "[[", 2))

        attributeX$transcript_id[hasASidX] <-
            unlist(lapply(str_split(attributeX$id[hasASidX], "[+]"), "[[", 1))

        m <- match(c("id", "gene_id", attribute), colnames(orfsY))
        orfsY.part <- orfsY[, m]
        attributeY <- aggregate(. ~ id + gene_id, orfsY.part, aggFun)

        hasASidY <- grep("AS", attributeY$id)
        attributeY$as_group <- attributeY$gene_id
        attributeY$transcript_id <- attributeY$id

        hasLeafIdY <- grep("upre_", attributeY$id)
        attributeY$id[hasLeafIdY] <-
            gsub("upre_", "", attributeY$id[hasLeafIdY])
        attributeY$id[hasLeafIdY] <- stringr::str_sub(gsub("\\-[^]]\\:*", ":", paste0(gsub("[+-][-]", "-", attributeY$id[hasLeafIdY]), ":")), 1, -2)

        attributeY$as_group[hasASidY] <-
            unlist(lapply(str_split(attributeY$id[hasASidY], " "), "[[", 2))

        attributeY$transcript_id[hasASidY] <-
            unlist(lapply(str_split(attributeY$id[hasASidY], "[+]"), "[[", 1))

        m <- match(attributeX$id, attributeY$id)
        if (any(is.na(m))) {
            # hasASidX <- grep("[+]", attributeX$id)
            # if isoforms are not generated by leafcutter
            if (!(any(grepl("clu", attributeX$id)) |
                any(grepl("clu", attributeY$id)))) {
                if (length(hasASidX) > 0) {
                    m2 <- match(
                        attributeX$transcript_id[hasASidX],
                        attributeY$transcript_id
                    )
                    attributeY2 <- attributeY[m2, ]
                    attributeY2$id <- attributeX$id[hasASidX]
                    attributeY2$as_group <- attributeX$as_group[hasASidX]
                    attributeY <- rbind(attributeY, attributeY2)
                }
                # hasASidY <- grep("[+]", attributeY$id)
                if (length(hasASidY) > 0) {
                    m2 <- match(
                        attributeY$transcript_id[hasASidY],
                        attributeX$transcript_id
                    )
                    attributeX2 <- attributeX[m2, ]
                    attributeX2$id <- attributeY$id[hasASidY]
                    attributeX2$as_group <- attributeY$as_group[hasASidY]
                    attributeX <- rbind(attributeX, attributeX2)
                }
                if (length(hasASidY) == 0 & length(hasASidX) == 0) {
                    attributeX$id <- attributeX$gene_id
                    attributeY$id <- attributeY$gene_id
                } else {
                    m2 <- match(attributeX$id, attributeY$id)
                    attributeX <- attributeX[which(!is.na(m2)), ]
                    attributeY <- attributeY[m2[which(!is.na(m2))], ]
                    m <- match(attributeX$id, attributeY$id)
                }
            }
        }

        colnames(attributeX)[3] <- "attr"
        colnames(attributeY)[3] <- "attr"

        if (compareBy == "transcript") {
            m <- match(attributeX$id, attributeY$id)
            attributeComparisons <-
                data.frame(
                    id = attributeX$id,
                    attr_x = attributeX$attr,
                    attr_y = attributeY$attr[m]
                )

            m <- match(attributeY$id, attributeX$id)
            attributeComparisonsY <-
                data.frame(
                    id = attributeY$id,
                    attr_x = attributeX$attr[m],
                    attr_y = attributeY$attr
                )

            add <-
                which(!(attributeComparisonsY$id %in% attributeComparisons$id))

            if (length(add) > 0) {
                attributeComparisons <-
                    rbind(attributeComparisons, attributeComparisonsY[add, ])
            }
        } else if (compareBy == "gene") {
            attributeX2 <- aggregate(attr ~ as_group, attributeX, aggFun)
            attributeY2 <- aggregate(attr ~ as_group, attributeY, aggFun)

            m <- match(attributeX2$as_group, attributeY2$as_group)
            attributeComparisons <- data.frame(
                id = attributeX2[, 1],
                attr_x = attributeX2[, -1],
                attr_y = attributeY2[m, -1]
            )
            attributeComparisons <- attributeComparisons[which(!is.na(m)), ]
        }
        colnames(attributeComparisons) <- gsub(
            "attr",
            attribute,
            colnames(attributeComparisons)
        )

        if (compareUTR == TRUE & attribute == "orf_length") {
            if (nrow(attributeComparisons) > 0) {
                if (all(grepl("AS", orfsX$id))) {
                    id.x <- paste0(
                        attributeComparisons$id, "_",
                        attributeComparisons$orf_length_x
                    )

                    hasLeafIdX <- grep("dnre_", orfsX$id)
                    orfsXid <- orfsX$id
                    orfsXid[hasLeafIdX] <-
                        stringr::str_sub(
                            gsub(
                                "\\-[^]]\\:*", ":",
                                paste0(gsub("[+-][-]", "-", orfsXid[hasLeafIdX]), ":")
                            ),
                            1, -2
                        )

                    orfsXid[hasLeafIdX] <- gsub("dnre_", "", orfsXid[hasLeafIdX])

                    if (compareBy == "gene") {
                        orfsXid <- unlist(lapply(str_split(orfsXid, " "), "[[", 2))
                        m1 <- match(id.x, paste0(
                            orfsXid,
                            "_", orfsX$orf_length
                        ))
                    } else {
                        m1 <- match(id.x, paste0(orfsXid, "_", orfsX$orf_length))
                    }
                } else {
                    matchToGene <- match(
                        attributeComparisons$id,
                        attributeX$as_group
                    )
                    id.x <- paste0(
                        unlist(lapply(str_split(
                            attributeX$id[matchToGene], "[+]"
                        ), "[[", 1)), "_",
                        attributeComparisons$orf_length_x
                    )
                    m1 <- match(id.x, paste0(
                        (orfsX$gene_id), "_",
                        orfsX$orf_length
                    ))
                }

                if (all(grepl("AS", orfsY$id))) {
                    id.y <- paste0(
                        attributeComparisons$id, "_",
                        attributeComparisons$orf_length_y
                    )

                    hasLeafIdY <- grep("upre_", orfsY$id)
                    orfsYid <- orfsY$id
                    orfsYid[hasLeafIdY] <-
                        stringr::str_sub(
                            gsub(
                                "\\-[^]]\\:*", ":",
                                paste0(gsub("[+-][-]", "-", orfsYid[hasLeafIdY]), ":")
                            ),
                            1, -2
                        )
                    orfsYid[hasLeafIdY] <- gsub("upre_", "", orfsYid[hasLeafIdY])

                    if (compareBy == "gene") {
                        orfsYid <- unlist(lapply(str_split(orfsYid, " "), "[[", 2))
                        m2 <- match(id.y, paste0(
                            orfsYid,
                            "_", orfsY$orf_length
                        ))
                    } else {
                        m2 <- match(id.y, paste0(orfsYid, "_", orfsY$orf_length))
                    }
                } else {
                    matchToGene <- match(
                        attributeComparisons$id,
                        attributeY$as_group
                    )
                    id.y <- paste0(
                        unlist(lapply(str_split(
                            attributeY$id[matchToGene], "[+]"
                        ), "[[", 1)), "_",
                        attributeComparisons$orf_length_y
                    )
                    m2 <- match(id.y, paste0((orfsY$gene_id), "_", orfsY$orf_length))
                }

                attributeComparisons$utr3_length_x <- orfsX$utr3_length[m1]
                attributeComparisons$utr3_length_y <- orfsY$utr3_length[m2]
                attributeComparisons$utr5_length_x <-
                    orfsX$start_site_nt[m1]
                attributeComparisons$utr5_length_y <-
                    orfsY$start_site_nt[m2]
            } else {
                attributeComparisons$utr3_length_x <- numeric(0)
                attributeComparisons$utr3_length_y <- numeric(0)
                attributeComparisons$utr5_length_x <- numeric(0)
                attributeComparisons$utr5_length_y <- numeric(0)
            }
        }

        return(attributeComparisons)
    } else {
        blank <- data.frame(
            id = character(0),
            attr_x = numeric(0),
            attr_y = numeric(0)
        )
        colnames(blank) <- gsub("attr", attribute, colnames(blank))
        if (compareUTR == TRUE) {
            blank$utr3_length_x <- numeric(0)
            blank$utr3_length_y <- numeric(0)
            blank$utr5_length_x <- numeric(0)
            blank$utr5_length_y <- numeric(0)
        }
        return(blank)
    }
}
#' calculate percentage of orfB contained in orfA
#' @param orfA character string of ORF amino acid sequence
#' @param orfB character string of ORF amino acid sequence
#' @param substitutionCost cost for substitutions in ORF sequences.
#' Set to 1 if substitutions should be weighted equally to insertions and deletions.
#' @return percentage of orfB contained in orfA
#' @export
#' @import stringdist
#' @import stringr
#' @importFrom utils adist
#' @family ORF annotation
#' @author Beth Signal
#' @examples
#' orfSimilarity("MFGLDIYAGTRSSFRQFSLT", "MFGLDIYAGTRSSFRQFSLT")
#' orfSimilarity("MFGLDIYAGTRSSFRQFSLT", "MFGLDIYAFRQFSLT")
#' orfSimilarity("MFGLDIYAFRQFSLT", "MFGLDIYAGTRSSFRQFSLT")
#' orfSimilarity("MFGLDIYAGTRXXFRQFSLT", "MFGLDIYAGTRSSFRQFSLT")
#' orfSimilarity("MFGLDIYAGTRXXFSLT", "MFGLDIYAGTRSSFRQFSLT", 1)
orfSimilarity <- function(orfA, orfB, substitutionCost = 100) {
    if (is.na(orfA) | is.na(orfB)) {
        return(NA)
    } else {
        if (nchar(orfA) > nchar(orfB)) {
            lcs <- utils::adist(orfA, orfB,
                costs = list(
                    ins = 100,
                    del = 1,
                    sub = substitutionCost
                )
            )[1, 1]
        } else if (nchar(orfA) == nchar(orfB)) {
            lcs <- utils::adist(orfA, orfB,
                costs = list(
                    ins = 1,
                    del = 1,
                    sub = substitutionCost
                )
            )[1, 1]
        } else {
            lcs <- utils::adist(orfA, orfB,
                costs = list(
                    ins = 1,
                    del = 100,
                    sub = substitutionCost
                )
            )[1, 1]
        }

        if (lcs <= nchar(orfA) + nchar(orfB)) {
            return(((nchar(orfA) + nchar(orfB) - lcs) / 2) /
                max(nchar(orfA), nchar(orfB)))
        } else {
            return(0)
        }
    }
}
