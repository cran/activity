#' Animal activity statistics
#'
#' Provides functions to estimate and compare activity parameters from sensor data.
#'
#' @details Sensors that record active animals (eg camera traps) build up a record of
#' the distribution of activity over the course of the day. Records are more frequent
#' when animals are more active, and less frequent or absent when animals are inactive.
#' The area under the distribution of records thus contains information on the overall
#' level of activity in a sampled population. This package provides tools for plotting
#' activity distributions, quantifying the overall level of activity with error, and
#' statistically comparing distributions through bootstrapping.
#'
#' The core function is \code{fitact}, which creates an \code{actmod} object containing
#' the circular kernel PDF, and the activity level estimate derived from this. The
#' generic plot function for \code{actmod} objects plots the distribution. Functions
#' starting with \code{compare} make statistical comparisons between distributions or
#' activity estimates. Note that all time or other circular data should be in radians
#' (in the range 0 to 2*pi).
#'
#' @references Rowcliffe, M., Kays, R., Kranstauber, B., Carbone, C., Jansen, P.A. (2014) Quantifying animal activity level using camera trap data. Methods in Ecology and Evolution.
#' @name activity
"_PACKAGE"

#' Animal record time of day data
#'
#' Barro Colorado Island 2008 data: times of day at which animal records occured
#' (\code{time}), together with species (\code{species}).
#'
#' @format A dataframe with 17820 observations and 2 variables.
#' @source http://dx.doi.org/10.6084/m9.figshare.1160536
#' @name BCItime
#' @docType data
NULL

#' Animal speed data
#'
#' Barro Colorado Island 2008 data: speeds of animal passages past camera traps
#' (\code{speed}), together with species (\code{species}) and time of day (\code{time})
#' for each record.
#'
#' @format A dataframe with 2204 observations and 3 variables.
#' @source http://dx.doi.org/10.6084/m9.figshare.1160536
#' @name BCIspeed
#' @docType data
NULL

#' Activity model class.
#'
#' An S4 class describing activity models fitted to time of observation data.
#'
#' @slot data Object of class \code{"numeric"}, the input data.
#' @slot wt Object of class \code{"numeric"}, weights applied to the data.
#' @slot bw Object of class \code{"numeric"}, kernel bandwidth.
#' @slot adj Object of class \code{"numeric"}, kernel bandwidth adjustment multiplier.
#' @slot pdf Object of class \code{"matrix"} describing fitted probability density function:
#'  Column 1: A regular sequence of radian times at which PDF evaluated; range is [0, 2*pi] if unbounded, and sequence steps are range difference divided by 512.
#'  Column 2: Corresponding circular kernel PDF values.
#' Additionally if errors bootstrapped:
#'  Column 3: PDF standard error.
#'  Column 4: PDF lower 95\% confidence limit. Column 5: PDF upper 95\% confidence limit.
#' @slot act Object of class \code{"numeric"} giving activity level estimate and, if errors boostrapped, standard error and 95 percent confidence limits.
#' @export
setClass("actmod",
         representation(data="numeric", wt="numeric", bw="numeric", adj="numeric",
                        pdf="matrix", act="numeric"))

#' An S4 class describing linear-circular relationships.
#'
#' @slot data Object of class \code{"data.frame"}, the input data, with columns
#' \code{lindat} (linear data) and \code{circdat} (circular data).
#' @slot fit Object of class \code{"data.frame"}, summary of the model fit, with columns:
#'  \code{x}: A regular ascending sequence from 0 to 2*pi at which other columns evaluated;
#'  \code{fit}: The linear fitted values;
#'  \code{p}: The two tailed probability of observing the fitted values under a random (null) circular distribution;
#'  \code{nullLCL}: The lower 95\% confidence limit of the null distribution;
#'  \code{nullUCL}: The upper 95\% confidence limit of the null distribution.
#' @export
setClass("lincircmod", representation(data="data.frame", fit="data.frame"))


#' von Mises density function
#'
#' Probability density function for the von Mises circular distribution.
#'
#' If more than one of x, mu and k have length > 1, values are recycled.
#'
#' @param x numeric angles (assumed to be radian).
#' @param mu numeric, the mean direction of the distribution.
#' @param k non-negative numeric, the concentration parameter distribution (kappa).
#' @param log if TRUE log probabilities are returned.
#' @return Probability density value(s).
#' @examples
#' dvonm(seq(0, 2*pi, len=10), pi, 1)
#' @export
dvonm <- function(x, mu, k, log=FALSE){
  if(any(k<0)) stop("The concentration parameter k must be non-negative")
  x <- x %% (2*pi)
  mu <- mu %% (2*pi)
  res <- (exp(cos(x-mu) - 1))^k / (2 * pi * besselI(k, 0, TRUE))
  if(log) res <- log(res)
  res
}

#' title trigonometric moment length
#'
#' Calculate trigonometric moment length
#'
#' @param x a vector of circular values, assumed to be radian.
#' @param p order of trigonometric moment to be computed.
#' @return Trigonometric moment length of the input.
#' @export
trigmolen <- function(x, p){
  n <- length(x)
  cmean <- atan2(sum(sin(x)), sum(cos(x)))
  sin.p <- sum(sin(p * (x - cmean)))/n
  cos.p <- sum(cos(p * (x - cmean)))/n
  sqrt(sin.p^2 + cos.p^2)
}

#' Index of overlap between circular distributions.
#'
#' Calculates Dhat4 overlap index (see reference) between two kernel distributions.
#'
#' Uses linear interpolation to impute values from kernel distributions.
#'
#' @param fit1,fit2 Fitted activity models of class actmod created using function fitact.
#' @return Scalar overlap index (specifically Dhat4).
#' @references Ridout, M.S. & Linkie, M. (2009) Estimating overlap of daily activity patterns from camera trap data. Journal of Agricultural Biological and Environmental Statistics, 14, 322-337.
#' @examples
#' data(BCItime)
#' oceAct <- fitact(subset(BCItime, species=="ocelot")$time*2*pi)
#' broAct <- fitact(subset(BCItime, species=="brocket")$time*2*pi)
#' ovl4(oceAct, broAct)
#' @export
ovl4 <- function(fit1, fit2){
  f <- stats::approxfun(fit1@pdf[,1], fit1@pdf[,2])
  g <- stats::approxfun(fit2@pdf[,1], fit2@pdf[,2])
  fx <- f(fit1@data)
  gx <- g(fit1@data)
  fy <- f(fit2@data)
  gy <- g(fit2@data)
  xr <- gx/fx
  yr <- fy/gy
  (mean(ifelse(xr>1, 1, xr)) + mean(ifelse(yr>1, 1, yr))) / 2
}

#' Calculate circular kernel bandwidth.
#'
#' Uses an optimisation procedure to calculate the circular kernel bandwidth giving the best fit to the data.
#'
#' Mainly for internal use.
#'
#' @param dat Numeric data vector of radian times.
#' @param K Integer number of values of kappa over which to maximise (see references for details).
#' @return Single numeric bandwidth value.
#' @references Ridout, M.S. & Linkie, M. (2009) Estimating overlap of daily activity patterns from camera trap data. Journal of Agricultural Biological and Environmental Statistics, 14, 322-337.
#' @export
bwcalc <- function(dat,K=3)
{  if(!all(dat>=0 & dat<=2*pi)) warning("some dat values are <0 or >2*pi, expecting radian data")
   if(max(dat)<1) warning("max(dat) < 1, expecting radian data")

   minfunc <- function(kap,k,dat){
     trigmom <- trigmolen(dat, k)
     (besselI(kap,k)/besselI(kap,0) - trigmom)^2
   }
   kapk.calc <- function(k,dat)
     stats::optimise(minfunc,c(0,100),k,dat)$minimum
   kap <- max(sapply(1:K, kapk.calc, dat))
   ((3*length(dat)*kap^2*besselI(2*kap,2)) / (4*pi^0.5*besselI(kap,0)^2))^(2/5)
}

#' Circular kernel probability density function.
#'
#' Optionally weighted Von Mises kernel probability densities.
#'
#' If \code{bw} not provided it is calculated internally using \code{bw.calc}. The \code{adj} argument is used to adjust \code{bw} to facilitate exploration of fit flexibility.
#'
#' @param x Numeric vector of radian times at which to evaluate the PDF.
#' @param dat Numeric vector of radian time data to which the PDF is fitted.
#' @param wt A numeric vector of weights for each \code{dat} value.
#' @param bw Numeric value for kernel bandwidth.
#' @param adj Numeric kernel bandwidth multiplier.
#' @return Numeric vector of probability densities evaluated at \code{x}.
#' @seealso \code{\link{bwcalc}}
#' @examples
#' #Example with made up input
#' tt <- runif(100,0,2*pi)
#' xx <- seq(0,2*pi, pi/256)
#' pdf <- dvmkern(xx, tt)
#' plot(xx, pdf, type="l")
#' @export
dvmkern <- function(x,dat,wt=NULL,bw=NULL,adj=1){
  if(!all(dat>=0 & dat<=2*pi)) warning("some dat values are <0 or >2*pi, expecting radian data")
  if(max(dat)<1) warning("max(dat) < 1, expecting radian data")
  if(!all(x>=0 & x<=2*pi)) warning("some x values are <0 or >2*pi, expecting radian values")
  if(!is.null(wt) & length(wt)!=length(dat)) stop("dat and wt have different lengths")

  if(is.null(bw)) bw <- bwcalc(dat)
  if(is.null(wt)) wt <- rep(1,length(dat))
  dx <- expand.grid(dat,x)
  dif <- abs(dx[,2]-dx[,1])
  i <- dif>pi
  dif[i] <- 2*pi-dif[i]
  prob <- dvonm(dif, 0, bw*adj)
  apply(matrix(prob*wt, nrow=length(dat)),2,sum)/sum(wt)
}

#' Random numbers from empirical distribution function.
#'
#' Random numbers drawn from an empirical distribution defined by paired values and probabilities.
#'
#' @details The distribution function is defined by \code{fit}, which must be a dataframe containing (at least) columns named:
#'  x: a regular sequence of values from which to draw;
#'  y: corresponding pdf values.
#' @param n Integer number of random numbers to return.
#' @param fit Data frame defining the emprical distribution (see details).
#' @return A numeric vector.
#' @examples
#' data(BCItime)
#' tm <- 2*pi*subset(BCItime, species=="paca")$time
#' mod <- fitact(tm)
#' rn <- redf(1000, as.data.frame(mod@pdf))
#' @export
redf <- function(n, fit){
  if(sum(c("x","y") %in% names(fit)) != 2) stop("fit must be a dataframe with (at least) columns named x and y")
  if(diff(range(diff(fit$x)))>0.0001) stop("x doesn't seem to be a regular sequence")

  df <- (fit$y[-1]+fit$y[-nrow(fit)])/2
  cdf <- c(0,cumsum(df)/sum(df))
  rn <- stats::runif(n)
  stats::approx(cdf, fit$x, rn)$y
}

#' Modified kernel density function
#'
#' Modifies \code{stats::density} by:
#'  Adding SE and 95\% confidence intervals for the density to the output; and
#'  Truncating calculation (not just reporting) of density  values on from and/or to.
#'
#' @details Truncation copes with cases where no data are available outside truncation points.
#' Truncation is achieved by fitting the density to the data augmented by reflecting it
#' across each bound using the optimal bandwidth for the unaugmented data, and returning
#' the resulting densities for the region between the bounds.
#'
#' @param x numeric data vector
#' @param reps bootstrap iterations for SE/interval calculation; set to NULL to suppress
#' @param ... Additional arguments passed to \code{stas::density}
#' @return A list with the same components as \code{stats::density} output plus:
#'  \code{se}: standard error of the density
#'  \code{lcl}, \code{ucl}: lower and upper 95\% confidence intervals of the density

#' @examples
#' data(BCItime)
#' tm <- subset(BCItime, species=="ocelot")$time
#' dens <- density2(tm, from=0.25, to=0.75)
#' plot(dens$x, dens$y, type="l")
#' @export
density2 <- function(x, reps=999, ...){
  prm <- list(...)
  prmnm <- names(prm)

  if(sum(c("from","to") %in% prmnm)==2)
    if(prm$from>prm$to) stop("When double-bounded, from must be less than to")

  warn <- FALSE
  dmult <- 1
  xx <- x
  wt <- prm$weights
  if("from" %in% prmnm){
    if(any(x<prm$from)){
      warn <- TRUE
      x <- x[x>prm$from]
      if(!is.null(wt)) prm$weights <- prm$weights[x>prm$from]
    }
    dmult <- dmult+1
    xx <- c(xx, 2*prm$from-x)
    if(!is.null(wt)) wt <- c(wt, prm$weights)
  }
  if("to" %in% prmnm){
    if(any(x>prm$to)){
      warn <- TRUE
      x <- x[x<prm$to]
      if(!is.null(prm$weights)) prm$weights <- prm$weights[x<prm$to]
    }
    dmult <- dmult+1
    xx <- c(xx, 2*prm$to-x)
    if(!is.null(wt)) wt <- c(wt, prm$weights)
    }
  if(warn) warning("Some x values outside bounds were removed")
  if(!is.null(wt)) wt <- wt/sum(wt)
  prm$weights <- wt
  if(!("bw" %in% prmnm & is.numeric(prm$bw))){
    bw <- stats::density(x, ...)$bw
    prm$bw <- bw
  }

  dens <- do.call(stats::density, append(list(x=xx), prm))
  dens$y <- dens$y*dmult
  if(!is.null(reps)){
    f <- function(){
      xs <- sample(xx, length(xx), replace=T)
      denss <- do.call(stats::density, append(list(x=xs), prm))
      dmult*denss$y
    }
    bsres <- replicate(reps, f())
    se <- t(apply(bsres, 1, stats::sd))
    ci <- t(apply(bsres, 1, stats::quantile, c(0.025,0.975)))
    dens <- c(dens, se=se, lcl=list(ci[,1]), ucl=list(ci[,2]))
  }
  dens
}

#' Fit activity model to time-of-day data
#'
#' Fits kernel density to radian time-of-day data and estimates activity level from this distribution.
#' Optionally: 1. bootstraps the distribution, in which case SEs and confidence limits are also
#' stored for activity level and PDF; 2. weights the distribution; 3. truncates the distribution at given times.
#'
#' @details When no \code{bounds} are given (default), a circular kernel distribution is fitted using \code{dvmkern}.
#' Otherwise, a normal kernel distribution is used, truncated at the values of \code{bounds}, using \code{density2}.
#'
#' The bandwidth adjustment multiplier \code{adj} is provided to allow
#' exploration of the effect of adjusting the internally calculated bandwidth on
#' accuracy of activity level estimates.
#'
#' The alternative bootstrapping methods defined by \code{sample} are:
#' \itemize{
#'  \item{\code{"none"}: no bootstrapping}
#'  \item{\code{"data"}: sample from the data}
#'  \item{\code{"model"}: sample from the fitted probability density distribution}
#'  }
#' It's generally better to sample from the data, but sampling from
#' the fitted distribution can sometimes provide more sensible confidence intervals when
#' the number of observations is very small.
#' @param dat A numeric vector of radian time-of-day data.
#' @param wt A numeric vector of weights for each \code{dat} value.
#' @param reps Number of bootstrap iterations to perform. Ignored if \code{sample=="none"}.
#' @param bw Numeric value for kernel bandwidth. If NULL, calculated internally.
#' @param adj Numeric bandwidth adjustment multiplier.
#' @param sample Character string defining sampling method for bootstrapping errors (see details).
#' @param bounds A two-element vector defining radian bounds at which to truncate.
#' @param show Logical whether or not to show a progress bar while bootstrapping.
#' @return An object of type \code{actmod}
#' @examples
#' #Fit without confidence limits
#' data(BCItime)
#' tm <- 2*pi*subset(BCItime, species=="brocket")$time
#' mod1 <- fitact(tm)
#' plot(mod1)
#'
#' #Fit with confidence limits (limited reps to speed up)
#' mod2 <- fitact(tm, sample="data", reps=10)
#' plot(mod2)
#'
#' #Fit weighted function to correct for detection radius 1.2 times higher
#' #by day than by night, assuming day between pi/2 (6 am) and pi*2/3 (6 pm)
#' weight <- 1/ifelse(tm>pi/2 & tm<pi*3/2, 1.2, 1)
#' mod3 <- fitact(tm, wt=weight)
#' plot(mod3)
#' #Overplot unweighted version for comparison
#' plot(mod1, add=TRUE, tline=list(col=2))
#'
#' #Fit truncated function to consider only night time records,
#' #assuming night between pi*3/2 (6 pm) and pi/3 (6 am)
#' mod4 <- fitact(tm, bounds=c(pi*3/2, pi/2))
#' plot(mod4, centre="night")
#' @export
fitact <- function(dat, wt=NULL, reps=999, bw=NULL, adj=1, sample=c("none","data","model"),
                   bounds=NULL, show=TRUE)
{ if(!is.null(wt) & length(wt)!=length(dat)) stop("dat and wt have different lengths")

  sample <- match.arg(sample)
  if(!is.null(wt)){
    if(any(wt<0)) stop("Weights must be non-negative")
    wt <- wt/sum(wt)
  }

  if(is.null(bounds)){ #circular kernel
    if(is.null(bw)) bw <- bwcalc(dat)
    x <- seq(0,2*pi,pi/256)
    pdf <- dvmkern(x, dat, wt, adj, bw)
    act <- 1/(2*pi*max(pdf))
  } else{ #truncated normal kernel
    if(length(bounds)!=2) stop("If provided, bounds must be a two-element vector")
    if(min(bounds)<0 | max(bounds)>2*pi) stop("bounds must be radian (between 0 and 2*pi)")
    bdiff <- diff(bounds)
    if(diff(bounds)<0){
      dat <- dat-ifelse(dat>pi, 2*pi, 0)
      bounds[1] <- bounds[1]-2*pi
      bdiff <- diff(bounds)
    }
    oob <- dat<bounds[1] | dat>bounds[2]
    if(sum(oob>0)){
      warning("Some x values outside bounds were removed")
      dat <- dat[!oob]
      if(!is.null(wt)){
        wt <- wt[!oob]
        wt <- wt/sum(wt)
      }
    }
    dens <- density2(dat, from=bounds[1], to=bounds[2], weights=wt, adjust=adj,
                     bw=if(is.null(bw)) "nrd0" else bw, reps=NULL)
    bw <- dens$bw
    x <- dens$x
    pdf <- dens$y
    act <- 1/(bdiff*max(pdf))
  }

  if(sample=="none")
    sepdf <- lclpdf <- uclpdf <- seact <- lclact <- uclact <- numeric(0) else{
      if(sample=="model")
        samp <- matrix(redf(reps*length(dat), data.frame(x=x,y=pdf)), ncol=reps) else
          samp <- matrix(sample(dat, reps*length(dat), replace=TRUE, prob=wt), ncol=reps)

        if(is.null(bounds)){
          if(show)
            pdfs <- pbapply::pbapply(samp, 2, function(dat) dvmkern(x,dat,wt,adj=adj)) else
              pdfs <- apply(samp, 2, function(dat) dvmkern(x,dat,wt,adj=adj))
        } else
          if(show)
            pdfs <- pbapply::pbapply(samp, 2, function(dat) density2(dat, from=bounds[1], to=bounds[2],
                                     weights=wt, adjust=adj, bw=if(is.null(bw)) "nrd0" else bw,
                                     reps=NULL)$y) else
              pdfs <- apply(samp, 2, function(dat) density2(dat, from=bounds[1], to=bounds[2], weights=wt,
                          adjust=adj, bw=if(is.null(bw)) "nrd0" else bw, reps=NULL)$y)

    sepdf <- apply(pdfs,1,stats::sd)
    lclpdf <- apply(pdfs,1,stats::quantile,probs=0.025)
    uclpdf <- apply(pdfs,1,stats::quantile,probs=0.975)
    if(is.null(bounds)) acts <- 1/(2*pi*apply(pdfs,2,max)) else
      acts <- 1/(bdiff*apply(pdfs,2,max))
    seact <- stats::sd(acts)
    lclact <- stats::quantile(acts,0.025)
    uclact <- stats::quantile(acts,0.975)
  }

  if(is.null(wt)) wt <- 1
  if(min(x)<0){
    dat <- dat+ifelse(dat<0, 2*pi, 0)
    x <- x+ifelse(x<0, 2*pi, 0)
  }
  pdftab <- cbind(x=x, y=pdf, se=sepdf, lcl=lclpdf, ucl=uclpdf)[order(x), ]

  methods::new("actmod", data=dat, wt=wt, bw=bw, adj=adj, pdf=pdftab,
      act=c(act=act, se=seact, lcl=lclact, ucl=uclact))
}

#' Compare circular distributions.
#'
#' Randomisation test for the probability that two sets of circular observations come from the same distribution.
#'
#' Calculates overlap index Dhat4 (see references) for the two fitted distributions, then generates a null distribution of overlap indices using data sampled randomly with replacement from the combined data.
#' This randomised distribution is then used to define an empirical probability distribution against which  the probability that the observed overlap arose by chance is judged.
#' When one or both fitted models use weighted distributions, sampling probabilities are taken from the weights. If both models are weighted, the weights must therefore be on the same scale.
#'
#' @param fit1,fit2 Fitted activity models of class actmod created using function fitact.
#' @param reps Number of bootstrap iterations.
#' @return A named 4-element vector: obs = observed overlap index; null = mean null overlap index; seNull = standard error of the null distribution; pNull = probability observed index arose by chance.
#' @references Ridout, M.S. & Linkie, M. (2009) Estimating overlap of daily activity patterns from camera trap data. Journal of Agricultural Biological and Environmental Statistics, 14, 322-337.
#' @examples
#' #Example with bootstrap reps limited to reduce run time
#' data(BCItime)
#' tPaca <- 2*pi*BCItime$time[BCItime$species=="paca"]
#' tRat <- 2*pi*BCItime$time[BCItime$species=="rat"]
#' fPaca <- fitact(tPaca)
#' fRat <- fitact(tRat)
#' compareCkern(fPaca,fRat,reps=10)
#' @export
compareCkern <- function(fit1, fit2, reps=999){
  if(!inherits(fit1, "actmod") | !inherits(fit2, "actmod"))
    stop("Input must be fitted activity models (class actmod)")
  bnd <- range(fit1@pdf[,1])
  if(!all(bnd==range(fit2@pdf[,1])))
    stop("Distribution bounds are not identical")

  if(diff(bnd)==2*pi) bnd <- NULL
  olp <- ovl4(fit1,fit2)
  y1 <- fit1@data
  y2 <- fit2@data
  w1 <- fit1@wt
  w2 <- fit2@wt
  if(length(w1)==1) w1 <- rep(1, length(y1))
  if(length(w2)==1) w2 <- rep(1, length(y2))
  y <- c(y1,y2)
  w <- c(w1,w2)
  samp <- matrix(sample(1:length(y), reps*length(y), replace=T, prob=w), nrow=reps)
  f <- function(s){
    m1 <- fitact(y[s[1:length(y1)]], sample="n", bw=fit1@bw, adj=fit1@adj, bounds=bnd)
    m2 <- fitact(y[s[(length(y1)+1):length(y)]], sample="n", bw=fit1@bw, adj=fit1@adj, bounds=bnd)
    ovl4(m1,m2)
  }
  res <- pbapply::pbapply(samp, 1, f)
  fun <- stats::ecdf(res)
  c(obs=olp, null=mean(res), seNull=stats::sd(res), pNull=fun(olp))
}


#' Compare activity level estimates
#'
#' Wald test for the statistical difference between two or more activitiy level estimates.
#'
#' Uses a Wald test to ask whether the difference between estimates a1 and a2 is
#' significantly different from 0: statistic W = (a1-a2)^2 / (SE1^2+SE2^2) tested
#' on chi-sq distribution with 1 degree of freedom.
#'
#' @param fits A list of fitted \code{actmod} objects
#' @return A matrix with 4 columns: 1. differences between estimates; 2. SEs of the differences; 3. Wald statistics; 4. p-values (H0 is no difference between estimates). Matrix rows give all possible pairwise comparisons, numbered in the order in which they entered in the list \code{fits}.
#' @examples
#' #Test whether paca have a sigificantly different activity level from rat.
#' #Bootstrap reps limited to speed up example.
#' data(BCItime)
#' tPaca <- 2*pi*BCItime$time[BCItime$species=="ocelot"]
#' tRat <- 2*pi*BCItime$time[BCItime$species=="rat"]
#' fPaca <- fitact(tPaca, sample="data", reps=10)
#' fRat <- fitact(tRat, sample="data", reps=10)
#' fPaca@act
#' fRat@act
#' compareAct(list(fPaca,fRat))
#' @export
compareAct <- function(fits)
{ if(!inherits(fits, "list") | !all(unlist(lapply(fits,inherits,"actmod"))))
    stop("fits must be a list of actmod objects")
  if(min(unlist(lapply(fits, function(x) length(x@act))))==1)
    stop("all input model fits must be boostrapped")

  len <- length(fits)
  i <- rep(1:(len-1), (len-1):1)
  j <- unlist(sapply(2:len, function(i) i:len))
  acts <- unlist(lapply(fits, function(fit) fit@act[1]))
  seacts <- unlist(lapply(fits, function(fit) fit@act[2]))
  dif <- acts[i]-acts[j]
  vardif <- seacts[i]^2 + seacts[j]^2
  W <- dif^2/vardif
  prob <- 1-stats::pchisq(W,1)
  res <- cbind(Difference=dif, SE=sqrt(vardif), W=W, p=prob)
  dimnames(res)[[1]] <- paste(i,j,sep="v")
  res
}

#' Compare activity between times of day
#'
#' Uses a Wald test to statistically compare activity levels at given radian times of day for a fitted activity distribution.
#'
#' Bootrapping the activity model yields standard error estimates for the PDF. This function uses these SEs to compute a Wald statistic for the difference between PDF values (by inference activity levels) at given times of day: statistic W = (a1-a2)^2 / (SE1^2+SE2^2) tested on chi-sq distribution with 1 degree of freedom.
#'
#' @param fit Fitted \code{actmod} object with errors boostrapped (fit using \code{fitact} with \code{sample} argument != "none").
#' @param times Numeric vector of radian times of day at which to compare activity levels. All pairwise comparisons are made.
#' @return A matrix with 4 columns: 1. differences between PDF values; 2. SEs of the differences; 3. Wald statistics; 4. p-values (H0 is no difference between estimates). Matrix rows give all possible pairwise comparisons, numbered in the order in which they appear in vector \code{times}.
#' @examples
#' data(BCItime)
#' tPaca <- 2*pi*BCItime$time[BCItime$species=="paca"]
#' fPaca <- fitact(tPaca, sample="data", reps=10)
#' plot(fPaca)
#' compareTimes(fPaca, c(5.5,6,0.5,1))
#' @export
compareTimes <- function(fit, times)
{ if(!inherits(fit, "actmod")) stop("fit input must be an actmod object")
  if(!all(times>=0 & times<=2*pi)) stop("some times are <0 or >2*pi, expecting radian data")

  len <- length(times)
  i <- rep(1:(len-1), (len-1):1)
  j <- unlist(sapply(2:len, function(i) i:len))
  k <- findInterval(times, fit@pdf[,1])
  p <- (times-fit@pdf[,1][k]) / (fit@pdf[,1][k+1]-fit@pdf[,1][k])
  pdfs1 <- fit@pdf[,2][k]
  pdfs2 <- fit@pdf[,2][k+1]
  pdfs <- pdfs1 + p*(pdfs2-pdfs1)
  sepdfs1 <- fit@pdf[,3][k]
  sepdfs2 <- fit@pdf[,3][k+1]
  sepdfs <- sepdfs1 + p*(sepdfs2-sepdfs1)
  dif <- pdfs[i]-pdfs[j]
  vardif <- sepdfs[i]^2 + sepdfs[j]^2
  W <- dif^2/vardif
  prob <- 1-stats::pchisq(W,1)
  res <- cbind(Difference=dif, SE=sqrt(vardif), W=W, p=prob)
  dimnames(res)[[1]] <- paste(i,j,sep="v")
  res
}

#' Linear-circular kernel fit
#'
#' Fits a Von Mises kernel distribution describing a linear variable as a function of a circular predictor.
#'
#' @param x Numeric vector of radian values at which to evaluate the distribution.
#' @param circdat Numeric vector of radian data matched with \code{lindat}.
#' @param lindat Numeric vector of linear data matched with \code{circdat}.
#' @return A numeric vector of fitted \code{lindat} values matched with \code{x}.
#' @references Xu, H., Nichols, K. & Schoenberg, F.P. (2011) Directional kernel regression for wind and fire data. Forest Science, 57, 343-352.
#' @examples
#' data(BCIspeed)
#' i <- BCIspeed$species=="ocelot"
#' log_speed <- log(BCIspeed$speed[i])
#' time <- BCIspeed$time[i]*2*pi
#' circseq <- seq(0,2*pi,pi/256)
#' trend <- lincircKern(circseq, time, log_speed)
#' plot(time, log_speed, xlim=c(0, 2*pi))
#' lines(circseq, trend)
#' @export
lincircKern <- function(x,circdat,lindat)
{ if(length(lindat)!=length(circdat))
  stop("lindat and circdat lengths are unequal")
  if(min(circdat)<0 | max(circdat)>2*pi)
    stop("circdat values not between 0 and 2*pi, expecting radian data")
  if(min(x)<0 | max(x)>2*pi)
    stop("x values not between 0 and 2*pi, expecting radian values")

  hs <- 1.06 * min(stats::sd(lindat), (stats::quantile(lindat,0.75)-stats::quantile(lindat,0.25))/1.34) *
    length(lindat)^-0.2
  bw <- 1/hs^2
  dx <- expand.grid(circdat,x)
  dif <- abs(dx[,2]-dx[,1])
  i <- dif>pi
  dif[i] <- 2*pi-dif[i]
  prob <- matrix(dvonm(dif, 0, bw), nrow=length(circdat))
  apply(prob,2,function(z) mean(z*lindat)/mean(z))
}

#' Linear-circular regression
#'
#' Fits a Von Mises kernel distribution describing a linear variable as a function
#' of a circular predictor, and boostraps the null distribution in order to evaluate
#' significance of radial variation in the linear variable.
#'
#' Deviation of \code{lindat} from the null expecation is assessed either visually
#' by the degree to which the fitted distribution departs from the null confidence
#' interval (use generic plot function), or quantitatively by column \code{p} of
#' slot \code{fit} in the resulting \code{lincircmod-class} object.
#'
#' @param circdat Numeric vector of radian data matched with \code{lindat}.
#' @param lindat Numeric vector of linear data matched with \code{circdat}.
#' @param pCI Single numeric value between 0 and 1 defining proportional confidence interval to return.
#' @param reps Integer number of bootstrap repetitions to perform.
#' @param res Resolution of fitted distribution and null confidence interval - specifically a single integer number of points on the circular scale at which to record distributions.
#' @return An object of type \code{\link{lincircmod-class}}
#' @references Xu, H., Nichols, K. & Schoenberg, F.P. (2011) Directional kernel regression for wind and fire data. Forest Science, 57, 343-352.
#' @examples
#' #Example with reps limited to increase speed
#' data(BCIspeed)
#' i <- BCIspeed$species=="ocelot"
#' sp <- log(BCIspeed$speed[i])
#' tm <- BCIspeed$time[i]*2*pi
#' mod <- fitlincirc(tm, sp, reps=50)
#' plot(mod, CircScale=24, xaxp=c(0,24,4), xlab="Time", ylab="log(speed)")
#' legend(8,-3, c("Fitted speed", "Null CI"), col=1:2, lty=1:2)
#' @export
fitlincirc <- function(circdat, lindat, pCI=0.95, reps=10, res=512)
{ if(length(lindat)!=length(circdat))
  stop("lindat and circdat lengths are unequal")
  if(min(circdat)<0 | max(circdat)>2*pi)
    stop("circdat values not between 0 and 2*pi, expecting radian data")
  if(max(circdat)<1)
    warning("max(circdat) < 1, expecting radian data")

  n <- length(circdat)
  x <- seq(0,2*pi,2*pi/res)

  bs <- pbapply::pbsapply(1:reps, function(i)
  {  j <- sample(1:n,n,TRUE)
     lincircKern(x,circdat[j],lindat)
  })
  nulllcl <- apply(bs,1,stats::quantile,(1-pCI)/2)
  nullucl <- apply(bs,1,stats::quantile,(1+pCI)/2)
  fit <- lincircKern(x,circdat,lindat)
  p <- sapply(1:(res+1), function(i)
  { f <- stats::ecdf(bs[i,])
    f(fit[i])
  })
  p[p>0.5] <- 1-p[p>0.5]
  p <- 2*p

  methods::new("lincircmod", data=data.frame(circdat=circdat, lindat=lindat),
      fit=data.frame(x=x, fit=fit, p=p, nullLCL=nulllcl, nullUCL=nullucl))
}

#' Plot activity distribution
#'
#' Plot an activity probability distribution from a fitted \code{actmod} object.
#'
#' @details When xunit=="clock", The underlying numeric range of the x-axis is [0,24] if centre=="day",
#' or [-12,12] if centre=="night".
#' @param x Object of class \code{actmod}.
#' @param xunit Character string defining x-axis unit.
#' @param yunit Character string defining y-axis unit.
#' @param data Character string defining whether to plot the data distribution and if so which style to use.
#' @param centre Character string defining whether to centre the plot on midday or midnight.
#' @param dline List of plotting parameters for data lines.
#' @param tline List of plotting parameters for trend line.
#' @param cline List of plotting parameters for trend confidence interval lines.
#' @param add Logical defining whether to create a new plot (default) or add to an existing plot.
#' @param xaxis List of plotting parameters to pass to axis command for x-axis plot (see axis for arguments).
#' @param ... Additional arguments passed to internal plot call affecting only the plot frame and y axis. Modify x axis through xaxis.
#' @return No return value, called to create a plot visualising an activity model.
#' @examples
#' data(BCItime)
#' otm <- 2*pi*subset(BCItime, species=="ocelot")$time
#' btm <- 2*pi*subset(BCItime, species=="brocket")$time
#' omod <- fitact(otm)
#' bmod <- fitact(btm)
#' plot(omod, yunit="density", data="none")
#' plot(bmod, yunit="density", data="none", add=TRUE, tline=list(col="red"))
#' legend("topleft", c("Ocelot", "Brocket deer"), col=1:2, lty=1)
#'
#' mod <- fitact(otm, sample="data", reps=10)
#' plot(mod, dline=list(col="grey"),
#'           tline=list(col="red", lwd=2),
#'           cline=list(col="red", lty=3))
#'
#' mod2 <- fitact(otm, bounds=c(pi*3/2, pi/2))
#' plot(mod2, centre="night")
#' plot(mod2, centre="night", xlim=c(-6,6), xaxis=list(at=seq(-6,6,2)))
#' @export
plot.actmod <- function(x, xunit=c("clock","hours","radians"), yunit=c("frequency","density"),
                        data=c("histogram","rug","both","none"), centre=c("day","night"),
                        dline=list(lwd=ifelse(data=="rug", 0.1, 1)), tline=NULL, cline=list(lty=2),
                        add=FALSE, xaxis=NULL, ...){

  #function sets up the plot parameters with appropriate scales and labels with flexibility for modifcation using ...
  setup <- function(...){
    pprm <- list(...)
    pprm <- append(list(x=xlim, y=ylim, type="n", xaxt="n"), pprm)
    if(!("ylim" %in% names(pprm))) pprm <- append(pprm, list(ylim=ylim))
    if(!("ylab" %in% names(pprm)))
      pprm <- switch(yunit,
                     "frequency"=append(pprm, list(ylab="Frequency")),
                     "density"=append(pprm, list(ylab="Density"))
      )
    if(!("xlab" %in% names(pprm)))
      pprm <- switch(xunit,
                     "clock"=append(pprm, list(xlab="Time")),
                     "hours"=append(pprm, list(xlab="Hours")),
                     "radians"=append(pprm, list(xlab="Radians"))
      )
    do.call(graphics::plot, pprm)
    xaxis <- append(list(side=1), xaxis[!(names(xaxis)=="side")])
    if(xunit=="clock"){
      if(!("at" %in% names(xaxis))){
        at <- switch(centre,
                     "day"=seq(0, 24, 6),
                     "night"=seq(-12, 12, 6)
        )
        xaxis <- append(xaxis, list(at=at))
      }
      if(!("labels" %in% names(xaxis))){
        at <- xaxis$at
        hh <- trunc(at)
        mm <- round(60*(at-trunc(at)), 0)
        hh <- hh + ifelse(hh<0,24,0) - ifelse(mm<0, 1, 0)
        mm <- mm + ifelse(mm<0, 60, 0)
        lab <- paste0(ifelse(hh<10,"0",""), hh, ":", ifelse(mm<10,"0",""), mm)
        xaxis <- append(xaxis, list(labels=lab))
      }
    }
    do.call(graphics::axis, xaxis)
  }
  ### end setup function ###

  data <- match.arg(data)
  xunit <- match.arg(xunit)
  yunit <- match.arg(yunit)
  centre <- match.arg(centre)
  if(!"lty" %in% names(cline)) cline <- append(cline, list(lty=2))

  fit <- x
  pdf <- fit@pdf
  fdata <- fit@data

  if(centre=="night"){
    if(diff(range(pdf[,1]))==2*pi | min(pdf[,1]>=0)){
      if(diff(range(pdf[,1]))==2*pi) pdf <- pdf[-1,]
      pdf[,1] <- pdf[,1] - ifelse(pdf[,1]>pi, 2*pi, 0)
      pdf <- pdf[order(pdf[,1]), ]
    }
    fdata <- fdata-ifelse(fdata>pi,2*pi,0)
    xlim <- c(-pi,pi)
  }else xlim <- c(0,2*pi)

  x <- pdf[,"x"]
  y <- pdf[,"y"]
  if(ncol(pdf)==5)
  { lcl <- pdf[,"lcl"]
  ucl <- pdf[,"ucl"]
  } else lcl <- ucl <- numeric(0)

  if(xunit=="radians") maxbrk <- 2*pi else {
    xlim <- xlim*12/pi
    x <- x*12/pi
    fdata <- fdata*12/pi
    maxbrk <- 24
  }

  if(yunit=="frequency"){
    y <- y*length(fdata)*pi/12
    lcl <- lcl*length(fdata)*pi/12
    ucl <- ucl*length(fdata)*pi/12
  }else{
    if(xunit %in% c("clock","hours")){
      y <- y*pi/12
      lcl <- lcl*pi/12
      ucl <- ucl*pi/12
    }
  }

  if(data %in% c("histogram","both")){
    h <- switch(centre,
                "day"=graphics::hist(fdata, breaks=seq(0,maxbrk,maxbrk/24), plot=F),
                "night"=graphics::hist(fdata, breaks=seq(-maxbrk/2,maxbrk/2,maxbrk/24), plot=F))
    d <- switch(yunit,
                "frequency"=h$counts,
                "density"=h$density)
    ylim <- c(0,max(y,d,ucl,na.rm=T))
  } else ylim <- c(0,max(y,ucl,na.rm=T))

  #Plot data
  if(!add) setup(...)
  if(data %in% c("histogram","both")){
    if(!"lwd" %in% names(dline)) dline <- append(dline, list(lwd=1))
    do.call(graphics::lines, append(list(x=h$breaks, y=c(d,d[1]), type="s"), dline))
  }
  if(data %in% c("rug","both")){
    if(!"lwd" %in% names(dline)) dline <- append(dline, list(lwd=0.1))
    for(i in 1:length(fdata))
      do.call(graphics::lines, append(list(x=rep(fdata[i],2), y=max(y,na.rm=T)*-c(0,0.03)), dline))
  }

  #Plot trend
  i <- x < switch(centre, "day"=ifelse(xunit=="radians", pi, 12), 0)
  do.call(graphics::lines, append(list(x=x[i], y=y[i]), tline))
  do.call(graphics::lines, append(list(x=x[!i], y=y[!i]), tline))

  #Plot conf intervals
  if(length(lcl)>0)
  { do.call(graphics::lines, append(list(x=x[i], y=lcl[i]), cline))
    do.call(graphics::lines, append(list(x=x[i], y=ucl[i]), cline))
    do.call(graphics::lines, append(list(x=x[!i], y=lcl[!i]), cline))
    do.call(graphics::lines, append(list(x=x[!i], y=ucl[!i]), cline))
  }
}

#' Plot linear-circular relationship
#'
#' Plot linear against circular data along with the fitted and null confidence limit distributions from a fitted \code{lincircmod} object.
#'
#' @param x Object of class \code{lincircmod}.
#' @param CircScale Single numeric value defining the plotting maximum of the circular scale.
#' @param tlim Numeric vector with two elements >=0 and <=1 defining the lower and upper limits at which to plot distributions; default plots the full range.
#' @param fcol,flty,ncol,nlty Define line colour (\code{col}) and type (\code{lty}) for fitted (\code{f}) and null (\code{n}) distributions; input types as for \code{col} and \code{lty}, see \code{\link{par}}.
#' @param ... Additional arguments passed to the inital plot construction, affecting axes and data plot symbols.
#' @return No return value, called to create a plot visualising a linear-circular relationship.
#' @export
plot.lincircmod <- function(x, CircScale=2*pi, tlim=c(0,1), fcol="black", flty=1, ncol="red", nlty=2, ...){

  if(min(tlim)<0 | max(tlim)>1 | length(tlim)!=2) stop("tlim should contain two values >=0 and <=1")

  fit <- x
  fit <- x@fit
  dat <- x@data
  xx <- fit$x*CircScale/(2*pi)
  LinearData <- dat$lindat
  CircularData <- dat$circdat*CircScale/(2*pi)
  range <- tlim*CircScale
  graphics::plot(CircularData, LinearData, ...)
  if(range[1]<range[2])
  { i <- xx>=range[1] & xx<=range[2]
    graphics::lines(xx[i], fit$fit[i], col=fcol, lty=flty)
    graphics::lines(xx[i], fit$nullLCL[i], col=ncol, lty=nlty)
    graphics::lines(xx[i], fit$nullUCL[i], col=ncol, lty=nlty)
  } else
  {  i <- xx>=range[1]
     graphics::lines(xx[i], fit$fit[i], col=fcol, lty=flty)
     graphics::lines(xx[i], fit$nullLCL[i], col=ncol, lty=nlty)
     graphics::lines(xx[i], fit$nullUCL[i], col=ncol, lty=nlty)
     i <- xx<=range[2]
     graphics::lines(xx[i], fit$fit[i], col=fcol, lty=flty)
     graphics::lines(xx[i], fit$nullLCL[i], col=ncol, lty=nlty)
     graphics::lines(xx[i], fit$nullUCL[i], col=ncol, lty=nlty)
  }
}


#' Convert time of day data to numeric
#'
#' Accepts data of class POSIXct, POSIXlt or character and returns the  time of day element as numeric (any date element is ignored).
#'
#' @param x A vector of POSIXct, POSIXlt or character format time data to convert.
#' @param scale The scale on which to return times (see Value for options).
#' @param ... arguments passed to as.POSIXlt
#' @param tryFormats formats to try when converting date from character, passed to as.POSIXlt
#' @return A vector of numeric times of day in units defined by the \code{scale} argument:
#' radian, on the range [0, 2*pi];
#' hours, on the range [0, 24];
#' proportion, on the range [0, 1].
#' @seealso \code{\link{strptime}}
#' @examples
#' data(BCItime)
#' rtime <- gettime(BCItime$date)
#' htime <- gettime(BCItime$date, "hour")
#' ptime <- gettime(BCItime$date, "proportion")
#' summary(rtime)
#' summary(htime)
#' summary(ptime)
#' @export
gettime <- function(x, scale=c("radian","hour","proportion"), ...,
                    tryFormats=c("%Y-%m-%d %H:%M:%OS",
                                 "%Y/%m/%d %H:%M:%OS",
                                 "%Y:%m:%d %H:%M:%OS",
                                 "%Y-%m-%d %H:%M",
                                 "%Y/%m/%d %H:%M",
                                 "%Y:%m:%d %H:%M",
                                 "%Y-%m-%d",
                                 "%Y/%m/%d",
                                 "%Y:%m:%d")){
  scale <- match.arg(scale)
  x <- as.POSIXlt(x, tryFormats=tryFormats, ...)
  res <- x$hour + x$min/60 + x$sec/3600
  if(scale=="radian") res <- res*pi/12
  if(scale=="proportion") res <- res/24
  if(all(res==0, na.rm=T)) warning("All times are 0: may be just strptime default?")
  res
}


#' Wraps data on a given range.
#'
#' Input data outside the given bounds (default radian [0, 2*pi]) are wrapped to appear within the range.
#'
#' @details As an example of wrapping, on bounds [0, 1], a value of 1.2 will be converted to 0.2, while a value of -0.2 will be converted to 0.8.
#' @param x A vector of numeric data.
#' @param bounds The range within which to wrap \code{x} values
#' @return A vector of numeric values within the limits defined by \code{bounds}
#' @examples
#' data(BCItime)
#' adjtime <- BCItime$time + 1/24
#' summary(adjtime)
#' adjtime <- wrap(adjtime, c(0,1))
#' summary(adjtime)
#' @export
wrap <- function(x, bounds=c(0,2*pi)){
  bounds[1] + (x-bounds[1]) %% diff(bounds)
}


#' Circular mean
#'
#' Calculates the average direction of a set of radian circular values.
#'
#' @details The \code{base::mean} function is use internally, and additional arguments, e.g for missing data handling, are passed to this.
#' @param x A vector of radian values.
#' @param ... Arguments passed to \code{mean}.
#' @return A radian value giving mean direction.
#' @seealso \code{\link{mean}}
#' @examples
#' data(BCItime)
#' times <- subset(BCItime, species=="ocelot")$time*2*pi
#' cmean(times)
#' @export
cmean <- function(x, ...){
  X <- mean(cos(x), ...)
  Y <- mean(sin(x), ...)
  wrap(atan(Y/X) + ifelse(X<0,pi,0))
}

#' Calculates solar event times
#'
#' Calculates approximate times of sunrise and sunset and day lengths
#' for given dates at given locations.
#'
#' @details Function adapted from https://www.r-bloggers.com/2014/09/seeing-the-daylight-with-r/
#' @param date character, POSIX or Date format date/time value(s)
#' @param lat,lon latitude and longitude in decimal degrees
#' @param offset the time offset in hours relative to UTC (GMT) for results
#' @param ... arguments passed to as.POSIXlt
#' @param tryFormats formats to try when converting date from character, passed to as.POSIXlt
#' @return A dataframe with columns sunrise and sunset (given in the timezone defined by offset) and daylength, all expressed in hours.
#' @references Teets, D.A. 2003. Predicting sunrise and sunset times. The College Mathematics Journal 34(4):317-321.
#' @examples
#' data(BCItime)
#' dat <- subset(BCItime, species=="ocelot")$date
#' get_suntimes(dat, 9.156335, -79.847682, -5)
#' @export
get_suntimes <- function(date, lat, lon, offset, ...,
                         tryFormats=c("%Y-%m-%d %H:%M:%OS",
                                      "%Y/%m/%d %H:%M:%OS",
                                      "%Y:%m:%d %H:%M:%OS",
                                      "%Y-%m-%d %H:%M",
                                      "%Y/%m/%d %H:%M",
                                      "%Y:%m:%d %H:%M",
                                      "%Y-%m-%d",
                                      "%Y/%m/%d",
                                      "%Y:%m:%d")){
  nlat <- length(lat)
  nlon <- length(lon)
  ndat <- length(date)
  if((nlat>1 & nlat!=ndat) | (nlon>1 & nlon!=ndat))
    stop("lat and lon must have length 1 or the same length as date")
  # Day of year
  d <- as.POSIXlt(date, tryFormats=tryFormats, ...)$yday + 1
  # Radius of the earth (km)
  R <- 6378
  # Radians between the xy-plane and the ecliptic plane
  epsilon <- 23.45 * pi / 180
  # Convert observer's latitude to radians
  L <- lat * pi / 180
  # Calculate offset of sunrise based on longitude (min)
  # If lon is negative, then the mod represents degrees West of
  # a standard time meridian, so timing of sunrise and sunset should
  # be made later.
  lon_h <- 24 * lon / 360
  # The earth's mean distance from the sun (km)
  r <- 149598000
  theta <- 2 * pi / 365.25 * (d - 80)
  zs <- r * sin(theta) * sin(epsilon)
  rp <- sqrt(r^2 - zs^2)
  acos_term <- (R-zs * sin(L)) / (rp * cos(L))
  t0 <- suppressWarnings(1440 / (2*pi) * acos(acos_term))
  # A kludge adjustment for the radius of the sun
  that <- t0+5
  # Adjust "noon" for the fact that the earth's orbit is not circular:
  n <- 720 - 10 * sin(4 * pi * (d-80) / 365.25) + 8 * sin(2*pi*d / 365.25)
  ## now sunrise and sunset are:
  sunrise <- (n - that) / 60 - lon_h + offset
  sunset <- (n + that) / 60 - lon_h + offset
  daylength <- ifelse(acos_term < -1, 24,
                      ifelse(acos_term > 1, 0,
                             sunset-sunrise))
  data.frame(sunrise=sunrise, sunset=sunset, daylength=daylength)
}


#' Transforms clock time to solar time anchored to sun rise and sunset times for a given location.
#'
#' This is a wrapper for \code{transtime} that takes non-numeric date-time input together with latitude and longitude to calculate mean average sunrise and sunset times, which are then used to anchor the transformation using average anchoring.
#'
#' @details Time zone \code{tz} should be expressed in numeric hours relative to UTC (GMT).
#' @param dat A vector of character, POSIXct or POSIXlt date-time values.
#' @param lat,lon Single numeric values or numeric vectors the same length as \code{dat} giving site latitude and longitude in decimal format.
#' @param tz A single numeric value or numeric vector same length as \code{dat} giving time zone (see Details).
#' @param ... arguments passed to as.POSIXlt
#' @param tryFormats formats to try when converting date from character, passed to as.POSIXlt
#' @return A list with elements:
#' @return \code{input}: event input dates-times in POSIXlt format.
#' @return \code{clock}: radian clock time data.
#' @return \code{solar}: radian solar time data anchored to average sun rise and sun set times.
#' @references Vazquez, C., Rowcliffe, J.M., Spoelstra, K. and Jansen, P.A. in press. Comparing diel activity patterns of wildlife across latitudes and seasons: time transformation using day length. Methods in Ecology and Evolution.
#' @seealso \code{\link{strptime}, \link{transtime}}
#' @examples
#' data(BCItime)
#' subdat <- subset(BCItime, species=="ocelot")
#' times <- solartime(subdat$date, 9.156335, -79.847682, -5)
#' rawAct <- fitact(times$clock)
#' avgAct <- fitact(times$solar)
#' plot(rawAct)
#' plot(avgAct, add=TRUE, data="n", tline=list(col="cyan"))
#' @export
solartime <- function(dat, lat, lon, tz, ...,
                      tryFormats=c("%Y-%m-%d %H:%M:%OS",
                                   "%Y/%m/%d %H:%M:%OS",
                                   "%Y:%m:%d %H:%M:%OS",
                                   "%Y-%m-%d %H:%M",
                                   "%Y/%m/%d %H:%M",
                                   "%Y:%m:%d %H:%M",
                                   "%Y-%m-%d",
                                   "%Y/%m/%d",
                                   "%Y:%m:%d")){
  dat <- as.POSIXlt(dat, tryFormats=tryFormats, ...)
  posdat <- list(lat,lon,tz)
  if(!all(unlist(lapply(posdat, inherits, "numeric"))) |
     any(unlist(lapply(posdat, length)) != length(dat) &
         unlist(lapply(posdat, length)) != 1))
    stop("lat, lon and tz must all be numeric scalars, or vectors the same length as dat")

  suntimes <- wrap(get_suntimes(dat, lat, lon, tz)[,-3] * pi/12)
  tm <- gettime(dat)
  list(input=dat, clock=tm, solar=transtime(tm, suntimes))
}


#' Transforms clock time to solar times.
#'
#' Transforms time expressed relative to either the time of a single solar event (anchor times - Nouvellet et al. 2012), or two solar events (such as sun rise and sun set - Vazquez et al. in press).
#'
#' @details If double anchoring is requested (i.e. \code{type} is equinoctial
#' or average), the \code{anchor} argument requires a two-column matrix,
#' otherwise a vector. The argument \code{mnanchor} can usually be left at
#' its default \code{NULL} value. In this case, the mean anchors are set to
#' \code{c(pi/2, pi*3/2)} when \code{type}=="equinoctial", otherwise the
#' \code{anchor} mean(s).
#'
#' Although the anchors for transformation are usually likely to be solar
#' events (e.g. sun rise and/or sunset), they could be other celestial
#' (e.g. lunar) or human-related (e.g. timing of artificial lighting) events.
#' @param dat A vector of radian event clock times.
#' @param anchor A vector or matrix matched with \code{dat} containing radian anchor times on the day of each event (see Details).
#' @param mnanchor A scalar or two-element vector of numeric radian mean anchor times (see Details).
#' @param type The type of transformation to use (see Details).
#' @return  A vector of radian transformed times.
#' @references Vazquez, C., Rowcliffe, J.M., Spoelstra, K. and Jansen, P.A. in press. Comparing diel activity patterns of wildlife across latitudes and seasons: time transformation using day length. Methods in Ecology and Evolution.
#' @references Nouvellet, P., Rasmussen, G.S.A., Macdonald, D.W. and Courchamp, F. 2012. Noisy clocks and silent sunrises: measurement methods of daily activity pattern. Journal of Zoology 286: 179-184.
#' @examples
#' data(BCItime)
#' subdat <- subset(BCItime, species=="ocelot")
#' suntimes <- pi/12 * get_suntimes(subdat$date, 9.156335, -79.847682, -5)[, -3]
#' rawtimes <- subdat$time*2*pi
#' avgtimes <- transtime(rawtimes, suntimes)
#' eqntimes <- transtime(rawtimes, suntimes, type="equinoctial")
#' sngtimes <- transtime(rawtimes, suntimes[,1], type="single")
#' rawAct <- fitact(rawtimes)
#' avgAct <- fitact(avgtimes)
#' eqnAct <- fitact(eqntimes)
#' sngAct <- fitact(sngtimes)
#' plot(rawAct)
#' plot(avgAct, add=TRUE, data="n", tline=list(col="magenta"))
#' plot(eqnAct, add=TRUE, data="n", tline=list(col="orange"))
#' plot(sngAct, add=TRUE, data="n", tline=list(col="cyan"))
#' @export
transtime <- function(dat, anchor, mnanchor=NULL, type=c("average", "equinoctial", "single")){
  if(!all(dat>=0 & dat<=2*pi, na.rm=TRUE)) warning("some dat values are <0 or >2*pi, expecting radian data")
  if(max(dat, na.rm=TRUE)<1) warning("max(dat) < 1, expecting radian data")
  if(!all(anchor>=0 & anchor<=2*pi, na.rm=TRUE)) warning("some anchor values are <0 or >2*pi, expecting radian values")
  if(is.null(ncol(anchor))) anchor <- matrix(anchor, ncol=1)
  if(!all(apply(anchor, 2, is.numeric))) stop("anchor must be a numeric vector, matrix or data.frame")
  nr <- nrow(anchor)
  if(length(dat) != nr) stop("dat and anchor have different lengths")
  type <- match.arg(type)
  nc <- ncol(anchor)
  if(is.null(mnanchor)) mnanchor <- apply(anchor, 2, cmean, na.rm=TRUE)
  if(type=="single"){
    if(nc>1) warning("only one column needed for anchor; additional columns ignored")
  } else{
    if(nc==1) stop("double anchoring requires a two-column matrix or data.frame for anchor")
    if(!is.vector(mnanchor) | length(mnanchor)!=2) stop("if provided, mnanchor must be a 2-element vector for double anchoring")
    if(nc>2) warning("only two columns needed for anchor; additional columns ignored")
  }

  if(type=="single"){
    res <- wrap(mnanchor[1] + dat - anchor[,1])
  } else{
    difs <- wrap(cbind(dat,dat)-anchor)
    flip <- difs[,1]>difs[,2]
    a1 <- ifelse(flip, anchor[,2], anchor[,1])
    a2 <- ifelse(flip, anchor[,1], anchor[,2])
    relpos <- wrap(dat-a1) / wrap(a2-a1)
    interval <- switch(type,
                       "equinoctial"=pi,
                       "average"=ifelse(flip, wrap(mnanchor[1]-mnanchor[2]), wrap(mnanchor[2]-mnanchor[1]))
    )
    baseline <- switch(type,
                       "equinoctial"=ifelse(flip, pi*3/2, pi/2),
                       "average"=ifelse(flip, mnanchor[2], mnanchor[1])
    )
    res <- wrap(baseline + interval * relpos)
  }
  res
}
