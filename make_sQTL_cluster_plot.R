# 
# cluster_to_plot = "clu_34225"
#                    main_title = "CAST"
#                    vcf=vcf
#                    vcf_meta=vcf_meta
#                    exons_table = exons_table
#                    counts = clusters
#                    introns = annotatedClusters
#                    cluster_ids = annotatedClusters$clusterID
#                    snp_pos = "chr5:96076487"
#                    snp = "rs7724759"

#' Make cluster level plot
#'
#' @import ggplot2
#' @import gridExtra
#' @export 
make_sQTL_cluster_plot <- function(
  cluster_to_plot,
  main_title = NA,
  exons_table = NULL,
  vcf = NULL,
  vcf_meta = NULL,
  cluster_ids = NULL,
  counts = NULL,
  introns = NULL,
  snp_pos=NA,
  sigJunction=NA,
  snp = snp ){
  
  if( is.null(cluster_to_plot)){
    print("no cluster selected!")
  }
  
  stopifnot( snp %in% vcf_meta$SNP ) 
  
  # subset VCF and get groups
  vcfIndex <- which( vcf_meta$SNP == snp)
  VCF <- vcf[vcfIndex,10:ncol(vcf)]
  #table(t(VCF) )
  #for testing!
  VCF_meta <- vcf_meta[vcfIndex,]
  meta <- as.data.frame(t(VCF))
  meta$group=as.factor(meta[,1])
  group_names <- c(0,1,2)
  names(group_names) <- c(
      paste0( VCF_meta$REF, "/", VCF_meta$REF),
      paste0( VCF_meta$REF, "/", VCF_meta$ALT),
      paste0( VCF_meta$ALT, "/", VCF_meta$ALT)
  )
  # get SNP position
  SNP_pos <- as.numeric(str_split_fixed(snp_pos, ":",2)[,2])
  

  #stopifnot(cluster_to_plot %in% cluster_ids)
  # create variables for later
  y <- t(counts[ cluster_ids==cluster_to_plot, ])
  #x <- numeric(nrow(y))+1
  x <- meta$group
  #x <- group_names
  length_transform <- function(g){ log(g+1) }
  introns_to_plot <- introns[ introns$clusterID == cluster_to_plot, ] 
  summary_func <- colSums
  legend_title <- "Mean counts"
  alphabet <- c("a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z")
  
  
  junction_colour <- "red"
  cryptic_colour <- "pink"
  SNP_colour <- "goldenrod"
  # convert colnames(y) into intron meta data
  intron_meta=get_intron_meta(colnames(y))
  
  #intron_meta$verdict <- introns_to_plot$verdict[match(paste(intron_meta$start,intron_meta$end), paste(introns_to_plot$start, introns_to_plot$end) ) ]
  intron_meta$verdict <- introns_to_plot$verdict[
          match(paste0(intron_meta$chr,":",intron_meta$start,"-",intron_meta$end), introns_to_plot$coord) ]
  
  # all dPSI stuff isn't relevant for sQTLs
  
  #intron_meta$dPSI <- introns_to_plot$deltapsi[match(paste(intron_meta$start,intron_meta$end), paste(introns_to_plot$start, introns_to_plot$end) ) ]
  # give alphabetical rank based on dPSI
  #ranks <- alphabet[1:nrow(intron_meta)]
  #absPSI <- intron_meta$dPSI[ order( abs(intron_meta$dPSI), decreasing=TRUE) ]
  #intron_meta$rank <- ranks[match(intron_meta$dPSI, absPSI)]
  
  # make sure intron_meta has "chr" in front of chromosome name so it plays nice with the exon table
  if( all( ! grepl("chr", intron_meta$chr))){
    intron_meta$chr <- paste0("chr", as.character(intron_meta$chr))
  }

  #print(intron_meta)

  new_theme_empty <- theme_bw(base_size = 15 )
  new_theme_empty$panel.background = element_rect(fill="white", colour = "white")
  new_theme_empty$line <- element_blank()
  new_theme_empty$rect <- element_blank()
  new_theme_empty$strip.text <- element_blank()
  new_theme_empty$axis.text <- element_blank()
  
  groups=sort(unique(x))
  
  max_log <- .5*ceiling(2*log10( 1+max( unlist( foreach (tis=groups) %do% { intron_meta$counts=summary_func(y[ tis==x,,drop=F]) } ) ) ))
  
  breaks <- if (max_log <= 2.5) seq(0,max_log,by=0.5) else seq(0,ceiling(max_log),by=1)
  limits <- c(0.0,max_log)
  
  intron_meta$id=as.factor(1:nrow(intron_meta)) # number each junction
  temp=intron_meta[,c("id","start","end")]
  m=reshape2::melt(temp, id.vars = "id") # melt to get list of all coordinates
  
  s=unique(m$value) # get unique start and end values
  # add the SNP position to the mix - what happens when SNP is far away?
  if ( !is.na(SNP_pos) ){
    s=c(s,SNP_pos)
  }
  s=sort(s) 
  d=s[2:length(s)]-s[1:length(s)-1] # get the difference between pairs of coordinates
  trans_d <- length_transform(d) # e.g. log(d+1), sqrt(d), d ^ .33 # apply a trasnformation function - doesn't work on negative numbers!
  coords <- c(0,cumsum(trans_d))
  names(coords)=s
  
  snp_coord=coords[as.character(SNP_pos)]
  
  total_length=sum(trans_d) # ==max(coords)
  my_xlim=c(-.05*total_length,1.05*total_length)
  first_plot <- TRUE
  
  ############## 
  # PLOT SETTINGS
  ###############
  min_proportion = 0#.01 # if a junction's normalised proportion is less than this then don't plot!
  min_height=0
  max_height=0
  curv <- 0.1
  min_exon_length <- 0.5
  divider_length <- 0.05 # the white spacers to divide overlapping exons
  maxratio=0
  minratio=1.0
  yFactor = 0.65   # originally set as 0.65
  yConstant = -0.25 # originally set as 0.5
  curveMax = 10
  curveExponent = 2
  yOffset = 0
  centreLineWidth = 3   # horizontal white line to clean up the edges of the curves
  labelTextSize=5 # orignally set as 5
  yAxisTextSize = 20
  legendTextSize = 15
  
  mainPalette <- c(junction_colour, cryptic_colour)
  if( !is.na(snp_pos)){
    mainPalette <- c(mainPalette, SNP_colour)
  }
  #summary_func=function(a) apply(a,2,mean)
  #summary_func=function(a) apply(sweep(a,1,rowSums(a),"/"),2,mean)
  # sweep is dividing each entry in each row by the sum of all entries in that row and then apply is finding the mean value of each column
  summary_func <- function(a) apply( sweep(a,1,rowSums(a),"/"),2, function(g) mean(g, na.rm=T) ) 

  if( !is.na(sigJunction)){
    sig.junction <- str_split_fixed(sigJunction,":",4)[1,]
  }
  
  plots <- foreach (tis=groups) %do% {
    # print(y[tiss=x,,drop=F])
    intron_meta$counts=summary_func(y[ tis==x,,drop=FALSE])
    #print(length(intron_meta$counts))
    maxratio=max(c(max(intron_meta$counts/sum(intron_meta$counts)), maxratio)) # find max and min values of summarised counts
    minratio=min(c(min(intron_meta$counts/sum(intron_meta$counts)), minratio))
  }
  #print(c(maxratio, minratio))
  last_group=groups[length(groups)]
  
  plots <- list()
  for( fancyVar in 1:length(groups) ){

    intron_meta$counts=summary_func(y[ groups[fancyVar]==x,,drop=F])
    intron_meta$prop=intron_meta$counts#/sum(intron_meta$counts)  # this has been changed

    group_sample_size=sum(groups[fancyVar]==x)
    #print(intron_meta$counts)

    # for each junction
    allEdges=do.call(rbind,foreach (i=1:nrow(intron_meta)) %do% {
      #allEdges=do.call(rbind,foreach (i=1:2) %do% {
      if (i%%2==1) return(NULL)  # only care about the even numbered junctions?
      #if (intron_meta$counts[i]==0) return(NULL)
      start=coords[ as.character(intron_meta$start[i]) ]
      end=coords[ as.character(intron_meta$end[i]) ]
      l=end-start  # length of junction
      #edge = data.frame(bezier(x=c(start, (start + end)/2, end), y=c(0, (1+sqrt(l)) * ( (i %% 2)*2-1 ), 0),evaluation = len))
      # h=(1+sqrt(l)) * ( (i %% 2)*2-1 )
      # min_height=min(min_height,h)
      # max_height=max(max_height,h)

      edge = data.frame(start, end)
      edge$startv <- intron_meta$start[i]
      edge$endv <- intron_meta$end[i]
      edge$start <- start  # why do this again? You already set them
      edge$end <- end
      edge$log10counts=intron_meta$counts[i]+1

      # label each junction
      #edge$label=paste0(format(intron_meta$prop[i],digits=2, scientific=FALSE),"^", intron_meta$rank[i])
      edge$label=format(intron_meta$prop[i],digits=2, scientific=FALSE)
      
      #edge$label=format(intron_meta$counts[i], scientific=F)
      #edge$label=paste(format(intron_meta$counts[i], scientific=F),'\n(',format(intron_meta$prop[i],digits=2),')',sep='')
      edge$clu<- intron_meta$clu[i]
      #edge$Curve <- j
      edge$Group <- i
      edge$xtext <-start+l/2
      edge$ytext <- -( ( l^(yFactor) / 2 ) + yConstant)  # magic formula here
      #edge$SIZE <- intron_meta$prop[i]
      #edge$SIZE <- intron_meta$prop[i]+1 # make SIZE equal to the normalised count + 1
      #edge$SIZE <- as.factor(.bincode(intron_meta$prop[i]+0.1, breaks=seq(0,100,1)/100, include.lowest=TRUE))
      edge$verdict <- ifelse( intron_meta$verdict[i] == "annotated", yes = "annotated", no ="cryptic")
      # if matches sigJunction
      edge$embolden <- paste(edge$startv, edge$endv) == paste(sig.junction[2], sig.junction[3])
      
      
      # if proportion = 0 then remove junction
      edge <- edge[ edge$label > min_proportion | edge$embolden, ]
      
      edge
    })

    allEdgesP=do.call(rbind,foreach (i=1:nrow(intron_meta)) %do% {
      if (i%%2==0) return(NULL)  # just the odd numbered junctions
      #if (intron_meta$counts[i]==0) return(NULL)
      start=coords[ as.character(intron_meta$start[i]) ]
      end=coords[ as.character(intron_meta$end[i]) ]
      l=end-start
      #edge = data.frame(bezier(x=c(start, (start + end)/2, end), y=c(0, (1+sqrt(l)) * ( (i %% 2)*2-1 ), 0),evaluation = len))
      # h=(1+sqrt(l)) * ( (i %% 2)*2-1 )
      # min_height=min(min_height,h)
      # max_height=max(max_height,h)

      edge = data.frame(start, end)
      edge$startv <- intron_meta$start[i]
      edge$endv <- intron_meta$end[i]
      edge$start <- start
      edge$end <- end
      edge$log10counts=intron_meta$counts[i]+1
      #edge$label=paste0(format(intron_meta$prop[i],digits=2, scientific=FALSE),"^",intron_meta$rank[i])
      edge$label=format(intron_meta$prop[i],digits=2, scientific=FALSE)
      
      #edge$label=format(intron_meta$prop[i],digits=2, scientific=T)
      #edge$label=paste(format(intron_meta$counts[i], scientific=F),'\n(',format(intron_meta$prop[i],digits=2),')',sep='')
      edge$clu<- intron_meta$clu[i]
      #edge$Curve <- j
      edge$Group <- i
      edge$xtext <-start+l/2
      edge$ytext <- l^(yFactor)/2+yConstant
      #edge$SIZE <- intron_meta$prop[i]
      #edge$SIZE <- as.factor(.bincode(intron_meta$prop[i], breaks=seq(0,100,1)/100, include.lowest=TRUE))
      edge$SIZE <- intron_meta$prop[i]+1
      edge$verdict <- ifelse( intron_meta$verdict[i] == "annotated", yes = "annotated", no ="cryptic")
      edge$embolden <- paste(edge$startv, edge$endv) == paste(sig.junction[2], sig.junction[3])
      
      edge <- edge[ edge$label > min_proportion | edge$embolden, ]
      edge
    })
    print("allEdges:")
    print(allEdges)
    print("allEdgesP:")
    print(allEdgesP)

    if ( all(is.na(main_title)) | !first_plot){
      new_theme_empty$plot.title <- element_blank()
    }
    first_plot <- FALSE
    
    #MAXcounts <- max(c(max(with(allEdgesP,1)),max(with(allEdges,1))))
    #YLIMN <- max(with(allEdgesP,end-start))
    #YLIMP <- max(with(allEdges,end-start))
    #print(is.numeric(allEdgesP$SIZE))
    #print(allEdges)
    #print(allEdgesP)
    if( nrow(allEdgesP) == 0){
      YLIMN <- min( allEdges$ytext) + 0.25 * min( allEdges$ytext)
      YLIMP <- -YLIMN
    }
    if( nrow(allEdges) == 0 ){
      YLIMP <- max( allEdgesP$ytext) + 0.25 * max( allEdgesP$ytext)
      YLIMN <- -YLIMP
    }
    if( nrow(allEdges) > 0 & nrow(allEdgesP) > 0 ){
      YLIMP <- max( allEdgesP$ytext) + 0.25 * max( allEdgesP$ytext)
      YLIMN <- min( allEdges$ytext) + 0.25 * min( allEdges$ytext)
    }
    print( YLIMP)
    print( YLIMN)
    print(my_xlim)
    # print(allEdgesP)
    # print(allEdges)
    # if value is 0 then don't plot curve - no longer works due to superscript letters in labels
    #allEdgesP <- allEdgesP[ allEdgesP$label != 0, ]
    #allEdges <- allEdges[ allEdges$label != 0, ]
    # junction_colour if annotated? a different colour if not
    g <- ggplot()
      if(nrow(allEdgesP) > 0){
        g <- g +
        geom_curve(data=allEdgesP, aes(x = start, xend = xtext, y = yOffset, yend = ytext, group = Group, colour = verdict, size = curveMax * (log10counts - 1)^curveExponent ),
                 angle=90, curvature=-curv,lineend="round") +
        geom_curve(data=allEdgesP, aes(x = xtext, xend = end, y = ytext, yend = yOffset, group = Group, colour = verdict, size = curveMax * (log10counts - 1)^curveExponent ),
                 angle=90, curvature=-curv,lineend="round")
      }
      if(nrow(allEdges) > 0){
        g <- g + geom_curve(data=allEdges, aes(x = start, xend = xtext, y = -yOffset, yend = ytext, group = Group, colour = verdict, size = curveMax * (log10counts - 1)^curveExponent ),
                 angle=90,curvature=curv,lineend="round") +
           geom_curve(data=allEdges, aes(x = xtext, xend = end, y = ytext, yend = -yOffset, group = Group, colour = verdict, size = curveMax * (log10counts - 1)^curveExponent ),
                 angle=90,curvature=curv,lineend="round")
      }
    g <- g + new_theme_empty +
      # make the y axis label the group
      #ylab(paste0(groups[fancyVar]," (n=",group_sample_size,")")) +
      ylab(paste0("\n",names(group_names)[fancyVar],"\n(n=",group_sample_size,")")) +
      theme(axis.title.y = element_text( angle = 0, vjust = 0.75, size = yAxisTextSize )) +
      xlab("") +
      xlim(my_xlim) +
      # horizontal line - smooth out the ends of the curves
      geom_hline(yintercept=0, size = centreLineWidth, colour = "white") +
      geom_hline(yintercept=0,alpha=.9, size=1)

      # label the junctions
      if( nrow(allEdgesP) > 0 ){
          g <- g + geom_label(data=allEdgesP,aes(x=xtext,y=0.95*ytext,label=label), size = labelTextSize, 
                              label.size = NA, parse=TRUE, fill = "white",
                              colour = "black", label.r = unit(0.3,"lines"), label.padding = unit(0.3,"lines") ) 
                }
      if( nrow(allEdges) > 0 ){
          g <- g + geom_label(data=allEdges,aes(x=xtext,y=0.95*ytext,label=label), size= labelTextSize, label.size = NA, parse=TRUE, fill = "white", 
                             colour = "black", label.r = unit(0.3,"lines"), label.padding = unit(0.3,"lines") ) 
          
      }
      
      if( !is.na(sigJunction) ){
        if(nrow(allEdges[allEdges$embolden,]) > 0){
          g <- g + geom_label(data=allEdges[allEdges$embolden,],aes(x=xtext,y=0.95*ytext,label=label), fontface = "bold", size= labelTextSize, label.size = NA, parse=FALSE, fill = "white", 
                                colour = "black", label.r = unit(0.3,"lines"), label.padding = unit(0.3,"lines") ) 
        }
        if( nrow(allEdges[allEdgesP$embolden,]) > 0){
          g <- g + geom_label(data=allEdgesP[allEdgesP$embolden,],aes(x=xtext,y=0.95*ytext,label=label), fontface="bold", size = labelTextSize, label.size = NA, parse=FALSE, fill = "white",
                     colour = "black", label.r = unit(0.3,"lines"), label.padding = unit(0.3,"lines") )
        }
      }
    
      g <- g +
      ylim(YLIMN,YLIMP) +
      scale_size_continuous(limits=c(0,10),guide='none')
    # is this used for anything? color is currently set to clu which doesn't change for each junction


    plots[[fancyVar]] <- g  # return the plot
  }

  # ADDING EXTRA STUFF TO THE PLOTS
  
  df <- data.frame(x=coords, xend=total_length*(s-min(s))/(max(s)-min(s)), y=0, yend=min_height)
  # Control segment between diagram to exon
  # if (! is.null( exons_table) ){
  # plots[[length(plots)]] <- plots[[length(plots)]] + geom_segment(data=df, aes(x=x,y=y,xend=xend,yend=yend),alpha=0.2, lty=2)
  # }
  
  # ADDING EXON ANNOTATION
  
  if (!is.null(exons_table)) {
    
    # find the exons
    exons_chr <- exons_table[ exons_table$chr==intron_meta$chr[1], ] # subset by chr
    
    stopifnot( nrow(exons_chr) > 0)
    
    exons_here <- exons_chr[ ( min(s) <= exons_chr$start & exons_chr$start <= max(s) ) | ( min(s) <= exons_chr$end & exons_chr$end <= max(s) ), ] # find exons
    print(exons_here)
    # if exons found - remove exons that don't actually start or end with a junction
    # and any repeated exons or any exons larger than 500bp
    if( nrow(exons_here) > 0 ){ 
      exons_here <-  unique( 
        exons_here[ ( exons_here$end %in% intron_meta$start | 
                        exons_here$start %in% intron_meta$end ) &
                      ( exons_here$end - exons_here$start <= 1000 |
                        exons_here$end == min(intron_meta$start) |
                        exons_here$start == max(intron_meta$end) ), ]
      )
    }
    # if any exons survive the cull
    if ( nrow( exons_here) > 0) {
      exons_here$gene_name=factor(exons_here$gene_name)
      n_genes <- seq(1, length( levels(exons_here$gene_name) ) )
      gene_name_df <- data.frame( x= 0.2*total_length,#(n_genes * total_length) / (max(n_genes) + 1), 
                                  y=YLIMN, 
                                  label=rev(levels(exons_here$gene_name))
                                )
      # count the occurences of each gene's exons and order by it
      gene_name_df$N <- table(exons_here$gene_name)[ gene_name_df$label ]
      gene_name_df <- gene_name_df[ order(gene_name_df$N, decreasing = TRUE), ]
      
      # for gene name colouring (black by default, other colours for multiple genes)
      cbbPalette <- c("#000000", "#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7")
      # sort out colour pallette - most common gene goes first!
      cbbPalette <- cbbPalette[ 1:length(gene_name_df$label) ]
      names(cbbPalette) <- gene_name_df$label
      # add junction colours 
      mainPalette <- c(cbbPalette, junction_colour, cryptic_colour)
      names(mainPalette)[ (length(mainPalette)-1):length(mainPalette) ] <- c("annotated","cryptic")
      
      if(!is.na(snp_pos)){
        mainPalette <- c(mainPalette, SNP_colour)
        names(mainPalette)[length(mainPalette)] <- snp
      }

      # fit exons within the cluster scale
      invert_mapping=function(pos){
        if (pos %in% s) coords[as.character(pos)] else
          if (pos < min(s)) my_xlim[1] else
            if (pos > max(s)) my_xlim[2] else {
              w=which( pos < s[2:length(s)] & pos > s[1:(length(s)-1)] )
              stopifnot(length(w)==1)
              coords[w] + (coords[w+1]-coords[w])*(pos - s[w])/(s[w+1]-s[w])
            }
      }
      

      exon_df <- data.frame( x=sapply(exons_here$start,invert_mapping), 
                               xend=sapply(exons_here$end,invert_mapping), 
                               y=0, 
                               yend=0,
                               label = exons_here$gene_name)
        
      # alter exon sizes to conform to a minimum exon length
      exon_df[ (exon_df$xend - exon_df$x) < min_exon_length, ]$xend <- exon_df[ (exon_df$xend - exon_df$x) < min_exon_length, ]$x + min_exon_length
      
      # remove exons that are now duplicates - overlapping exons that extend outside of the plotting space and are squished to same coordinates
      exon_df <- exon_df[ !duplicated( paste(exon_df$x, exon_df$xend) ),]
      
      ## STRANDING
      # pick principal gene - the one that contributes the most exons to the cluster will be at the top of the df
      principal_gene <- gene_name_df$label[1]
      gene_strand <- unique(exons_here[exons_here$gene_name == principal_gene,]$strand)
      if( length(gene_strand)  > 1 & !is.na(gene_strand) ){
        gene_strand <- NULL
      }else{
        # assign strand arrows based on lengths of intron
        exon_intervals <- Intervals( matrix(data = c(exon_df$x, exon_df$xend), ncol = 2) )
        #exon_intervals <- intervals::interval_union( exon_intervals )
        intron_intervals <- intervals::interval_complement( exon_intervals )
        intron_intervals <- intron_intervals[ 2:(nrow(intron_intervals)-1),]
        # strand arrows should be placed between exons
        strand_df <- as.data.frame(intron_intervals)
        # remove strand arrows where the introns are too small
        strand_df <- strand_df[ (strand_df$V2 - strand_df$V1) > 0.025 * total_length,]
        strand_df$midpoint <- strand_df$V1 + (strand_df$V2 - strand_df$V1) / 2
        
        group <- c()
        for(i in 1:nrow(strand_df)){
          group <- c(group, rep(i,2))
        }
        # make strand_df
        if( gene_strand == "+"){
          strand_df <- data.frame( x = c(rbind(strand_df$V1, strand_df$midpoint)),
                                   group = group, 
                                   y = 0) 
        }
        if( gene_strand == "-"){
          strand_df <- data.frame( x = c(rbind(strand_df$midpoint, strand_df$V2)),
                                   group = group,
                                   y = 0)
        }
        
        # add strand position - which way should the arrows go?
        if( gene_strand == "+" ){
          strand_pos <- "last"
        }
        if( gene_strand == "-" ){
          strand_pos <- "first"
        }
        # add strand arrows to plot
        for (i in 1:length(plots) ){
          plots[[i]] <- plots[[i]] +
            geom_line( data = strand_df, 
                       aes( x = x, y = y, group = group ), colour = "black", size=1, 
                       arrow = arrow(ends = strand_pos, type = "open", angle = 30, length = unit(0.1, units = "inches" ))) 
        }
      }

      # add exons to plots
      for (i in 1:length(plots) ){ 
        plots[[i]] <- plots[[i]] +
          geom_segment( data=exon_df, aes(x=x,y=y,xend=xend,yend=yend, colour = label), alpha=1, size=6) +
          geom_segment( data = exon_df, aes(x = x, xend = x+divider_length, y = y, yend = yend), colour = "white", size = 6, alpha = 1) +
          geom_segment( data = exon_df, aes(x = xend-divider_length, xend=xend, y = y, yend = yend), colour = "white", size = 6, alpha = 1)
      }
    }
  }
  

  # TITLE
  
  # give a main_title argument, ideally a vector of c(gene_name, cluster_name)
  if( all( !is.na(main_title) ) ){    
    if( length(main_title) > 1){
      plots[[1]] <- plots[[1]] + ggtitle(main_title[1],subtitle = main_title[2]) +
      theme(plot.title = element_text(face="bold.italic", colour="black", size = 15, hjust = 0.45), # centre titles - account for xlabels
          plot.subtitle = element_text(hjust = 0.45))
    }else{
    plots[[1]] = plots[[1]] + ggtitle(main_title) 
    }
  }
  
  # add colour palette - different depending on whether exons are included or not - hide in top plot

  # ARRANGE PLOTS
  
  #do.call( gridExtra::grid.arrange, c(plots, list(ncol=1)))
  # only if no SNP is present
  
  
  if( is.na(snp_pos) ){
    
    # add colour legend to bottom-most plot
    
    plots[[1]] <- plots[[1]] + 
      scale_colour_manual("", values = mainPalette ) + guides(colour=FALSE) # don't show colour legend in top plot
    plots[[2]] <- plots[[2]] +
      scale_colour_manual("", values = mainPalette ) + theme(legend.position="bottom", 
                                                             legend.justification = 'right',
                                                             legend.text = element_text(size = legendTextSize) 
                                                             ) 
    
    gridExtra::grid.arrange( plots[[1]], plots[[2]], ncol =1)
  }else{
      # sQTL specific options
    
      SNP_df <- data.frame( x=snp_coord,
                            xend=snp_coord + (0.005*snp_coord),
                            y=0,
                            yend=0,
                            label = snp )
      if(snp_coord == 0){
        SNP_df$x <- 0
        SNP_df$xend <- 0 + (0.5*min_exon_length)
      }  
      print(SNP_df)
      
      # if SNP falls outside of cluster then annotate the distance to the edge of the cluster in kb
      # danger of SNP overlapping exactly with a coord
      intron_coords <- coords[ names(coords) != as.character(SNP_pos) | duplicated( names(coords) ) ]
      
      if( all(snp_coord > intron_coords) | all(snp_coord < intron_coords) ){
        # find smallest distance
        distance <- abs( snp_coord - intron_coords)
        adjacent_coord <- intron_coords[which( distance == min(distance)) ]
        
        # make a df
        relative_coords <- as.numeric( c( snp_coord, adjacent_coord))
        absolute_coords <- as.numeric( c( names(snp_coord), names(adjacent_coord)))
        snp_distance_df <- data.frame(
          x = min( relative_coords ),
          xend = max( relative_coords ),
          label = paste0( signif( (max( absolute_coords ) - min( absolute_coords ) )/1000, 3),"kb" ),
          label_pos = mean( relative_coords )
        )
      }else{
        print(snp_coord)
        print(intron_coords)
        # if SNP is within cluster, plot distance to nearest junction in bp
        distance <- abs( snp_coord - intron_coords)
        adjacent_coord <- intron_coords[which( distance == min(distance)) ]
        relative_coords <- as.numeric( c( snp_coord, adjacent_coord))
        absolute_coords <- as.numeric( c( names(snp_coord), names(adjacent_coord)))
        snp_distance_df <- data.frame(
          x = min( relative_coords ),
          xend = max( relative_coords ),
          label = paste0( ( (max( absolute_coords ) - min( absolute_coords ) ) ),"bp" ),
          label_pos = mean( relative_coords )
        )
        
        
      } 

      # add SNP to plot
      for (i in 1:length(plots) ){ 
        plots[[i]] <- plots[[i]] +  
          geom_segment(data=SNP_df,aes(x=x,y=y,xend=xend,yend=yend, colour = label), size = 6.5 ) +
          scale_colour_manual("", values = mainPalette ) + geom_vline(xintercept=snp_coord, linetype = 3, colour = SNP_colour)
      }
      
      # add distance arrow to plot
      plots[[length(plots)]] <- plots[[ length(plots)]] +
        geom_segment(data = snp_distance_df, 
                     aes( x = x, xend = xend, y = 0.3*YLIMN, yend = 0.3*YLIMN),
                     colour = "black", 
                     arrow = arrow(ends = "both", type = "open", angle = 20, length = unit(0.075, units = "inches") ) ) +
        geom_text( data = snp_distance_df, aes( x = label_pos, y = 0.45*YLIMN, label = label), size = labelTextSize)
      
      
      for (i in 1:( length(plots) - 1) ){
        plots[[i]] <- plots[[i]] + 
        guides(colour=FALSE) 
      }
      plots[[length(plots)]] <- plots[[length(plots)]] + 
        theme(legend.position="bottom",
              legend.justification = 'right',
              legend.text = element_text(size = legendTextSize)
              ) 
    
      # arranging
      if( length( plots ) == 2){
        gridExtra::grid.arrange( plots[[1]], plots[[2]], ncol =1)
      }
      if( length( plots ) == 3){
        gridExtra::grid.arrange( plots[[1]], plots[[2]], plots[[3]], ncol =1)
      }
  }

  }
  

