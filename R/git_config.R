#' Get and set Git configuration variables
#'
#' \code{git_config} and convenience wrappers \code{git_config_global} and
#' \code{git_config_local} can be used to get or set Git configuration. All
#' rely on \code{\link[git2r:config]{git2r::config}()}.
#'
#' Variables can be listed by specifying the names as strings or in a unnamed
#' list or vector of strings. Don't specify anything if you want to see them
#' all. Non-existent variables will return value \code{NULL}.
#'
#' Variables can be set by specifying them as arguments in \code{variable =
#' value} form or as a named list. To unset a variable, i.e. \code{git config
#' --unset}, specify \code{NULL} as the value.
#'
#' When variables are set, the previous values are returned in an invisible
#' named list, analogous to \code{\link{par}} or \code{\link{setwd}}. Such a
#' list can be passed back in to \code{git_config_local} or
#' \code{git_config_global} to restore the previous configuration.
#'
#' Consult the \href{https://git-scm.com/docs/git-config}{git-config man page}
#' for a long yet non-comprehensive list of variables.
#'
#' For future GitHub happiness, it is highly recommended that you set
#' \code{user.email} to an email address that is associated with your GitHub
#' account: \url{https://help.github.com/articles/setting-your-email-in-git/}.
#'
#' @param ... The Git configuration variables to get or set. If unspecified,
#'   all are returned, i.e. the output should match the result of \code{git
#'   config --list}.
#' @param where Specifies which variables. The default, \code{de_facto}, applies
#'   only to a query and requests the variables in force, i.e. where local repo
#'   variables override global user-level variables, when both are defined.
#'   \code{local} or \code{global} narrows the scope to the associated
#'   configuration file: for \code{local}, \code{.git/config} in the targetted
#'   \code{repo}, and for \code{global}, \code{~/.gitconfig} in user's home
#'   directory. When setting, if \code{where} is unspecified, the local
#'   configuration is modified.
#' @template repo
#'
#' @return A named list of Git configuration variables, with class
#'   \code{githug_list} for pretty-printing purposes.
#' @export
#'
#' @references
#'
#' \href{https://git-scm.com/book/en/v2/Getting-Started-First-Time-Git-Setup}{Getting
#' Started - First-Time Git Setup} from the Pro Git book by Scott Chacon and Ben
#' Straub
#'
#' \href{https://git-scm.com/book/en/v2/Customizing-Git-Git-Configuration}{Customizing
#' Git - Git Configuration} from the Pro Git book by Scott Chacon and Ben Straub
#'
#' \href{https://git-scm.com/docs/git-config}{git-config man page}
#'
#' @examples
#' ## see git config currently in effect, based on working directory
#' git_config()         # local > global, same as git_config(where = "de_facto")
#' git_config_local()   #                 same as git_config(where = "local")
#' git_config_global()  #                 same as git_config(where = "global")
#'
#' ## set and get global config
#' \dontrun{
#' ## set and list global config
#' git_config_global(user.name = "thelma", user.email = "thelma@example.org")
#' git_config_global("user.name", "user.email")
#' }
#'
#' ## specify a Git repo
#' repo <- git_init(tempfile("githug-config-example-"))
#' git_config_local(repo = repo)
#'
#' ## switch working directory to the repo
#' owd <- setwd(repo)
#'
#' ## set local variables for current repo
#' git_config_local(user.name = "louise", user.email = "louise@example.org")
#'
#' ## get specific local variables, including a non-existent one
#' git_config_local("user.name", "color.branch", "user.email")
#'
#' ## set local variables, then restore
#' ocfg <- git_config_local(user.name = "oops", user.email = "oops@example.org")
#' git_config_local("user.name", "user.email")
#' git_config_local(ocfg)
#' git_config_local("user.name", "user.email")
#'
#' ## set a custom variable
#' ocfg <- git_config_local(githug.lol = "wut")
#' git_config_local("githug.lol")
#'
#' setwd(owd)
git_config <- function(..., where = c("de_facto", "local", "global"),
                       repo = ".") {
  vars <- list_depth_one(list(...))
  vnames <- names(vars) %||% list_to_chr(vars)
  cfg <- git_config_get(vnames = vnames, where = where, repo = repo)
  if (!is_named(vars)) {
    return(cfg)
  }
  git_config_set(vars = vars, where = where, repo = repo)
  invisible(cfg)
}

#' @describeIn git_config Get or set global Git config, a la \code{git config
#'   --global}
#' @export
git_config_global <-
  function(..., repo = ".") git_config(..., where = "global", repo = repo)

#' @describeIn git_config Get or set local Git config, a la \code{git config
#'   --local}
#' @export
git_config_local <-
  function(..., repo = ".") git_config(..., where = "local", repo = repo)

#' Get Git config variables named in a character vector
#'
#' @export
#' @keywords internal
git_config_get <- function(vnames = character(),
                           where = c("de_facto", "local", "global"),
                           repo = ".") {
  stopifnot(is.character(vnames))
  where <- match.arg(where)
  gr <- if (is_in_repo(repo)) as.git_repository(repo) else NULL
  cfg <- git2r::config(repo = gr)
  cfg$local <- cfg$local %||% list()
  cfg$global <- cfg$global %||% list()
  cfg <- switch(where,
                de_facto = utils::modifyList(cfg$global, cfg$local),
                local = cfg$local,
                global = cfg$global)
  ## I don't think a config var can have length > 1, but I'd like to know,
  ## because I have definitely not planned for it
  if (length(cfg)) stopifnot(max(lengths(cfg)) <= 1L)
  structure(screen(cfg, vnames), class = c("githug_list", "list"))
}

#' Set Git config variables as given by a named list
#'
#' @export
#' @keywords internal
git_config_set <- function(vars,
                           where = c("de_facto", "local", "global"),
                           repo = ".") {
  stopifnot(is.list(vars), is_named(vars), max(lengths(vars)) <= 1L)
  where <- match.arg(where)
  gr <- if (is_in_repo(repo)) as.git_repository(repo) else NULL
  if (where == "de_facto") {
    message("setting where = \"local\"")
    where <- "local"
  }
  if (where == "local" && is.null(gr)) {
    stop("no git repo exists here:\n", repo, call. = FALSE)
  }
  cargs <- c(repo = gr, global = where == "global", vars)
  ncfg <- do.call(git2r::config, cargs)
  return(invisible(NULL))
}
