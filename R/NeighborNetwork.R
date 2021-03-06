#' Neighbor network analysis.
#'
#' @param peptideSet A set of peptide sequences.
#' @param longerPeptideSet A set of peptide sequences. Should be one amino acid longer than \code{shorterPeptideSet}.
#' @param shorterPeptideSet A set of peptide sequences. Should be one amino acid shorter than \code{longerPeptideSet}.
#' @param numSet An attribute for the vertices.
#' @param directed Should the network be converted from undirected to directed? Directions are determined using the \code{numSet} provided.
#' @param weighted Should the network be converted to weihted? Edge weights are determined using the \code{numSet} provided.
#' @export
#' @rdname NeighborNetwork
#' @name NeighborNetwork
distMat_Sbst <- function(peptideSet){
  # Input check...
  if(class(peptideSet)!="AAStringSet"){
    peptideSet <- Biostrings::AAStringSet(peptideSet)
  }
  if(length(unique(S4Vectors::nchar(peptideSet)))>=2){
    message("Input sequences must be of the same length!")
    return(NULL)
  }

  sequenceSet <- as.character(peptideSet)
  DistMat.auto <- Matrix::sparseMatrix(c(), c(), x=F, dims=c(length(peptideSet), length(peptideSet)))
  pbQ <- length(peptideSet)>1000
  if(pbQ){
    pb <- pbapply::timerProgressBar(min=1, max=length(peptideSet), char="+", style=1)
    for(i in 1:length(peptideSet)){
      pbapply::setTimerProgressBar(pb, i)
      DistMat.auto[i, 1:i] <- stringdist::stringdist(sequenceSet[[i]], peptideSet[1:i], method="hamming")<=1
    }
    cat("\n")
  }else{
    for(i in 1:length(peptideSet)){
      DistMat.auto[i, 1:i] <- stringdist::stringdist(sequenceSet[[i]], peptideSet[1:i], method="hamming")<=1
    }
  }
  diag(DistMat.auto) <- F
  return(DistMat.auto)  # An m x m triangular matrix: m = length(peptideSet)
}
#' @export
#' @rdname NeighborNetwork
#' @name NeighborNetwork
distMat_Indel <- function(longerPeptideSet, shorterPeptideSet){
  # Input check...
  if(class(longerPeptideSet)!="AAStringSet"){
    longerPeptideSet <- Biostrings::AAStringSet(longerPeptideSet)
  }
  if(class(shorterPeptideSet)!="AAStringSet"){
    shorterPeptideSet <- Biostrings::AAStringSet(shorterPeptideSet)
  }
  longerSeq <- as.character(longerPeptideSet)
  shorterSeq <- as.character(shorterPeptideSet)
  leng_longer <- unique(nchar(longerSeq))
  leng_shorter <- unique(nchar(shorterSeq))
  if(length(leng_longer)>=2){
    message("Input longer sequences must be of the same length!")
    return(NULL)
  }
  if(length(leng_shorter)>=2){
    message("Input shorter sequences must be of the same length!")
    return(NULL)
  }
  if(leng_longer<=leng_shorter){
    message("The longer sequences must be one amino acid longer than the shorter sequences!")
    return(NULL)
  }
  if(leng_longer-leng_shorter>=2){
    message("The length difference between longer and shorter sequences must be one amino acid!")
    return(NULL)
  }

  longerSeq.degenerate <- unlist(lapply(1:leng_longer, function(i){seq <- longerSeq; stringr::str_sub(seq, i, i) <- ""; return(seq)}))
  longerSeq.degenerate <- matrix(longerSeq.degenerate, ncol=leng_longer)
  DistMat.juxt <- Matrix::sparseMatrix(c(), c(), x=F, dims=c(length(shorterPeptideSet), length(longerPeptideSet)))
  pbQ <- length(shorterPeptideSet)>1000
  if(pbQ){
    pb <- pbapply::timerProgressBar(min=1, max=length(shorterPeptideSet), char="+", style=1)
    for(i in 1:length(shorterPeptideSet)){
      pbapply::setTimerProgressBar(pb, i)
      DistMat.juxt[i,] <- rowSums(longerSeq.degenerate==shorterSeq[[i]])!=0
    }
    cat("\n")
  }else{
    for(i in 1:length(shorterPeptideSet)){
      DistMat.juxt[i,] <- rowSums(longerSeq.degenerate==shorterSeq[[i]])!=0
    }
  }
  DistMat.juxt <- Matrix::t(DistMat.juxt)
  return(DistMat.juxt) # An m x n matrix: m = length(longerPeptideSet), n = length(shorterPeptideSet)
}
#' @export
#' @rdname NeighborNetwork
#' @name NeighborNetwork
neighborNetwork <- function(peptideSet, numSet=NULL, directed=T, weighted=T){
  # Internally used workflows
  net_main <- function(peptideSet){
    ## Input check...
    if(class(peptideSet)!="AAStringSet"){
      peptideSet <- Biostrings::AAStringSet(peptideSet)
    }
    if(length(unique(peptideSet))!=length(peptideSet)){
      message("Duplicates are removed from the input sequences.")
      peptideSet <- unique(peptideSet)
    }

    ## Serialized adjacency matrix calculation
    peptideSetList <- split(peptideSet, S4Vectors::nchar(peptideSet))
    if(length(names(peptideSetList))>=2){
      sequenceLengthPairGrid <- suppressWarnings(dplyr::bind_rows(
        data.frame(V1=names(peptideSetList), V2=names(peptideSetList), Type="Sbst"),
        data.frame(as.data.frame(t(combn(names(peptideSetList), 2))), Type="Indel")
      )) %>% dplyr::rename(V2="V1", V1="V2") %>% dplyr::select(V1, V2, Type)
    }else{
      sequenceLengthPairGrid <- data.frame(V1=names(peptideSetList), V2=names(peptideSetList), Type="Sbst")
    }
    sequenceLengthPairGrid <- sequenceLengthPairGrid %>%
      dplyr::filter((as.numeric(V1)-as.numeric(V2)) %in% c(0, 1)) ## V1>=V2
    sequenceLengthPairN <- nrow(sequenceLengthPairGrid)

    ends <- as.numeric(cumsum(table(S4Vectors::nchar(peptideSet))))
    starts <- (c(0, ends)+1)[1:length(ends)]
    positionGrid <- as.data.frame(t(data.frame(starts, ends)))
    colnames(positionGrid) <- names(peptideSetList)

    DistMat <- Matrix::sparseMatrix(c(), c(), x=F, dims=rep(length(peptideSet), 2))

    message(paste0("Number of sequence length pairs = ", sequenceLengthPairN))
    for(i in which(sequenceLengthPairGrid$"Type"=="Sbst")){
      message(paste0("Pair ", i, "/", sequenceLengthPairN, " | Substitution: sequence length = ", sequenceLengthPairGrid[i,1]))
      s1 <- peptideSetList[[sequenceLengthPairGrid[i,1]]]
      p1 <- positionGrid[[sequenceLengthPairGrid[i,1]]]
      p1 <- seq(p1[1], p1[2])
      DistMat[p1, p1] <- distMat_Sbst(s1)
    }
    for(i in which(sequenceLengthPairGrid$"Type"=="Indel")){
      message(paste0("Pair ", i, "/", sequenceLengthPairN, " | Indel: sequence length pair = ", sequenceLengthPairGrid[i,1], " and ", sequenceLengthPairGrid[i,2]))
      s1 <- peptideSetList[[sequenceLengthPairGrid[i,1]]]
      p1 <- positionGrid[[sequenceLengthPairGrid[i,1]]]
      p1 <- seq(p1[1], p1[2])
      s2 <- peptideSetList[[sequenceLengthPairGrid[i,2]]]
      p2 <- positionGrid[[sequenceLengthPairGrid[i,2]]]
      p2 <- seq(p2[1], p2[2])
      DistMat[p1, p2] <- distMat_Indel(s1, s2)
    }
    DistMat <- DistMat|Matrix::t(DistMat) ## Symmetricalization

    ## Neighbor network
    net <- DistMat %>%
      igraph::graph_from_adjacency_matrix(mode="undirected", weighted=NULL, diag=F) %>%
      igraph::set_vertex_attr("label", value=as.character(unlist(lapply(peptideSetList, as.character)))) %>%
      igraph::simplify()
    return(net)
  }
  net_pairs_DF <- function(net){
    ## Get peptide pairs
    df <- as.data.frame(igraph::as_edgelist(net, names=T))
    colnames(df) <- c("Node1","Node2")
    df[["AASeq1"]] <- igraph::V(net)$label[df$"Node1"]
    df[["AASeq2"]] <- igraph::V(net)$label[df$"Node2"]
    df <- dplyr::select(df, -Node1, -Node2)

    ## Annotate mutational types and patterns
    message("Annotating mutations...")
    pept1 <- df$"AASeq1"
    pept2 <- df$"AASeq2"
    n_max <- max(nchar(c(pept1, pept2)))
    df_mut <- data.table::data.table("AASeq1"=pept1, "AASeq2"=pept2, "MutType"=NA, "MutPattern"="Substitution")
    df_mut[nchar(AASeq1)<nchar(AASeq2), MutPattern:="Insertion"]
    df_mut[nchar(AASeq1)>nchar(AASeq2), MutPattern:="Deletion"]

    ### Substitutions
    paramDT <- data.table::CJ("Position"=1:n_max, "AA"=Biostrings::AA_STANDARD)
    subst <- foreach::foreach(i=1:nrow(paramDT))%do%{
      pos <- paramDT$Position[[i]]
      aa <- paramDT$AA[[i]]
      pept1_tmp <- pept1
      mut <- paste0("_", pos, "_", aa)
      mut <- paste0(stringr::str_sub(pept1_tmp, pos, pos), mut, ";")
      stringr::str_sub(pept1_tmp, pos, pos) <- aa
      mut[!pept1_tmp==pept2] <- ""
      return(mut)
    } %>%
      data.table::as.data.table() %>%
      apply(1, paste0, collapse="") %>%
      stringr::str_replace(";$", "")
    df_mut[, MutType:=subst]

    ### Indels
    ins <- foreach::foreach(pos=1:n_max)%do%{
      pept2_tmp <- pept2
      mut <- paste0("-_", pos, "_")
      mut <- paste0(mut, stringr::str_sub(pept2_tmp, pos, pos), ";")
      stringr::str_sub(pept2_tmp, pos, pos) <- ""
      mut[!pept2_tmp==pept1] <- ""
      return(mut)
    } %>%
      data.table::as.data.table() %>%
      apply(1, paste0, collapse="") %>%
      stringr::str_replace(";$", "")
    del <- foreach::foreach(pos=1:n_max)%do%{
      pept1_tmp <- pept1
      mut <- paste0("_", pos, "_-")
      mut <- paste0(stringr::str_sub(pept1_tmp, pos, pos), mut, ";")
      stringr::str_sub(pept1_tmp, pos, pos) <- ""
      mut[!pept1_tmp==pept2] <- ""
      return(mut)
    } %>%
      data.table::as.data.table() %>%
      apply(1, paste0, collapse="") %>%
      stringr::str_replace(";$", "")
    df_mut[MutPattern=="Insertion", MutType:=ins[ins!=""]]
    df_mut[MutPattern=="Deletion", MutType:=del[del!=""]]

    ## Output
    df <- dplyr::left_join(df, df_mut, by=c("AASeq1", "AASeq2"))
    df$"MutType" <- sapply(stringr::str_split(df$"MutType", ";"), dplyr::last)
    gc();gc()
    return(df)
  }

  # A basic, non-directional, non-weighted network
  net <- net_main(peptideSet)
  pairDF <- net_pairs_DF(net)
  if(is.null(numSet)) return(list("NeighborNetwork"=net, "PairDF"=pairDF))

  # A directional, weighted network
  df_num <- data.frame("Peptide"=as.character(peptideSet), "Score"=numSet, stringsAsFactors=F)
  pairDF_DW <- pairDF %>%
    dplyr::inner_join(df_num, by=c("AASeq1"="Peptide")) %>%
    dplyr::inner_join(df_num, by=c("AASeq2"="Peptide")) %>%
    dplyr::transmute(AASeq1, AASeq2, Score1=Score.x, Score2=Score.y, MutType, MutPattern)
  reverseMutTypes <- function(mutTypes){
    paste0(rev(strsplit(mutTypes, "_", fixed=T)[[1]]), collapse="_")
  }
  pairDF_DW <- dplyr::bind_rows(
    pairDF_DW,
    pairDF_DW %>%
      dplyr::rename(AASeq1=AASeq2, AASeq2=AASeq1, Score1=Score2, Score2=Score1) %>%
      dplyr::mutate(MutType=sapply(MutType, reverseMutTypes),
                    MutPattern=dplyr::if_else(MutPattern=="Insertion", "Deletion", MutPattern))
  ) %>%
    dplyr::filter(Score1<=Score2) %>%
    dplyr::transmute(AASeq1, AASeq2, Score1, Score2, ScoreRatio=Score2/Score1, MutType, MutPattern)
  net_DW <- igraph::graph_from_data_frame(pairDF_DW, directed=directed)
  net_DW <- igraph::set_vertex_attr(net_DW, name="label", value=igraph::V(net_DW)$name)
  if(weighted==T) igraph::E(net_DW)$weight <- 1/igraph::E(net_DW)$ScoreRatio ## inverse to transform ratios (distances) into edge weights
  return(
    list(
      "NeighborNetwork"=net,
      "PairDF"=pairDF,
      "NeighborNetwork_DW"=net_DW,
      "PairDF_DW"=pairDF_DW
    )
  )
}
