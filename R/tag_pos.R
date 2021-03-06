#' Tag Text with Parts of Speech
#'
#' A wrapper for \pkg{NLP} and \pkg{openNLP} to easily tag text with parts of
#' speech.  The \pkg{openNLP} annotator "computes Penn Treebank parse annotations
#' using the Apache OpenNLP chunking parser for English."
#'
#' @param text.var The text string variable.
#' @param engine The backend pat of speech tagger, either "openNLP" or "coreNLP".
#' The default "openNLP" uses the \pkg{openNLP} package.  If the user has the
#' Stanford CoreNLP suite (\file{http://stanfordnlp.github.io/CoreNLP/})
#' installed this can be used as the tagging backend instead.
#' @param element.chunks The number of elements to include in a chunk. Chunks are
#' passed through an \code{\link[base]{lapply}} and size is kept within a tolerance
#' because of memory allocation in the tagging process with \pkg{Java}.
#' @param \ldots Other arguments passed to \code{tagger:::core_tagger} including
#' \code{stanford.tagger = stansent::coreNLP_loc()} and \code{java.path}, the
#' path to \pkg{CoreNLP} and \pkg{Java} respectively.  Use
#' \code{\link[tagger]{check_setup}} to check that \pkg{Java} is installed and
#' of correct version and that Stanford's \pkg{CoreNLP} is installed and in root.
#' @return Returns a list of part of speech tagged vectors.  The pretty printing
#' does not indicated this feature, but the words and parts of speech are easily
#' accessible through indexing.
#' @export
#' @examples
#' (x <- tag_pos("They refuse to permit us to obtain the refuse permit"))
#' c(x) ## The true structure of a `tag_pos` object
#'
#' (out1 <- tag_pos(sam_i_am))
#' tidy_pos(out1)
#' as_word_tag(out1)
#' count_tags(out1)
#' as_basic(out1)
#' as_universal(out1)
#' plot(out1)
#' \dontrun{
#' (out2 <- tag_pos(presidential_debates_2012$dialogue)) # ~40 sec run time
#' count_tags(out2)
#' count_tags(out2, by = presidential_debates_2012$person)
#' with(presidential_debates_2012, count_tags(out2, by = list(person, time)))
#' plot(out2)
#'
#' ## CoreNLP
#' tag_pos(sam_i_am, engine = 'coreNLP')
#' }
tag_pos <- function(text.var, engine = "openNLP",
    element.chunks = floor(2000 * (23.5/mean(sapply(text.var, nchar), na.rm = TRUE))),
    ...){

    len <- length(text.var)

    ## locate empty or missing text elements
    nas <- sort(union(which(is.na(text.var)), grep("^\\s*$", text.var)))

    ## replace empty text with a period
    if(!identical(nas, integer(0))){
       text.var[nas] <- "."
    }

    ## Chunking the text into memory sized chunks:
    ## caluclate the start/end indexes of the chunks
    ends <- c(utils::tail(seq(0, by = element.chunks,
        length.out = ceiling(len/element.chunks)), -1), len)
    starts <- c(1, utils::head(ends + 1 , -1))

    ## chunk the text
    text_list <- Map(function(s, e) {text.var[s:e]}, starts, ends)

    switch(engine,
        coreNLP = {

            ## loop through the chunks and tag them
            out <- unlist(lapply(text_list, function(x){
                x <- core_tagger(x, ...)
                gc()
                x
            }), recursive = FALSE)

        },
        openNLP = {

            ## Need pos and word token annotations.
            PTA <- openNLP::Maxent_POS_Tag_Annotator()
            WTA <- openNLP::Maxent_Word_Token_Annotator()

            ## loop through the chunks and tag them
            out <- unlist(lapply(text_list, function(x){
                x <- tagPOS(x, PTA, WTA)
                gc()
                x
            }), recursive = FALSE)
        },
        stop("`engine` must be either \"openNLP\" or \"coreNLP\".")
    )


    if(!identical(nas, integer(0))){
       out[nas] <- NA
    }

    class(out) <- c("tag_pos", class(out))
    out
}



#' Prints a tag_pos Object
#'
#' Prints a tag_pos object.
#'
#' @param x The tag_pos object.
#' @param n The number of rows to print (.5 * n goes to head and .5 * n goes to tail).
#' @param width The width of the tag rows to print.
#' @param \ldots ignored
#' @method print tag_pos
#' @export
print.tag_pos <- function(x, n = 10, width = .7 * getOption("width"), ...){
    n <- ceiling(10/2)
    y <- as_word_tag(x)
    if (length(y) <= 2*n) {
        print(y)
        #cat(sprintf("\n%s\n\nn = %s", paste(rep("*", 25), collapse="  "), length(y)))
    } else {
        top <- widther(utils::head(y, n), width=width)
        tails <- c(length(y) - (n-1)):length(y)
        bot <- widther(y[tails], width=width)

        numbs <- sprintf(paste0("%-", 1+nchar(length(y)), "s"), paste0(seq_along(y), "."))
        cat(paste(numbs[1:n], top, sep=" ", collapse="\n"))
        cat("\n.\n.\n.\n")

        cat(paste(numbs[tails], bot, sep=" ", collapse="\n"), "\n")
        #cat(sprintf("\n%s\nn = %s", paste(rep("-", 45), collapse=""), length(y)))
    }
}


#' Plots a tag_pos Object
#'
#' Plots a tag_pos object.
#'
#' @param x The tag_pos object
#' @param item.name The name of the variable that contains the groups (different
#' element in the vector/list).
#' @param \ldots Other arguments passed to \code{\link[termco]{plot_counts}}.
#' @method plot tag_pos
#' @export
plot.tag_pos <- function(x, item.name = "POS Tag", ...){
    y <- lapply(x, names)
    termco::plot_counts(y, item.name = item.name, ...)
}


widther <- function(x, width) {
    prime <- lapply(x, strwrap, width=width)
    y <- sapply(prime, "[[", 1)
    y[sapply(prime, length) > 1] <- paste(y[sapply(prime, length) > 1], "...")
    y
}


