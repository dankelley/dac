## vim:textwidth=128:expandtab:shiftwidth=4:softtabstop=4

#' Download and Cache a Topographic File
#'
#' @description
#'
#' @template intro
#'
#' @details
#'
#' Data are downloaded (from \samp{https://maps.ngdc.noaa.gov/viewers/wcs-client/}, by
#' default) and a string containing the full path
#' to the downloaded file is returned. If \code{destfile} is not supplied,
#' then the filename is constructed from the query, which means that 
#' subsequent calls to \code{download.topo}  with identical parameters will
#' simply return the name of the cached file, assuming the user has not
#' deleted it in the meantime. 
#'
#' The data are downloaded with \code{\link[utils]{download.file}}, using a URL
#' devised from reverse engineering web-based queries constructed by
#' the default \code{server} used here. Note that the data source is "etopo1",
#' which is a 1 arc-second file [1,2].
#'
#' Three values are permitted for \code{format},
#' each named after the
#' targets of menu items on the
#' NOAA website (as of August 2016): (1) \code{"aaigrid"} (for
#' the menu item "ArcGIS ASCII Grid"), which
#' yields a text file, (2) \code{"netcdf"} (the default,
#' for the menu item named
#' "NetCDF"), which yields a NetCDF file
#' and (3) \code{"gmt"} (for the menu item named
#' "GMT NetCDF"), which yields a NetCDF file in
#' another format. All of these file formats are
#' recognized by \code{\link{read.topo}}.
#' (The NOAA server has more options, and if
#' \code{\link{read.topo}} is extended to handle them, they will
#' also be added here.)
#'
#' @param west,east Longitudes of the western and eastern sides of the box.
#'
#' @param south,north Latitudes of the southern and northern sides of the box.
#'
#' @param resolution Optional grid spacing, in minutes. If not supplied,
#' a default value of 4 (corresponding to 7.4km, or 4 nautical
#' miles) is used. Note that (as of August 2016) the original data are on
#' a 1-minute grid, which limits the possibilities for \code{resolution}.
#'
#' @param format Optional string indicating the type of file to download. If
#' not supplied, this defaults to \code{"gmt"}. See \dQuote{Details}.
#'
#' @param server Optional string indicating the server from which to get the data.
#' If not supplied, the default
#' \samp{"https://gis.ngdc.noaa.gov/cgi-bin/public/wcs/etopo1.xyz"}
#' will be used.
#'
#' @template filenames
#'
#' @template debug
#'
#' @return String indicating the full pathname to the downloaded file.
#'
#' @author Dan Kelley
#'
#' @examples
#'\dontrun{
#' topoFile <- dac::download.topo(west=-64, east=-60, south=43, north=46)
#' library(oce)
#' topo <- read.topo(topoFile)
#' imagep(topo, zlim=c(-400, 400), drawTriangles=TRUE)
#' data(coastlineWorldFine, package="ocedata")
#' lines(coastlineWorldFine[["longitude"]], coastlineWorldFine[["latitude"]])
#'}
#'
#' @section Webserver history:
#' All versions of \code{download.topo} to date have used a NOAA server as
#' the data source, but the URL has not been static. A list of the
#' servers that have been used is provided below,
#' in hopes that it can help users to make guesses
#' for \code{server}, should \code{download.topo} fail because of 
#' a fail to download the data because of a broken link. Another
#' hint is to look at the source code for
#' \code{\link[marmap]{getNOAA.bathy}} in the \CRANpkg{marmap} package,
#' which is also forced to track the moving target that is NOAA.
#'
#' \itemize{
#' \item August 2016. 
#' \samp{http://maps.ngdc.noaa.gov/mapviewer-support/wcs-proxy/wcs.groovy}
#'
#' \item December 2016.
#' \samp{http://mapserver.ngdc.noaa.gov/cgi-bin/public/wcs/etopo1.xyz}
#'
#' \item June-September 2017.
#' \samp{https://gis.ngdc.noaa.gov/cgi-bin/public/wcs/etopo1.xyz}
#' }
#'
#' @seealso The work is done with \code{\link[utils]{download.file}}.
#'
#' @references
#' 1. \samp{https://www.ngdc.noaa.gov/mgg/global/global.html}
#'
#' 2. Amante, C. and B.W. Eakins, 2009. ETOPO1 1 Arc-Minute Global Relief
#' Model: Procedures, Data Sources and Analysis. NOAA Technical Memorandum
#' NESDIS NGDC-24. National Geophysical Data Center, NOAA. doi:10.7289/V5C8276M
#' [access date: Aug 30, 2017].
download.topo <- function(west, east, south, north, resolution, format, server,
                           destdir=".", destfile, force=FALSE,
                           debug=getOption("dacDebug", 0))
{
    if (missing(server)) {
        server <- "https://gis.ngdc.noaa.gov/cgi-bin/public/wcs/etopo1.xyz"
        ## server <- "http://mapserver.ngdc.noaa.gov/cgi-bin/public/wcs/etopo1.xyz" 
        ## server <- "http://maps.ngdc.noaa.gov/mapviewer-support/wcs-proxy/wcs.groovy"
    }
    if (missing(destdir))
        destdir <- "."
    if (missing(format))
        format <- "gmt"
    if (missing(resolution))
        resolution <- 4
    res <- resolution / 60
    if (west > 180)
        west <- west - 360
    if (east > 180)
        east <- east - 360
    wName <- paste(abs(round(west,2)), if (west <= 0) "W" else "E", sep="")
    eName <- paste(abs(round(east,2)), if (east <= 0) "W" else "E", sep="")
    sName <- paste(abs(round(south,2)), if (south <= 0) "S" else "N", sep="")
    nName <- paste(abs(round(north,2)), if (north <= 0) "S" else "N", sep="")
    resolutionName <- paste(resolution, "min", sep="")
    if (missing(destfile))
        destfile <- paste("topo", wName, eName, sName, nName, resolutionName, sep="_")
    formatChoices <- c("aaigrid", "gmt", "netcdf")
    formatId <- pmatch(format, formatChoices)
    if (is.na(formatId))
        stop("'format' must be one of the following: '", paste(formatChoices, collapse="' '"), "', but it is '", format, "'")
    format <- formatChoices[formatId]
    filename <- ""
    if (format=="netcdf") {
        destfile <- paste(destfile, "_netcdf.nc", sep="")
        filename <- "etopo1.nc"
    } else if (format=="gmt") {
        destfile <- paste(destfile, "_gmt.nc", sep="")
        filename <- "etopo1.grd"
    } else if (format=="aiagrid") {
        destfile <- paste(destfile, "_aiagrid.asc", sep="")
        filename <- "etopo1.asc"
    } else {
        stop("unrecognized file format")
    }
    destination <- paste(destdir, destfile, sep="/")
    ## The URLS are reverse engineered from the website
    ##
    ## Menu item 'ArcGIS ASCII Grid'
    ## http://maps.ngdc.noaa.gov/mapviewer-support/wcs-proxy/wcs.groovy?filename=etopo1.asc&request=getcoverage&version=1.0.0&service=wcs&coverage=etopo1&CRS=EPSG:4326&format=aaigrid&resx=0.016666666666666667&resy=0.016666666666666667&bbox=-66.26953124998283,42.03297433243247,-57.788085937485086,46.95026224217615

    ## Menu item 'NetCDF' yields format="netcdf", as below
    ## http://maps.ngdc.noaa.gov/mapviewer-support/wcs-proxy/wcs.groovy?filename=etopo1.nc&request=getcoverage&version=1.0.0&service=wcs&coverage=etopo1&CRS=EPSG:4326&format=netcdf&resx=0.016666666666666667&resy=0.016666666666666667&bbox=-63.69873046873296,44.824708282290764,-62.3803710937333,45.259422036342194
    ##
    ## Menu item 'GMT NetCDF' yields format="gmt", as below
    ## http://maps.ngdc.noaa.gov/mapviewer-support/wcs-proxy/wcs.groovy?filename=etopo1.grd&request=getcoverage&version=1.0.0&service=wcs&coverage=etopo1&CRS=EPSG:4326&format=gmt&resx=0.016666666666666667&resy=0.016666666666666667&bbox=-66.26953124998283,42.03297433243247,-57.788085937485086,46.95026224217615
    ## http://maps.ngdc.noaa.gov/mapviewer-support/wcs-proxy/wcs.groovy?filename=etopo1.grd&request=getcoverage&version=1.0.0&service=wcs&coverage=etopo1&CRS=EPSG:4326&format=gmt&resx=0.016666666666666667&resy=0.016666666666666667&bbox=-63.69873046873296,44.824708282290764,-62.3803710937333,45.259422036342194
    url <- sprintf("%s?filename=%s&request=getcoverage&version=1.0.0&service=wcs&coverage=etopo1&CRS=EPSG:4326&format=%s&resx=%f&resy=%f&bbox=%f,%f,%f,%f",
                   server, filename, format, res, res, west, south, east, north)
    dacDebug(debug, "source url:", url, "\n")
    if (!force && 1 == length(list.files(path=destdir, pattern=paste("^", destfile, "$", sep="")))) {
        dacDebug(debug, "Not downloading", destfile, "because it is already present in", destdir, "\n")
    } else {
        download.file(url, destination)
        dacDebug(debug, "Downloaded file stored as '", destination, "'\n", sep="")
    }
    destination
}
