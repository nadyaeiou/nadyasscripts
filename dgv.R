g_multiplier <- function(n1, n2) {
  # multiplier to convert d to g
  # taken from metafor package
  degfreedom = n1 + n2 - 2
  corrector = exp(lgamma(degfreedom/2) - log(sqrt(degfreedom/2)) - lgamma((degfreedom-1)/2))
  return(corrector)
}

poolsd <- function(n1, sd1, n2, sd2) {
  # computes pooled sd
  numerator = (n1 - 1)*(sd1 ^ 2) + (n2 - 1)*(sd2 ^ 2)
  denominator = n1 + n2 - 2
  sdpooled = sqrt(numerator / denominator)
  return(sdpooled)
}

d_between <- function(n1, m1, sd1, n2, m2, sd2, g = FALSE) {
  # computes d (or g) for between-subj design
  difference = m1 - m2
  sdpooled = poolsd(n1, sd1, n2, sd2)
  d = difference / sdpooled
  if(g){d = d * g_multiplier(n1, n2)}
  return(d)
}

d_mixed <- function(n1, m1pre, m1post, sd1pre, n2, m2pre, m2post, sd2pre) {
  # computes d (or g) for mixed design (pretest-posttest-control)
  multiplier = 1 - (3 / (4*(n1+n2) - 9))
  difference = (m1post - m1pre) - (m2post - m2pre)
  sdpooled = poolsd(n1, sd1pre, n2, sd2pre)
  d = multiplier * difference / sdpooled
  return(d)
}

d_within <- function(mpost, mpre, sdpre) {
  # computes d (or g) for within-subj design
  # note that some ppl say within-subj design should not even be incl in meta
  numerator = mpost - mpre
  d = numerator / sdpre
  return(d)
}

variance_dg <- function(n1, n2, smd, method = "cooper1994") {
  # compute vd or vg, ie sampling variance
  
  if(method != "cooper1994" & method != "metafor") stop("Unknown method. Use 'cooper1994' or 'metafor' as method.")
  
  if(method == "cooper1994") {
    left = (n1 + n2) / (n1 * n2)
    right = smd^2 / (2 * (n1 + n2 - 2))
    multiplier = (n1 + n2) / (n1 + n2 - 2)
    v = (left + right) * multiplier
    return(v)
  }
  
  if(method == "metafor") {
    left = 1/n1 + 1/n2
    right = smd^2 / (2 * (n1 + n2))
    v = left + right
    return(v)
  }
}
