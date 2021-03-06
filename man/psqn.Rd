% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/RcppExports.R
\name{psqn}
\alias{psqn}
\title{Partially Separable Function Optimization}
\usage{
psqn(
  par,
  fn,
  n_ele_func,
  rel_eps = 1e-08,
  max_it = 100L,
  n_threads = 1L,
  c1 = 1e-04,
  c2 = 0.9,
  use_bfgs = TRUE,
  trace = 0L,
  cg_tol = 0.5,
  strong_wolfe = TRUE,
  env = NULL,
  max_cg = 0L,
  pre_method = 1L
)
}
\arguments{
\item{par}{Initial values for the parameters. It is a concatenated
vector of the global parameters and all the private parameters.}

\item{fn}{Function to compute the element functions and their
derivatives. Each call computes an element function. See the examples
section.}

\item{n_ele_func}{Number of element functions.}

\item{rel_eps}{Relative convergence threshold.}

\item{max_it}{Maximum number of iterations.}

\item{n_threads}{Number of threads to use.}

\item{c1, c2}{Thresholds for the Wolfe condition.}

\item{use_bfgs}{Logical for whether to use BFGS updates or SR1 updates.}

\item{trace}{Integer where larger values gives more information during the
optimization.}

\item{cg_tol}{Threshold for the conjugate gradient method.}

\item{strong_wolfe}{\code{TRUE} if the strong Wolfe condition should be used.}

\item{env}{Environment to evaluate \code{fn} in. \code{NULL} yields the
global environment.}

\item{max_cg}{Maximum number of conjugate gradient iterations in each
iteration. Use zero if there should not be a limit.}

\item{pre_method}{Preconditioning method in the conjugate gradient method.
Zero yields no preconditioning, one yields diagonal preconditioning, and
two yields the incomplete Cholesky factorization from Eigen.}
}
\value{
An object with the following elements:
\item{par}{the estimated global and private parameters.}
\item{value}{function value at \code{par}.}
\item{info}{information code. 0 implies convergence.
-1 implies that the maximum number iterations is reached.
-2 implies that the conjugate gradient method failed.
-3 implies that the line search failed.
-4 implies that the user interrupted the optimization.}
\item{counts}{An integer vector with the number of function evaluations,
gradient evaluations, and the number of conjugate gradient iterations.}
\item{convergence}{\code{TRUE} if \code{info == 0}.}
}
\description{
Optimization method for specially structured partially separable
functions.
}
\details{
The function follows the method described by Nocedal and Wright (2006)
and mainly what is described in Section 7.4. Details are provided
in the psqn vignette. See \code{vignette("psqn", package = "psqn")}.

The partially separable function we consider are special in that the
function to be minimized is a sum of so-called element functions which
only depend on few shared (global) parameters and some
private parameters which are particular to each element function. A generic
method for other partially separable functions is available through the
\code{\link{psqn_generic}} function.

The optimization function is also available in C++ as a header-only
library. Using C++ may reduce the computation time substantially. See
the vignette in the package for examples.

You have to define the \code{PSQN_USE_EIGEN} macro variable in C++ if you want
to use the incomplete Cholesky factorization from Eigen. You will also have
to include Eigen or RcppEigen. This is not needed when you use the R
functions documented here. The incomplete Cholesky factorization comes
with some additional overhead because of the allocations of the
factorization,
forming the factorization, and the assignment of the sparse version of
the Hessian approximation.
However, it may substantially reduce the required number of conjugate
gradient iterations.
}
\examples{
# example with inner problem in a Taylor approximation for a GLMM as in the
# vignette

# assign model parameters, number of random effects, and fixed effects
q <- 2 # number of private parameters per cluster
p <- 1 # number of global parameters
beta <- sqrt((1:p) / sum(1:p))
Sigma <- diag(q)

# simulate a data set
set.seed(66608927)
n_clusters <- 20L # number of clusters
sim_dat <- replicate(n_clusters, {
  n_members <- sample.int(8L, 1L) + 2L
  X <- matrix(runif(p * n_members, -sqrt(6 / 2), sqrt(6 / 2)),
              p)
  u <- drop(rnorm(q) \%*\% chol(Sigma))
  Z <- matrix(runif(q * n_members, -sqrt(6 / 2 / q), sqrt(6 / 2 / q)),
              q)
  eta <- drop(beta \%*\% X + u \%*\% Z)
  y <- as.numeric((1 + exp(-eta))^(-1) > runif(n_members))

  list(X = X, Z = Z, y = y, u = u, Sigma_inv = solve(Sigma))
}, simplify = FALSE)

# evalutes the negative log integrand.
#
# Args:
#   i cluster/element function index.
#   par the global and private parameter for this cluster. It has length
#       zero if the number of parameters is requested. That is, a 2D integer
#       vector the number of global parameters as the first element and the
#       number of private parameters as the second element.
#   comp_grad logical for whether to compute the gradient.
r_func <- function(i, par, comp_grad){
  dat <- sim_dat[[i]]
  X <- dat$X
  Z <- dat$Z

  if(length(par) < 1)
    # requested the dimension of the parameter
    return(c(global_dim = NROW(dat$X), private_dim = NROW(dat$Z)))

  y <- dat$y
  Sigma_inv <- dat$Sigma_inv

  beta <- par[1:p]
  uhat <- par[1:q + p]
  eta <- drop(beta \%*\% X + uhat \%*\% Z)
  exp_eta <- exp(eta)

  out <- -sum(y * eta) + sum(log(1 + exp_eta)) +
    sum(uhat * (Sigma_inv \%*\% uhat)) / 2
  if(comp_grad){
    d_eta <- -y + exp_eta / (1 + exp_eta)
    grad <- c(X \%*\% d_eta,
              Z \%*\% d_eta + dat$Sigma_inv \%*\% uhat)
    attr(out, "grad") <- grad
  }

  out
}

# optimize the log integrand
res <- psqn(par = rep(0, p + q * n_clusters), fn = r_func,
            n_ele_func = n_clusters)
head(res$par, p)              # the estimated global parameters
tail(res$par, n_clusters * q) # the estimated private parameters

# compare with
beta
c(sapply(sim_dat, "[[", "u"))
}
\references{
Nocedal, J. and Wright, S. J. (2006). \emph{Numerical Optimization}
(2nd ed.). Springer.

Lin, C. and Moré, J. J. (1999). \emph{Incomplete Cholesky factorizations
with limited memory}. SIAM Journal on Scientific Computing.
}
